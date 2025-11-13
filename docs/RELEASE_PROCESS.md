# Release Process

This document describes the complete release process for QuantumTrader-Pro.

## Overview

QuantumTrader-Pro uses an automated release pipeline powered by GitHub Actions. When you push a version tag, GitHub automatically builds signed APKs, runs security scans, and creates a GitHub release.

---

## Prerequisites

Before creating a release:

- [ ] All changes merged to `main` branch
- [ ] All tests passing on main
- [ ] No pending security issues
- [ ] Code generation completed successfully
- [ ] PR reviewed and approved (if applicable)

---

## Release Workflow

### 1. Prepare Release

#### Update Version

Run the version bump script:

```bash
# For bug fixes
./scripts/bump-version.sh patch  # 2.1.0 -> 2.1.1

# For new features (backwards-compatible)
./scripts/bump-version.sh minor  # 2.1.0 -> 2.2.0

# For breaking changes
./scripts/bump-version.sh major  # 2.1.0 -> 3.0.0
```

The script will:
- Update `version.properties`
- Increment VERSION_CODE
- Provide next steps

#### Update CHANGELOG.md

Edit `CHANGELOG.md` to document the release:

```bash
nano CHANGELOG.md
```

Add a new section for your version:

```markdown
## [2.1.1] - 2025-01-15

### Added
- New feature X
- Enhancement Y

### Fixed
- Bug Z
- Issue W

### Security
- Security improvement Q
```

#### Commit Changes

```bash
# Check what changed
git status

# Add version and changelog
git add version.properties CHANGELOG.md

# Commit with semantic message
git commit -m "chore: Bump version to 2.1.1"

# Push to main
git push origin main
```

### 2. Create Release Tag

```bash
# Get the new version
VERSION=$(grep VERSION_NAME version.properties | cut -d'=' -f2)

# Create annotated tag
git tag -a "v${VERSION}" -m "Release v${VERSION}"

# Verify tag
git tag -l "v${VERSION}" -n

# Push tag (this triggers the release workflow!)
git push origin "v${VERSION}"
```

⚠️ **Important:** Pushing the tag triggers the automated release workflow!

### 3. Monitor Release Build

GitHub Actions will automatically:

1. **Security Scanning** (~2 minutes)
   - Secret detection with Gitleaks
   - Vulnerability scanning with Trivy
   - Upload results to Security tab

2. **Build Release APKs** (~10 minutes)
   - Set up Flutter 3.19.0 + Java 17
   - Run code generation
   - Execute tests
   - Build signed APKs (3 architectures)
   - Generate SHA256 checksums

3. **Create GitHub Release** (~1 minute)
   - Extract changelog
   - Create release notes
   - Upload APKs and checksums
   - Publish release

**Total time:** ~10-15 minutes

#### Monitor Workflow

```bash
# List workflow runs
gh run list --workflow=release.yml

# Watch current run
gh run watch

# View workflow in browser
gh workflow view release.yml --web
```

Or visit: https://github.com/Dezirae-Stark/QuantumTrader-Pro/actions

### 4. Verify Release

Once the workflow completes:

1. **Check Release Page**
   ```bash
   # Open latest release
   gh release view --web
   ```

2. **Verify Artifacts**
   - ✅ ARM64 APK (`*-arm64.apk`)
   - ✅ ARM32 APK (`*-arm32.apk`)
   - ✅ x86_64 APK (`*-x86_64.apk`)
   - ✅ Checksums file (`SHA256SUMS.txt`)

3. **Test Download**
   ```bash
   # Download latest release
   gh release download

   # Verify checksums
   sha256sum -c SHA256SUMS.txt
   ```

4. **Test Installation**
   - Install APK on test device
   - Verify app version in About screen
   - Test core functionality

### 5. Post-Release

#### Announce Release (Optional)

- Update website/docs with new version
- Post release announcement
- Notify users

#### Monitor Issues

- Watch for crash reports
- Monitor user feedback
- Prepare hotfix if needed

---

## Emergency Rollback

If a critical issue is discovered after release:

### Option 1: Delete Release

```bash
# Delete the release
gh release delete v2.1.1 --yes

# Delete the tag locally
git tag -d v2.1.1

# Delete the tag remotely
git push --delete origin v2.1.1
```

### Option 2: Create Hotfix

