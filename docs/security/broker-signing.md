# Broker Catalog Signing Security

Security documentation for the QuantumTrader Pro broker catalog cryptographic signing system.

## 🔒 Overview

The broker catalog uses **Ed25519 digital signatures** to ensure:

- **Authenticity**: Only authorized parties can publish valid catalogs
- **Integrity**: Tampering is detected and rejected
- **Non-repudiation**: Signed catalogs prove origin

## 🔑 Key Management

### Key Generation

Generate an Ed25519 keypair using minisign:

```bash
# Install minisign
# Ubuntu/Debian: sudo apt install minisign
# macOS: brew install minisign
# Or download from: https://jedisct1.github.io/minisign/

# Generate keypair
minisign -G -p broker_catalog.pub -s broker_catalog.key

# You will be prompted for a password (REQUIRED for security)
```

**Output:**
- `broker_catalog.pub` - Public key (embed in app)
- `broker_catalog.key` - Private key (store in GitHub Secrets, **NEVER commit**)

### Key Format

**Public Key** (broker_catalog.pub):
```
untrusted comment: minisign public key ABCD1234
RWQy...Base64EncodedKey...==
```

**Private Key** (broker_catalog.key):
```
untrusted comment: minisign encrypted secret key
RWR...Base64EncodedEncryptedKey...==
```

### Embedding Public Key in App

1. **Extract the Base64 key** from `broker_catalog.pub` (second line)

2. **Update `SignatureVerifier.kt`**:

```kotlin
object SignatureVerifier {
    private const val PUBLIC_KEY_BASE64 = "RWQy...YOUR_ACTUAL_PUBLIC_KEY...=="
}
```

3. **Commit the updated file**:

```bash
git add android/app/src/main/kotlin/.../SignatureVerifier.kt
git commit -m "Update broker catalog public key"
git push
```

### Storing Private Key in GitHub Secrets

1. **Navigate to Data Repository**:
   - Go to `https://github.com/Dezirae-Stark/QuantumTrader-Pro-data`
   - Settings → Secrets and variables → Actions

2. **Create Environment** (if not exists):
   - Name: `broker-pages`
   - Protection rules: Require approval for deployments (optional but recommended)

3. **Add Secrets**:

   **Secret 1**: `BROKER_SIGNING_PRIVATE_KEY`
   ```bash
   # Copy the ENTIRE contents of broker_catalog.key
   cat broker_catalog.key | pbcopy  # macOS
   cat broker_catalog.key | xclip -selection clipboard  # Linux
   ```

   **Secret 2**: `BROKER_SIGNING_PASSWORD`
   ```
   The password you entered when generating the key
   ```

4. **Verify Secrets**:
   - Both secrets should appear in the `broker-pages` environment
   - Secrets are encrypted at rest by GitHub
   - Never visible in logs or outputs

## 🔐 Signing Process

### Automated (GitHub Actions)

The `publish-brokers.yml` workflow automatically signs:

```yaml
- name: Sign broker catalog
  env:
    BROKER_SIGNING_PRIVATE_KEY: ${{ secrets.BROKER_SIGNING_PRIVATE_KEY }}
    BROKER_SIGNING_PASSWORD: ${{ secrets.BROKER_SIGNING_PASSWORD }}
  run: |
    echo "$BROKER_SIGNING_PRIVATE_KEY" > /tmp/broker_signing.key
    echo "$BROKER_SIGNING_PASSWORD" | minisign -S \
      -s /tmp/broker_signing.key \
      -m brokers.json \
      -t "QuantumTrader-Pro broker catalog $(date -u +%Y-%m-%d)"
    rm -f /tmp/broker_signing.key
```

**Output**: `brokers.json.sig`

### Manual Signing (Emergency)

If you need to sign manually:

```bash
# Sign the file
minisign -S -s broker_catalog.key -m brokers.json -t "QuantumTrader-Pro catalog"

# Verify signature
minisign -V -p broker_catalog.pub -m brokers.json

# Output: brokers.json.sig
```

## ✅ Verification Process

### In-App Verification

1. **Fetch** `brokers.json` and `brokers.json.sig` over HTTPS
2. **Parse** minisign signature file:
   ```
   untrusted comment: <timestamp>
   RWT...BASE64_SIGNATURE...==
   trusted comment: QuantumTrader-Pro broker catalog 2025-11-12
   ```
3. **Verify** Ed25519 signature with embedded public key
4. **Accept** if valid, **reject** and fall back to cache if invalid

### Manual Verification

To verify a signed catalog:

```bash
# Download files
curl -O https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json
curl -O https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json.sig

# Verify (requires broker_catalog.pub)
minisign -V -p broker_catalog.pub -m brokers.json

# Expected output:
# Signature and comment signature verified
# Trusted comment: QuantumTrader-Pro broker catalog 2025-11-12
```

## 🔄 Key Rotation

### When to Rotate

Rotate keys if:

- **Compromise suspected**: Private key may be exposed
- **Scheduled rotation**: Every 1-2 years for best practice
- **Personnel change**: Key holder leaves the project
- **Algorithm upgrade**: Migrating to newer crypto (future)

### Rotation Procedure

**Phase 1: Generate New Key**

```bash
# Generate new keypair
minisign -G -p broker_catalog_new.pub -s broker_catalog_new.key

# Backup old keys securely
```

**Phase 2: Dual-Key Period (30 days)**

1. **Update App** (SignatureVerifier.kt):
   ```kotlin
   private const val PUBLIC_KEY_BASE64 = "RWQy...OLD_KEY...=="
   private const val PUBLIC_KEY_BACKUP_BASE64 = "RWQy...NEW_KEY...=="
   ```

