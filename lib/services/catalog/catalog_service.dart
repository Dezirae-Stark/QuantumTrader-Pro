import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../constants/catalog_constants.dart';
import '../../models/catalog/broker_catalog.dart';
import '../../models/catalog/catalog_metadata.dart';
import 'catalog_cache.dart';
import 'catalog_downloader.dart';
import 'catalog_verifier.dart';

/// Exception thrown when catalog service operations fail
class CatalogServiceException implements Exception {
  final String message;
  final String? catalogId;
  final Object? originalError;

  CatalogServiceException(
    this.message, {
    this.catalogId,
    this.originalError,
  });

  @override
  String toString() => 'CatalogServiceException: $message'
      '${catalogId != null ? ' (catalog: $catalogId)' : ''}' '${originalError != null ? ' - $originalError' : ''}';
}

/// Catalog Service - Main Orchestrator
///
/// High-level service for loading, verifying, and caching broker catalogs.
/// Implements cache-first strategy with automatic fallback and retry logic.
///
/// Usage:
/// ```dart
/// final catalogService = CatalogService();
/// await catalogService.initialize();
///
/// // Load a specific catalog (cache-first)
/// final catalog = await catalogService.loadCatalog('sample-broker-1');
///
/// // Load all available catalogs
/// final catalogs = await catalogService.loadAllCatalogs();
///
/// // Force refresh a catalog
/// await catalogService.refreshCatalog('sample-broker-1');
/// ```
class CatalogService {
  final CatalogDownloader _downloader;
  final CatalogVerifier _verifier;
  final CatalogCache _cache;

  bool _isInitialized = false;

  CatalogService({
    CatalogDownloader? downloader,
    CatalogVerifier? verifier,
    CatalogCache? cache,
  })  : _downloader = downloader ?? CatalogDownloader(),
        _verifier = verifier ?? CatalogVerifier(),
        _cache = cache ?? CatalogCache();

