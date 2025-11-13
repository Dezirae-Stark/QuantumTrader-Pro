# PR-3: Android Dynamic Catalog Loader - Implementation Plan

**Status:** 🚧 In Progress
**Author:** Dezirae Stark
**Date:** 2025-11-12
**Branch:** `feature/pr3-android-catalog-loader`
**Base:** `feature/pr2-dynamic-broker-catalog`
**Depends On:** PR-1, PR-2

---

## 🎯 Objectives

### Primary Goals
- Integrate Ed25519 signature verification into Android app
- Implement catalog download from GitHub repository
- Add local catalog caching with SQLite/Hive
- Verify catalog signatures before loading
- Handle catalog updates and version management
- Provide offline catalog access

### Success Criteria
- [ ] Dart signature verification library integrated
- [ ] Catalog download service functional
- [ ] Ed25519 public key hardcoded in app
- [ ] Signature verification before catalog loading
- [ ] Local caching with persistence
- [ ] Catalog update mechanism (check for new catalogs)
- [ ] Error handling for invalid signatures
- [ ] Unit tests for verification logic
- [ ] Integration tests for download/cache flow

---

## 📋 Architecture Overview

### Component Structure

```
lib/
├── services/
│   ├── catalog_service.dart           # Main catalog management
│   ├── catalog_downloader.dart        # Download from GitHub
│   ├── catalog_verifier.dart          # Signature verification
│   └── catalog_cache.dart             # Local storage
├── models/
│   ├── broker_catalog.dart            # Catalog data model
│   ├── broker_platform.dart           # MT4/MT5 platform info
│   └── catalog_metadata.dart          # Metadata model
├── utils/
│   └── signature_verifier.dart        # Ed25519 verification (from PR-2)
└── constants/
    └── catalog_constants.dart         # Public key, URLs

test/
├── services/
│   ├── catalog_service_test.dart
│   ├── catalog_verifier_test.dart
│   └── catalog_downloader_test.dart
└── utils/
    └── signature_verifier_test.dart
```

### Data Flow

```
App Startup
    ↓
Check for cached catalogs
    ↓
If expired or missing → Download from GitHub
    ↓
Download catalog JSON + signature
    ↓
Verify Ed25519 signature with hardcoded public key
    ↓
If VALID:
    ├─ Parse catalog JSON
    ├─ Cache to local storage
    └─ Load into app state
If INVALID:
    ├─ Log security warning
    ├─ Use cached catalogs (if available)
    └─ Show error to user
```

---

## 🔐 Signature Verification Integration

### Public Key Hardcoding

**File:** `lib/constants/catalog_constants.dart`

```dart
class CatalogConstants {
  // Ed25519 public key for catalog verification
  // WARNING: Replace with production key before release!
  static const String publicKey =
      'DEMO_KEY_DO_NOT_USE_IN_PRODUCTION_PLEASE_GENERATE_NEW_KEYS==';

  // GitHub raw URLs for catalog repository
  static const String baseUrl =
      'https://raw.githubusercontent.com/Dezirae-Stark/QuantumTrader-Pro';
  static const String branch = 'main';
  static const String catalogPath = 'broker-catalogs/catalogs';

  // Catalog update settings
  static const Duration cacheExpiry = Duration(days: 7);
  static const Duration updateCheckInterval = Duration(hours: 24);
}
```

### Verification Service

**File:** `lib/services/catalog_verifier.dart`

```dart
class CatalogVerifier {
  final CatalogVerifier _signatureVerifier;

  CatalogVerifier()
      : _signatureVerifier = CatalogVerifier(
          publicKeyB64: CatalogConstants.publicKey
        );

  Future<bool> verifyCatalog(
    String catalogJson,
    String signatureB64
  ) async {
    try {
      final catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;
      return await _signatureVerifier.verifyData(catalogData, signatureB64);
    } catch (e) {
      debugPrint('Catalog verification error: $e');
      return false;
    }
  }

  Future<BrokerCatalog?> verifyAndLoad(
    String catalogJson,
    String signatureB64,
  ) async {
    if (!await verifyCatalog(catalogJson, signatureB64)) {
      throw CatalogVerificationException('Invalid signature');
    }

    final catalogData = jsonDecode(catalogJson) as Map<String, dynamic>;
    return BrokerCatalog.fromJson(catalogData);
  }
}
```