2. **Release app update** with dual keys

3. **Update GitHub Secrets** with new private key

4. **Start signing with new key**

During this period:
- ✅ Old app versions verify with old key
- ✅ New app versions accept both keys
- ✅ All new catalogs signed with new key

**Phase 3: Cutover (after 90% adoption)**

1. **Update App**:
   ```kotlin
   private const val PUBLIC_KEY_BASE64 = "RWQy...NEW_KEY...=="
   private const val PUBLIC_KEY_BACKUP_BASE64 = null
   ```

2. **Release app update**

3. **Securely delete old private key**

4. **Document rotation in security log**

### Rotation Checklist

Pre-rotation:
- [ ] Generate new keypair
- [ ] Backup old keys to secure offline storage
- [ ] Test signing with new key locally
- [ ] Document rotation plan

Rotation:
- [ ] Add backup key to app
- [ ] Release app update with dual keys
- [ ] Wait for 90% user adoption (check Play Console)
- [ ] Update GitHub Secrets
- [ ] Test signing workflow with new key
- [ ] Monitor for verification errors

Post-rotation:
- [ ] Remove old key from app
- [ ] Release final update
- [ ] Securely wipe old private key
- [ ] Update documentation
- [ ] Send announcement to users

## 🚨 Compromise Response

If private key is compromised:

### Immediate Actions (Hour 0)

1. **Revoke GitHub Secrets**
   - Delete `BROKER_SIGNING_PRIVATE_KEY`
   - Disable `broker-pages` environment

2. **Stop Publishing**
   - Disable `publish-brokers.yml` workflow

3. **Notify Users**
   - Post security advisory
   - Recommend users verify broker selections

4. **Generate New Keys**
   - Follow key generation procedure
   - Use different password

### Short-term (Hour 1-24)

5. **Emergency App Update**
   - Add new public key as primary
   - Mark old key as revoked (don't verify)
   - Push emergency release

6. **Audit Catalog History**
   - Review all commits to data repo
   - Check for unauthorized changes
   - Verify all published catalogs

7. **Communicate**
   - Post incident report
   - Explain impact and remediation
   - Provide timeline

### Long-term (Week 1+)

8. **Root Cause Analysis**
   - Determine how compromise occurred
   - Fix security gaps
   - Document lessons learned

9. **Security Improvements**
   - Consider hardware keys (YubiKey)
   - Implement key splitting
   - Add monitoring/alerting

10. **Policy Update**
    - Revise key management procedures
    - Update incident response plan
    - Train team members

## 🛡️ Threat Model

### Protected Threats

| Threat | Mitigation |
|--------|-----------|
| Catalog tampering | Ed25519 signature verification |
| Man-in-the-middle | HTTPS + signature |
| Unauthorized publishing | Private key in GitHub Secrets |
| Replay attacks | Signature includes timestamp |
| Downgrade attacks | Schema version validation |

### Residual Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-----------|
| Private key compromise | High | Low | Key rotation, secure storage |
| GitHub infrastructure compromise | High | Very Low | Trust in GitHub security |
| Client-side malware | High | Medium | OS-level security, user education |
| Algorithm vulnerability | Medium | Very Low | Monitor crypto research, plan upgrade |

### Assumptions

We trust:
- ✅ GitHub Actions secret storage
- ✅ GitHub Pages infrastructure
- ✅ System CA certificates
- ✅ Android OS security
- ✅ Ed25519 algorithm

We do NOT trust:
- ❌ Network (assumed hostile)
- ❌ User device (may have malware)
- ❌ Local storage (can be tampered)

## 📊 Monitoring & Auditing

### Key Performance Indicators

Track in app analytics:

- **Signature verification success rate** (should be ~100%)
- **Update fetch success rate** (expected >95%)
- **Cache hit rate**
- **Time since last update** (user distribution)

### Audit Log

Maintain in data repo:

```
AUDIT_LOG.md

## 2025-11-12
- Event: Initial key generation
- Key ID: ABCD1234
- Action: Generated and deployed
- Operator: @your-github-username

## 2025-12-15
- Event: Catalog update
- Brokers added: 3
- Signature: Valid
```

### Security Monitoring

Set up alerts for:

- ❌ Signature verification failures (app-side)
- ❌ GitHub Actions workflow failures
- ❌ Unusual commit patterns in data repo
- ❌ Rapid key rotation (potential compromise)

## 📋 Compliance

### OWASP Mobile Top 10

| Risk | How We Mitigate |
|------|-----------------|
| M1: Improper Platform Usage | Follow Android security best practices |
| M2: Insecure Data Storage | No credentials stored, encrypted cache |
| M3: Insecure Communication | HTTPS + signature verification |
| M4: Insecure Authentication | N/A (no user auth for catalog) |
| M5: Insufficient Cryptography | Ed25519 (modern, secure algorithm) |

### Best Practices

- ✅ Use industry-standard algorithms (Ed25519)
- ✅ Never commit private keys
- ✅ Encrypt private keys at rest
- ✅ Rotate keys periodically
- ✅ Maintain offline backups
- ✅ Document security procedures
- ✅ Plan for compromise scenarios

## 📞 Security Contact

For security issues:

1. **DO NOT** open public GitHub issue
2. **DO** email security concerns to: [security@your-domain.com]
3. **Include**: Clear description, impact assessment, reproduction steps
4. **Expect**: Response within 48 hours

## 📚 References

- [Minisign Documentation](https://jedisct1.github.io/minisign/)
- [Ed25519 Specification](https://ed25519.cr.yp.to/)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-top-10/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)

---

**Last Updated**: 2025-11-12
**Security Version**: 1.0
**Key Rotation Schedule**: 2026-11-12 (annual)
