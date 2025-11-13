# Broker Catalog Signing Guide

Complete guide to generating keys, signing catalogs, and managing cryptographic security for QuantumTrader Pro broker catalogs.

## 🎯 Overview

Broker catalogs are signed with **Ed25519** digital signatures to ensure:
- **Authenticity**: Catalogs come from authorized source
- **Integrity**: Catalogs haven't been tampered with
- **Non-repudiation**: Signature proves who signed the catalog

## 🔧 Prerequisites

### Software Requirements

```bash
# Python 3.8+
python3 --version

# Install dependencies
cd tools
pip install -r requirements.txt
```

**Required packages:**
- `PyNaCl>=1.5.0` - Ed25519 cryptography
- `jsonschema>=4.17.0` - Schema validation
- `click>=8.1.0` - CLI interface

### Security Requirements

- Secure machine for key generation (offline recommended)
- Password manager or hardware security module (HSM)
- Encrypted backup storage
- Access control policies

## 🔑 Step 1: Generate Ed25519 Key Pair

### First Time Setup

```bash
cd tools
python3 generate-keys.py
```

**Output:**
```
======================================================================
QUANTUMTRADER PRO - BROKER CATALOG ED25519 KEY PAIR GENERATOR
======================================================================

PUBLIC KEY (commit to repository):
----------------------------------------------------------------------
A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2==
----------------------------------------------------------------------

⚠️  PRIVATE KEY (NEVER COMMIT - store securely):
----------------------------------------------------------------------
X1Y2Z3A4B5C6D7E8F9G0H1I2J3K4L5M6N7O8P9Q0R1S2T3U4V5W6X7Y8Z9A0B1C2D3E4F5G6==
----------------------------------------------------------------------

======================================================================
🔐 SECURITY WARNINGS:
======================================================================
✓ Save public key to: broker-catalogs/keys/public.key
✓ Hardcode public key in Android app for verification

⚠️  Store private key securely:
   - Use password manager (1Password, Bitwarden)
   - Use encrypted keystore
   - Use hardware security module (HSM)
   - Use secure vault (HashiCorp Vault)

❌ NEVER:
   - Commit private key to version control
   - Share private key via email/chat
   - Store private key in plain text file
   - Include private key in CI/CD logs

======================================================================

Save public key to broker-catalogs/keys/public.key? (y/n):
```

### Storing Keys

**Public Key:**
```bash
# Save to repository (safe to commit)
echo "A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2==" > ../keys/public.key
git add ../keys/public.key
git commit -m "Add Ed25519 public key for catalog verification"
```

**Private Key:**
```bash
# Option 1: Save to encrypted file (recommended)
echo "PRIVATE_KEY_HERE" | gpg --symmetric --armor > ~/secrets/catalog-private-key.asc

# Option 2: Save to password manager
# Copy private key to 1Password/Bitwarden/LastPass
# Label: "QuantumTrader Pro Catalog Signing Key"

# Option 3: Environment variable (ephemeral)
export CATALOG_PRIVATE_KEY="PRIVATE_KEY_HERE"
```

## ✍️  Step 2: Sign Broker Catalog

### Create Catalog JSON

```bash
cd catalogs
vi your-broker.json
```

**Minimum required fields:**
```json
{
  "schema_version": "1.0.0",
  "catalog_id": "your-broker-id",
  "catalog_name": "Your Broker Name",
  "last_updated": "2025-11-12T00:00:00Z",
  "platforms": {
    "mt4": {
      "available": true,
      "demo_server": "YourBroker-Demo",
      "live_servers": ["YourBroker-Live"]
    },
    "mt5": {
      "available": true,
      "demo_server": "YourBroker-MT5-Demo",
      "live_servers": ["YourBroker-MT5-Live"]
    }
  }
}
```

### Sign the Catalog

**Method 1: Inline private key**
```bash
python3 ../tools/sign-catalog.py your-broker.json \
    --private-key "YOUR_PRIVATE_KEY_BASE64"
```

**Method 2: Private key from file**
```bash
# Decrypt private key
gpg --decrypt ~/secrets/catalog-private-key.asc > /tmp/private.key

# Sign catalog
python3 ../tools/sign-catalog.py your-broker.json \
    --private-key-file /tmp/private.key

# Clean up
shred -u /tmp/private.key
```

**Method 3: Environment variable**
```bash
export CATALOG_PRIVATE_KEY="$(gpg --decrypt ~/secrets/catalog-private-key.asc)"

python3 ../tools/sign-catalog.py your-broker.json \
    --private-key "$CATALOG_PRIVATE_KEY"

unset CATALOG_PRIVATE_KEY
```

**Expected output:**
```
======================================================================
QUANTUMTRADER PRO - BROKER CATALOG SIGNER
======================================================================

📄 Reading catalog: your-broker.json
   Catalog ID: your-broker-id
   Name: Your Broker Name
   Schema: 1.0.0
🔄 Canonicalizing JSON...
   Canonical size: 458 bytes
🔑 Loading private key...
✍️  Signing catalog...
   Signature: 4KpZ3xQFqZvJ8y7V2wN9xRtE...
💾 Saving signature: your-broker.json.sig

======================================================================
✅ SUCCESS
======================================================================
   Catalog: your-broker.json
   Signature: your-broker.json.sig

Next steps:
   1. Verify signature: python3 verify-catalog.py your-broker.json
   2. Commit both files to repository
   3. Tag release if ready for distribution
======================================================================
```

## ✓ Step 3: Verify Signature

Always verify signatures after signing:

```bash
python3 ../tools/verify-catalog.py your-broker.json \
    --public-key-file ../keys/public.key
```