---

## 📥 Catalog Download Service

### GitHub Raw URL Construction

**File:** `lib/services/catalog_downloader.dart`

```dart
class CatalogDownloader {
  final http.Client _client;

  CatalogDownloader({http.Client? client})
      : _client = client ?? http.Client();

  Future<CatalogDownloadResult> downloadCatalog(String catalogId) async {
    final baseUrl = CatalogConstants.baseUrl;
    final branch = CatalogConstants.branch;
    final path = CatalogConstants.catalogPath;

    // Construct URLs
    final catalogUrl = '$baseUrl/$branch/$path/$catalogId.json';
    final signatureUrl = '$baseUrl/$branch/$path/$catalogId.json.sig';

    try {
      // Download catalog JSON
      final catalogResponse = await _client.get(Uri.parse(catalogUrl));
      if (catalogResponse.statusCode != 200) {
        throw CatalogDownloadException(
          'Failed to download catalog: ${catalogResponse.statusCode}'
        );
      }

      // Download signature
      final signatureResponse = await _client.get(Uri.parse(signatureUrl));
      if (signatureResponse.statusCode != 200) {
        throw CatalogDownloadException(
          'Failed to download signature: ${signatureResponse.statusCode}'
        );
      }

      return CatalogDownloadResult(
        catalogJson: catalogResponse.body,
        signatureB64: signatureResponse.body.trim(),
      );
    } catch (e) {
      throw CatalogDownloadException('Download failed: $e');
    }
  }

  Future<List<CatalogMetadata>> downloadIndex() async {
    final indexUrl = '${CatalogConstants.baseUrl}/${CatalogConstants.branch}/'
                     '${CatalogConstants.catalogPath}/index.json';

    final response = await _client.get(Uri.parse(indexUrl));
    if (response.statusCode != 200) {
      throw CatalogDownloadException('Failed to download index');
    }

    final indexData = jsonDecode(response.body) as Map<String, dynamic>;
    final catalogsList = indexData['catalogs'] as List;

    return catalogsList
        .map((c) => CatalogMetadata.fromJson(c))
        .toList();
  }
}
```

---

## 💾 Local Caching Strategy

### Storage Options

**Option 1: Hive (Chosen)**
- Fast NoSQL database for Flutter
- Type-safe with code generation
- Perfect for caching structured data
- Already used in app for settings

**Option 2: SQLite**
- Relational database
- More overhead
- Better for complex queries

**Decision: Use Hive for consistency with existing app architecture**

### Cache Structure

**File:** `lib/services/catalog_cache.dart`

```dart
@HiveType(typeId: 10)
class CachedCatalog extends HiveObject {
  @HiveField(0)
  final String catalogId;

  @HiveField(1)
  final String catalogJson;

  @HiveField(2)
  final String signatureB64;

  @HiveField(3)
  final DateTime cachedAt;

  @HiveField(4)
  final DateTime lastVerified;

  @HiveField(5)
  final bool isVerified;

  CachedCatalog({
    required this.catalogId,
    required this.catalogJson,
    required this.signatureB64,
    required this.cachedAt,
    required this.lastVerified,
    required this.isVerified,
  });
}

class CatalogCache {
  static const String boxName = 'broker_catalogs';
  late Box<CachedCatalog> _box;

  Future<void> init() async {
    Hive.registerAdapter(CachedCatalogAdapter());
    _box = await Hive.openBox<CachedCatalog>(boxName);
  }

  Future<void> cacheCatalog(
    String catalogId,
    String catalogJson,
    String signatureB64,
  ) async {
    final cached = CachedCatalog(
      catalogId: catalogId,
      catalogJson: catalogJson,
      signatureB64: signatureB64,
      cachedAt: DateTime.now(),
      lastVerified: DateTime.now(),
      isVerified: true,
    );

    await _box.put(catalogId, cached);
  }

  CachedCatalog? getCatalog(String catalogId) {
    return _box.get(catalogId);
  }

  List<CachedCatalog> getAllCatalogs() {
    return _box.values.toList();
  }

  Future<void> removeCatalog(String catalogId) async {
    await _box.delete(catalogId);
  }

  Future<void> clearCache() async {
    await _box.clear();
  }

  bool isCacheExpired(String catalogId) {
    final cached = getCatalog(catalogId);
    if (cached == null) return true;

    final age = DateTime.now().difference(cached.cachedAt);
    return age > CatalogConstants.cacheExpiry;
  }
}
```