  /// Initialize the catalog service
  ///
  /// Must be called before any other operations.
  /// Safe to call multiple times.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('✓ CatalogService already initialized');
      return;
    }

    try {
      debugPrint('🚀 Initializing CatalogService...');

      // Initialize cache (Hive)
      await _cache.initialize();

      // Cleanup expired catalogs on startup
      await _cache.cleanupExpiredCatalogs();

      _isInitialized = true;
      debugPrint('✓ CatalogService initialized');
    } catch (e) {
      throw CatalogServiceException(
        'Failed to initialize CatalogService',
        originalError: e,
      );
    }
  }

  /// Ensure service is initialized before operations
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw CatalogServiceException(
        'CatalogService not initialized. Call initialize() first.',
      );
    }
  }

  /// Load a catalog by ID (cache-first strategy)
  ///
  /// 1. Check cache first (fast)
  /// 2. If cache miss or expired, download and verify
  /// 3. Update cache with fresh data
  /// 4. Return verified BrokerCatalog
  ///
  /// Throws [CatalogServiceException] if catalog cannot be loaded.
  Future<BrokerCatalog> loadCatalog(String catalogId) async {
    _ensureInitialized();

    debugPrint('📂 Loading catalog: $catalogId');

    try {
      // Step 1: Check cache
      final cached = await _cache.getCatalog(catalogId);

      if (cached != null && cached.isVerified) {
        debugPrint('✓ Using cached catalog: $catalogId');

        // Parse and return cached catalog
        final catalogData = jsonDecode(cached.catalogJson) as Map<String, dynamic>;
        return BrokerCatalog.fromJson(catalogData);
      }

      // Step 2: Cache miss or expired - download fresh data
      debugPrint('📥 Cache miss for $catalogId - downloading...');

      final downloadResult = await _downloader.downloadCatalog(catalogId);

      // Step 3: Verify signature
      final catalog = await _verifier.verifyAndLoad(
        downloadResult.catalogJson,
        downloadResult.signatureB64,
      );

      // Step 4: Update cache
      await _cache.cacheCatalog(
        catalogId: catalogId,
        catalogJson: downloadResult.catalogJson,
        signatureB64: downloadResult.signatureB64,
        isVerified: true,
        schemaVersion: catalog.schemaVersion,
        catalogName: catalog.catalogName,
      );

      debugPrint('✓ Loaded and cached catalog: $catalogId');
      return catalog;
    } catch (e) {
      // If download fails, try to use cached version even if expired
      final cached = await _cache.getCatalog(catalogId);

      if (cached != null) {
        debugPrint('⚠️  Download failed, using expired cache for: $catalogId');

        final catalogData = jsonDecode(cached.catalogJson) as Map<String, dynamic>;
        return BrokerCatalog.fromJson(catalogData);
      }

      throw CatalogServiceException(
        'Failed to load catalog',
        catalogId: catalogId,
        originalError: e,
      );
    }
  }

  /// Load all available catalogs
  ///
  /// 1. Downloads catalog index
  /// 2. Loads each catalog (cache-first)
  /// 3. Returns successfully loaded catalogs
  /// 4. Skips catalogs that fail to load
  ///
  /// [concurrency] Maximum number of concurrent downloads (default: 3)
  /// [forceRefresh] Skip cache and download fresh data (default: false)
  Future<List<BrokerCatalog>> loadAllCatalogs({
    int concurrency = 3,
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();

    debugPrint('📂 Loading all catalogs (concurrency: $concurrency, forceRefresh: $forceRefresh)');

    try {
      // Get catalog index
      final index = await _downloader.downloadIndex();

      if (index.catalogs.isEmpty) {
        debugPrint('⚠️  No catalogs available in index');
        return [];
      }

      debugPrint('📋 Found ${index.catalogs.length} catalogs in index');

      // Load catalogs with limited concurrency
      final catalogs = <BrokerCatalog>[];
      final failures = <String>[];

      for (var i = 0; i < index.catalogs.length; i += concurrency) {
        final batch = index.catalogs
            .skip(i)
            .take(concurrency)
            .map((metadata) => forceRefresh
                ? refreshCatalog(metadata.id)
                : loadCatalog(metadata.id));

        final batchResults = await Future.wait(
          batch,
          eagerError: false,
        );

        for (var j = 0; j < batchResults.length; j++) {
          try {
            final catalog = await batchResults[j];
            catalogs.add(catalog);
          } catch (e) {
            final catalogId = index.catalogs[i + j].id;
            failures.add(catalogId);
            debugPrint('⚠️  Failed to load catalog: $catalogId - $e');
          }
        }
      }

      debugPrint('✓ Loaded ${catalogs.length}/${index.catalogs.length} catalogs'
          '${failures.isNotEmpty ? ' (${failures.length} failed)' : ''}');

      return catalogs;
    } catch (e) {
      throw CatalogServiceException(
        'Failed to load all catalogs',
        originalError: e,
      );
    }
  }

  /// Force refresh a catalog (skip cache, download fresh)
  ///
  /// Downloads and verifies the latest catalog, then updates cache.
  /// Use this when you need to ensure you have the latest data.
  Future<BrokerCatalog> refreshCatalog(String catalogId) async {
    _ensureInitialized();

    debugPrint('🔄 Refreshing catalog: $catalogId');

    try {
      // Download fresh data
      final downloadResult = await _downloader.downloadCatalog(catalogId);

      // Verify signature
      final catalog = await _verifier.verifyAndLoad(
        downloadResult.catalogJson,
        downloadResult.signatureB64,
      );

      // Update cache
      await _cache.cacheCatalog(
        catalogId: catalogId,
        catalogJson: downloadResult.catalogJson,
        signatureB64: downloadResult.signatureB64,
        isVerified: true,
        schemaVersion: catalog.schemaVersion,
        catalogName: catalog.catalogName,
      );

      debugPrint('✓ Refreshed catalog: $catalogId');
      return catalog;
    } catch (e) {
      throw CatalogServiceException(
        'Failed to refresh catalog',
        catalogId: catalogId,
        originalError: e,
      );
    }
  }

  /// Refresh all catalogs (download fresh data for all)
  ///
  /// Forces download and verification of all catalogs.
  /// Updates cache with fresh data.
  ///
  /// [concurrency] Maximum number of concurrent downloads (default: 3)
  Future<List<BrokerCatalog>> refreshAllCatalogs({
    int concurrency = 3,
  }) async {
    return loadAllCatalogs(
      concurrency: concurrency,
      forceRefresh: true,
    );
  }

  /// Get the catalog index (list of available catalogs)
  ///
  /// Returns metadata about all available catalogs without downloading them.
  Future<CatalogIndex> getCatalogIndex() async {
    _ensureInitialized();

    try {
      return await _downloader.downloadIndex();
    } catch (e) {
      throw CatalogServiceException(
        'Failed to get catalog index',
        originalError: e,
      );
    }
  }

  /// Get list of cached catalog IDs
  ///
  /// Returns IDs of all locally cached catalogs (including expired).
  Future<List<String>> getCachedCatalogIds() async {
    _ensureInitialized();

    try {
      return await _cache.getCatalogIds();
    } catch (e) {
      throw CatalogServiceException(
        'Failed to get cached catalog IDs',
        originalError: e,
      );
    }
  }

  /// Check if a catalog is cached and valid
  Future<bool> isCatalogCached(String catalogId) async {
    _ensureInitialized();

    try {
      return await _cache.hasValidCatalog(catalogId);
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached catalogs
  ///
  /// Removes all locally stored catalogs.
  /// Next loadCatalog() call will download fresh data.
  Future<void> clearCache() async {
    _ensureInitialized();

    try {
      await _cache.clearCache();
      debugPrint('✓ Cleared all cached catalogs');
    } catch (e) {
      throw CatalogServiceException(
        'Failed to clear cache',
        originalError: e,
      );
    }
  }

  /// Remove a specific catalog from cache
  Future<void> removeCachedCatalog(String catalogId) async {
    _ensureInitialized();

    try {
      await _cache.removeCatalog(catalogId);
      debugPrint('✓ Removed cached catalog: $catalogId');
    } catch (e) {
      throw CatalogServiceException(
        'Failed to remove cached catalog',
        catalogId: catalogId,
        originalError: e,
      );
    }
  }

  /// Get cache statistics
  ///
  /// Returns metadata about the cache state for monitoring and debugging.
  Future<Map<String, dynamic>> getCacheStats() async {
    _ensureInitialized();

    try {
      return await _cache.getCacheStats();
    } catch (e) {
      throw CatalogServiceException(
        'Failed to get cache statistics',
        originalError: e,
      );
    }
  }

  /// Get service status
  ///
  /// Returns diagnostic information about the service state.
  Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final cacheStats = _isInitialized
          ? await _cache.getCacheStats()
          : <String, dynamic>{};

      return {
        'initialized': _isInitialized,
        'signature_verification_enabled':
            CatalogConstants.enableSignatureVerification,
        'cache_expiry_days': CatalogConstants.cacheExpiry.inDays,
        'cached_catalogs': cacheStats['total_catalogs'] ?? 0,
        'valid_catalogs': cacheStats['valid_catalogs'] ?? 0,
        'expired_catalogs': cacheStats['expired_catalogs'] ?? 0,
      };
    } catch (e) {
      return {
        'initialized': _isInitialized,
        'error': e.toString(),
      };
    }
  }

  /// Check if service is initialized and ready
  bool get isInitialized => _isInitialized;

  /// Dispose of the service and release resources
  ///
  /// Closes cache, HTTP client, and cleans up resources.
  /// Service cannot be used after dispose() - must call initialize() again.
  Future<void> dispose() async {
    try {
      await _cache.dispose();
      _downloader.dispose();
      _isInitialized = false;
      debugPrint('✓ CatalogService disposed');
    } catch (e) {
      debugPrint('⚠️  Error disposing CatalogService: $e');
    }
  }
}
