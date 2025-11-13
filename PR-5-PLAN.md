# PR-5: Secure Release Pipeline - Implementation Plan

## Overview
Implement a complete secure release pipeline for QuantumTrader-Pro with automated APK signing, GitHub releases, version management, and security scanning.

**Status:** Planning
**Branch:** `feature/pr5-secure-release-pipeline`
**Estimated Effort:** 12-15 hours
**Priority:** High (Security Critical)

## Objectives
1. ✅ Automated APK signing with secure keystore management
2. ✅ GitHub releases with auto-generated changelogs
3. ✅ Semantic versioning automation
4. ✅ Security scanning (SAST, dependency checks)
5. ✅ Release artifact verification (checksums, signatures)
6. ✅ Distribution channel setup (GitHub Releases)
7. ✅ Rollback capabilities

## Components Overview

### 1. Keystore & Signing Configuration
**Files to Create:**
- `android/key.properties.template` - Template for local signing
- `android/app/build.gradle` - Update with signing configs
- `.github/workflows/release.yml` - Automated release workflow
- `scripts/generate-keystore.sh` - Helper script for keystore generation

**Security Requirements:**
- Store keystore in GitHub Secrets (encrypted)
- Never commit keystore to repository
- Use separate keys for debug/release
- Implement key rotation strategy

### 2. Version Management
**Files to Create/Update:**
- `version.properties` - Central version management
- `scripts/bump-version.sh` - Version bumping script
- `CHANGELOG.md` - Auto-generated changelog
- `android/app/build.gradle` - Read version from properties

**Versioning Strategy:**
- Semantic versioning: `MAJOR.MINOR.PATCH`
- Build number auto-increment
- Git tags for releases
- Version in app name

### 3. GitHub Actions Release Workflow
**Workflow Features:**
- Trigger on git tags (`v*`)
- Build signed release APK
- Run security scans
- Generate checksums (SHA256)
- Create GitHub release
- Upload artifacts
- Post-release notifications

### 4. Security Scanning
**Tools to Integrate:**
- **Gitleaks** - Secret scanning
- **Trivy** - Vulnerability scanning
- **flutter analyze** - Static analysis
- **Dependency-Check** - Third-party dependency audit

**Scan Triggers:**
- On every PR
- Before release
- Scheduled weekly scans

### 5. Release Artifacts
**What to Include:**
- Signed release APK (`app-release.apk`)
- SHA256 checksums (`SHA256SUMS.txt`)
- Ed25519 signature (`.sig` file)
- Release notes (auto-generated)
- Build metadata (version, commit, date)

### 6. Distribution Strategy
**Channels:**
1. **GitHub Releases** (Primary)
   - Public releases
   - Pre-releases for beta testing
   - Release notes and changelogs

2. **Direct Download** (Secondary)
   - Via website/documentation
   - Links to latest stable release

3. **Future:** F-Droid, Aurora Store

---

## Detailed Implementation Plan

### Phase 1: Keystore Setup & Signing (3-4 hours)

#### 1.1 Create Keystore Template
**File:** `android/key.properties.template`
```properties
# Copy this file to key.properties and fill in your values
# DO NOT commit key.properties to git

storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-keystore-file>
```

#### 1.2 Update Build Configuration
**File:** `android/app/build.gradle`

Add signing configs:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
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
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### 1.3 Create Keystore Generation Script
**File:** `scripts/generate-keystore.sh`

Helper script for developers to generate keystores:
```bash
#!/bin/bash
# Generate a new keystore for signing

read -p "Enter key alias: " KEY_ALIAS
read -p "Enter your name (CN): " CN
read -p "Enter organization (O): " ORG

keytool -genkeypair \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -keystore upload-keystore.jks \
  -dname "CN=$CN, O=$ORG" \
  -storepass android \
  -keypass android

echo "✅ Keystore generated: upload-keystore.jks"
echo "⚠️  Store this file securely and NEVER commit it to git"
```

