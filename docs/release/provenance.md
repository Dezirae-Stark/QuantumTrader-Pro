# 🔐 Release Provenance & Verification Guide

## Overview

Every official QuantumTrader Pro release includes cryptographic signatures, checksums, and Software Bill of Materials (SBOM) to ensure authenticity, integrity, and supply-chain transparency.

**⚠️ IMPORTANT:** Always download releases from [GitHub Releases](https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases). Do **not** consume ephemeral GitHub Actions artifacts—they lack the same provenance guarantees and may expire.

---

## 📦 Release Assets

Each release includes:

| Asset | Purpose |
|-------|---------|
| `QuantumTraderPro-vX.X.X.apk` | The Android application binary |
| `QuantumTraderPro-vX.X.X.apk.sha256` | SHA256 checksum for integrity verification |
| `QuantumTraderPro-vX.X.X.apk.sha256.asc` | GPG signature of the checksum (if available) |
| `sbom-android-vX.X.X.json` | Android dependency SBOM (CycloneDX format) |
| `sbom-flutter-vX.X.X.json` | Flutter dependency SBOM (CycloneDX format) |
| `provenance-vX.X.X.json` | Build metadata and provenance information |

---

## ✅ Verification Steps

### 1. Download Release Assets

```bash
# Replace vX.X.X with the actual version number (e.g., v2.1.0)
VERSION="v2.1.0"
REPO="Dezirae-Stark/QuantumTrader-Pro"

# Download APK and verification files
wget https://github.com/${REPO}/releases/download/${VERSION}/QuantumTraderPro-${VERSION}.apk
wget https://github.com/${REPO}/releases/download/${VERSION}/QuantumTraderPro-${VERSION}.apk.sha256
wget https://github.com/${REPO}/releases/download/${VERSION}/QuantumTraderPro-${VERSION}.apk.sha256.asc

# Optional: Download SBOMs and provenance
wget https://github.com/${REPO}/releases/download/${VERSION}/sbom-android-${VERSION}.json
wget https://github.com/${REPO}/releases/download/${VERSION}/sbom-flutter-${VERSION}.json
wget https://github.com/${REPO}/releases/download/${VERSION}/provenance-${VERSION}.json
```

### 2. Verify SHA256 Checksum

**Purpose:** Ensures the APK was not corrupted or tampered with during download.

```bash
# Verify checksum (Linux/macOS/Termux)
sha256sum -c QuantumTraderPro-${VERSION}.apk.sha256

# Expected output:
# QuantumTraderPro-vX.X.X.apk: OK
```

**Windows (PowerShell):**
```powershell
$version = "v2.1.0"
$expectedHash = (Get-Content "QuantumTraderPro-$version.apk.sha256").Split()[0]
$actualHash = (Get-FileHash "QuantumTraderPro-$version.apk" -Algorithm SHA256).Hash.ToLower()

if ($actualHash -eq $expectedHash) {
    Write-Host "✅ Checksum verified: APK is authentic" -ForegroundColor Green
} else {
    Write-Host "❌ Checksum MISMATCH! Do not install this APK!" -ForegroundColor Red
}
```

**⚠️ If verification fails:** The file may be corrupted or malicious. Do **not** install. Re-download from GitHub Releases.

---

### 3. Verify GPG Signature (Optional but Recommended)

**Purpose:** Cryptographically proves the release was signed by the QuantumTrader Pro maintainer.

#### 3.1 Import the Public GPG Key

The maintainer's public key fingerprint will be published in:
- This repository's README
- Release notes
- GitHub profile

```bash
# Import public key from keyserver (example - replace with actual key ID)
gpg --recv-keys <KEY_ID>

# OR import from a file if provided
gpg --import quantum-trader-pro-public.asc

# Verify key fingerprint matches the published one
gpg --fingerprint <KEY_ID>
```

**Expected fingerprint format:**
```
pub   rsa4096 2025-01-12 [SC]
      ABCD 1234 EFGH 5678 IJKL 9012 MNOP 3456 QRST 7890
uid           Dezirae Stark <clockwork.halo@tutanota.de>
sub   rsa4096 2025-01-12 [E]
```

#### 3.2 Verify the Signature

```bash
# Verify the GPG signature
gpg --verify QuantumTraderPro-${VERSION}.apk.sha256.asc QuantumTraderPro-${VERSION}.apk.sha256

# Expected output:
# gpg: Signature made Mon Jan 12 10:30:00 2025 UTC
# gpg:                using RSA key ABCD1234EFGH5678IJKL9012MNOP3456QRST7890
# gpg: Good signature from "Dezirae Stark <clockwork.halo@tutanota.de>" [unknown]
# gpg: WARNING: This key is not certified with a trusted signature!
# gpg:          There is no indication that the signature belongs to the owner.
```

**✅ "Good signature"** means the file is authentic.

**⚠️ "BAD signature"** means tampering occurred—do not use the APK!

**Note about trust warnings:** GPG may warn that the key is not certified unless you explicitly trust it:
```bash
# To trust the key (after verifying fingerprint):
gpg --edit-key <KEY_ID>
gpg> trust
gpg> 5 (ultimate trust)
gpg> quit
```

---

## 📋 SBOM (Software Bill of Materials)

### What is an SBOM?

An SBOM is a machine-readable inventory of all software components, libraries, and dependencies included in the application. It enables:

