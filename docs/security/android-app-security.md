# Android App Security

**Last Updated:** 2025-01-12
**Version:** 1.0
**Applies To:** QuantumTrader Pro Android Application

---

## Overview

This document describes the security measures implemented in the QuantumTrader Pro Android application to protect user credentials, network communications, and build artifacts.

---

## Security Features

### 1. Network Security Configuration

**File:** `android/app/src/main/res/xml/network_security_config.xml`

**Purpose:** Enforces TLS-only communication and prevents cleartext (HTTP) traffic.

**Key Policies:**
- ✅ **HTTP Blocked:** All cleartext traffic is prohibited by default
- ✅ **HTTPS Required:** Only encrypted TLS connections allowed
- ✅ **Certificate Pinning Ready:** Infrastructure for pinning API certificates
- ✅ **Debug Certificates Restricted:** Prevents use of dev certificates in production

**localhost Exception:**
For local development testing, localhost/127.0.0.1/192.168.x.x are allowed cleartext. Remove this exception for production builds.

**Certificate Pinning (Optional):**
To enable certificate pinning for your API endpoints:

```bash
# Get certificate SHA-256 hash
openssl s_client -connect api.yourserver.com:443 < /dev/null | \
  openssl x509 -pubkey -noout | \
  openssl rsa -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64
```

Then uncomment and configure the pinning section in `network_security_config.xml`.

### 2. Secure Credential Storage

**Dependency:** `flutter_secure_storage: ^9.0.0`

**Purpose:** Stores sensitive credentials in Android Keystore, encrypted hardware-backed storage.

**Usage Example:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Store credentials securely
await storage.write(key: 'mt4_login', value: loginValue);
await storage.write(key: 'mt4_password', value: passwordValue);

// Retrieve credentials
final login = await storage.read(key: 'mt4_login');
final password = await storage.read(key: 'mt4_password');

// Delete credentials
await storage.delete(key: 'mt4_login');
await storage.deleteAll(); // Clear all stored data
```

**Security Benefits:**
- Encrypted with hardware-backed keys (Android Keystore)
- Inaccessible to other apps or rooted devices (best effort)
- Survives app updates
- Automatically deleted on app uninstall

**Important:** Never store credentials in SharedPreferences or plain text files!

### 3. Build Watermark (Traceability)

**File:** `android/app/build.gradle`

**Purpose:** Embeds git commit hash and build timestamp into APK for incident tracing.

**What's Included:**
- `GIT_COMMIT_HASH`: Short git commit hash (e.g., "a1b2c3d")
- `BUILD_TIMESTAMP`: Unix timestamp of build time

**Access in Kotlin/Java:**
```kotlin
import com.quantumtrader.pro.BuildConfig

val gitHash = BuildConfig.GIT_COMMIT_HASH
val buildTimestamp = BuildConfig.BUILD_TIMESTAMP
```

**Use Cases:**
- Trace APK back to exact source code version
- Verify authenticity of build
- Incident response: identify vulnerable code versions
- Supply chain auditing

---

## AndroidManifest Changes

**Before (Insecure):**
```xml
<application
    ...
    android:usesCleartextTraffic="true">
```

**After (Secure):**
```xml
<application
    ...
    android:networkSecurityConfig="@xml/network_security_config">
```

**Impact:**
- HTTP connections now fail with `java.io.IOException: Cleartext HTTP traffic not permitted`
- Forces all network traffic over HTTPS
- Protects credentials from network sniffing

---

## Testing

### Verify Network Security

**Test HTTP Blocking:**
```dart
// This should FAIL with network security config
final response = await http.get(Uri.parse('http://insecure-api.com/data'));
// Expected error: Cleartext HTTP traffic not permitted
```

**Test HTTPS Success:**
```dart
// This should SUCCEED
final response = await http.get(Uri.parse('https://secure-api.com/data'));
```

### Verify Secure Storage

```dart
// Store test data
await storage.write(key: 'test_key', value: 'secret_data');

// Verify retrieval
final retrieved = await storage.read(key: 'test_key');
assert(retrieved == 'secret_data');

// Verify deletion
await storage.delete(key: 'test_key');
final deleted = await storage.read(key: 'test_key');
assert(deleted == null);
```

### Verify Build Watermark

```bash
# Build APK
flutter build apk

# Extract BuildConfig
unzip -p build/app/outputs/flutter-apk/app-release.apk \
  classes.dex | \
  grep -a "GIT_COMMIT_HASH"

# Should show embedded git hash
```

---

## Best Practices

### Credential Handling

1. **Always use flutter_secure_storage for:**
   - MT4/MT5 login credentials
   - API tokens/keys
   - Telegram bot tokens
   - Any sensitive user data

2. **Never use SharedPreferences for:**
   - Passwords or API keys
   - Personally identifiable information (PII)
   - Financial data

3. **Clear credentials on:**
   - User logout
   - App uninstall
   - Account deletion

### Network Security

1. **Always use HTTPS endpoints** for:
   - Bridge server connections
   - API calls
   - WebSocket connections (WSS)

2. **Implement certificate pinning for:**
   - Production API servers
   - Bridge server connections
   - High-value transactions

3. **Update pinned certificates:**
   - Before certificate expiration
   - Include backup pins to avoid lockout
   - Test certificate rotation process

### Build Security

1. **Sign release builds** with production keystore
2. **Never commit keystore files** to git
3. **Verify build watermark** before distributing APK
4. **Document build provenance** for audits

---

## Migration Guide

### Migrating from SharedPreferences to Secure Storage

**Old (Insecure):**
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('password', userPassword); // INSECURE!
final password = prefs.getString('password');
```

**New (Secure):**
```dart
final storage = FlutterSecureStorage();
await storage.write(key: 'password', value: userPassword); // SECURE
final password = await storage.read(key: 'password');
```

**Migration Script:**
```dart
Future<void> migrateCredentials() async {
  final prefs = await SharedPreferences.getInstance();
  final storage = FlutterSecureStorage();

  // Migrate existing credentials
  final oldPassword = prefs.getString('password');
  if (oldPassword != null) {
    await storage.write(key: 'password', value: oldPassword);
    await prefs.remove('password'); // Delete old insecure storage
  }

  // Repeat for other sensitive keys
}
```

---

## Troubleshooting

### "Cleartext HTTP traffic not permitted"

**Cause:** Attempting HTTP connection with network security config.

**Solution:**
1. Change endpoint to HTTPS
2. For local development, verify localhost exception in config
3. For production, never allow cleartext traffic

### "Unable to access secure storage"

**Cause:** Android Keystore issues (device-specific).

**Solution:**
1. Check Android version (requires API 18+, best on 23+)
2. Handle exceptions gracefully with fallback:
```dart
try {
  await storage.write(key: 'data', value: value);
} catch (e) {
  // Fallback or user notification
  print('Secure storage unavailable: $e');
}
```

### "Build watermark shows 'unknown'"

**Cause:** Git not available during build.

**Solution:**
1. Verify git installed: `git --version`
2. Ensure building inside git repository
3. Check CI/CD has git access

---

## References

- [Android Network Security Config](https://developer.android.com/training/articles/security-config)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

---

## Change Log

| Date       | Version | Changes |
|------------|---------|---------|
| 2025-01-12 | 1.0     | Initial Android security documentation |

---

**Questions?** Open an issue with the `android` or `security` label.
