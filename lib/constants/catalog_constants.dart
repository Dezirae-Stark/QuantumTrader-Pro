/// Broker Catalog Constants
///
/// This file contains Ed25519 public key and GitHub repository URLs
/// for broker catalog verification and download.
///
/// ⚠️ IMPORTANT: Replace demo public key with production key before release!

class CatalogConstants {
  CatalogConstants._(); // Private constructor to prevent instantiation

  // =========================================================================
  // Ed25519 PUBLIC KEY (for catalog signature verification)
  // =========================================================================

  /// Ed25519 public key for verifying broker catalog signatures.
  ///
  /// ⚠️ WARNING: This is a DEMO KEY for development/testing only!
  ///
  /// Before production release:
  /// 1. Generate new Ed25519 key pair: `python3 broker-catalogs/tools/generate-keys.py`
  /// 2. Replace this constant with your production public key
  /// 3. Re-sign all broker catalogs with production private key
  /// 4. Test signature verification thoroughly
  ///
  /// Security: This public key is SAFE to hardcode in the app.
  /// It's used to verify catalog signatures and cannot be used to sign catalogs.
  static const String ed25519PublicKey =
      'DEMO_KEY_DO_NOT_USE_IN_PRODUCTION_PLEASE_GENERATE_NEW_KEYS==';

  // =========================================================================
  // GitHub Repository URLs
  // =========================================================================

  /// Base GitHub repository URL
  static const String githubRepoUrl =
      'https://raw.githubusercontent.com/Dezirae-Stark/QuantumTrader-Pro';

  /// Branch to fetch catalogs from
  ///
  /// Use 'main' for production, 'develop' for testing
  static const String githubBranch = 'main';

  /// Path to broker-catalogs directory in repository
  static const String catalogBasePath = 'broker-catalogs/catalogs';

  /// Full URL pattern for catalog downloads
  ///
  /// Example: https://raw.githubusercontent.com/.../main/broker-catalogs/catalogs/sample-broker-1.json
  static String catalogUrl(String catalogId) =>
      '$githubRepoUrl/$githubBranch/$catalogBasePath/$catalogId.json';

  /// Full URL pattern for signature downloads
  ///
  /// Example: https://raw.githubusercontent.com/.../main/broker-catalogs/catalogs/sample-broker-1.json.sig
  static String signatureUrl(String catalogId) =>
      '$githubRepoUrl/$githubBranch/$catalogBasePath/$catalogId.json.sig';

  /// URL for catalog index (master list of all catalogs)
  static String get indexUrl =>
      '$githubRepoUrl/$githubBranch/$catalogBasePath/index.json';

  // =========================================================================
  // Cache Settings
  // =========================================================================

  /// How long to cache broker catalogs before checking for updates
  static const Duration cacheExpiry = Duration(days: 7);

  /// How often to check for catalog updates in background
  static const Duration updateCheckInterval = Duration(hours: 24);

  /// Maximum age of catalog before forcing refresh
  static const Duration maxCatalogAge = Duration(days: 30);

  // =========================================================================
  // Network Settings
  // =========================================================================

  /// HTTP request timeout for catalog downloads
  static const Duration downloadTimeout = Duration(seconds: 30);

  /// Number of retry attempts for failed downloads
  static const int maxRetries = 3;

  /// Delay between retry attempts (exponential backoff)
  static const Duration retryDelay = Duration(seconds: 2);

  // =========================================================================
  // Local Storage
  // =========================================================================

  /// Hive box name for storing cached broker catalogs
  static const String catalogBoxName = 'broker_catalogs';

  /// Hive box name for catalog metadata (last update times, etc.)
  static const String metadataBoxName = 'catalog_metadata';

  // =========================================================================
  // Feature Flags
  // =========================================================================

  /// Enable signature verification (should always be true in production)
  static const bool enableSignatureVerification = true;

  /// Allow loading catalogs with expired signatures (DANGEROUS - for testing only)
  static const bool allowExpiredSignatures = false;

  /// Enable automatic catalog updates in background
  static const bool enableAutoUpdate = true;

  /// Show debug information about catalog verification
  static const bool debugCatalogVerification = false;

  // =========================================================================
  // Error Messages
  // =========================================================================

  static const String errorInvalidSignature =
      'Catalog signature verification failed. This catalog may have been tampered with.';

  static const String errorDownloadFailed =
      'Failed to download broker catalog. Please check your internet connection.';

  static const String errorCacheMissing =
      'No cached catalogs available. Please connect to the internet to download broker catalogs.';

  static const String errorParsingFailed =
      'Failed to parse broker catalog. The catalog may be corrupted.';

  // =========================================================================
  // User-Facing Messages
  // =========================================================================

  static const String messageVerifyingCatalog =
      'Verifying broker catalog...';

  static const String messageDownloadingCatalogs =
      'Downloading broker catalogs...';

  static const String messageUsingCachedCatalogs =
      'Using cached broker catalogs';

  static const String messageUpdatingCatalogs =
      'Checking for catalog updates...';

  // =========================================================================
  // Development/Testing
  // =========================================================================

  /// Sample catalog IDs for testing
  static const List<String> sampleCatalogIds = [
    'sample-broker-1',
    'sample-broker-2',
  ];

  /// Enable mock catalogs for offline development (REMOVE in production)
  static const bool useMockCatalogs = false;

  // =========================================================================
  // Version Information
  // =========================================================================

  /// Catalog schema version this app supports
  static const String supportedSchemaVersion = '1.0.0';

  /// Minimum catalog schema version for compatibility
  static const String minimumSchemaVersion = '1.0.0';
}