**Expected output:**
```
======================================================================
QUANTUMTRADER PRO - BROKER CATALOG SIGNATURE VERIFIER
======================================================================

📄 Reading catalog: your-broker.json
   Catalog ID: your-broker-id
   Name: Your Broker Name
   Schema: 1.0.0
🔄 Canonicalizing JSON...
   Canonical size: 458 bytes
📝 Reading signature: your-broker.json.sig
   Signature: 4KpZ3xQFqZvJ8y7V2wN9xRtE...
🔑 Loading public key...
🔍 Verifying signature...

======================================================================
✅ SIGNATURE VALID
======================================================================
   Catalog: your-broker.json
   Signature: your-broker.json.sig

   ✓ Signature verified successfully
   ✓ Catalog has NOT been tampered with
   ✓ Catalog was signed by holder of private key
   ✓ Safe to use this catalog
======================================================================
```

## 📋 Step 4: Update Index

Add your catalog to `catalogs/index.json`:

```json
{
  "schema_version": "1.0.0",
  "last_updated": "2025-11-12T00:00:00Z",
  "total_catalogs": 3,
  "catalogs": [
    ...existing catalogs...,
    {
      "id": "your-broker-id",
      "name": "Your Broker Name",
      "file": "your-broker.json",
      "signature": "your-broker.json.sig",
      "last_updated": "2025-11-12T00:00:00Z"
    }
  ]
}
```

## 🚀 Step 5: Commit and Push

```bash
cd ..
git status

# Should show:
# - catalogs/your-broker.json (new or modified)
# - catalogs/your-broker.json.sig (new or modified)
# - catalogs/index.json (modified)

git add catalogs/your-broker.json \
        catalogs/your-broker.json.sig \
        catalogs/index.json

git commit -m "Add Your Broker catalog with Ed25519 signature"

git push origin main
```

## 🔄 Updating Existing Catalogs

When updating a catalog:

1. **Edit JSON file**
   ```bash
   vi catalogs/existing-broker.json
   ```

2. **Update timestamp**
   ```json
   {
     "last_updated": "2025-11-13T00:00:00Z"  // Current timestamp
   }
   ```

3. **Re-sign**
   ```bash
   python3 tools/sign-catalog.py catalogs/existing-broker.json \
       --private-key "$CATALOG_PRIVATE_KEY"
   ```

4. **Verify**
   ```bash
   python3 tools/verify-catalog.py catalogs/existing-broker.json \
       --public-key-file keys/public.key
   ```

5. **Update index**
   - Update timestamp in `catalogs/index.json`
   - Update `total_catalogs` if needed

6. **Commit**
   ```bash
   git add catalogs/existing-broker.* catalogs/index.json
   git commit -m "Update Existing Broker catalog"
   git push
   ```

## 🔐 Security Best Practices

### Key Generation
- Generate keys on offline/secure machine
- Use entropy from hardware RNG if available
- Generate unique keys per deployment
- Never reuse keys across projects

### Key Storage
- Encrypt private keys at rest
- Use strong passphrases (20+ characters)
- Store backups in separate secure location
- Use HSM for production environments

### Key Usage
- Limit access to signing keys (need-to-know basis)
- Use ephemeral environment variables when possible
- Clear private keys from memory after use
- Log all signing operations for audit

### Key Rotation
- Rotate keys annually or after compromise
- Plan key rotation procedure in advance
- Document key history
- Update Android app with new public key

## 🛡️ Threat Scenarios

### Scenario 1: Private Key Compromised

**Impact:** Attacker can sign fake catalogs

**Response:**
1. Immediately stop using compromised key
2. Generate new key pair
3. Re-sign all catalogs with new key
4. Update public key in repository
5. Release new Android app with new public key
6. Document incident in SECURITY.md

### Scenario 2: Catalog Tampered

**Impact:** Signature verification fails

**Response:**
- Android app rejects catalog automatically
- User not affected (invalid catalogs not loaded)
- Investigate how tampering occurred
- Verify integrity of catalog repository

### Scenario 3: Man-in-the-Middle Attack

**Impact:** None (signature verification detects tampering)

**Response:**
- Ed25519 signatures prevent MITM attacks
- Even if download is intercepted, tampering detected
- No action needed (system works as designed)

## 📊 Signature Verification Flow

```
1. Android app downloads catalog.json
        ↓
2. Android app downloads catalog.json.sig
        ↓
3. App canonicalizes JSON (sorted keys, no whitespace)
        ↓
4. App decodes signature from base64
        ↓
5. App verifies signature using hardcoded public key
        ↓
6a. Valid → Load catalog into UI
6b. Invalid → Reject and show error
```

## 🧪 Testing Signatures

### Test Tampering Detection

```bash
# 1. Sign a catalog
python3 tools/sign-catalog.py catalogs/test.json --private-key "$KEY"

# 2. Verify (should pass)
python3 tools/verify-catalog.py catalogs/test.json --public-key-file keys/public.key

# 3. Modify catalog
echo "TAMPERED" >> catalogs/test.json

# 4. Verify again (should FAIL)
python3 tools/verify-catalog.py catalogs/test.json --public-key-file keys/public.key

# Expected: ❌ SIGNATURE INVALID
```

### Test Cross-Platform Verification

```bash
# Sign with Python
python3 tools/sign-catalog.py catalogs/test.json --private-key "$KEY"

# Verify with Python
python3 lib/signature-verifier.py catalogs/test.json "$PUBLIC_KEY"

# Verify with Node.js
node lib/signature-verifier.js catalogs/test.json "$PUBLIC_KEY"

# All should output: ✓ Signature VALID
```

## 📞 Support

For signing issues:
- See: `keys/README.md` (key management)
- See: `README.md` (general docs)
- See: `../../SECURITY.md` (security issues)
- GitHub Issues: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

---

**Remember**: The security of the entire system depends on protecting your private key!
