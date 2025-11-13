# Keystore Setup Guide

This guide explains how to set up Android keystores for signing QuantumTrader-Pro APKs.

## Overview

Android requires all APKs to be digitally signed before installation. QuantumTrader-Pro uses:
- **Debug keystore**: Automatic, for development
- **Release keystore**: Manual setup required, for production releases

---

## For Developers (Local Signing)

### Prerequisites

- Java JDK installed (Java 11 or later)
- `keytool` command available (comes with JDK)

### Step 1: Generate Keystore

Use the provided script:

```bash
# Navigate to project root
cd QuantumTrader-Pro

# Run keystore generation script
./scripts/generate-keystore.sh
```

The script will prompt for:
- **Key alias**: Identifier for the key (e.g., `quantumtrader`)
- **Your name (CN)**: Your full name
- **Organization (O)**: Company/organization name (optional)
- **Country code (C)**: Two-letter country code (e.g., `US`)

Then you'll be asked to create passwords:
- **Keystore password**: Used to access the keystore file
- **Key password**: Used to access the specific key

⚠️ **Use strong passwords** (16+ characters, mix of letters, numbers, symbols)

### Step 2: Configure key.properties

```bash
# Copy template
cp android/key.properties.template android/key.properties

# Edit with your values
nano android/key.properties
```

Fill in:

```properties
storePassword=YourStrongKeystorePassword123!
keyPassword=YourStrongKeyPassword123!
keyAlias=quantumtrader
storeFile=upload-keystore.jks
```

### Step 3: Build Signed APK

```bash
# Build release APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

### Step 4: Verify Signing

```bash
# Check APK signature
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk

# Should show:
# jar verified.
```

---

## For CI/CD (GitHub Actions)

### Prerequisites

- Generated keystore file (`upload-keystore.jks`)
- Keystore passwords
- GitHub repository access

### Step 1: Encode Keystore to Base64

```bash
# Encode keystore
base64 -w 0 android/app/upload-keystore.jks > keystore.base64.txt

# On macOS:
base64 -i android/app/upload-keystore.jks > keystore.base64.txt

# Copy the base64 string (it's one long line)
cat keystore.base64.txt
```

### Step 2: Add GitHub Secrets

1. Go to repository: **Settings** → **Secrets and variables** → **Actions**

2. Click **"New repository secret"**

3. Add these secrets:

   | Name | Value | Example |
   |------|-------|---------|
   | `KEYSTORE_BASE64` | Base64-encoded keystore | `MIIJXAIBAzCCCS...` |
   | `KEY_ALIAS` | Your key alias | `quantumtrader` |
   | `KEY_PASSWORD` | Key password | `YourKeyPass123!` |
   | `STORE_PASSWORD` | Keystore password | `YourStorePass123!` |

4. Verify secrets are set:
   - Each should show "✅ Set" with last updated date

### Step 3: Test Workflow

Push a test tag to trigger the release workflow:

```bash
# Create test tag
git tag v2.1.0-test

# Push tag
git push origin v2.1.0-test

# Watch workflow
gh run watch
```

### Step 4: Verify Build

1. Check workflow logs for signing success
2. Download APK from artifacts
3. Verify signature:
   ```bash
   jarsigner -verify -verbose -certs QuantumTrader-Pro-v2.1.0-test-arm64.apk
   ```

---

## Manual Keystore Generation

If you prefer not to use the script:

```bash
keytool -genkeypair \
  -alias quantumtrader \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -keystore upload-keystore.jks \
  -dname "CN=Your Name, O=Your Organization, C=US"
```

Parameters explained:
- `-alias`: Key identifier (you'll use this in key.properties)
- `-keyalg`: Algorithm (RSA recommended)
- `-keysize`: Key size in bits (4096 for security)
- `-validity`: Days until expiration (10000 = ~27 years)
- `-keystore`: Output filename
- `-dname`: Distinguished name (CN=name, O=org, C=country)

---

## Security Best Practices

### DO ✅

- **Use strong passwords** (16+ characters)
- **Store keystore securely** (encrypted backup)
- **Never commit keystore to git** (already in .gitignore)
- **Use different keys for debug/release**
- **Document key generation parameters**
- **Backup keystore in multiple secure locations**
- **Use password manager for passwords**
- **Rotate keys every 2-3 years**

### DON'T ❌

- **Never commit keystore files** (*.jks, *.keystore)
- **Never commit key.properties** (passwords)
- **Never share keystore passwords in plain text**
- **Never upload keystore to public cloud**
- **Never reuse passwords across keys**
- **Never use weak passwords** (<16 chars)

---

## Keystore Backup

### Create Encrypted Backup

```bash
# Create encrypted backup
gpg --symmetric --cipher-algo AES256 upload-keystore.jks

