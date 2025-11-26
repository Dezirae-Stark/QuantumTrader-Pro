# QuantumTrader-Pro Android Environment Setup

## Overview

This document provides complete setup instructions for building and deploying the QuantumTrader-Pro Android application, including development environment setup, build configuration, and deployment procedures.

## System Requirements

### Development Machine Requirements
- **OS:** Windows 10+, macOS 10.14+, Linux (64-bit)
- **RAM:** 8GB minimum, 16GB recommended
- **Storage:** 20GB free space
- **CPU:** Intel i5 or equivalent

### Android Device Requirements
- **Android Version:** 7.0 (API 24) or higher
- **RAM:** 2GB minimum
- **Storage:** 100MB free space
- **Network:** 4G/5G or Wi-Fi

## Development Environment Setup

### 1. Install Flutter SDK

**Windows:**
```powershell
# Download Flutter SDK
# From: https://flutter.dev/docs/get-started/install/windows

# Extract to C:\flutter
# Add to PATH: C:\flutter\bin

# Verify installation
flutter --version
flutter doctor
```

**macOS:**
```bash
# Using Homebrew
brew install --cask flutter

# Or manual installation
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Add to ~/.zshrc or ~/.bashrc
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
```

**Linux:**
```bash
# Download and extract
cd ~/development
tar xf flutter_linux_3.19.0-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"

# Add to ~/.bashrc
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc

# Install dependencies
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### 2. Install Android Studio

**All Platforms:**
1. Download from: https://developer.android.com/studio
2. Install Android Studio
3. During setup, install:
   - Android SDK
   - Android SDK Command-line Tools
   - Android SDK Build-Tools
   - Android Emulator

### 3. Configure Android SDK

```bash
# Set environment variables
# Windows (add to System Environment Variables)
ANDROID_HOME = C:\Users\%USERNAME%\AppData\Local\Android\Sdk

# macOS/Linux (add to ~/.bashrc or ~/.zshrc)
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

### 4. Accept Android Licenses

```bash
flutter doctor --android-licenses
# Accept all licenses
```

### 5. Install Additional Tools

```bash
# VS Code (recommended)
# Install Flutter extension
code --install-extension Dart-Code.flutter

# Android Studio plugins
# Open Android Studio → Plugins
# Install: Flutter, Dart
```

## Project Setup

### 1. Clone and Navigate

```bash
git clone https://github.com/yourusername/QuantumTrader-Pro.git
cd QuantumTrader-Pro
```

### 2. Install Flutter Dependencies

```bash
# Get all dependencies
flutter pub get

# Verify project
flutter analyze
```

### 3. Generate Required Files

```bash
# Generate code for models
flutter pub run build_runner build --delete-conflicting-outputs

# This creates:
# - Freezed models
# - JSON serialization
# - Hive adapters
```

### 4. Android-Specific Configuration

**Create Keystore (for release builds):**
```bash
# Navigate to android directory
cd android

# Generate keystore
keytool -genkey -v -keystore quantumtrader.jks -keyalg RSA -keysize 2048 -validity 10000 -alias quantumtrader

# Create key.properties from template
cp key.properties.template key.properties

# Edit key.properties
nano key.properties
```

**key.properties content:**
```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=quantumtrader
storeFile=../quantumtrader.jks
```

**Important:** Add to .gitignore:
```bash
echo "android/key.properties" >> .gitignore
echo "android/quantumtrader.jks" >> .gitignore
```

### 5. Configure Bridge Server Endpoint

**Update lib/services/mt4_service.dart:**
```dart
class MT4Service {
  // Change from localhost to your bridge server IP
  String _apiEndpoint = 'http://192.168.1.100:8080'; // Your local IP
  
  // Or use platform-specific configuration
  String _apiEndpoint = Platform.isAndroid 
    ? 'http://10.0.2.2:8080'  // Android emulator
    : 'http://localhost:8080'; // iOS simulator
}
```

### 6. Configure Network Permissions

**Verify android/app/src/main/AndroidManifest.xml:**
```xml
<manifest>
    <!-- Internet permissions (should already be present) -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    
    <!-- For notifications -->
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    
    <application
        android:name="${applicationName}"
        android:label="QuantumTrader Pro"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false"> <!-- Set to true for dev only -->
```

## Building the Application

### 1. Debug Build

```bash
# Connect device via USB or start emulator
adb devices  # Verify device is connected

# Run in debug mode
flutter run

# Or specify device
flutter run -d <device-id>
```

### 2. Profile Build

```bash
# For performance testing
flutter run --profile
```

### 3. Release Build

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Output locations:
# APK: build/app/outputs/flutter-apk/app-release.apk
# Bundle: build/app/outputs/bundle/release/app-release.aab
```

### 4. Build Variants

```bash
# Split APKs by ABI (smaller size)
flutter build apk --release --split-per-abi

# This creates:
# app-arm64-v8a-release.apk
# app-armeabi-v7a-release.apk
# app-x86_64-release.apk
```

## Testing on Devices

### 1. Android Emulator

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch Pixel_7_API_33

# Run app on emulator
flutter run
```

### 2. Physical Device

