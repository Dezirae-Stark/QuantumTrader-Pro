/// Broker Catalog Signature Verifier - Dart/Flutter Library
///
/// Ed25519 signature verification for broker catalogs in Flutter/Dart.
/// Used by QuantumTrader Pro Android app to verify downloaded catalogs.
///
/// Usage Example:
/// ```dart
/// import 'package:your_package/signature_verifier.dart';
///
/// final verifier = CatalogVerifier(publicKeyB64: 'YOUR_PUBLIC_KEY');
///
/// // Verify catalog data
/// if (verifier.verifyData(catalogData, signatureB64)) {
///   print('Valid catalog!');
/// }
/// ```
///
/// Dependencies (add to pubspec.yaml):
/// ```yaml
/// dependencies:
///   cryptography: ^2.5.0
/// ```

import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Exception thrown when catalog verification fails
class CatalogVerificationException implements Exception {
  final String message;
  CatalogVerificationException(this.message);

  @override
  String toString() => 'CatalogVerificationException: $message';
}

/// Ed25519 signature verifier for broker catalogs
class CatalogVerifier {
  final String publicKeyB64;
  final SimplePublicKey _publicKey;

  /// Initialize verifier with public key
  ///
  /// [publicKeyB64] Base64-encoded Ed25519 public key (44 characters)
  ///
  /// Throws [CatalogVerificationException] if public key is invalid
  CatalogVerifier({required this.publicKeyB64})
      : _publicKey = _decodePublicKey(publicKeyB64);

  static SimplePublicKey _decodePublicKey(String publicKeyB64) {
    try {
      final publicKeyBytes = base64.decode(publicKeyB64);
      return SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    } catch (e) {
      throw CatalogVerificationException('Invalid public key: $e');
    }
  }

  /// Canonicalize JSON for deterministic verification
  ///
  /// [data] Map to canonicalize
  ///
  /// Returns canonical JSON string (sorted keys, no whitespace)
  static String canonicalizeJson(Map<String, dynamic> data) {
    // Sort keys recursively
    Map<String, dynamic> sortedMap(Map<String, dynamic> map) {
      final sorted = <String, dynamic>{};
      final keys = map.keys.toList()..sort();
      for (final key in keys) {
        final value = map[key];
        if (value is Map<String, dynamic>) {
          sorted[key] = sortedMap(value);
        } else if (value is List) {
          sorted[key] = value.map((e) {
            if (e is Map<String, dynamic>) {
              return sortedMap(e);
            }
            return e;
          }).toList();
        } else {
          sorted[key] = value;
        }
      }
      return sorted;
    }

    final sorted = sortedMap(data);
    return jsonEncode(sorted);
  }

  /// Verify signature of catalog data
  ///
  /// [catalogData] Map containing catalog data
  /// [signatureB64] Base64-encoded Ed25519 signature
  ///
  /// Returns true if signature is valid, false otherwise
  ///
  /// Throws [CatalogVerificationException] if verification process fails
  Future<bool> verifyData(
    Map<String, dynamic> catalogData,
    String signatureB64,
  ) async {
    try {
      // Canonicalize JSON
      final canonicalJson = canonicalizeJson(catalogData);
      final message = utf8.encode(canonicalJson);

      // Decode signature
      final signature = Signature(
        base64.decode(signatureB64),
        publicKey: _publicKey,
      );

      // Verify signature
      final algorithm = Ed25519();
      final isValid = await algorithm.verify(message, signature: signature);

      return isValid;
    } on CatalogVerificationException {
      rethrow;
    } catch (e) {
      throw CatalogVerificationException('Verification failed: $e');
    }
  }

  /// Verify and load catalog if valid
  ///
  /// [catalogJson] JSON string of catalog
  /// [signatureB64] Base64-encoded Ed25519 signature
  ///
  /// Returns catalog data map if signature is valid
  ///
  /// Throws [CatalogVerificationException] if signature is invalid
  Future<Map<String, dynamic>> verifyAndLoad(
    String catalogJson,
    String signatureB64,
  ) async {
    // Parse JSON
    final catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;

    // Verify signature
    final isValid = await verifyData(catalogData, signatureB64);

    if (!isValid) {
      throw CatalogVerificationException(
        'Invalid signature - catalog may be tampered',
      );
    }

    return catalogData;
  }

  /// Download and verify catalog from URL
  ///
  /// [catalogUrl] URL to catalog JSON file
  /// [signatureUrl] URL to signature file
  ///
  /// Returns catalog data map if signature is valid
  ///
  /// Throws [CatalogVerificationException] if signature is invalid
  /// or download fails
  ///
  /// Note: Requires http package. Add to pubspec.yaml:
  /// ```yaml
  /// dependencies:
  ///   http: ^1.1.0
  /// ```
  Future<Map<String, dynamic>> downloadAndVerify(
    String catalogUrl,
    String signatureUrl,
  ) async {
    try {
      // Import http dynamically (optional dependency)
      final http = await import('package:http/http.dart') as dynamic;

      // Download catalog
      final catalogResponse = await http.get(Uri.parse(catalogUrl));
      if (catalogResponse.statusCode != 200) {
        throw CatalogVerificationException(
          'Failed to download catalog: HTTP ${catalogResponse.statusCode}',
        );
      }

      // Download signature
      final signatureResponse = await http.get(Uri.parse(signatureUrl));
      if (signatureResponse.statusCode != 200) {
        throw CatalogVerificationException(
          'Failed to download signature: HTTP ${signatureResponse.statusCode}',
        );
      }

      final catalogJson = catalogResponse.body;
      final signatureB64 = signatureResponse.body.trim();

      // Verify and load
      return await verifyAndLoad(catalogJson, signatureB64);
    } catch (e) {
      if (e is CatalogVerificationException) rethrow;
      throw CatalogVerificationException('Download failed: $e');
    }
  }
}

/// Convenience function for one-off verification
///
/// [catalogJson] JSON string of catalog
/// [signatureB64] Base64-encoded Ed25519 signature
/// [publicKeyB64] Base64-encoded Ed25519 public key
///
/// Returns true if signature is valid, false otherwise
Future<bool> verifyCatalog(
  String catalogJson,
  String signatureB64,
  String publicKeyB64,
) async {
  final verifier = CatalogVerifier(publicKeyB64: publicKeyB64);
  final catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;
  return await verifier.verifyData(catalogData, signatureB64);
}

/// Example usage
void main() async {
  // Example public key (replace with actual key)
  const publicKey = 'YOUR_PUBLIC_KEY_BASE64';

  // Example catalog JSON
  const catalogJson = '''
  {
    "schema_version": "1.0.0",
    "catalog_id": "example-broker",
    "catalog_name": "Example Broker",
    "last_updated": "2025-11-12T00:00:00Z",
    "platforms": {
      "mt4": {"available": true},
      "mt5": {"available": true}
    }
  }
  ''';

  // Example signature
  const signature = 'SIGNATURE_BASE64';

  try {
    final verifier = CatalogVerifier(publicKeyB64: publicKey);
    final isValid = await verifier.verifyAndLoad(catalogJson, signature);

    if (isValid != null) {
      print('✓ Signature VALID');
      print('Catalog ID: ${isValid['catalog_id']}');
    }
  } on CatalogVerificationException catch (e) {
    print('✗ $e');
  }
}