# This creates: upload-keystore.jks.gpg
# Store this in multiple secure locations
```

### Restore from Backup

```bash
# Decrypt backup
gpg --decrypt upload-keystore.jks.gpg > upload-keystore.jks
```

### Backup Locations

Store in at least 2 of these:
- 🔒 Encrypted USB drive
- 🔒 Secure cloud storage (encrypted)
- 🔒 Password manager (some support file attachments)
- 🔒 Encrypted local backup
- 🔒 Physical safe/vault

---

## Key Rotation

### When to Rotate

- Every 2-3 years (recommended)
- If password compromised
- If keystore leaked
- When changing ownership

### How to Rotate

1. **Generate new keystore**
   ```bash
   ./scripts/generate-keystore.sh
   # Use different alias: quantumtrader-v2
   ```

2. **Test new keystore**
   ```bash
   # Update key.properties with new values
   flutter build apk --release
   ```

3. **Update CI/CD secrets**
   - Encode new keystore
   - Update GitHub Secrets

4. **Document change**
   - Update CHANGELOG.md
   - Note key rotation date
   - Archive old keystore securely

---

## Troubleshooting

### "keytool: command not found"

Install Java JDK:

```bash
# Debian/Ubuntu
apt-get install openjdk-17-jdk

# macOS
brew install openjdk@17

# Verify
keytool -help
```

### "Keystore file not found" (during build)

Check:
1. Keystore exists: `ls -l android/app/upload-keystore.jks`
2. key.properties exists: `ls -l android/key.properties`
3. Path in key.properties is correct

### "Wrong password" error

- Verify password in key.properties matches keystore
- Check for typos (passwords are case-sensitive)
- Try re-entering password

### "Release APK not signed"

Check build.gradle:
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release  // Should use release config
    }
}
```

### CI/CD "Keystore decode failed"

- Verify KEYSTORE_BASE64 secret is set
- Check base64 encoding is correct (single line, no breaks)
- Ensure no extra spaces/newlines in secret

---

## Keystore Information

### View Keystore Details

```bash
# List keys in keystore
keytool -list -v -keystore upload-keystore.jks

# Show specific key
keytool -list -alias quantumtrader -keystore upload-keystore.jks
```

### Export Public Certificate

```bash
# Export certificate (for verification)
keytool -export -alias quantumtrader \
  -keystore upload-keystore.jks \
  -file release-cert.cer

# View certificate
keytool -printcert -file release-cert.cer
```

---

## File Locations

```
QuantumTrader-Pro/
├── android/
│   ├── app/
│   │   ├── upload-keystore.jks          # Release keystore (NOT IN GIT)
│   │   └── build.gradle                 # Signing configuration
│   ├── key.properties                   # Keystore config (NOT IN GIT)
│   └── key.properties.template          # Template (IN GIT)
└── scripts/
    └── generate-keystore.sh             # Generation script
```

**⚠️ Files NOT in git:**
- `upload-keystore.jks`
- `key.properties`
- `*.keystore`
- `*.jks`

All excluded in `.gitignore`

---

## Quick Reference

### Generate Keystore
```bash
./scripts/generate-keystore.sh
```

### Configure Local Signing
```bash
cp android/key.properties.template android/key.properties
nano android/key.properties  # Fill in values
```

### Build Signed Release
```bash
flutter build apk --release
```

### Encode for CI/CD
```bash
base64 -w 0 android/app/upload-keystore.jks
```

### Verify APK Signature
```bash
jarsigner -verify -verbose -certs app-release.apk
```

---

## Related Documentation

- [Release Process](RELEASE_PROCESS.md)
- [Security Best Practices](SECURITY.md)
- [Android App Signing Documentation](https://developer.android.com/studio/publish/app-signing)

---

## Support

For keystore issues:

1. Check this guide
2. Review error messages carefully
3. Verify file locations and permissions
4. Check GitHub Actions logs (for CI/CD)
5. Open an issue if needed

---

**Last Updated:** 2025-01-12