---

## 📦 Data Models

### BrokerCatalog Model

**File:** `lib/models/broker_catalog.dart`

```dart
@freezed
class BrokerCatalog with _$BrokerCatalog {
  const factory BrokerCatalog({
    required String schemaVersion,
    required String catalogId,
    required String catalogName,
    required DateTime lastUpdated,
    required BrokerPlatforms platforms,
    BrokerMetadata? metadata,
    BrokerFeatures? features,
    TradingConditions? tradingConditions,
    List<AccountType>? accountTypes,
    ContactInfo? contact,
    String? disclaimer,
  }) = _BrokerCatalog;

  factory BrokerCatalog.fromJson(Map<String, dynamic> json) =>
      _$BrokerCatalogFromJson(json);
}

@freezed
class BrokerPlatforms with _$BrokerPlatforms {
  const factory BrokerPlatforms({
    required PlatformConfig mt4,
    required PlatformConfig mt5,
  }) = _BrokerPlatforms;

  factory BrokerPlatforms.fromJson(Map<String, dynamic> json) =>
      _$BrokerPlatformsFromJson(json);
}

@freezed
class PlatformConfig with _$PlatformConfig {
  const factory PlatformConfig({
    required bool available,
    String? demoServer,
    List<String>? liveServers,
  }) = _PlatformConfig;

  factory PlatformConfig.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigFromJson(json);
}
```

---

## 🔄 Catalog Management Service

### Main Service

**File:** `lib/services/catalog_service.dart`

```dart
class CatalogService {
  final CatalogDownloader _downloader;
  final CatalogVerifier _verifier;
  final CatalogCache _cache;

  CatalogService({
    CatalogDownloader? downloader,
    CatalogVerifier? verifier,
    CatalogCache? cache,
  })  : _downloader = downloader ?? CatalogDownloader(),
        _verifier = verifier ?? CatalogVerifier(),
        _cache = cache ?? CatalogCache();

  Future<void> init() async {
    await _cache.init();
  }

  /// Load all broker catalogs (from cache or download)
  Future<List<BrokerCatalog>> loadCatalogs({
    bool forceRefresh = false,
  }) async {
    try {
      // Download catalog index
      final index = await _downloader.downloadIndex();

      final catalogs = <BrokerCatalog>[];

      for (final metadata in index) {
        final catalog = await _loadCatalog(
          metadata.id,
          forceRefresh: forceRefresh,
        );

        if (catalog != null) {
          catalogs.add(catalog);
        }
      }

      return catalogs;
    } catch (e) {
      debugPrint('Failed to load catalogs: $e');
      // Fall back to cached catalogs
      return _loadCachedCatalogs();
    }
  }

  Future<BrokerCatalog?> _loadCatalog(
    String catalogId, {
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && !_cache.isCacheExpired(catalogId)) {
      final cached = _cache.getCatalog(catalogId);
      if (cached != null && cached.isVerified) {
        try {
          return BrokerCatalog.fromJson(
            jsonDecode(cached.catalogJson)
          );
        } catch (e) {
          debugPrint('Failed to parse cached catalog: $e');
        }
      }
    }

    // Download from GitHub
    try {
      final result = await _downloader.downloadCatalog(catalogId);

      // Verify signature
      final catalog = await _verifier.verifyAndLoad(
        result.catalogJson,
        result.signatureB64,
      );

      // Cache verified catalog
      await _cache.cacheCatalog(
        catalogId,
        result.catalogJson,
        result.signatureB64,
      );

      return catalog;
    } catch (e) {
      debugPrint('Failed to download catalog $catalogId: $e');

      // Fall back to cache
      final cached = _cache.getCatalog(catalogId);
      if (cached != null) {
        return BrokerCatalog.fromJson(
          jsonDecode(cached.catalogJson)
        );
      }

      return null;
    }
  }

  List<BrokerCatalog> _loadCachedCatalogs() {
    final cachedCatalogs = _cache.getAllCatalogs();

    return cachedCatalogs
        .where((c) => c.isVerified)
        .map((c) {
          try {
            return BrokerCatalog.fromJson(
              jsonDecode(c.catalogJson)
            );
          } catch (e) {
            return null;
          }
        })
        .whereType<BrokerCatalog>()
        .toList();
  }

  /// Force refresh all catalogs
  Future<void> refreshCatalogs() async {
    await loadCatalogs(forceRefresh: true);
  }

  /// Clear all cached catalogs
  Future<void> clearCache() async {
    await _cache.clearCache();
  }
}
```