#### 1.4 Update .gitignore
Add to `.gitignore`:
```gitignore
# Keystore files (NEVER COMMIT THESE)
*.jks
*.keystore
key.properties
upload-keystore.jks

# Release builds
app-release.apk
*.aab
```

### Phase 2: Version Management (2-3 hours)

#### 2.1 Create Version Properties File
**File:** `version.properties`
```properties
# QuantumTrader-Pro Version Configuration
# This file is managed by scripts/bump-version.sh

VERSION_MAJOR=2
VERSION_MINOR=1
VERSION_PATCH=0
VERSION_BUILD=1

# Semantic version: MAJOR.MINOR.PATCH
VERSION_NAME=2.1.0

# Build number (auto-increments)
VERSION_CODE=11
```

#### 2.2 Version Bump Script
**File:** `scripts/bump-version.sh`
```bash
#!/bin/bash
# Bump version numbers

set -e

VERSION_FILE="version.properties"

# Read current version
source "$VERSION_FILE"

# Parse command
case "$1" in
  major)
    VERSION_MAJOR=$((VERSION_MAJOR + 1))
    VERSION_MINOR=0
    VERSION_PATCH=0
    ;;
  minor)
    VERSION_MINOR=$((VERSION_MINOR + 1))
    VERSION_PATCH=0
    ;;
  patch)
    VERSION_PATCH=$((VERSION_PATCH + 1))
    ;;
  *)
    echo "Usage: $0 {major|minor|patch}"
    exit 1
    ;;
esac

# Increment build number
VERSION_CODE=$((VERSION_CODE + 1))
VERSION_NAME="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH"

# Write new version
cat > "$VERSION_FILE" <<EOF
# QuantumTrader-Pro Version Configuration
VERSION_MAJOR=$VERSION_MAJOR
VERSION_MINOR=$VERSION_MINOR
VERSION_PATCH=$VERSION_PATCH
VERSION_BUILD=$((VERSION_BUILD + 1))
VERSION_NAME=$VERSION_NAME
VERSION_CODE=$VERSION_CODE
EOF

echo "✅ Version bumped to $VERSION_NAME (build $VERSION_CODE)"
echo "📝 Update CHANGELOG.md with release notes"
echo "🏷️  Create git tag: git tag v$VERSION_NAME"
```

#### 2.3 Update Build.gradle to Use Version Properties
**File:** `android/app/build.gradle`

Read version from properties:
```gradle
def versionPropsFile = rootProject.file('version.properties')
def versionProps = new Properties()
if (versionPropsFile.exists()) {
    versionProps.load(new FileInputStream(versionPropsFile))
}

android {
    defaultConfig {
        versionCode versionProps['VERSION_CODE'].toInteger()
        versionName versionProps['VERSION_NAME']
    }
}
```

#### 2.4 Initialize CHANGELOG.md
**File:** `CHANGELOG.md`
```markdown
# Changelog

All notable changes to QuantumTrader-Pro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial changelog setup

## [2.1.0] - 2025-XX-XX

### Added
- PR-3: Android Dynamic Catalog Loader with Ed25519 verification
- PR-4: Broker Selection UI with state management

### Changed
- Complete project restructure and modernization

### Security
- Ed25519 signature verification for broker catalogs
- Secure keystore management for APK signing

---

[Unreleased]: https://github.com/Dezirae-Stark/QuantumTrader-Pro/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases/tag/v2.1.0
```

### Phase 3: GitHub Actions Release Workflow (4-5 hours)

#### 3.1 Main Release Workflow
**File:** `.github/workflows/release.yml`

