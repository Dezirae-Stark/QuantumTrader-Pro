# Catalog Services - Integration Guide

Complete catalog loading system with Ed25519 signature verification, Hive caching, and robust error handling.

---

## 📋 Overview

The catalog system consists of 4 services:

1. **CatalogDownloader** - Downloads catalogs from GitHub
2. **CatalogVerifier** - Verifies Ed25519 signatures
3. **CatalogCache** - Local Hive storage
4. **CatalogService** - Main orchestrator (USE THIS)

**For most use cases, you only need to use `CatalogService`** - it coordinates all the other services automatically.

---

## 🚀 Quick Start

### 1. Prerequisites

**IMPORTANT:** Before running the app, generate Freezed/Hive code:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

This generates:
- `broker_catalog.freezed.dart`, `broker_catalog.g.dart`
- `catalog_metadata.freezed.dart`, `catalog_metadata.g.dart`
- `cached_catalog.g.dart` (Hive adapter)

### 2. Initialize Service

In your `main.dart`:

```dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/catalog/catalog_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize CatalogService
  final catalogService = CatalogService();
  await catalogService.initialize();

  runApp(MyApp(catalogService: catalogService));
}
```

### 3. Load Catalogs

```dart
// Load a specific catalog (cache-first)
try {
  final catalog = await catalogService.loadCatalog('sample-broker-1');
  print('Loaded: ${catalog.catalogName}');
  print('Platforms: MT4=${catalog.platforms.mt4.available}, MT5=${catalog.platforms.mt5.available}');
} catch (e) {
  print('Error loading catalog: $e');
}

// Load all available catalogs
try {
  final catalogs = await catalogService.loadAllCatalogs();
  print('Loaded ${catalogs.length} catalogs');

  for (final catalog in catalogs) {
    print('- ${catalog.catalogName} (${catalog.catalogId})');
  }
} catch (e) {
  print('Error loading catalogs: $e');
}
```

### 4. Refresh Catalogs

```dart
// Force refresh a specific catalog (skip cache)
final freshCatalog = await catalogService.refreshCatalog('sample-broker-1');

// Refresh all catalogs
final freshCatalogs = await catalogService.refreshAllCatalogs();
```

---

## 📚 API Reference

### CatalogService

Main service for loading and managing catalogs.

#### Initialization

```dart
final catalogService = CatalogService();
await catalogService.initialize();
```

#### Loading Catalogs

```dart
// Load one catalog (cache-first)
Future<BrokerCatalog> loadCatalog(String catalogId)

// Load all catalogs (cache-first)
Future<List<BrokerCatalog>> loadAllCatalogs({
  int concurrency = 3,        // Max concurrent downloads
  bool forceRefresh = false,  // Skip cache
})

// Force refresh one catalog
Future<BrokerCatalog> refreshCatalog(String catalogId)

// Force refresh all catalogs
Future<List<BrokerCatalog>> refreshAllCatalogs({
  int concurrency = 3,
})
```

#### Metadata & Cache

```dart
// Get catalog index (list of available catalogs)
Future<CatalogIndex> getCatalogIndex()

// Get cached catalog IDs
Future<List<String>> getCachedCatalogIds()

// Check if catalog is cached
Future<bool> isCatalogCached(String catalogId)

// Clear cache
Future<void> clearCache()

// Remove specific catalog
Future<void> removeCachedCatalog(String catalogId)

// Get cache statistics
Future<Map<String, dynamic>> getCacheStats()

// Get service status
Future<Map<String, dynamic>> getServiceStatus()
```

#### Cleanup

```dart
// Dispose when done
await catalogService.dispose();
```

---

## 🏗️ Architecture

### Cache-First Strategy

1. **Check cache first** (fast, works offline)
2. If cache **miss or expired**, download from GitHub
3. **Verify Ed25519 signature**
4. **Update cache** with fresh data
5. If download fails, **fallback to expired cache**

### Error Handling

- **Network errors**: Automatic retry with exponential backoff
- **Signature failures**: Catalog rejected, exception thrown
- **Download failures**: Fallback to cache (even if expired)
- **Cache errors**: Wrapped in `CatalogCacheException`

### Security

- ✅ All catalogs verified before loading (Ed25519)
- ✅ Public key hardcoded in `CatalogConstants`
- ✅ Invalid signatures result in rejection
- ✅ Signatures stored with catalogs for re-verification

---

## 🔧 Configuration

Configuration in `lib/constants/catalog_constants.dart`:

```dart
class CatalogConstants {
  // Ed25519 public key (REPLACE IN PRODUCTION)
  static const String ed25519PublicKey = 'YOUR_PUBLIC_KEY_HERE';

  // GitHub repository URLs
  static const String githubRepoUrl =
      'https://raw.githubusercontent.com/USER/REPO';
  static const String githubBranch = 'main';

  // Cache settings
  static const Duration cacheExpiry = Duration(days: 7);
  static const Duration updateCheckInterval = Duration(hours: 24);

  // Network settings
  static const Duration downloadTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Feature flags
  static const bool enableSignatureVerification = true;
  static const bool debugCatalogVerification = false;
}
```

---

## 🎯 Usage Examples

### Example 1: Display Broker List