```bash
# Create hotfix
./scripts/bump-version.sh patch  # 2.1.1 -> 2.1.2

# Fix the issue
# ... make changes ...

# Commit and release
git commit -am "fix: Critical issue description"
git tag -a v2.1.2 -m "Hotfix release"
git push origin main v2.1.2
```

---

## Beta/Pre-Release

For testing before official release:

### Create Beta Tag

```bash
# Tag with beta suffix
git tag -a v2.1.0-beta.1 -m "Beta release"
git push origin v2.1.0-beta.1
```

### Mark as Pre-Release

The workflow automatically detects beta/rc tags and marks them as pre-release.

---

## Troubleshooting

### Workflow Failed

1. **Check Logs**
   ```bash
   gh run view --log-failed
   ```

2. **Common Issues:**

   **Security scan failed:**
   - Check for leaked secrets
   - Review Gitleaks/Trivy output
   - Fix issues and re-tag

   **Build failed:**
   - Verify Flutter version compatibility
   - Check code generation errors
   - Ensure tests pass locally

   **Keystore error:**
   - Verify GitHub Secrets are set:
     - KEYSTORE_BASE64
     - KEY_ALIAS
     - KEY_PASSWORD
     - STORE_PASSWORD

3. **Re-run Failed Jobs**
   ```bash
   gh run rerun <run-id> --failed
   ```

### Tag Already Exists

If you need to re-create a tag:

```bash
# Delete local tag
git tag -d v2.1.0

# Delete remote tag
git push --delete origin v2.1.0

# Delete release
gh release delete v2.1.0 --yes

# Create new tag
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0
```

---

## GitHub Secrets Configuration

Required secrets for release workflow:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `KEYSTORE_BASE64` | Base64-encoded keystore | `base64 -w 0 upload-keystore.jks` |
| `KEY_ALIAS` | Keystore alias | From keystore creation |
| `KEY_PASSWORD` | Key password | From keystore creation |
| `STORE_PASSWORD` | Store password | From keystore creation |

Optional:
- `GITLEAKS_LICENSE`: For Gitleaks Pro features

### Add Secrets

1. Go to: Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret
4. Verify: Secrets should show as "✅ Set"

---

## Release Checklist

Use this checklist for each release:

- [ ] All changes merged to main
- [ ] Tests passing
- [ ] Version bumped (`./scripts/bump-version.sh`)
- [ ] CHANGELOG.md updated
- [ ] Changes committed
- [ ] Tag created (`git tag -a vX.Y.Z`)
- [ ] Tag pushed (`git push origin vX.Y.Z`)
- [ ] Workflow completed successfully
- [ ] Release verified on GitHub
- [ ] APKs downloaded and tested
- [ ] Checksums verified
- [ ] App installed and tested
- [ ] Release announced (if applicable)

---

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0): Breaking changes, incompatible API
- **MINOR** (x.X.0): New features, backwards-compatible
- **PATCH** (x.x.X): Bug fixes, backwards-compatible

Examples:
- `2.1.0 → 2.1.1`: Bug fix
- `2.1.1 → 2.2.0`: New feature
- `2.2.0 → 3.0.0`: Breaking change

Pre-release suffixes:
- `2.1.0-alpha.1`: Alpha release
- `2.1.0-beta.2`: Beta release
- `2.1.0-rc.1`: Release candidate

---

## Automation Details

### Trigger

The release workflow triggers on:
- Push to tags matching `v*` (e.g., `v2.1.0`)
- Manual workflow dispatch

### Jobs

1. **security-scan** (2 min)
   - Gitleaks, Trivy
   - Must pass to proceed

2. **build-release** (10 min)
   - Flutter setup
   - Code generation
   - APK signing
   - Checksum generation

3. **create-release** (1 min)
   - Changelog extraction
   - GitHub release creation
   - Artifact upload

4. **notify-release** (30 sec)
   - Success notification

### Artifacts

Artifacts are retained for **90 days**:
- APK files (arm64, arm32, x86_64)
- SHA256 checksums

---

## Support

For issues with the release process:

1. Check workflow logs: `gh run view --log`
2. Review this documentation
3. Check GitHub Actions status
4. Open an issue if needed

---

## Related Documentation

- [Keystore Setup Guide](KEYSTORE_SETUP.md)
- [Security Best Practices](SECURITY.md)
- [Contributing Guide](../CONTRIBUTING.md)

---

**Last Updated:** 2025-01-12