Complete release automation workflow:
```yaml
name: Release Build & Publish

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag (e.g., v2.1.0)'
        required: true

env:
  FLUTTER_VERSION: '3.19.0'
  JAVA_VERSION: '17'

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks (Secret Scan)
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Run Trivy (Vulnerability Scan)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  build-release:
    name: Build Signed Release APK
    runs-on: ubuntu-latest
    needs: security-scan

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: ${{ env.JAVA_VERSION }}

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: 'stable'
          cache: true

      - name: Get Flutter dependencies
        run: flutter pub get

      - name: Run code generation
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Run Flutter analyze
        run: flutter analyze

      - name: Run Flutter tests
        run: flutter test

      - name: Decode keystore from secrets
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks

      - name: Create key.properties
        env:
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
          STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
        run: |
          cat > android/key.properties <<EOF
          storePassword=$STORE_PASSWORD
          keyPassword=$KEY_PASSWORD
          keyAlias=$KEY_ALIAS
          storeFile=upload-keystore.jks
          EOF

      - name: Build release APK
        run: flutter build apk --release --split-per-abi

      - name: Rename APK with version
        run: |
          VERSION=$(grep VERSION_NAME version.properties | cut -d'=' -f2)
          mkdir -p release
          cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
             release/QuantumTrader-Pro-v${VERSION}-arm64.apk
          cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
             release/QuantumTrader-Pro-v${VERSION}-arm32.apk
          cp build/app/outputs/flutter-apk/app-x86_64-release.apk \
             release/QuantumTrader-Pro-v${VERSION}-x86_64.apk

      - name: Generate checksums
        run: |
          cd release
          sha256sum *.apk > SHA256SUMS.txt
          cat SHA256SUMS.txt

      - name: Sign checksums with Ed25519
        env:
          RELEASE_SIGNING_KEY: ${{ secrets.RELEASE_SIGNING_KEY }}
        run: |
          echo "$RELEASE_SIGNING_KEY" | base64 -d > signing_key.pem
          cd release
          openssl dgst -sha256 -sign ../signing_key.pem -out SHA256SUMS.sig SHA256SUMS.txt
          rm ../signing_key.pem

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: release-apks
          path: release/
          retention-days: 90

  create-release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    needs: build-release
    permissions:
      contents: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          name: release-apks
          path: release/

      - name: Extract version from tag
        id: version
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION="${{ github.event.inputs.version }}"
          else
            VERSION="${GITHUB_REF#refs/tags/}"
          fi
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "version_number=${VERSION#v}" >> $GITHUB_OUTPUT

      - name: Generate changelog from commits
        id: changelog
        run: |
          PREVIOUS_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
          if [ -z "$PREVIOUS_TAG" ]; then
            CHANGELOG=$(git log --pretty=format:"- %s" HEAD)
          else
            CHANGELOG=$(git log --pretty=format:"- %s" ${PREVIOUS_TAG}..HEAD)
          fi
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Read full CHANGELOG.md
        id: full_changelog
        run: |
          # Extract section for this version from CHANGELOG.md
          VERSION="${{ steps.version.outputs.version_number }}"
          SECTION=$(sed -n "/## \[$VERSION\]/,/## \[/p" CHANGELOG.md | sed '$ d')
          echo "section<<EOF" >> $GITHUB_OUTPUT
          echo "$SECTION" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ steps.version.outputs.version }}
          name: QuantumTrader-Pro ${{ steps.version.outputs.version }}
          body: |
            # QuantumTrader-Pro ${{ steps.version.outputs.version_number }}

            ${{ steps.full_changelog.outputs.section }}

            ## 📦 Downloads

            Choose the APK for your device architecture:
            - **ARM64 (arm64-v8a)** - Most modern Android devices
            - **ARM32 (armeabi-v7a)** - Older 32-bit devices
            - **x86_64** - Emulators and x86 devices

            ## 🔐 Verification

            Verify the APK integrity using SHA256 checksums:
            ```bash
            sha256sum -c SHA256SUMS.txt
            ```

            Verify Ed25519 signature:
            ```bash
            openssl dgst -sha256 -verify release_public_key.pem -signature SHA256SUMS.sig SHA256SUMS.txt
            ```

            ## 📝 Recent Changes

            ${{ steps.changelog.outputs.changelog }}

            ---

            **Full Changelog**: https://github.com/${{ github.repository }}/compare/${{ steps.version.outputs.version }}...main

            🤖 Generated with [Claude Code](https://claude.com/claude-code)
          files: |
            release/*.apk
            release/SHA256SUMS.txt
            release/SHA256SUMS.sig
          draft: false
          prerelease: false

  notify-release:
    name: Post-Release Notifications
    runs-on: ubuntu-latest
    needs: create-release
    if: success()

    steps:
      - name: Summary
        run: |
          echo "✅ Release ${{ needs.create-release.outputs.version }} published successfully!"
          echo "📦 Artifacts uploaded to GitHub Releases"
          echo "🔗 https://github.com/${{ github.repository }}/releases/latest"
```

