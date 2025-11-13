# Build Instructions - QuantumTrader Pro

## ⚠️ Build Environment Requirements

The QuantumTrader Pro Android app is a **Flutter application** and requires specific build tools.

---

## 🚫 Known Issues

### Building in Termux (Android)

**Current Limitation**: Flutter builds are not fully supported in Termux due to:
- Missing Flutter SDK
- Limited Android SDK support
- Resource-intensive compilation

**Recommendation**: Build on a desktop/laptop environment

---

## ✅ Recommended Build Environments

### Option 1: Linux (Ubuntu/Debian)

```bash
# Install Flutter
sudo snap install flutter --classic
# OR download from: https://flutter.dev/docs/get-started/install/linux

# Install Android SDK
sudo apt install android-sdk

# Clone and build
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro
flutter pub get
flutter build apk --release
```

### Option 2: macOS

```bash
# Install Flutter
brew install --cask flutter

# Install Android Studio (includes Android SDK)
brew install --cask android-studio

# Clone and build
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro
flutter pub get
flutter build apk --release
```

### Option 3: Windows

```powershell
# Download Flutter SDK from:
# https://flutter.dev/docs/get-started/install/windows

# Install Android Studio from:
# https://developer.android.com/studio

# Clone and build
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro
flutter pub get
flutter build apk --release
```

### Option 4: GitHub Actions (CI/CD)

The repository includes workflows in `.github/workflows/` that can build automatically:

```yaml
# See: .github/workflows/android.yml
# Builds on every push to main branch
```

To trigger a build:
1. Push to `main` branch
2. Go to Actions tab on GitHub
3. Download built APK from artifacts

---

## 🔍 Troubleshooting Build Errors

### Error: "Flutter not found"

**Solution**: Install Flutter SDK
```bash
# Check Flutter installation
flutter doctor

# If not installed, follow: https://flutter.dev/docs/get-started/install
```

### Error: "Android SDK not found"

**Solution**: Install Android SDK via Android Studio or command line
```bash
# Install Android Studio (easiest)
# OR set ANDROID_HOME environment variable to SDK location
export ANDROID_HOME=$HOME/Android/Sdk
```

### Error: "Kotlin compilation failed"

**Solution**: Check `android/app/build.gradle` dependencies

```bash
# Clean and rebuild
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

### Error: "R class not found"

**Solution**: Ensure all layout files are valid XML

```bash
# Check for XML syntax errors in:
# - android/app/src/main/res/layout/*.xml
# - android/app/src/main/res/xml/*.xml

# Rebuild resources
cd android
./gradlew clean assembleDebug
```

### Error: "Duplicate class" or dependency conflicts

**Solution**: Check for version conflicts in `build.gradle`

```bash
# View dependency tree
cd android
./gradlew app:dependencies
```

---

## 🧪 Verifying the Broker Catalog Code

The broker catalog code added in PR #12 can be verified without a full build:

### Kotlin Syntax Check

```bash
# Check all Kotlin files compile
find android/app/src/main/kotlin -name "*.kt" -exec kotlinc {} \;
```

### Layout Validation

```bash
# Validate XML layouts
find android/app/src/main/res/layout -name "*.xml" -exec xmllint --noout {} \;
```

### Resource ID Verification

```bash
# Ensure all referenced IDs exist in layouts
grep -r "R\.id\." android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/
```

---

## 📱 Testing Without Building

### Code Review

All broker catalog code is in:
- `android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/*.kt`
- `android/app/src/main/res/layout/fragment_broker_selection.xml`
- `android/app/src/main/res/layout/item_broker.xml`
- `android/app/src/main/assets/brokers.json`

### Static Analysis

```bash
# Use Android Studio's Code Inspection
# File → Inspect Code → Inspection Results
```

### Documentation Review

All documentation is complete and can be reviewed without building:
- `docs/user/broker-setup.md`
- `docs/dev/broker-catalog.md`
- `docs/security/broker-signing.md`

---

## 🚀 Quick Build (Desktop Required)

If you have a desktop with Flutter installed:

```bash
# 1. Pull the branch
git checkout feature/broker-selector-pr1

# 2. Get dependencies
flutter pub get

# 3. Build debug APK (faster)
flutter build apk --debug

# 4. Or build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-debug.apk
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔧 Alternative: Use GitHub Actions

If you don't have a local build environment:

1. **Merge PR #12** to main branch
2. **Push to main** - this triggers the Android workflow
3. **Wait for build** (~10-15 minutes)
4. **Download APK** from Actions → Artifacts

Or create a new workflow file:

```yaml
# .github/workflows/build-broker-pr.yml
name: Build Broker PR

on:
  push:
    branches: [ feature/broker-selector-pr1 ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - run: flutter pub get
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v3
        with:
          name: debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
```

---

## ❓ What Specific Error Did You Get?

Please provide:

1. **Full error message**
2. **Build command you used**
3. **Environment** (Termux / Linux / macOS / Windows)

This will help diagnose the specific issue.

---

## 📞 Common Solutions Summary

| Error | Solution |
|-------|----------|
| "Flutter not found" | Install Flutter SDK |
| "Android SDK not found" | Install Android Studio |
| "Kotlin compilation failed" | Run `flutter clean` then `flutter pub get` |
| "R class not found" | Check XML layout files for syntax errors |
| "Build fails in Termux" | Use desktop environment or GitHub Actions |
| "Dependency conflicts" | Check `build.gradle` for version mismatches |

---

## ✅ Pre-Merge Checklist

Before merging PR #12, verify:

- [ ] Code compiles without errors
- [ ] All Kotlin files have valid syntax
- [ ] All XML layouts are well-formed
- [ ] Dependencies resolve correctly
- [ ] No duplicate class errors
- [ ] Resources (layouts, IDs) match code references

---

**Need help?** Please share:
- The exact error message
- Your build environment
- The command you ran

This will help provide a targeted fix!
