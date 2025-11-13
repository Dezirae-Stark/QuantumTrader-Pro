import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../constants/catalog_constants.dart';
import '../../models/catalog/broker_catalog.dart';
import '../../utils/signature_verifier.dart';

/// Exception thrown when catalog verification fails
class CatalogVerificationException implements Exception {
  final String message;
  final String? catalogId;
  final Object? originalError;

  CatalogVerificationException(
    this.message, {
    this.catalogId,
    this.originalError,
  });

  @override
  String toString() => 'CatalogVerificationException: $message'
      '${catalogId != null ? ' (catalog: $catalogId)' : ''}'
      '${originalError != null ? ' - $originalError' : ''}';
}

/// Catalog Verifier Service
///
/// Wraps the Ed25519 signature verification library for broker catalogs.
/// Verifies catalog integrity before allowing them to be loaded into the app.
class CatalogVerifier {
  final CatalogVerifier _signatureVerifier;

  CatalogVerifier({String? publicKey})
      : _signatureVerifier = CatalogVerifier(
          publicKeyB64: publicKey ?? CatalogConstants.ed25519PublicKey,
        );

  /// Verify a catalog's Ed25519 signature
  ///
  /// Returns true if signature is valid, false otherwise.
  /// Does not throw exceptions - use for simple verification checks.
  ///
  /// [catalogJson] The raw catalog JSON string
  /// [signatureB64] The base64-encoded Ed25519 signature
  Future<bool> verifyCatalog(
    String catalogJson,
    String signatureB64,
  ) async {
    if (!CatalogConstants.enableSignatureVerification) {
      debugPrint('⚠️  Signature verification DISABLED');
      return true;
    }

    try {
      final catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;
      final catalogId = catalogData['catalog_id'] as String?;

      if (CatalogConstants.debugCatalogVerification) {
        debugPrint('🔍 Verifying catalog: ${catalogId ?? 'unknown'}');
      }

      final isValid = await _signatureVerifier.verifyData(
        catalogData,
        signatureB64,
      );

      if (CatalogConstants.debugCatalogVerification) {
        debugPrint('${isValid ? '✓' : '✗'} Signature verification: '
            '${isValid ? 'VALID' : 'INVALID'}');
      }

      return isValid;
    } catch (e) {
      debugPrint('✗ Catalog verification error: $e');
      return false;
    }
  }

  /// Verify and load a catalog
  ///
  /// Verifies the catalog signature and parses it into a [BrokerCatalog] model.
  /// Throws [CatalogVerificationException] if signature is invalid or parsing fails.
  ///
  /// [catalogJson] The raw catalog JSON string
  /// [signatureB64] The base64-encoded Ed25519 signature
  Future<BrokerCatalog> verifyAndLoad(
    String catalogJson,
    String signatureB64,
  ) async {
    // Parse catalog data first to get ID for error messages
    late Map<String, dynamic> catalogData;
    String? catalogId;

    try {
      catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;
      catalogId = catalogData['catalog_id'] as String?;
    } catch (e) {
      throw CatalogVerificationException(
        'Failed to parse catalog JSON',
        originalError: e,
      );
    }

    // Verify signature
    if (CatalogConstants.enableSignatureVerification) {
      final isValid = await verifyCatalog(catalogJson, signatureB64);

      if (!isValid) {
        throw CatalogVerificationException(
          'Invalid Ed25519 signature - catalog may have been tampered with',
          catalogId: catalogId,
        );
      }
    } else if (CatalogConstants.debugCatalogVerification) {
      debugPrint('⚠️  Signature verification DISABLED - loading unverified catalog');
    }

    // Parse into BrokerCatalog model
    try {
      final catalog = BrokerCatalog.fromJson(catalogData);

      // Validate schema version
      if (!_isSchemaVersionCompatible(catalog.schemaVersion)) {
        throw CatalogVerificationException(
          'Incompatible schema version: ${catalog.schemaVersion} '
          '(supported: ${CatalogConstants.supportedSchemaVersion})',
          catalogId: catalogId,
        );
      }

      return catalog;
    } catch (e) {
      if (e is CatalogVerificationException) rethrow;

      throw CatalogVerificationException(
        'Failed to parse catalog model',
        catalogId: catalogId,
        originalError: e,
      );
    }
  }

  /// Verify multiple catalogs concurrently
  ///
  /// Returns a map of catalog ID to verification result (true = valid, false = invalid).
  /// Does not throw exceptions - failed verifications return false.
  Future<Map<String, bool>> verifyMultipleCatalogs(
    Map<String, CatalogData> catalogs,
  ) async {
    final results = <String, bool>{};

    final futures = catalogs.entries.map((entry) async {
      final catalogId = entry.key;
      final data = entry.value;

      try {
        final isValid = await verifyCatalog(
          data.catalogJson,
          data.signatureB64,
        );
        results[catalogId] = isValid;
      } catch (e) {
        debugPrint('✗ Error verifying catalog $catalogId: $e');
        results[catalogId] = false;
      }
    });

    await Future.wait(futures);

    final validCount = results.values.where((v) => v).length;
    debugPrint('✓ Verified ${results.length} catalogs: '
        '$validCount valid, ${results.length - validCount} invalid');

    return results;
  }

  /// Check if catalog schema version is compatible with app
  bool _isSchemaVersionCompatible(String schemaVersion) {
    try {
      final parts = schemaVersion.split('.');
      final major = int.parse(parts[0]);
      final minor = parts.length > 1 ? int.parse(parts[1]) : 0;

      final supportedParts = CatalogConstants.supportedSchemaVersion.split('.');
      final supportedMajor = int.parse(supportedParts[0]);
      final supportedMinor = supportedParts.length > 1 ? int.parse(supportedParts[1]) : 0;

      // Compatible if major version matches and minor version >= minimum
      return major == supportedMajor && minor >= supportedMinor;
    } catch (e) {
      debugPrint('⚠️  Failed to parse schema version: $schemaVersion');
      return false;
    }
  }

  /// Get verification statistics for debugging
  Map<String, dynamic> getVerificationStats() {
    return {
      'enabled': CatalogConstants.enableSignatureVerification,
      'supported_schema': CatalogConstants.supportedSchemaVersion,
      'minimum_schema': CatalogConstants.minimumSchemaVersion,
      'debug_mode': CatalogConstants.debugCatalogVerification,
    };
  }
}

/// Helper class to hold catalog data for batch verification
class CatalogData {
  final String catalogJson;
  final String signatureB64;

  CatalogData({
    required this.catalogJson,
    required this.signatureB64,
  });
}
