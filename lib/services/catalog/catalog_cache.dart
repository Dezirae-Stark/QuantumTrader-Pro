import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../constants/catalog_constants.dart';
import '../../models/catalog/cached_catalog.dart';

/// Exception thrown when cache operations fail
class CatalogCacheException implements Exception {
  final String message;
  final Object? originalError;

  CatalogCacheException(
    this.message, {
    this.originalError,
  });

  @override
  String toString() => 'CatalogCacheException: $message'
      '${originalError != null ? ' - $originalError' : ''}';
}

/// Catalog Cache Service
///
/// Manages local storage of broker catalogs using Hive.
/// Handles cache expiry, cleanup, and statistics.
class CatalogCache {
  static const String _boxName = 'broker_catalogs';
  Box<CachedCatalog>? _box;

  /// Initialize the cache (open Hive box)
  ///
  /// Must be called before any other cache operations.
  /// Safe to call multiple times - will return existing box if already open.
  Future<void> initialize() async {
    if (_box != null && _box!.isOpen) {
      debugPrint('✓ Catalog cache already initialized');
      return;
    }

    try {
      // Register adapter if not already registered
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(CachedCatalogAdapter());
      }

      _box = await Hive.openBox<CachedCatalog>(_boxName);
      debugPrint('✓ Catalog cache initialized: ${_box!.length} catalogs');
    } catch (e) {
      throw CatalogCacheException(
        'Failed to initialize catalog cache',
        originalError: e,
      );
    }
  }

  /// Ensure box is initialized before operations
  void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw CatalogCacheException(
        'Cache not initialized. Call initialize() first.',
      );
    }
  }

  /// Cache a catalog
  ///
  /// Stores the catalog in Hive with verification status and timestamps.
  /// Overwrites existing catalog with same ID.
  Future<void> cacheCatalog({
    required String catalogId,
    required String catalogJson,
    required String signatureB64,
    required bool isVerified,
    String? schemaVersion,
    String? catalogName,
  }) async {
    _ensureInitialized();

    try {
      final cached = CachedCatalog(
        catalogId: catalogId,
        catalogJson: catalogJson,
        signatureB64: signatureB64,
        cachedAt: DateTime.now(),
        lastVerified: DateTime.now(),
        isVerified: isVerified,
        schemaVersion: schemaVersion,
        catalogName: catalogName,
      );

      await _box!.put(catalogId, cached);

      if (CatalogConstants.debugCatalogVerification) {
        debugPrint('✓ Cached catalog: $catalogId (verified: $isVerified)');
      }
    } catch (e) {
      throw CatalogCacheException(
        'Failed to cache catalog: $catalogId',
        originalError: e,
      );
    }
  }

  /// Get a cached catalog by ID
  ///
  /// Returns null if catalog not found or expired.
  /// Does NOT verify signature - caller should re-verify if needed.
  Future<CachedCatalog?> getCatalog(String catalogId) async {
    _ensureInitialized();

    try {
      final cached = _box!.get(catalogId);

      if (cached == null) {
        if (CatalogConstants.debugCatalogVerification) {
          debugPrint('⚠️  Cache miss: $catalogId');
        }
        return null;
      }

      // Check if expired
      if (cached.isExpired(CatalogConstants.cacheExpiry)) {
        if (CatalogConstants.debugCatalogVerification) {
          debugPrint('⚠️  Cache expired: $catalogId');
        }
        return null;
      }

      if (CatalogConstants.debugCatalogVerification) {
        debugPrint('✓ Cache hit: $catalogId');
      }

      return cached;
    } catch (e) {
      throw CatalogCacheException(
        'Failed to get cached catalog: $catalogId',
        originalError: e,
      );
    }
  }

  /// Get all cached catalogs (including expired)
  ///
  /// Returns empty list if no catalogs cached.
  Future<List<CachedCatalog>> getAllCatalogs() async {
    _ensureInitialized();

    try {
      return _box!.values.toList();
    } catch (e) {
      throw CatalogCacheException(
        'Failed to get all cached catalogs',
        originalError: e,
      );
    }
  }

  /// Get all valid (non-expired) cached catalogs
  ///
  /// Filters out expired catalogs automatically.
  Future<List<CachedCatalog>> getValidCatalogs() async {
    final allCatalogs = await getAllCatalogs();

    return allCatalogs
        .where((c) => !c.isExpired(CatalogConstants.cacheExpiry))
        .toList();
  }

  /// Get expired catalogs
  ///
  /// Returns catalogs that have exceeded the expiry duration.
  Future<List<CachedCatalog>> getExpiredCatalogs() async {
    final allCatalogs = await getAllCatalogs();

    return allCatalogs
        .where((c) => c.isExpired(CatalogConstants.cacheExpiry))
        .toList();
  }

  /// Check if a catalog exists and is valid (not expired)
  Future<bool> hasValidCatalog(String catalogId) async {
    final cached = await getCatalog(catalogId);
    return cached != null;
  }

  /// Remove a specific catalog from cache
  Future<void> removeCatalog(String catalogId) async {
    _ensureInitialized();

    try {
      await _box!.delete(catalogId);
      debugPrint('✓ Removed catalog from cache: $catalogId');
    } catch (e) {
      throw CatalogCacheException(
        'Failed to remove catalog: $catalogId',
        originalError: e,
      );
    }
  }

  /// Clear all catalogs from cache
  Future<void> clearCache() async {
    _ensureInitialized();

    try {
      final count = _box!.length;
      await _box!.clear();
      debugPrint('✓ Cleared cache: $count catalogs removed');
    } catch (e) {
      throw CatalogCacheException(
        'Failed to clear cache',
        originalError: e,
      );
    }
  }

  /// Cleanup expired catalogs
  ///
  /// Removes all catalogs that have exceeded the expiry duration.
  /// Returns the number of catalogs removed.
  Future<int> cleanupExpiredCatalogs() async {
    _ensureInitialized();

    try {
      final expired = await getExpiredCatalogs();

      if (expired.isEmpty) {
        debugPrint('✓ Cache cleanup: no expired catalogs');
        return 0;
      }

      for (final catalog in expired) {
        await _box!.delete(catalog.catalogId);
      }

      debugPrint('✓ Cache cleanup: removed ${expired.length} expired catalogs');
      return expired.length;
    } catch (e) {
      throw CatalogCacheException(
        'Failed to cleanup expired catalogs',
        originalError: e,
      );
    }
  }

  /// Update verification status for a cached catalog
  ///
  /// Updates lastVerified timestamp and isVerified flag.
  /// Useful for periodic re-verification without re-downloading.
  Future<void> updateVerificationStatus({
    required String catalogId,
    required bool isVerified,
  }) async {
    _ensureInitialized();

    try {
      final cached = _box!.get(catalogId);

      if (cached == null) {
        throw CatalogCacheException(
          'Catalog not found in cache: $catalogId',
        );
      }

      // Create updated copy with new verification status
      final updated = CachedCatalog(
        catalogId: cached.catalogId,
        catalogJson: cached.catalogJson,
        signatureB64: cached.signatureB64,
        cachedAt: cached.cachedAt,
        lastVerified: DateTime.now(),
        isVerified: isVerified,
        schemaVersion: cached.schemaVersion,
        catalogName: cached.catalogName,
      );

      await _box!.put(catalogId, updated);

      if (CatalogConstants.debugCatalogVerification) {
        debugPrint('✓ Updated verification status: $catalogId (verified: $isVerified)');
      }
    } catch (e) {
      if (e is CatalogCacheException) rethrow;

      throw CatalogCacheException(
        'Failed to update verification status: $catalogId',
        originalError: e,
      );
    }
  }

  /// Get cache statistics
  ///
  /// Returns metadata about the cache state for debugging and monitoring.
  Future<Map<String, dynamic>> getCacheStats() async {
    _ensureInitialized();

    try {
      final allCatalogs = await getAllCatalogs();
      final validCatalogs = await getValidCatalogs();
      final expiredCatalogs = await getExpiredCatalogs();

      final verifiedCount = validCatalogs.where((c) => c.isVerified).length;
      final unverifiedCount = validCatalogs.where((c) => !c.isVerified).length;

      DateTime? oldestCache;
      DateTime? newestCache;

      if (allCatalogs.isNotEmpty) {
        oldestCache = allCatalogs
            .map((c) => c.cachedAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        newestCache = allCatalogs
            .map((c) => c.cachedAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      return {
        'total_catalogs': allCatalogs.length,
        'valid_catalogs': validCatalogs.length,
        'expired_catalogs': expiredCatalogs.length,
        'verified_count': verifiedCount,
        'unverified_count': unverifiedCount,
        'oldest_cache': oldestCache?.toIso8601String(),
        'newest_cache': newestCache?.toIso8601String(),
        'cache_expiry_days': CatalogConstants.cacheExpiry.inDays,
        'box_size_bytes': _box!.length * 4096, // Rough estimate
      };
    } catch (e) {
      throw CatalogCacheException(
        'Failed to get cache statistics',
        originalError: e,
      );
    }
  }

  /// Get list of cached catalog IDs
  Future<List<String>> getCatalogIds() async {
    _ensureInitialized();

    try {
      final allCatalogs = await getAllCatalogs();
      return allCatalogs.map((c) => c.catalogId).toList();
    } catch (e) {
      throw CatalogCacheException(
        'Failed to get catalog IDs',
        originalError: e,
      );
    }
  }

  /// Close the cache (close Hive box)
  ///
  /// Call this when the cache is no longer needed.
  /// Safe to call multiple times.
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
      debugPrint('✓ Catalog cache closed');
    }
  }

  /// Check if cache is initialized
  bool get isInitialized => _box != null && _box!.isOpen;

  /// Get number of cached catalogs
  int get catalogCount => _box?.length ?? 0;
}
