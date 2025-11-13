# Broker Catalog Setup Guide

Complete setup guide for deploying the QuantumTrader Pro dynamic broker catalog system.

## 📋 Prerequisites

- GitHub account with admin access to:
  - `Dezirae-Stark/QuantumTrader-Pro` (main app repo)
  - `Dezirae-Stark/QuantumTrader-Pro-data` (data repo - to be created)
- `minisign` installed on your local machine
- `git` and `gh` CLI tools

## 🚀 Step-by-Step Setup

### Phase 1: Generate Signing Keys

#### 1.1 Install minisign

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install minisign
```

**macOS:**
```bash
brew install minisign
```

**From Source:**
```bash
git clone https://github.com/jedisct1/minisign.git
cd minisign
mkdir build && cd build
cmake .. && make
sudo make install
```

**Verify Installation:**
```bash
minisign -v
# Expected output: minisign 0.11 or later
```

#### 1.2 Generate Keypair

```bash
# Create a secure directory
mkdir -p ~/broker-keys
cd ~/broker-keys

# Generate keys
minisign -G -p broker_catalog.pub -s broker_catalog.key

# You'll be prompted for a password
# ⚠️ IMPORTANT: Use a strong, unique password and save it securely!
```

**Output:**
```
Password:
Password (one more time):
Deriving a key from the password and decrypting the secret key... done
```

**Files created:**
- `broker_catalog.pub` - Public key (will be embedded in app)
- `broker_catalog.key` - Private key (will be stored in GitHub Secrets)

#### 1.3 Backup Keys Securely

```bash
# Create encrypted backup
tar czf broker-keys-backup.tar.gz broker_catalog.*
gpg -c broker-keys-backup.tar.gz

# Store broker-keys-backup.tar.gz.gpg in a secure location:
# - Hardware security key
# - Encrypted cloud storage (personal, not org)
# - Physical safe

# Document the backup location in your password manager
```

### Phase 2: Create Data Repository

#### 2.1 Create GitHub Repository

```bash
# Using GitHub CLI
gh repo create Dezirae-Stark/QuantumTrader-Pro-data \
  --public \
  --description "Dynamic broker catalog for QuantumTrader Pro" \
  --clone

cd QuantumTrader-Pro-data
```

**Or via Web UI:**
1. Go to https://github.com/organizations/Dezirae-Stark/repositories/new
2. Name: `QuantumTrader-Pro-data`
3. Description: "Dynamic broker catalog for QuantumTrader Pro"
4. Public repository
5. Initialize with README: No (we'll copy template)
6. Create repository

#### 2.2 Copy Template Files

```bash
# Navigate to data repo
cd ~/QuantumTrader-Pro-data

