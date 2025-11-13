# Broker Catalog Signing Keys

This directory contains the Ed25519 public key used for verifying broker catalog signatures.

## ⚠️ IMPORTANT: Demo Keys Only

**The keys in this repository are DEMO KEYS for illustration purposes only.**

**DO NOT use these keys in production!**

Before deploying QuantumTrader Pro:
1. Generate new Ed25519 keys using `tools/generate-keys.py`
2. Replace `public.key` with your newly generated public key
3. Store private key securely (NEVER commit to repository)
4. Re-sign all broker catalogs with your new private key
5. Update Android app to use your new public key

## Files

### `public.key`
- **Purpose**: Verify signatures of broker catalogs
- **Format**: Base64-encoded Ed25519 public key (44 characters)
- **Safety**: Safe to commit to public repository
- **Usage**: Hardcoded in Android app for signature verification

### `private.key` (NOT INCLUDED)
- **Purpose**: Sign broker catalogs
- **Format**: Base64-encoded Ed25519 private key (88 characters)
- **Safety**: **NEVER** commit to version control
- **Storage**: Secure password manager, HSM, or encrypted vault

## Generating New Keys

```bash
cd tools
pip install -r requirements.txt
python3 generate-keys.py
```

This will output:
- Public key → Save to `keys/public.key` (commit to repo)
- Private key → Save to secure storage (NEVER commit)

## Key Management Best Practices

### ✅ DO:
- Generate unique keys for your deployment
- Store private key in password manager (1Password, Bitwarden)
- Use hardware security module (HSM) for production
- Rotate keys periodically (e.g., annually)
- Keep backup of private key in secure offline storage
- Use different keys for development/staging/production

### ❌ DON'T:
- Use the demo keys provided in this repository
- Commit private keys to version control
- Share private keys via email/chat/Slack
- Store private keys in plain text files
- Reuse keys across different projects
- Store private keys in CI/CD environment variables

## Key Rotation Procedure

If you need to rotate keys (e.g., key compromise, scheduled rotation):

1. **Generate New Keys**
   ```bash
   python3 tools/generate-keys.py
   ```

2. **Re-sign All Catalogs**
   ```bash
   for catalog in catalogs/*.json; do
       python3 tools/sign-catalog.py "$catalog" --private-key "$NEW_PRIVATE_KEY"
   done
   ```

3. **Update Repository**
   ```bash
   git add keys/public.key catalogs/*.sig
   git commit -m "Rotate signing keys"
   git tag -s v2.x.x
   git push --tags
   ```

4. **Update Android App**
   - Update hardcoded public key in app code
   - Release new app version
   - Users must update app to use new catalogs

5. **Revoke Old Keys**
   - Document key rotation in SECURITY.md
   - Announce to users via release notes
   - Archive old public key for reference

## Security Considerations

### Threat Model

**If private key is compromised:**
- Attacker can sign malicious broker catalogs
- Users could be directed to fraudulent brokers
- Immediate key rotation required

**If public key is compromised:**
- No security impact (public keys are meant to be public)
- Continue using existing keys

### Key Storage Recommendations

**Development:**
- Local password manager
- Encrypted file with strong passphrase
- Environment variable (ephemeral, not persisted)

**Production:**
- Hardware Security Module (HSM)
- Cloud KMS (AWS KMS, Google Cloud KMS, Azure Key Vault)
- HashiCorp Vault
- Dedicated signing server (air-gapped)

## Verification

After generating new keys, verify they work:

```bash
# Sign a test catalog
python3 tools/sign-catalog.py catalogs/sample-broker-1.json \
    --private-key "$PRIVATE_KEY"

# Verify signature
python3 tools/verify-catalog.py catalogs/sample-broker-1.json \
    --public-key-file keys/public.key
```

Expected output:
```
✅ SIGNATURE VALID
```

## Support

For questions about key management or signature verification:
- See: `../SIGNING.md`
- See: `../../SECURITY.md`
- GitHub Issues: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

---

**Remember**: Cryptographic security is only as strong as your key management practices. Protect your private keys!