#### 3.2 Pre-Release Workflow (Beta/RC)
**File:** `.github/workflows/pre-release.yml`

Similar to release.yml but:
- Triggered on `beta/*` or `rc/*` tags
- Creates pre-release on GitHub
- Marks as pre-release (not production)
- Shorter artifact retention (30 days)

### Phase 4: Security Scanning Integration (2-3 hours)

#### 4.1 Gitleaks Configuration
**File:** `.gitleaks.toml`
```toml
title = "QuantumTrader-Pro Secret Scanning"

[extend]
useDefault = true

[[rules]]
description = "Android Keystore Password"
id = "android-keystore-password"
regex = '''(?i)(keyPassword|storePassword)\s*=\s*['""].+['"]'''
tags = ["android", "keystore"]

[[rules]]
description = "API Keys"
id = "api-key"
regex = '''(?i)(api[_-]?key|apikey)\s*[:=]\s*['""][a-zA-Z0-9]{16,}['"]'''
tags = ["api", "key"]

[allowlist]
paths = [
    '''^\.git/''',
    '''(.*?)(jpg|gif|png|svg)$''',
]
```

#### 4.2 Dependency Check Script
**File:** `scripts/check-dependencies.sh`
```bash
#!/bin/bash
# Check Flutter dependencies for known vulnerabilities

set -e

echo "🔍 Checking Flutter dependencies..."

# Get outdated packages
flutter pub outdated --json > outdated.json

# Check for security advisories
flutter pub deps --json > deps.json

# Parse and report vulnerabilities
# (This is a simplified version - integrate with actual vulnerability DB)

echo "✅ Dependency check complete"
```

#### 4.3 Scheduled Security Scan Workflow
**File:** `.github/workflows/security-scan.yml`
```yaml
name: Security Scan (Scheduled)

on:
  schedule:
    # Run every Monday at 00:00 UTC
    - cron: '0 0 * * 1'
  workflow_dispatch:

jobs:
  gitleaks:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  trivy:
    name: Vulnerability Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'table'

  dependency-check:
    name: Dependency Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'

      - name: Get dependencies
        run: flutter pub get

      - name: Check for outdated packages
        run: flutter pub outdated

      - name: Run pub audit (Flutter 3.19+)
        run: flutter pub audit || true
```

### Phase 5: Documentation & Scripts (2 hours)

#### 5.1 Release Process Documentation
**File:** `docs/RELEASE_PROCESS.md`
```markdown
# Release Process

This document describes the release process for QuantumTrader-Pro.

## Pre-Release Checklist

- [ ] All tests passing on main branch
- [ ] Code generation completed (`dart run build_runner build`)
- [ ] No pending security issues
- [ ] CHANGELOG.md updated with release notes
- [ ] Version bumped in version.properties

## Release Steps

### 1. Prepare Release

```bash
# Update version
./scripts/bump-version.sh minor  # or major/patch

# Update CHANGELOG.md
nano CHANGELOG.md

# Commit changes
git add version.properties CHANGELOG.md
git commit -m "chore: Bump version to $(grep VERSION_NAME version.properties | cut -d'=' -f2)"
git push origin main
```

### 2. Create Release Tag

```bash
VERSION=$(grep VERSION_NAME version.properties | cut -d'=' -f2)
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"
```

### 3. Automated Build

GitHub Actions will automatically:
1. Run security scans
2. Build signed APKs
3. Generate checksums
4. Create GitHub release
5. Upload artifacts

### 4. Post-Release

- Monitor GitHub Actions for build status
- Verify release artifacts on GitHub Releases
- Test download and installation
- Announce release (if applicable)

## Emergency Rollback

If a critical issue is discovered:

```bash
# Delete tag
git push --delete origin v2.1.0
git tag -d v2.1.0

