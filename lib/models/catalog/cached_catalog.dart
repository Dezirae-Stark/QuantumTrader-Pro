import 'package:hive/hive.dart';

part 'cached_catalog.g.dart';

/// Cached Broker Catalog
///
/// Stored in Hive for offline access and performance.
/// Contains the raw JSON and signature for re-verification.
@HiveType(typeId: 10)
class CachedCatalog extends HiveObject {
  /// Unique catalog identifier
  @HiveField(0)
  final String catalogId;

  /// Raw catalog JSON string
  @HiveField(1)
  final String catalogJson;

  /// Base64-encoded Ed25519 signature
  @HiveField(2)
  final String signatureB64;

  /// When this catalog was first cached
  @HiveField(3)
  final DateTime cachedAt;

  /// When signature was last verified
  @HiveField(4)
  final DateTime lastVerified;

  /// Whether signature verification passed
  @HiveField(5)
  final bool isVerified;

  /// Catalog schema version (for compatibility)
  @HiveField(6)
  final String? schemaVersion;

  /// Catalog name (for display without parsing JSON)
  @HiveField(7)
  final String? catalogName;

  CachedCatalog({
    required this.catalogId,
    required this.catalogJson,
    required this.signatureB64,
    required this.cachedAt,
    required this.lastVerified,
    required this.isVerified,
    this.schemaVersion,
    this.catalogName,
  });

  /// Check if cache is expired based on configured expiry duration
  bool isExpired(Duration expiryDuration) {
    final age = DateTime.now().difference(cachedAt);
    return age > expiryDuration;
  }

  /// Check if verification is stale (needs re-verification)
  bool needsReverification(Duration reverificationInterval) {
    final age = DateTime.now().difference(lastVerified);
    return age > reverificationInterval;
  }

  @override
  String toString() {
    return 'CachedCatalog('
        'id: $catalogId, '
        'name: $catalogName, '
        'verified: $isVerified, '
        'cached: $cachedAt, '
        'lastVerified: $lastVerified'
        ')';
  }
}