- **Supply-chain transparency**: Know exactly what code runs in your app
- **Vulnerability tracking**: Quickly identify if a dependency has known CVEs
- **License compliance**: Verify all dependencies meet licensing requirements
- **Security audits**: Enable third-party security assessments

### Inspecting the SBOM

QuantumTrader Pro provides two SBOMs in **CycloneDX 1.5 JSON format**:

1. **`sbom-android-vX.X.X.json`**: Android/Gradle dependencies (Java/Kotlin libraries)
2. **`sbom-flutter-vX.X.X.json`**: Flutter/Dart dependencies (pub packages)

#### View SBOM Components

```bash
# View all Android dependencies
jq '.components[] | {name: .name, version: .version, type: .type}' sbom-android-${VERSION}.json

# View Flutter dependencies
jq '.components[] | {name: .name, version: .version}' sbom-flutter-${VERSION}.json

# Search for a specific dependency
jq '.components[] | select(.name | contains("okhttp"))' sbom-android-${VERSION}.json

# Count total components
jq '.components | length' sbom-android-${VERSION}.json
```

#### Check for Known Vulnerabilities

Use SBOM scanning tools to cross-reference with vulnerability databases:

```bash
# Example using OSS Index (free tool)
pip install jake
jake sbom sbom-android-${VERSION}.json

# Example using CycloneDX CLI (if available)
cyclonedx-cli analyze sbom-android-${VERSION}.json
```

**Popular SBOM analysis tools:**
- [Dependency-Track](https://dependencytrack.org/) - Open-source vulnerability management
- [Grype](https://github.com/anchore/grype) - Vulnerability scanner
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)

---

## 🔬 Build Provenance Metadata

The `provenance-vX.X.X.json` file contains build environment details:

```json
{
  "version": "v2.1.0",
  "buildTime": "2025-01-12T10:30:00Z",
  "commit": "abc123def456...",
  "commitShort": "abc123d",
  "branch": "v2.1.0",
  "workflow": "Release with Provenance & Signatures",
  "runId": "12345678",
  "runNumber": "42",
  "actor": "Dezirae-Stark",
  "repository": "Dezirae-Stark/QuantumTrader-Pro",
  "flutterVersion": "3.19.0",
  "javaVersion": "17",
  "buildType": "release"
}
```

### Verify Build Provenance

```bash
# View build metadata
jq '.' provenance-${VERSION}.json

# Verify the commit hash matches the tagged commit
git show $(jq -r '.commit' provenance-${VERSION}.json)

# Check the workflow run on GitHub
WORKFLOW_RUN=$(jq -r '.runId' provenance-${VERSION}.json)
echo "View build logs: https://github.com/Dezirae-Stark/QuantumTrader-Pro/actions/runs/${WORKFLOW_RUN}"
```

**Reproducibility:** The provenance metadata allows anyone to verify that:
1. The APK was built from the tagged commit
2. The build occurred on GitHub Actions (not a local machine)
3. The build environment matches declared versions (Flutter 3.19.0, Java 17)

---

## 🚨 Security Best Practices

### ✅ DO:
- Download releases **only** from [GitHub Releases](https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases)
- Always verify checksums before installation
- Verify GPG signatures when available
- Review SBOM for unexpected dependencies
- Check provenance metadata for unexpected build environments

### ❌ DON'T:
- **Do not download APKs from GitHub Actions artifacts** (they expire after 90 days and lack full provenance)
- Do not install APKs from third-party sites or mirrors
- Do not skip checksum verification
- Do not ignore GPG signature verification failures

### Reporting Issues

If you encounter verification failures or suspect tampering:

1. **Do not install the APK**
2. Open a security issue: [https://github.com/Dezirae-Stark/QuantumTrader-Pro/security/advisories/new](https://github.com/Dezirae-Stark/QuantumTrader-Pro/security/advisories/new)
3. Include verification output and file hashes

**Private security disclosure:** Email `clockwork.halo@tutanota.de` with `[SECURITY]` in subject line.

---

## 📚 Additional Resources

- [CycloneDX SBOM Specification](https://cyclonedx.org/)
- [NIST Software Supply Chain Security](https://www.nist.gov/itl/executive-order-improving-nations-cybersecurity/software-supply-chain-security-guidance)
- [SLSA Framework](https://slsa.dev/) - Supply-chain Levels for Software Artifacts
- [Sigstore](https://www.sigstore.dev/) - Keyless signing (future enhancement)

---

## 🔑 Maintainer Public Key

**Current Signing Key Information:**

```
Key ID: [TO BE ADDED - Generated during first signed release]
Fingerprint: [TO BE ADDED]
Email: clockwork.halo@tutanota.de
```

**Key will be published:**
- In this document after first signed release
- On [keys.openpgp.org](https://keys.openpgp.org/)
- In release notes

**Validity:** Check key expiration before use. If expired, a new key will be announced via GitHub release notes.

---

## 📝 Verification Checklist

Before installing QuantumTrader Pro APK:

- [ ] Downloaded from official GitHub Releases (not Actions artifacts)
- [ ] SHA256 checksum verified successfully
- [ ] GPG signature verified (if available)
- [ ] SBOM reviewed for unexpected dependencies
- [ ] Provenance metadata inspected
- [ ] Release notes reviewed for security advisories

**If all checks pass:** The APK is authentic and safe to install.

**If any check fails:** Do not install. Report the issue immediately.

---

*Last updated: 2025-01-12*
*QuantumTrader Pro Security Team*