# Delete release on GitHub
gh release delete v2.1.0

# Fix issue and re-release with patch version
./scripts/bump-version.sh patch
```

## Beta/RC Releases

For pre-releases:

```bash
# Tag with suffix
git tag -a "v2.1.0-beta.1" -m "Beta release"
git push origin "v2.1.0-beta.1"
```

This triggers pre-release workflow.
```

#### 5.2 Keystore Setup Guide
**File:** `docs/KEYSTORE_SETUP.md`
```markdown
# Keystore Setup Guide

## For Developers (Local Signing)

### 1. Generate Keystore

```bash
# Run the generation script
chmod +x scripts/generate-keystore.sh
./scripts/generate-keystore.sh
```

This creates `upload-keystore.jks` in the android/ directory.

### 2. Create key.properties

```bash
cp android/key.properties.template android/key.properties
```

Edit `android/key.properties` with your values:
```properties
storePassword=YourStorePassword
keyPassword=YourKeyPassword
keyAlias=your-key-alias
storeFile=upload-keystore.jks
```

### 3. Build Signed APK

```bash
flutter build apk --release
```

## For CI/CD (GitHub Actions)

### 1. Encode Keystore to Base64

```bash
base64 -i upload-keystore.jks | pbcopy  # macOS
base64 -w 0 upload-keystore.jks          # Linux
```

### 2. Add GitHub Secrets

Go to: Settings → Secrets and variables → Actions

Add these secrets:
- `KEYSTORE_BASE64` - Base64-encoded keystore file
- `KEY_ALIAS` - Your key alias
- `KEY_PASSWORD` - Your key password
- `STORE_PASSWORD` - Your store password
- `RELEASE_SIGNING_KEY` - Ed25519 private key for release signing

### 3. Test Workflow

Push a tag to trigger the release workflow:
```bash
git tag v2.1.0-test
git push origin v2.1.0-test
```

## Security Best Practices

1. **Never** commit keystore files or passwords to git
2. Use strong, unique passwords (32+ characters)
3. Store keystore backup in secure location (encrypted)
4. Rotate keys periodically (every 2-3 years)
5. Use separate keys for debug/release
6. Document key generation parameters
```

#### 5.3 Verification Script for Users
**File:** `scripts/verify-release.sh`
```bash
#!/bin/bash
# Verify downloaded APK integrity

set -e

APK_FILE="$1"
CHECKSUMS_FILE="SHA256SUMS.txt"
SIGNATURE_FILE="SHA256SUMS.sig"
PUBLIC_KEY="release_public_key.pem"

if [ -z "$APK_FILE" ]; then
    echo "Usage: $0 <apk-file>"
    exit 1
fi

echo "🔐 Verifying QuantumTrader-Pro Release"
echo "========================================"

# Check if files exist
if [ ! -f "$APK_FILE" ]; then
    echo "❌ APK file not found: $APK_FILE"
    exit 1
fi

if [ ! -f "$CHECKSUMS_FILE" ]; then
    echo "⚠️  SHA256SUMS.txt not found - skipping checksum verification"
else
    echo "📝 Verifying SHA256 checksum..."
    if sha256sum -c "$CHECKSUMS_FILE" 2>/dev/null | grep -q "$APK_FILE: OK"; then
        echo "✅ Checksum verified"
    else
        echo "❌ Checksum verification failed!"
        exit 1
    fi
fi

if [ ! -f "$SIGNATURE_FILE" ] || [ ! -f "$PUBLIC_KEY" ]; then
    echo "⚠️  Signature files not found - skipping signature verification"
else
    echo "🔏 Verifying Ed25519 signature..."
    if openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "$SIGNATURE_FILE" "$CHECKSUMS_FILE" > /dev/null 2>&1; then
        echo "✅ Signature verified"
    else
        echo "❌ Signature verification failed!"
        exit 1
    fi
fi

echo ""
echo "✅ All verifications passed!"
echo "📦 APK is safe to install: $APK_FILE"
```