# Copy template from main repo
cp -r ~/QuantumTrader-Pro/docs/data-repo-template/* .
cp -r ~/QuantumTrader-Pro/docs/data-repo-template/.github .

# Copy schema file
cp ~/QuantumTrader-Pro/docs/brokers.schema.json .

# Copy initial broker list
cp ~/QuantumTrader-Pro/android/app/src/main/assets/brokers.json .

# Commit
git add .
git commit -m "Initial broker catalog setup"
git push origin main
```

#### 2.3 Enable GitHub Pages

**Via GitHub CLI:**
```bash
gh api repos/Dezirae-Stark/QuantumTrader-Pro-data/pages \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -f source[branch]=main \
  -f source[path]=/
```

**Via Web UI:**
1. Go to repository Settings
2. Scroll to "Pages" section
3. Source: Deploy from a branch
4. Branch: `main`
5. Folder: `/ (root)`
6. Save

**Verify Pages Deployment:**
- URL: https://dezirae-stark.github.io/QuantumTrader-Pro-data/
- Wait 2-3 minutes for initial deployment
- Check that `brokers.json` is accessible

### Phase 3: Configure GitHub Secrets

#### 3.1 Create Environment

1. Go to https://github.com/Dezirae-Stark/QuantumTrader-Pro-data/settings/environments
2. Click "New environment"
3. Name: `broker-pages`
4. (Optional) Configure protection rules:
   - ☑️ Required reviewers (recommend 1-2 people)
   - ☑️ Wait timer: 0 minutes
5. Click "Configure environment"

#### 3.2 Add Secrets

**Secret 1: BROKER_SIGNING_PRIVATE_KEY**

```bash
# Display private key for copying
cat ~/broker-keys/broker_catalog.key
```

1. In environment settings, click "Add secret"
2. Name: `BROKER_SIGNING_PRIVATE_KEY`
3. Value: Paste the ENTIRE contents of `broker_catalog.key`
   ```
   untrusted comment: minisign encrypted secret key
   RWR...long base64 string...==
   ```
4. Click "Add secret"

**Secret 2: BROKER_SIGNING_PASSWORD**

1. Click "Add secret"
2. Name: `BROKER_SIGNING_PASSWORD`
3. Value: Enter the password you used when generating the key
4. Click "Add secret"

**Verify Secrets:**
- Both secrets should appear in the `broker-pages` environment
- Secret values should be hidden (shown as `***`)

### Phase 4: Update Android App

#### 4.1 Extract Public Key

```bash
# Display public key
cat ~/broker-keys/broker_catalog.pub

# Expected format:
# untrusted comment: minisign public key ABCD1234
# RWQy...base64 encoded key...==
```

Copy the **second line** (the base64 encoded key starting with `RWQ`)

#### 4.2 Update SignatureVerifier.kt

```bash
cd ~/QuantumTrader-Pro

# Edit the file
nano android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/SignatureVerifier.kt
```

Replace the placeholder key:

```kotlin
private const val PUBLIC_KEY_BASE64 = "RWQy...YOUR_ACTUAL_PUBLIC_KEY...=="
```

With your actual public key (second line from `broker_catalog.pub`).

#### 4.3 Commit Changes

```bash
git add android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/SignatureVerifier.kt
git commit -m "Add production broker catalog public key"
git push origin main
```

### Phase 5: Test the System

#### 5.1 Trigger Signing Workflow

```bash
cd ~/QuantumTrader-Pro-data

# Make a small change to trigger workflow
echo "# Last updated: $(date)" >> README.md
git add README.md
git commit -m "Test: Trigger signing workflow"
git push origin main
```

#### 5.2 Monitor Workflow

```bash
# Watch workflow execution
gh run watch

# Or via web UI:
# https://github.com/Dezirae-Stark/QuantumTrader-Pro-data/actions
```

**Expected Results:**
- ✅ All validation steps pass
- ✅ Signature file created
- ✅ Deployed to GitHub Pages

#### 5.3 Verify Deployment

```bash
# Check that files are accessible
curl -I https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json
curl -I https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json.sig

# Expected: HTTP/2 200 OK
```

#### 5.4 Test Signature Verification

```bash
cd ~/QuantumTrader-Pro-data

# Download published files
curl -o test-brokers.json https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json
curl -o test-brokers.json.sig https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json.sig

# Verify with public key
minisign -V -p ~/broker-keys/broker_catalog.pub -m test-brokers.json

# Expected output:
# Signature and comment signature verified
# Trusted comment: QuantumTrader-Pro broker catalog YYYY-MM-DD
```

### Phase 6: Create Release Workflow

#### 6.1 Create Release Workflow

```bash
cd ~/QuantumTrader-Pro

# Create workflow file
nano .github/workflows/release.yml
```

Copy the following content:

```yaml
name: Release Build

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Validate embedded broker list
        run: |
          jq -e '.[].name and .[].platform and .[].webTerminalUrl' \
            android/app/src/main/assets/brokers.json
          echo "✅ Embedded broker list valid"

      - name: Install dependencies
        run: flutter pub get

      - name: Build APK
        run: flutter build apk --release

      - name: Generate checksums
        run: |
          cd build/app/outputs/flutter-apk
          sha256sum app-release.apk > app-release.apk.sha256
          cat app-release.apk.sha256

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            build/app/outputs/flutter-apk/app-release.apk
            build/app/outputs/flutter-apk/app-release.apk.sha256
          body: |
            ## QuantumTrader Pro Release

            ### Broker Catalog
            - **Embedded brokers**: $(jq '. | length' android/app/src/main/assets/brokers.json)
            - **Dynamic catalog**: https://dezirae-stark.github.io/QuantumTrader-Pro-data/
            - **Signature verified**: Yes (Ed25519)

            ### Installation
            1. Download `app-release.apk`
            2. Verify checksum: `sha256sum -c app-release.apk.sha256`
            3. Install on Android device
```

Commit and push:

```bash
git add .github/workflows/release.yml
git commit -m "Add release workflow with broker validation"
git push origin main
```

### Phase 7: Documentation

#### 7.1 Update Main README

```bash
cd ~/QuantumTrader-Pro

# Add broker catalog section
nano README.md
```

Add this section before "Contributing":

```markdown
## 🏦 Broker Selection

QuantumTrader Pro supports multiple MT4/MT5 brokers through a dynamic catalog:

- **Auto-updating**: Broker list updates weekly in the background
- **Cryptographically signed**: Ed25519 signatures ensure authenticity
- **Offline-ready**: Embedded fallback list included
- **User-friendly**: Search, filter, and select your broker

Supported brokers include LHFX, OANDA, ICMarkets, Pepperstone, XM Global, and more.

To add your broker: Submit a PR to [QuantumTrader-Pro-data](https://github.com/Dezirae-Stark/QuantumTrader-Pro-data)

📖 **User Guide**: See [docs/user/broker-setup.md](docs/user/broker-setup.md)
```

Commit:

```bash
git add README.md
git commit -m "docs: Add broker catalog section to README"
git push origin main
```

### Phase 8: Security Hardening (Recommended)

#### 8.1 Enable Branch Protection

For `QuantumTrader-Pro-data`:

1. Go to Settings → Branches
2. Add rule for `main`:
   - ☑️ Require pull request reviews (1 approval)
   - ☑️ Require status checks to pass
   - ☑️ Require branches to be up to date
   - ☑️ Include administrators

#### 8.2 Set Up Monitoring

Create a monitoring checklist:

```bash
cd ~/QuantumTrader-Pro-data

# Create monitoring doc
cat > MONITORING.md <<'EOF'
# Broker Catalog Monitoring

## Daily Checks
- [ ] GitHub Actions workflows passing
- [ ] Pages deployment successful

## Weekly Checks
- [ ] Signature verification working in production app
- [ ] No unauthorized commits to catalog
- [ ] Secret expiration dates reviewed

## Monthly Checks
- [ ] Audit logs reviewed
- [ ] Key rotation schedule on track
- [ ] User feedback on broker list
EOF

git add MONITORING.md
git commit -m "Add monitoring checklist"
git push
```

#### 8.3 Document Key Locations

```bash
# Create secure note in password manager:
# Title: "QuantumTrader Broker Signing Keys"
# Fields:
#   - Public Key Location: ~/broker-keys/broker_catalog.pub
#   - Private Key Backup: [Location of encrypted backup]
#   - Backup Encryption Password: [GPG passphrase]
#   - Signing Key Password: [minisign password]
#   - GitHub Secret Location: Dezirae-Stark/QuantumTrader-Pro-data/settings/environments/broker-pages
#   - Next Rotation Date: 2026-11-12
```

## ✅ Verification Checklist

Before going live, verify:

### Data Repository
- [ ] Repository created and public
- [ ] GitHub Pages enabled and accessible
- [ ] `brokers.json` loads at Pages URL
- [ ] Workflow runs successfully
- [ ] `brokers.json.sig` generated
- [ ] Signature verification works locally
- [ ] Branch protection enabled

### Secrets
- [ ] `BROKER_SIGNING_PRIVATE_KEY` added to environment
- [ ] `BROKER_SIGNING_PASSWORD` added to environment
- [ ] Secrets not visible in logs
- [ ] Private key backed up securely
- [ ] Backup location documented

### Android App
- [ ] Public key embedded in `SignatureVerifier.kt`
- [ ] Embedded `brokers.json` valid and up-to-date
- [ ] Network security config allows github.io
- [ ] Dependencies added to build.gradle
- [ ] App compiles successfully
- [ ] Manual testing on device:
  - [ ] Broker list loads
  - [ ] Search and filter work
  - [ ] Manual update works
  - [ ] Offline fallback works
  - [ ] WebTerminal link opens

### Documentation
- [ ] User guide complete
- [ ] Developer guide complete
- [ ] Security documentation complete
- [ ] README updated
- [ ] Monitoring checklist created

### Testing
- [ ] Unit tests passing
- [ ] Signature verification tested
- [ ] Offline mode tested
- [ ] Network error handling tested
- [ ] Cache persistence tested

## 🎉 Go Live!

Once all checks pass:

1. **Tag a release**:
   ```bash
   cd ~/QuantumTrader-Pro
   git tag -a v2.1.0 -m "Add dynamic broker catalog"
   git push origin v2.1.0
   ```

2. **Monitor release workflow**

3. **Announce to users**:
   - Post release notes
   - Explain new broker selection feature
   - Link to user guide

4. **Monitor for issues**:
   - Watch for crash reports
   - Check GitHub Issues
   - Monitor signature verification rates

## 📞 Support

Need help? Check:

- **Setup Issues**: [docs/dev/broker-catalog.md](docs/dev/broker-catalog.md)
- **Security Questions**: [docs/security/broker-signing.md](docs/security/broker-signing.md)
- **User Questions**: [docs/user/broker-setup.md](docs/user/broker-setup.md)

## 🔄 Maintenance

### Weekly
- Check workflow runs
- Review catalog for needed updates

### Monthly
- Review audit logs
- Check for security advisories
- Update documentation if needed

### Annually
- Rotate signing keys (see security docs)
- Review threat model
- Update dependencies

---

**Setup Version**: 1.0
**Last Updated**: 2025-11-12
