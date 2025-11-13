# QuantumTrader Pro - Broker Catalog Repository

**Cryptographically-signed broker catalog system with Ed25519 signature verification.**

## 🎯 Overview

This directory contains the broker catalog infrastructure for QuantumTrader Pro. Broker catalogs are JSON files containing broker metadata (server names, features, trading conditions) that are cryptographically signed with Ed25519 to ensure authenticity and prevent tampering.

### Why Signed Catalogs?

- ✅ **Authenticity**: Verify catalogs come from trusted source
- ✅ **Tamper-Proof**: Detect any unauthorized modifications
- ✅ **Decentralized**: No central server required for verification
- ✅ **Offline Verification**: Works without internet connection
- ✅ **Fast**: Ed25519 signature verification is extremely fast (<10ms)

## 📁 Directory Structure

```
broker-catalogs/
├── README.md                  # This file
├── SIGNING.md                 # Signing guide
├── schema/                    # JSON Schema definitions
│   ├── broker-catalog.schema.json
│   └── signature.schema.json
├── catalogs/                  # Broker catalog JSON files
│   ├── index.json            # Master catalog index
│   ├── sample-broker-1.json
│   ├── sample-broker-1.json.sig
│   ├── sample-broker-2.json
│   └── sample-broker-2.json.sig
├── keys/                      # Cryptographic keys
│   ├── README.md             # Key management guide
│   ├── public.key            # Ed25519 public key (committed)
│   └── .gitignore            # Excludes private keys
├── tools/                     # Signing and verification tools
│   ├── generate-keys.py      # Generate Ed25519 key pair
│   ├── sign-catalog.py       # Sign broker catalogs
│   ├── verify-catalog.py     # Verify signatures
│   └── requirements.txt      # Python dependencies
└── lib/                       # Verification libraries
    ├── signature-verifier.py   # Python library
    ├── signature-verifier.js   # JavaScript/Node.js library
    └── signature_verifier.dart # Dart/Flutter library
```

## 🚀 Quick Start

### For Catalog Users (Android App)

The Android app automatically:
1. Downloads broker catalogs from GitHub
2. Verifies Ed25519 signatures using hardcoded public key
3. Loads verified catalogs into broker selection UI
4. Rejects catalogs with invalid signatures

**No manual steps required!**

### For Catalog Contributors

#### 1. Generate Keys (First Time Only)

```bash
cd tools
pip install -r requirements.txt
python3 generate-keys.py
```

Save the output:
- **Public key** → `keys/public.key` (commit to repo)
- **Private key** → Secure storage (NEVER commit!)

#### 2. Create Broker Catalog

Create `catalogs/your-broker.json` following the schema:

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
      "live_servers": ["YourBroker-Live1"]
    },
    "mt5": {
      "available": true,
      "demo_server": "YourBroker-MT5-Demo",
      "live_servers": ["YourBroker-MT5-Live"]
    }
  }
}
```

See `schema/broker-catalog.schema.json` for full schema.

#### 3. Sign Catalog

```bash
python3 tools/sign-catalog.py catalogs/your-broker.json \
    --private-key "$YOUR_PRIVATE_KEY"
```

This creates `catalogs/your-broker.json.sig`.

#### 4. Verify Signature

```bash
python3 tools/verify-catalog.py catalogs/your-broker.json \
    --public-key-file keys/public.key
