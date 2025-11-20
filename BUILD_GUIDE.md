# 🔧 QuantumTrader Pro - Build Guide

This guide explains how to build the QuantumTrader Pro APK from source.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Method 1: Local Build](#method-1-local-build-recommended)
- [Method 2: GitHub Actions (Automated)](#method-2-github-actions-automated)
- [Method 3: Cloud Build Services](#method-3-cloud-build-services)
- [Installation](#installation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

1. **Flutter SDK** (3.19.0 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
   - Add Flutter to your system PATH

2. **Android Studio** or **Android SDK Command-line Tools**
   - Download from: https://developer.android.com/studio
   - Install Android SDK Platform 34 (API Level 34)
   - Install Android SDK Build-Tools 34.0.0

3. **Java Development Kit (JDK)** 17
   - Download from: https://adoptium.net/

4. **Git**
   - Download from: https://git-scm.com/downloads

### System Requirements

- **Operating System**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 18.04+)
- **RAM**: Minimum 8GB (16GB recommended)
- **Disk Space**: 10GB free space
- **Internet**: Required for downloading dependencies

---

## Method 1: Local Build (Recommended)

This is the most straightforward method for building the APK on your local machine.

### Step 1: Clone the Repository

```bash
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro
```

### Step 2: Verify Flutter Installation

```bash
flutter doctor
```

Ensure all checks pass (especially Flutter, Android toolchain, and Android Studio).

### Step 3: Install Dependencies

```bash
flutter pub get
```

This will download all required Dart packages defined in `pubspec.yaml`.

### Step 4: Build the APK

#### Option A: Release APK (Recommended for production)

```bash
flutter build apk --release
```

The APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

#### Option B: Debug APK (For testing)

```bash
flutter build apk --debug
```

#### Option C: Split APKs by ABI (Smaller file sizes)

```bash
flutter build apk --split-per-abi --release
```

This creates separate APKs for different architectures:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM - most modern devices)
- `app-x86_64-release.apk` (64-bit x86 - emulators)

### Step 5: Locate Your APK

```bash
# Copy APK to project root for easy access
cp build/app/outputs/flutter-apk/app-release.apk ./QuantumTraderPro-v2.0.0.apk
```

**Your APK is now ready for installation! 🎉**

---

## Method 2: GitHub Actions (Automated)

GitHub Actions can automatically build APKs on every commit or release.

### Step 1: Enable GitHub Actions Workflow

The repository includes a pre-configured workflow file at `.github/workflows/android.yml`.

**Note:** Due to GitHub OAuth token scope limitations, this file cannot be pushed directly. Follow these steps:

1. **Navigate to your repository on GitHub**:
   ```
   https://github.com/Dezirae-Stark/QuantumTrader-Pro
   ```

2. **Create the workflow file manually**:
   - Click "Add file" → "Create new file"
   - Name it: `.github/workflows/android.yml`
   - Copy the contents from the local `.github/workflows/android.yml` file
   - Commit the file

### Step 2: Trigger a Build

#### Option A: Push to Main Branch

```bash
git add .
git commit -m "Update app"
git push origin main
```

GitHub Actions will automatically build the APK.

#### Option B: Create a Release Tag

```bash
git tag -s v2.0.0 -m "Version 2.0.0 - Quantum Trading System"
git push origin v2.0.0
```

This will:
- Build the APK
- Create a GitHub Release
- Attach the APK to the release

#### Option C: Manual Workflow Dispatch

1. Go to "Actions" tab on GitHub
2. Select "Android CI/CD" workflow
3. Click "Run workflow"
4. Select branch (main)
5. Click "Run workflow"

### Step 3: Download the APK

After the workflow completes:

1. **From Workflow Artifacts** (available for 30 days):
   - Go to "Actions" tab
   - Click on the completed workflow run
   - Scroll to "Artifacts" section
   - Download `QuantumTraderPro-APK`

2. **From GitHub Releases** (permanent, if tagged):
   - Go to "Releases" tab
   - Find your release (e.g., v2.0.0)
   - Download the APK from "Assets"

---

## Method 3: Cloud Build Services

### Using Codemagic

1. Sign up at https://codemagic.io/
2. Connect your GitHub repository
3. Configure Flutter build settings:
   - **Platform**: Android
   - **Build command**: `flutter build apk --release`
4. Trigger build manually or on git push
5. Download APK from Codemagic dashboard

### Using AppCircle

1. Sign up at https://appcircle.io/
2. Add your repository
3. Create new Android build profile
4. Configure build workflow
5. Trigger build and download APK

---

## Installation

Once you have the APK:

### On Physical Android Device

1. **Transfer APK to your phone**:
   - Via USB cable (copy to Downloads folder)
   - Via email attachment
   - Via cloud storage (Google Drive, Dropbox)
   - Via direct download from GitHub Releases

2. **Enable installation from unknown sources**:
   - Go to **Settings** → **Security** → Enable **"Unknown Sources"**
   - Or (on newer Android): **Settings** → **Apps** → **Special Access** → **Install Unknown Apps** → Select your file manager → Enable

3. **Install the APK**:
   - Open file manager
   - Navigate to Downloads (or wherever you saved the APK)
   - Tap on `QuantumTraderPro-v2.0.0.apk`
   - Tap "Install"
   - Wait for installation to complete
   - Tap "Open"

### On Android Emulator

1. **Start your emulator** from Android Studio
2. **Drag and drop** the APK file onto the emulator window
3. Or use ADB:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

---

## Troubleshooting

### Common Build Errors

#### Error: "Flutter SDK not found"

**Solution**:
```bash
# Verify Flutter is in PATH
flutter --version

# If not found, add Flutter to PATH:
# Linux/macOS:
export PATH="$PATH:/path/to/flutter/bin"

# Windows (PowerShell):
$env:Path += ";C:\path\to\flutter\bin"
```

#### Error: "Android SDK not found"

**Solution**:
```bash
# Set ANDROID_HOME environment variable
# Linux/macOS:
export ANDROID_HOME=$HOME/Android/Sdk

# Windows:
set ANDROID_HOME=C:\Users\YourName\AppData\Local\Android\Sdk

# Then run:
flutter doctor --android-licenses
```

#### Error: "Gradle build failed"

**Solution**:
```bash
# Clean build cache
flutter clean
flutter pub get

# Try building again
flutter build apk --release
```

#### Error: "Execution failed for task ':app:lintVitalRelease'"

**Solution**: Add this to `android/app/build.gradle`:
```gradle
android {
    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }
}
```

#### Error: "Out of memory"

**Solution**: Increase JVM heap size in `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError
```

### APK Installation Errors

#### Error: "App not installed"

**Causes**:
- Insufficient storage space
- Conflicting package name with existing app
- Corrupted APK file

**Solutions**:
1. Free up storage space (need ~150MB)
2. Uninstall previous version first
3. Re-download or rebuild the APK

#### Error: "Installation blocked"

**Solution**: Enable "Install from Unknown Sources" in Android settings (see Installation section)

---

## File Sizes

Expected APK sizes:

- **Standard Release APK**: ~40-60 MB
- **Split APK (arm64-v8a)**: ~25-35 MB
- **Debug APK**: ~50-70 MB

---

## Signing the APK (Optional)

For production releases, you should sign the APK with your own keystore:

### Step 1: Generate Keystore

```bash
keytool -genkey -v -keystore ~/quantumtrader-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias quantumtrader
```

### Step 2: Configure Signing

Create `android/key.properties`:

```properties
storePassword=your_password
keyPassword=your_password
keyAlias=quantumtrader
storeFile=/path/to/quantumtrader-keystore.jks
```

### Step 3: Update `android/app/build.gradle`

Add before `android {`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Add inside `android {`:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### Step 4: Build Signed APK

```bash
flutter build apk --release
```

---

## Additional Resources

### Development Documentation
- **[Environment Setup Guide](docs/ENVIRONMENT_SETUP.md)** - Configure dev, staging, and production environments
- **[Secrets Management Guide](docs/SECRETS_MANAGEMENT.md)** - Manage API keys and credentials securely
- **[GitHub Secrets Setup](docs/GITHUB_SECRETS.md)** - Configure secrets for CI/CD
- **[Security Best Practices](docs/SECURITY.md)** - Security guidelines and best practices

### External Resources
- **Flutter Documentation**: https://flutter.dev/docs
- **Android Developer Guide**: https://developer.android.com/studio/build
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **QuantumTrader Pro Issues**: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

---

## Support

If you encounter issues not covered in this guide:

1. **Check existing issues**: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
2. **Create new issue**: Provide build logs and error messages
3. **Email support**: clockwork.halo@tutanota.de

---

**Built by Dezirae Stark**
📧 clockwork.halo@tutanota.de
🔗 [GitHub](https://github.com/Dezirae-Stark)

---

*Last Updated: November 8, 2025 - Version 2.0.0*