---

## 🧪 Testing Strategy

### Unit Tests

**File:** `test/utils/signature_verifier_test.dart`

```dart
void main() {
  group('SignatureVerifier', () {
    late CatalogVerifier verifier;

    setUp(() {
      verifier = CatalogVerifier(
        publicKeyB64: 'TEST_PUBLIC_KEY',
      );
    });

    test('verifies valid signature', () async {
      final catalogData = {'catalog_id': 'test'};
      final signature = 'VALID_SIGNATURE';

      final result = await verifier.verifyData(catalogData, signature);

      expect(result, isTrue);
    });

    test('rejects invalid signature', () async {
      final catalogData = {'catalog_id': 'test'};
      final signature = 'INVALID_SIGNATURE';

      final result = await verifier.verifyData(catalogData, signature);

      expect(result, isFalse);
    });

    test('rejects tampered catalog', () async {
      final catalogData = {'catalog_id': 'tampered'};
      final signature = 'ORIGINAL_SIGNATURE';

      final result = await verifier.verifyData(catalogData, signature);

      expect(result, isFalse);
    });
  });
}
```

### Integration Tests

**File:** `test/services/catalog_service_test.dart`

```dart
void main() {
  group('CatalogService', () {
    late CatalogService service;
    late MockDownloader mockDownloader;
    late MockVerifier mockVerifier;
    late MockCache mockCache;

    setUp(() {
      mockDownloader = MockDownloader();
      mockVerifier = MockVerifier();
      mockCache = MockCache();

      service = CatalogService(
        downloader: mockDownloader,
        verifier: mockVerifier,
        cache: mockCache,
      );
    });

    test('loads catalogs from network when cache expired', () async {
      when(mockCache.isCacheExpired(any)).thenReturn(true);
      when(mockDownloader.downloadCatalog(any))
          .thenAnswer((_) async => CatalogDownloadResult(...));
      when(mockVerifier.verifyAndLoad(any, any))
          .thenAnswer((_) async => BrokerCatalog(...));

      final catalogs = await service.loadCatalogs();

      expect(catalogs, isNotEmpty);
      verify(mockDownloader.downloadCatalog(any)).called(greaterThan(0));
    });

    test('uses cached catalogs when available and not expired', () async {
      when(mockCache.isCacheExpired(any)).thenReturn(false);
      when(mockCache.getCatalog(any)).thenReturn(CachedCatalog(...));

      final catalogs = await service.loadCatalogs();

      expect(catalogs, isNotEmpty);
      verifyNever(mockDownloader.downloadCatalog(any));
    });

    test('rejects catalog with invalid signature', () async {
      when(mockDownloader.downloadCatalog(any))
          .thenAnswer((_) async => CatalogDownloadResult(...));
      when(mockVerifier.verifyAndLoad(any, any))
          .thenThrow(CatalogVerificationException('Invalid'));

      final catalog = await service._loadCatalog('test');

      expect(catalog, isNull);
    });
  });
}
```