```

Expected output: `✅ SIGNATURE VALID`

#### 5. Update Index

Add your catalog to `catalogs/index.json`:

```json
{
  "catalogs": [
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

#### 6. Commit and Push

```bash
git add catalogs/your-broker.json catalogs/your-broker.json.sig catalogs/index.json
git commit -m "Add Your Broker catalog"
git push
```

## 🔐 Ed25519 Signature System

### How It Works

```
Developer (you)
    ↓
Generate Ed25519 key pair
    ↓
Create broker catalog JSON
    ↓
Sign JSON with private key → Creates .sig file
    ↓
Commit JSON + .sig to repository
    ↓
Android app downloads JSON + .sig
    ↓
App verifies signature with hardcoded public key
    ↓
If valid: Load catalog
If invalid: Reject (tampered or unauthorized)
```

### Security Guarantees

**With Ed25519 signatures:**
- Catalog authenticity is cryptographically guaranteed
- Any tampering invalidates the signature
- No man-in-the-middle attacks possible
- No central server or API required

**Attacker cannot:**
- Modify existing catalogs (signature fails)
- Create fake catalogs (no private key)
- Intercept and alter downloads (signature fails)

### Key Management

**Public Key** (`keys/public.key`):
- 44-character base64 string
- Safe to commit to public repository
- Hardcoded in Android app
- Used to verify signatures

**Private Key** (NOT in repository):
- 88-character base64 string
- **NEVER commit to version control**
- Store in password manager or HSM
- Used to sign catalogs

See `keys/README.md` for detailed key management guide.

## 📋 Catalog Schema

### Required Fields

```json
{
  "schema_version": "1.0.0",          // Schema version
  "catalog_id": "unique-id",          // Unique identifier
  "catalog_name": "Broker Name",      // Display name
  "last_updated": "2025-11-12T00:00:00Z",  // ISO 8601 timestamp
  "platforms": {                      // MT4/MT5 availability
    "mt4": {...},
    "mt5": {...}
  }
}
```

### Optional Fields

- `metadata`: Broker info (website, email, regulatory bodies)
- `features`: Trading conditions (min deposit, leverage, spreads)
- `trading_conditions`: Policies (commission, swaps, hedging)
- `account_types`: Available account types
- `contact`: Contact information
- `disclaimer`: Risk disclaimer

See `schema/broker-catalog.schema.json` for complete specification.

## 🛠️ Tools

### `generate-keys.py`
Generate new Ed25519 key pair.

```bash
python3 tools/generate-keys.py
```

### `sign-catalog.py`
Sign a broker catalog JSON file.

```bash
python3 tools/sign-catalog.py <catalog.json> --private-key <KEY>
```

### `verify-catalog.py`
Verify catalog signature.

```bash
python3 tools/verify-catalog.py <catalog.json> --public-key-file keys/public.key
```

See individual tool `--help` for full options.

## 📚 Verification Libraries

### Python

```python
from lib.signature_verifier import CatalogVerifier

verifier = CatalogVerifier(public_key_b64="...")
if verifier.verify_file('catalog.json'):
    print("Valid!")
```

### JavaScript/Node.js

```javascript
const { CatalogVerifier } = require('./lib/signature-verifier');

const verifier = new CatalogVerifier(publicKeyB64);
if (verifier.verifyData(catalogData, signatureB64)) {
    console.log('Valid!');
}
```

### Dart/Flutter

```dart
import 'package:your_app/signature_verifier.dart';

final verifier = CatalogVerifier(publicKeyB64: '...');
if (await verifier.verifyData(catalogData, signatureB64)) {
  print('Valid!');
}
```

## ⚠️ Important Notes

### Demo Keys

**The keys in this repository are DEMO KEYS for illustration only.**

Before production use:
1. Generate new keys with `tools/generate-keys.py`
2. Replace `keys/public.key`
3. Re-sign all catalogs
4. Update Android app with new public key

### No Broker Endorsements

- Sample catalogs are fictional examples
- No specific broker is endorsed or recommended
- QuantumTrader Pro works with any MT4/MT5 broker
- Users choose brokers based on their own research

### Security Responsibility

- Protect your private key
- Verify all catalogs before committing
- Never commit secrets to version control
- Follow key management best practices

## 🔄 Workflow Examples

### Adding a New Broker

```bash
# 1. Create catalog JSON
vi catalogs/newbroker.json

# 2. Validate against schema (optional)
jsonschema -i catalogs/newbroker.json schema/broker-catalog.schema.json

# 3. Sign catalog
python3 tools/sign-catalog.py catalogs/newbroker.json \
    --private-key-file ~/.secrets/catalog-signing-key

# 4. Verify signature
python3 tools/verify-catalog.py catalogs/newbroker.json \
    --public-key-file keys/public.key

# 5. Update index
vi catalogs/index.json  # Add entry for newbroker

# 6. Commit
git add catalogs/newbroker.json catalogs/newbroker.json.sig catalogs/index.json
git commit -m "Add NewBroker catalog"
git push
```

### Updating Existing Catalog

```bash
# 1. Edit catalog
vi catalogs/existingbroker.json

# 2. Update timestamp
# Set "last_updated" to current ISO 8601 timestamp

# 3. Re-sign
python3 tools/sign-catalog.py catalogs/existingbroker.json \
    --private-key-file ~/.secrets/catalog-signing-key

# 4. Verify
python3 tools/verify-catalog.py catalogs/existingbroker.json \
    --public-key-file keys/public.key

# 5. Update index timestamp
vi catalogs/index.json

# 6. Commit
git add catalogs/existingbroker.json catalogs/existingbroker.json.sig catalogs/index.json
git commit -m "Update ExistingBroker catalog"
git push
```

## 🧪 Testing

Run verification tests:

```bash
# Test all catalogs
for catalog in catalogs/*.json; do
    [ "$catalog" = "catalogs/index.json" ] && continue
    echo "Testing: $catalog"
    python3 tools/verify-catalog.py "$catalog" --public-key-file keys/public.key
done
```

Expected: All catalogs show `✅ SIGNATURE VALID`.

## 📖 Further Reading

- **Signing Guide**: See `SIGNING.md`
- **Key Management**: See `keys/README.md`
- **JSON Schema**: See `schema/broker-catalog.schema.json`
- **Security**: See `../../SECURITY.md`
- **Android Integration**: See PR-3 documentation

## 🆘 Support

For questions or issues:
- **GitHub Issues**: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
- **Security Issues**: See `../../SECURITY.md`
- **Contributing**: See `../../CONTRIBUTING.md`

## 📄 License

MIT - QuantumTrader Pro

---

**Remember**: Cryptographic signatures are only as secure as your key management practices!
