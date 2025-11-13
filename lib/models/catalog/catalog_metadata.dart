import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_metadata.freezed.dart';
part 'catalog_metadata.g.dart';

/// Catalog Index Entry
///
/// Represents an entry in the master catalog index (index.json)
@freezed
class CatalogMetadata with _$CatalogMetadata {
  const factory CatalogMetadata({
    /// Catalog unique identifier
    required String id,

    /// Human-readable broker name
    required String name,

    /// Catalog file name (e.g., "sample-broker-1.json")
    required String file,

    /// Signature file name (e.g., "sample-broker-1.json.sig")
    required String signature,

    /// ISO 8601 timestamp of last update
    @JsonKey(name: 'last_updated') required DateTime lastUpdated,
  }) = _CatalogMetadata;

  factory CatalogMetadata.fromJson(Map<String, dynamic> json) =>
      _$CatalogMetadataFromJson(json);
}

/// Catalog Index Response
///
/// Represents the complete index.json file listing all available catalogs
@freezed
class CatalogIndex with _$CatalogIndex {
  const factory CatalogIndex({
    /// Schema version
    @JsonKey(name: 'schema_version') required String schemaVersion,

    /// Timestamp when index was last updated
    @JsonKey(name: 'last_updated') required DateTime lastUpdated,

    /// Total number of catalogs
    @JsonKey(name: 'total_catalogs') required int totalCatalogs,

    /// List of available catalogs
    required List<CatalogMetadata> catalogs,
  }) = _CatalogIndex;

  factory CatalogIndex.fromJson(Map<String, dynamic> json) =>
      _$CatalogIndexFromJson(json);
}
