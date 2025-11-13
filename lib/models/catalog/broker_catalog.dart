import 'package:freezed_annotation/freezed_annotation.dart';

part 'broker_catalog.freezed.dart';
part 'broker_catalog.g.dart';

/// Broker Catalog Model
///
/// Represents a complete broker catalog with platform information,
/// features, trading conditions, and metadata.
///
/// This model matches the JSON schema defined in:
/// broker-catalogs/schema/broker-catalog.schema.json
@freezed
class BrokerCatalog with _$BrokerCatalog {
  const factory BrokerCatalog({
    /// Schema version for compatibility checking
    @JsonKey(name: 'schema_version') required String schemaVersion,

    /// Unique identifier for this broker catalog
    @JsonKey(name: 'catalog_id') required String catalogId,

    /// Human-readable name of the broker
    @JsonKey(name: 'catalog_name') required String catalogName,

    /// ISO 8601 timestamp of last catalog update
    @JsonKey(name: 'last_updated') required DateTime lastUpdated,

    /// MT4/MT5 platform availability and server information
    required BrokerPlatforms platforms,

    /// Additional broker metadata (website, regulatory bodies, etc.)
    BrokerMetadata? metadata,

    /// Trading features (min deposit, leverage, spreads, etc.)
    BrokerFeatures? features,

    /// Trading conditions (commission, swaps, hedging, etc.)
    @JsonKey(name: 'trading_conditions') TradingConditions? tradingConditions,

    /// Available account types
    @JsonKey(name: 'account_types') List<AccountType>? accountTypes,

    /// Contact information
    ContactInfo? contact,

    /// Risk disclaimer text
    String? disclaimer,
  }) = _BrokerCatalog;

  factory BrokerCatalog.fromJson(Map<String, dynamic> json) =>
      _$BrokerCatalogFromJson(json);
}

/// Broker Platform Information (MT4/MT5)
@freezed
class BrokerPlatforms with _$BrokerPlatforms {
  const factory BrokerPlatforms({
    /// MT4 platform configuration
    required PlatformConfig mt4,

    /// MT5 platform configuration
    required PlatformConfig mt5,
  }) = _BrokerPlatforms;

  factory BrokerPlatforms.fromJson(Map<String, dynamic> json) =>
      _$BrokerPlatformsFromJson(json);
}

/// Platform Configuration (MT4 or MT5)
@freezed
class PlatformConfig with _$PlatformConfig {
  const factory PlatformConfig({
    /// Whether this platform is offered by the broker
    required bool available,

    /// Demo/practice server name
    @JsonKey(name: 'demo_server') String? demoServer,

    /// List of live server names
    @JsonKey(name: 'live_servers') List<String>? liveServers,
  }) = _PlatformConfig;

  factory PlatformConfig.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigFromJson(json);
}

/// Broker Metadata
@freezed
class BrokerMetadata with _$BrokerMetadata {
  const factory BrokerMetadata({
    /// Official broker website URL
    @JsonKey(name: 'official_website') String? officialWebsite,

    /// Support email address
    @JsonKey(name: 'support_email') String? supportEmail,

    /// Support phone number
    @JsonKey(name: 'support_phone') String? supportPhone,

    /// Country where broker is headquartered (ISO 3166-1 alpha-2)
    String? country,

    /// List of regulatory bodies
    @JsonKey(name: 'regulatory_bodies') List<String>? regulatoryBodies,

    /// License/registration numbers
    @JsonKey(name: 'license_numbers') List<String>? licenseNumbers,
  }) = _BrokerMetadata;

  factory BrokerMetadata.fromJson(Map<String, dynamic> json) =>
      _$BrokerMetadataFromJson(json);
}

/// Broker Trading Features
@freezed
class BrokerFeatures with _$BrokerFeatures {
  const factory BrokerFeatures({
    /// Minimum deposit amount in USD
    @JsonKey(name: 'min_deposit') double? minDeposit,

    /// Maximum leverage ratio (e.g., 500 for 1:500)
    @JsonKey(name: 'max_leverage') int? maxLeverage,

    /// Supported base currencies (USD, EUR, GBP, etc.)
    List<String>? currencies,

    /// Tradeable instrument types (forex, commodities, indices, etc.)
    List<String>? instruments,

    /// Spread information
    SpreadInfo? spreads,
  }) = _BrokerFeatures;

  factory BrokerFeatures.fromJson(Map<String, dynamic> json) =>
      _$BrokerFeaturesFromJson(json);
}

/// Spread Information
@freezed
class SpreadInfo with _$SpreadInfo {
  const factory SpreadInfo({
    /// Typical spread description
    String? typical,

    /// Whether spreads are variable or fixed
    bool? variable,
  }) = _SpreadInfo;

  factory SpreadInfo.fromJson(Map<String, dynamic> json) =>
      _$SpreadInfoFromJson(json);
}

/// Trading Conditions
@freezed
class TradingConditions with _$TradingConditions {
  const factory TradingConditions({
    /// Commission structure
    String? commission,

    /// Whether swap-free (Islamic) accounts are available
    @JsonKey(name: 'swap_free') bool? swapFree,

    /// Whether micro lots (0.01) are supported
    @JsonKey(name: 'micro_lots') bool? microLots,

    /// Whether hedging is allowed
    @JsonKey(name: 'hedging_allowed') bool? hedgingAllowed,

    /// Whether scalping is allowed
    @JsonKey(name: 'scalping_allowed') bool? scalpingAllowed,

    /// Whether Expert Advisors (automated trading) are allowed
    @JsonKey(name: 'ea_allowed') bool? eaAllowed,
  }) = _TradingConditions;

  factory TradingConditions.fromJson(Map<String, dynamic> json) =>
      _$TradingConditionsFromJson(json);
}

/// Account Type
@freezed
class AccountType with _$AccountType {
  const factory AccountType({
    /// Account type name (Standard, ECN, Pro, VIP, etc.)
    required String name,

    /// Minimum deposit for this account type
    @JsonKey(name: 'min_deposit') double? minDeposit,

    /// Spread information for this account type
    String? spreads,

    /// Commission structure for this account type
    String? commission,
  }) = _AccountType;

  factory AccountType.fromJson(Map<String, dynamic> json) =>
      _$AccountTypeFromJson(json);
}

/// Contact Information
@freezed
class ContactInfo with _$ContactInfo {
  const factory ContactInfo({
    /// Support email address
    String? email,

    /// Support phone number
    String? phone,

    /// Live chat URL
    @JsonKey(name: 'live_chat') String? liveChat,
  }) = _ContactInfo;

  factory ContactInfo.fromJson(Map<String, dynamic> json) =>
      _$ContactInfoFromJson(json);
}