**Enable Developer Options:**
1. Settings → About Phone
2. Tap "Build Number" 7 times
3. Enable Developer Options
4. Enable USB Debugging

**Connect and Run:**
```bash
# Verify device connection
adb devices

# Run on device
flutter run -d <device-id>

# Install release APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 3. Wireless Debugging (Android 11+)

```bash
# Enable Wireless debugging on device
# Get pairing code from device

# Pair device
adb pair <ip:port>

# Connect
adb connect <ip:port>

# Run app
flutter run
```

## Environment-Specific Configurations

### 1. Development Environment

**Create .env.development:**
```env
API_ENDPOINT=http://10.0.2.2:8080
LOG_LEVEL=debug
ENABLE_MOCK_DATA=true
```

### 2. Staging Environment

**Create .env.staging:**
```env
API_ENDPOINT=https://staging.quantumtrader.com
LOG_LEVEL=info
ENABLE_MOCK_DATA=false
```

### 3. Production Environment

**Create .env.production:**
```env
API_ENDPOINT=https://api.quantumtrader.com
LOG_LEVEL=error
ENABLE_MOCK_DATA=false
```

## Performance Optimization

### 1. Enable R8/ProGuard

**android/app/build.gradle:**
```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### 2. Optimize Images

```bash
# Install image optimizer
npm install -g imageoptim-cli

# Optimize assets
imageoptim 'assets/icons/**/*.png'
```

### 3. Reduce APK Size

```bash
# Analyze APK size
flutter build apk --analyze-size

# Use app bundles for Play Store
flutter build appbundle
```

## Debugging Tools

### 1. Flutter Inspector

```bash
# Run with Flutter Inspector
flutter run --debug

# In VS Code: Run → Start Debugging
# In Android Studio: Run → Debug
```

### 2. Performance Profiling

```bash
# CPU profiling
flutter run --profile --trace-startup

# Memory profiling
flutter run --profile --dart-define=FLUTTER_PROFILE_MODE=true
```

### 3. Network Debugging

**Using Charles Proxy:**
1. Install Charles Proxy
2. Configure device proxy settings
3. Install Charles certificate on device
4. Monitor API calls

**Using Flutter DevTools:**
```bash
# Launch DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Network tab shows all HTTP requests
```

## Common Issues & Solutions

### 1. Build Failures

**Issue: Gradle build failed**
```bash
# Clean and rebuild
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

**Issue: Duplicate class errors**
```bash
# Update dependencies
flutter pub upgrade
flutter pub deps

# Force resolve conflicts
flutter pub cache repair
```

### 2. Runtime Issues

**Issue: Network requests failing**
- Check API endpoint configuration
- Verify network permissions
- Test with `curl` from device

**Issue: White screen on launch**
```bash
# Check logs
adb logcat | grep flutter

# Common causes:
# - Missing internet permission
# - Incorrect API endpoint
# - Crash in initialization
```

### 3. Performance Issues

**Issue: Slow app startup**
- Enable R8/ProGuard
- Reduce initial data loads
- Implement splash screen properly

**Issue: Janky scrolling**
- Use `ListView.builder` for long lists
- Implement image caching
- Profile with Flutter DevTools

## Deployment

### 1. Google Play Store

**Preparation:**
1. Create developer account ($25 one-time fee)
2. Prepare store listing assets:
   - App icon (512x512)
   - Feature graphic (1024x500)
   - Screenshots (min 2, max 8)
   - App description
   - Privacy policy

**Upload Process:**
```bash
# Build app bundle
flutter build appbundle --release

# Upload via Play Console
# https://play.google.com/console
```

### 2. Direct APK Distribution

```bash
# Build universal APK
flutter build apk --release

# Or split APKs
flutter build apk --release --split-per-abi

# Host on:
# - GitHub Releases
# - Your website
# - Firebase App Distribution
```

### 3. Continuous Deployment

**GitHub Actions workflow:**
```yaml
name: Android Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      
      - name: Build APK
        run: |
          flutter pub get
          flutter build apk --release
      
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## Security Considerations

### 1. Obfuscation

```bash
# Build with obfuscation
flutter build apk --obfuscate --split-debug-info=debug-info
```

### 2. Certificate Pinning

**Add to network_security_config.xml:**
```xml
<pin-set expiration="2025-01-01">
    <pin digest="SHA-256">base64-encoded-pin</pin>
</pin-set>
```

### 3. Secure Storage

```dart
// Use flutter_secure_storage for sensitive data
final storage = FlutterSecureStorage();
await storage.write(key: 'api_key', value: 'secret');
```

## Testing Checklist

- [ ] App launches without crashes
- [ ] Can connect to bridge server
- [ ] Real-time data updates work
- [ ] All screens load correctly
- [ ] Trading operations execute
- [ ] Push notifications work
- [ ] App works offline (where applicable)
- [ ] No memory leaks
- [ ] Performance is acceptable
- [ ] Security measures in place

## Next Steps

1. Set up CI/CD pipeline
2. Configure crash reporting (Firebase Crashlytics)
3. Implement analytics
4. Set up A/B testing
5. Prepare for app store submission