```dart
import 'package:flutter/material.dart';
import 'services/catalog/catalog_service.dart';

class BrokerListScreen extends StatefulWidget {
  final CatalogService catalogService;

  BrokerListScreen({required this.catalogService});

  @override
  _BrokerListScreenState createState() => _BrokerListScreenState();
}

class _BrokerListScreenState extends State<BrokerListScreen> {
  List<BrokerCatalog>? catalogs;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedCatalogs = await widget.catalogService.loadAllCatalogs();

      setState(() {
        catalogs = loadedCatalogs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load brokers: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!),
            ElevatedButton(
              onPressed: _loadCatalogs,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: catalogs!.length,
      itemBuilder: (context, index) {
        final catalog = catalogs![index];
        return ListTile(
          title: Text(catalog.catalogName),
          subtitle: Text('ID: ${catalog.catalogId}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (catalog.platforms.mt4.available)
                Chip(label: Text('MT4')),
              if (catalog.platforms.mt5.available)
                Chip(label: Text('MT5')),
            ],
          ),
          onTap: () {
            // Navigate to broker details
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BrokerDetailsScreen(catalog: catalog),
              ),
            );
          },
        );
      },
    );
  }
}
```

### Example 2: Periodic Refresh

```dart
import 'dart:async';
import 'services/catalog/catalog_service.dart';

class CatalogRefreshService {
  final CatalogService _catalogService;
  Timer? _refreshTimer;

  CatalogRefreshService(this._catalogService);

  /// Start periodic refresh (every 24 hours)
  void startPeriodicRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(
      Duration(hours: 24),
      (_) => _refreshCatalogs(),
    );

    print('Started periodic catalog refresh (every 24 hours)');
  }

  Future<void> _refreshCatalogs() async {
    print('🔄 Refreshing catalogs...');

    try {
      final catalogs = await _catalogService.refreshAllCatalogs();
      print('✓ Refreshed ${catalogs.length} catalogs');
    } catch (e) {
      print('⚠️  Failed to refresh catalogs: $e');
      // Not critical - will use cache
    }
  }

  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
```

### Example 3: Cache Management

```dart
import 'services/catalog/catalog_service.dart';

Future<void> showCacheStats(CatalogService catalogService) async {
  final stats = await catalogService.getCacheStats();

  print('=== Cache Statistics ===');
  print('Total catalogs: ${stats['total_catalogs']}');
  print('Valid catalogs: ${stats['valid_catalogs']}');
  print('Expired catalogs: ${stats['expired_catalogs']}');
  print('Verified: ${stats['verified_count']}');
  print('Unverified: ${stats['unverified_count']}');
  print('Cache size: ${stats['box_size_bytes']} bytes');
}

Future<void> clearCacheIfNeeded(CatalogService catalogService) async {
  final stats = await catalogService.getCacheStats();

  final expiredCount = stats['expired_catalogs'] as int;

  if (expiredCount > 10) {
    print('⚠️  ${expiredCount} expired catalogs - clearing cache');
    await catalogService.clearCache();
    print('✓ Cache cleared');
  }
}
```

---

## 🧪 Testing

### Unit Tests Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'services/catalog/catalog_service.dart';

void main() {
  group('CatalogService', () {
    late CatalogService catalogService;

    setUp(() async {
      // Initialize Hive for testing
      await Hive.initFlutter();

      catalogService = CatalogService();
      await catalogService.initialize();
    });

    tearDown(() async {
      await catalogService.dispose();
    });

    test('should load catalog from cache', () async {
      // TODO: Add test implementation
    });

    test('should download catalog if cache miss', () async {
      // TODO: Add test implementation
    });

    test('should reject invalid signatures', () async {
      // TODO: Add test implementation
    });
  });
}
```

---

## 🔐 Security Notes

### Public Key Management

⚠️ **IMPORTANT:** Replace the demo public key before production:

1. Generate new Ed25519 key pair:
   ```bash
   cd broker-catalogs/tools
   python generate-keys.py
   ```

2. Update `lib/constants/catalog_constants.dart`:
   ```dart
   static const String ed25519PublicKey = 'YOUR_PRODUCTION_PUBLIC_KEY';
   ```

3. Sign all catalogs with the private key:
   ```bash
   python sign-catalog.py path/to/catalog.json path/to/private.key
   ```

### Signature Verification

- ALL catalogs are verified before loading
- Invalid signatures throw `CatalogVerificationException`
- No fallback to unverified catalogs
- Verification can be disabled for testing: `CatalogConstants.enableSignatureVerification = false`

---

## 🐛 Troubleshooting

### Build Errors

**Error:** "The getter 'copyWith' isn't defined"
- **Solution:** Run `dart run build_runner build --delete-conflicting-outputs`

**Error:** "MissingStubError: 'toJson'"
- **Solution:** Freezed code not generated. Run build_runner.

### Runtime Errors

**Error:** "CatalogService not initialized"
- **Solution:** Call `await catalogService.initialize()` before use

**Error:** "HiveError: Box not found"
- **Solution:** Initialize Hive: `await Hive.initFlutter()`

**Error:** "Invalid Ed25519 signature"
- **Solution:** Catalog may be corrupted or tampered with. Delete cache and re-download.

**Error:** "Network error: Failed to download catalog"
- **Solution:** Check internet connection. Service will fallback to cache if available.

---

## 📖 Additional Resources

- **PR-2 Documentation:** `broker-catalogs/README.md` - Catalog format and signing
- **Signing Guide:** `broker-catalogs/SIGNING.md` - How to sign catalogs
- **Implementation Plan:** `PR-3-PLAN.md` - Architecture and design decisions
- **Progress Report:** `PR-3-PROGRESS.md` - Development status

---

## 🤝 Contributing

When modifying the catalog services:

1. Maintain backward compatibility with existing code
2. Update this README with new features
3. Add unit tests for new functionality
4. Update PR-3-PROGRESS.md with changes
5. Follow existing error handling patterns

---

**Status:** ✅ Services layer complete and ready for integration
**Version:** PR-3 Part 2/3
**Last Updated:** 2025-11-12
