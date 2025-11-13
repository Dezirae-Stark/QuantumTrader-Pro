import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../constants/catalog_constants.dart';
import '../../models/catalog/catalog_metadata.dart';

/// Exception thrown when catalog download fails
class CatalogDownloadException implements Exception {
  final String message;
  final int? statusCode;
  final Object? originalError;

  CatalogDownloadException(
    this.message, {
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'CatalogDownloadException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${originalError != null ? ' - $originalError' : ''}';
}

/// Result of downloading a catalog (JSON + signature)
class CatalogDownloadResult {
  final String catalogJson;
  final String signatureB64;
  final DateTime downloadedAt;

  CatalogDownloadResult({
    required this.catalogJson,
    required this.signatureB64,
    required this.downloadedAt,
  });
}

/// Catalog Downloader Service
///
/// Downloads broker catalogs and signatures from GitHub repository.
/// Handles network errors, retries, and timeouts.
class CatalogDownloader {
  final http.Client _client;
  final Duration _timeout;
  final int _maxRetries;
  final Duration _retryDelay;

  CatalogDownloader({
    http.Client? client,
    Duration? timeout,
    int? maxRetries,
    Duration? retryDelay,
  })  : _client = client ?? http.Client(),
        _timeout = timeout ?? CatalogConstants.downloadTimeout,
        _maxRetries = maxRetries ?? CatalogConstants.maxRetries,
        _retryDelay = retryDelay ?? CatalogConstants.retryDelay;

  /// Download a specific broker catalog by ID
  ///
  /// Downloads both the catalog JSON file and its Ed25519 signature.
  /// Retries on network failures with exponential backoff.
  ///
  /// Throws [CatalogDownloadException] if download fails after retries.
  Future<CatalogDownloadResult> downloadCatalog(String catalogId) async {
    debugPrint('📥 Downloading catalog: $catalogId');

    // Construct URLs
    final catalogUrl = CatalogConstants.catalogUrl(catalogId);
    final signatureUrl = CatalogConstants.signatureUrl(catalogId);

    try {
      // Download catalog JSON
      final catalogJson = await _downloadWithRetry(
        catalogUrl,
        'catalog JSON',
      );

      // Download signature
      final signatureB64 = await _downloadWithRetry(
        signatureUrl,
        'signature',
      );

      final result = CatalogDownloadResult(
        catalogJson: catalogJson,
        signatureB64: signatureB64.trim(),
        downloadedAt: DateTime.now(),
      );

      debugPrint('✓ Downloaded catalog: $catalogId');
      return result;
    } catch (e) {
      debugPrint('✗ Failed to download catalog $catalogId: $e');
      rethrow;
    }
  }

  /// Download the master catalog index (list of all available catalogs)
  ///
  /// Returns a [CatalogIndex] containing metadata for all available catalogs.
  ///
  /// Throws [CatalogDownloadException] if download or parsing fails.
  Future<CatalogIndex> downloadIndex() async {
    debugPrint('📥 Downloading catalog index');

    final indexUrl = CatalogConstants.indexUrl;

    try {
      final indexJson = await _downloadWithRetry(
        indexUrl,
        'catalog index',
      );

      final indexData = jsonDecode(indexJson) as Map<String, dynamic>;
      final index = CatalogIndex.fromJson(indexData);

      debugPrint('✓ Downloaded catalog index: ${index.totalCatalogs} catalogs');
      return index;
    } catch (e) {
      debugPrint('✗ Failed to download catalog index: $e');
      if (e is FormatException) {
        throw CatalogDownloadException(
          'Failed to parse catalog index',
          originalError: e,
        );
      }
      rethrow;
    }
  }

  /// Download all catalogs listed in the index
  ///
  /// Downloads catalogs concurrently for better performance.
  /// Returns successfully downloaded catalogs, skipping any that fail.
  ///
  /// [concurrency] Maximum number of concurrent downloads (default: 3)
  Future<List<CatalogDownloadResult>> downloadAllCatalogs({
    int concurrency = 3,
  }) async {
    debugPrint('📥 Downloading all catalogs (concurrency: $concurrency)');

    try {
      // Get catalog index
      final index = await downloadIndex();

      if (index.catalogs.isEmpty) {
        debugPrint('⚠️  No catalogs available in index');
        return [];
      }

      // Download catalogs with limited concurrency
      final results = <CatalogDownloadResult>[];
      final failures = <String>[];

      for (var i = 0; i < index.catalogs.length; i += concurrency) {
        final batch = index.catalogs
            .skip(i)
            .take(concurrency)
            .map((metadata) => downloadCatalog(metadata.id));

        final batchResults = await Future.wait(
          batch,
          eagerError: false,
        );

        for (var j = 0; j < batchResults.length; j++) {
          try {
            final result = await batchResults[j];
            results.add(result);
          } catch (e) {
            final catalogId = index.catalogs[i + j].id;
            failures.add(catalogId);
            debugPrint('⚠️  Failed to download catalog: $catalogId');
          }
        }
      }

      debugPrint('✓ Downloaded ${results.length}/${index.catalogs.length} catalogs'
          '${failures.isNotEmpty ? ' (${failures.length} failed)' : ''}');

      return results;
    } catch (e) {
      debugPrint('✗ Failed to download all catalogs: $e');
      throw CatalogDownloadException(
        'Failed to download catalogs',
        originalError: e,
      );
    }
  }

  /// Download a file with retry logic and exponential backoff
  ///
  /// Internal method that handles retries for individual file downloads.
  Future<String> _downloadWithRetry(
    String url,
    String description,
  ) async {
    var attempt = 0;
    var delay = _retryDelay;

    while (true) {
      attempt++;

      try {
        return await _downloadFile(url);
      } catch (e) {
        final isLastAttempt = attempt >= _maxRetries;

        if (isLastAttempt) {
          throw CatalogDownloadException(
            'Failed to download $description after $_maxRetries attempts',
            originalError: e,
          );
        }

        // Exponential backoff
        debugPrint('⚠️  Download failed (attempt $attempt/$_maxRetries), '
            'retrying in ${delay.inSeconds}s...');

        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  /// Download a single file from URL
  ///
  /// Internal method that performs the actual HTTP GET request.
  Future<String> _downloadFile(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 404) {
        throw CatalogDownloadException(
          'File not found',
          statusCode: 404,
        );
      } else {
        throw CatalogDownloadException(
          'HTTP request failed',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw CatalogDownloadException(
        'Download timeout after ${_timeout.inSeconds}s',
      );
    } on http.ClientException catch (e) {
      throw CatalogDownloadException(
        'Network error',
        originalError: e,
      );
    }
  }

  /// Close the HTTP client
  ///
  /// Call this when done with the downloader to release resources.
  void dispose() {
    _client.close();
  }
}