---

## 📱 User Experience Flow

### App Startup

1. **Show splash screen**
2. **Initialize catalog service**
3. **Load catalogs** (cached or download)
4. **Verify signatures** in background
5. **Display broker selection** when ready

### Catalog Update

1. **Check for updates** (periodically or manual)
2. **Download new catalogs** if available
3. **Verify signatures**
4. **Update cache**
5. **Notify user** of new brokers

### Error Handling

**Invalid Signature:**
```
❌ Security Warning
Broker catalog signature verification failed.
This catalog may have been tampered with.

[Use Cached Catalogs] [Retry Download]
```

**Network Error:**
```
⚠️ Connection Error
Could not download broker catalogs.
Using cached catalogs from [date].

[Retry] [Continue Offline]
```

---

## 🔐 Security Considerations

### Public Key Protection
- Hardcoded in app (cannot be changed without app update)
- Stored in constants file with clear documentation
- Production key must replace demo key before release

### Signature Verification
- All catalogs verified before use
- Invalid signatures rejected completely
- No fallback to unverified catalogs
- Tampered catalogs logged for security audit

### Cache Security
- Hive box can be encrypted
- Store signature alongside catalog
- Re-verify on app updates
- Clear cache on public key change

### Network Security
- HTTPS for all downloads (GitHub)
- Certificate pinning recommended
- Timeout for downloads
- Retry logic with exponential backoff

---

## 📊 Dependencies

### pubspec.yaml Updates

```yaml
dependencies:
  # Existing dependencies...

  # Cryptography for Ed25519
  cryptography: ^2.5.0

  # HTTP client
  http: ^1.1.0

  # Local storage (already in project)
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # JSON serialization (already in project)
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  # Existing dev dependencies...

  # Code generation
  build_runner: ^2.4.6
  freezed: ^2.4.5
  json_serializable: ^6.7.1
  hive_generator: ^2.0.1

  # Testing
  mockito: ^5.4.2
  integration_test:
    sdk: flutter
```

---

## 🚀 Implementation Phases

### Phase 1: Foundation
- [x] Create PR-3 branch
- [ ] Add dependencies to pubspec.yaml
- [ ] Copy signature_verifier.dart from broker-catalogs/lib
- [ ] Create catalog constants with public key

### Phase 2: Models
- [ ] Create BrokerCatalog model with freezed
- [ ] Create BrokerPlatforms model
- [ ] Create supporting models (metadata, features, etc.)
- [ ] Generate JSON serialization code

### Phase 3: Services
- [ ] Implement CatalogDownloader
- [ ] Implement CatalogVerifier
- [ ] Implement CatalogCache with Hive
- [ ] Implement main CatalogService

### Phase 4: Integration
- [ ] Update main.dart to initialize catalog service
- [ ] Create catalog provider with Riverpod
- [ ] Add catalog loading on app startup
- [ ] Handle errors gracefully

### Phase 5: Testing
- [ ] Write unit tests for signature verification
- [ ] Write unit tests for downloader
- [ ] Write integration tests for service
- [ ] Manual testing with demo catalogs

### Phase 6: Documentation
- [ ] Update README with catalog loading info
- [ ] Document public key replacement procedure
- [ ] Add troubleshooting section
- [ ] Create PR-3.md documentation

---

## ✅ Acceptance Criteria

- [ ] Dart signature verification working
- [ ] Catalogs downloaded from GitHub
- [ ] Signatures verified before loading
- [ ] Local caching with Hive
- [ ] Catalog updates handled
- [ ] Error handling comprehensive
- [ ] Unit tests passing (>80% coverage)
- [ ] Integration tests passing
- [ ] Documentation complete
- [ ] Demo public key clearly marked

---

**Status**: Planning complete, beginning implementation...