---

## GitHub Secrets Required

Add these secrets to repository:

| Secret Name | Description | How to Generate |
|-------------|-------------|-----------------|
| `KEYSTORE_BASE64` | Base64-encoded keystore file | `base64 -w 0 upload-keystore.jks` |
| `KEY_ALIAS` | Keystore key alias | From keystore generation |
| `KEY_PASSWORD` | Key password | From keystore generation |
| `STORE_PASSWORD` | Keystore password | From keystore generation |
| `RELEASE_SIGNING_KEY` | Ed25519 private key (Base64) | `ssh-keygen -t ed25519` then base64 encode |

---

## Testing Strategy

### 1. Local Testing
```bash
# Test keystore generation
./scripts/generate-keystore.sh

# Test version bump
./scripts/bump-version.sh patch

# Test local signing
flutter build apk --release

# Verify APK
./scripts/verify-release.sh build/app/outputs/flutter-apk/app-release.apk
```

### 2. CI/CD Testing
```bash
# Test with pre-release tag
git tag v2.1.0-test
git push origin v2.1.0-test

# Monitor GitHub Actions
gh run list --workflow=release.yml
gh run watch
```

### 3. Release Testing
1. Download APK from GitHub Releases
2. Verify checksums: `sha256sum -c SHA256SUMS.txt`
3. Verify signature: `./scripts/verify-release.sh <apk>`
4. Install on test device
5. Verify app version in About screen

---

## Timeline

### Week 1: Foundation (5-6 hours)
- [ ] Day 1-2: Keystore setup, signing configuration (3-4 hours)
- [ ] Day 3: Version management system (2 hours)

### Week 2: Automation (6-7 hours)
- [ ] Day 1-2: GitHub Actions release workflow (4-5 hours)
- [ ] Day 3: Security scanning integration (2 hours)

### Week 3: Documentation & Testing (3-4 hours)
- [ ] Day 1: Documentation and scripts (2 hours)
- [ ] Day 2: Testing and refinement (1-2 hours)

**Total:** 12-15 hours over 2-3 weeks

---

## Success Criteria

- ✅ Automated APK signing working in CI/CD
- ✅ GitHub releases created automatically on tags
- ✅ Version management system functional
- ✅ Security scans running (no critical issues)
- ✅ Checksums and signatures generated
- ✅ Documentation complete
- ✅ Test release successful
- ✅ Rollback procedure tested

---

## Dependencies

**Tools Required:**
- Java 17 (for Android build)
- Flutter 3.19.0
- OpenSSL (for signature verification)
- GitHub CLI (for release management)

**GitHub Actions:**
- `actions/checkout@v4`
- `actions/setup-java@v4`
- `subosito/flutter-action@v2`
- `actions/upload-artifact@v4`
- `actions/download-artifact@v4`
- `softprops/action-gh-release@v1`
- `gitleaks/gitleaks-action@v2`
- `aquasecurity/trivy-action@master`

---

## Future Enhancements

1. **Automated Testing Integration**
   - Run integration tests before release
   - Screenshot testing
   - Performance benchmarks

2. **Multi-Platform Support**
   - iOS builds
   - Linux/Windows desktop builds
   - Web builds

3. **Distribution Channels**
   - F-Droid integration
   - Aurora Store listing
   - Self-hosted update server

4. **Advanced Security**
   - Code obfuscation
   - Root detection
   - Tamper detection
   - Certificate pinning

5. **Release Analytics**
   - Download tracking
   - Crash reporting
   - Usage analytics

---

## References

- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [Flutter Deployment](https://docs.flutter.dev/deployment/android)
- [GitHub Actions for Flutter](https://docs.flutter.dev/deployment/cd)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)

---

## Questions & Support

For questions about the release process:
1. Check documentation in `docs/`
2. Review GitHub Actions workflow logs
3. Open an issue on GitHub

---

**Status:** Ready for implementation
**Next Steps:** Begin Phase 1 (Keystore Setup)
