# PR-2: Dynamic Broker Catalog Repository - Implementation Plan

**Status:** 🚧 In Progress
**Author:** Dezirae Stark
**Date:** 2025-11-12
**Branch:** `feature/pr2-dynamic-broker-catalog`
**Base:** `feature/pr1-broker-agnostic-refactor`
**Depends On:** PR-1

---

## 🎯 Objectives

### Primary Goals
- Create separate broker catalog repository structure
- Implement Ed25519 digital signature system for catalog verification
- Define JSON schema for broker metadata
- Build signature verification library
- Create sample broker catalogs
- Provide tooling for catalog signing and verification

### Success Criteria
- [ ] Broker catalog JSON schema defined and documented
- [ ] Ed25519 key generation and signing tools implemented
- [ ] Signature verification library (Python and JavaScript)
- [ ] Sample broker catalogs with valid signatures
- [ ] Documentation for catalog format and signing process
- [ ] No hardcoded broker endorsements
- [ ] Cryptographic chain of trust established

---

## 📋 Catalog Repository Structure

### Directory Layout
```
broker-catalogs/
├── README.md                      # Catalog repository documentation
├── SIGNING.md                     # How to sign broker catalogs
├── schema/
│   ├── broker-catalog.schema.json # JSON Schema definition
│   └── signature.schema.json      # Signature format schema
├── catalogs/
│   ├── sample-broker-1.json       # Example broker catalog
│   ├── sample-broker-1.json.sig   # Ed25519 signature
│   ├── sample-broker-2.json
│   ├── sample-broker-2.json.sig
│   └── index.json                 # Master catalog index
├── keys/
│   ├── README.md                  # Key management documentation
│   ├── public.key                 # Public verification key (committed)
│   └── .gitignore                 # Excludes private.key
├── tools/
│   ├── sign-catalog.py            # Python signing tool
│   ├── verify-catalog.py          # Python verification tool
│   ├── generate-keys.py           # Key generation utility
│   └── requirements.txt           # Python dependencies
└── lib/
    ├── signature-verifier.py      # Python verification library
    ├── signature-verifier.js      # JavaScript verification library
    └── signature-verifier.dart    # Dart verification library (for Flutter)
```

---

## 🔐 Ed25519 Signature System

### Why Ed25519?
- **Fast**: Extremely efficient signature verification
- **Small**: 64-byte signatures, 32-byte keys
- **Secure**: 128-bit security level, collision-resistant
- **Deterministic**: No random number generation needed
- **Widely Supported**: Available in Python (PyNaCl), JavaScript (tweetnacl), Dart (cryptography)

### Signature Flow

#### 1. Catalog Creation
```
Developer creates/updates broker catalog JSON
    ↓
JSON is canonicalized (deterministic formatting)
    ↓
Ed25519 private key signs the JSON
    ↓
Signature saved as catalog-name.json.sig
    ↓
Both files committed to catalog repository
```

#### 2. Catalog Verification (Android App)
```
App downloads catalog JSON and .sig file
    ↓
App has hardcoded Ed25519 public key
    ↓
App verifies signature against public key
    ↓
If valid: Load broker data
If invalid: Reject catalog (tampered or unauthorized)
```

### Key Management

#### Public Key
- **Location**: `broker-catalogs/keys/public.key`
- **Format**: Base64-encoded Ed25519 public key (44 characters)
- **Committed**: YES (safe to commit, used for verification)
- **Embedded**: Hardcoded in Android app for signature verification

#### Private Key
- **Location**: Developer's secure storage (NOT in repository)
- **Format**: Base64-encoded Ed25519 private key (88 characters)
- **Committed**: NO (never commit to any repository)
- **Usage**: Sign broker catalogs during release process
- **Protection**: Encrypted keystore, hardware security module, or secure vault

---

## 📄 Broker Catalog JSON Schema

### Catalog Format

```json
{
  "schema_version": "1.0.0",
  "catalog_id": "unique-broker-identifier",
  "catalog_name": "Sample Broker",
  "last_updated": "2025-11-12T00:00:00Z",
  "metadata": {
    "official_website": "https://broker-website.com",
    "support_email": "support@broker-website.com",
    "support_phone": "+1-800-BROKER",
    "country": "US",
    "regulatory_bodies": ["NFA", "CFTC"],
    "license_numbers": ["NFA ID: 0123456"]
  },
  "platforms": {
    "mt4": {
      "available": true,
      "demo_server": "BrokerName-Demo",
      "live_servers": [
        "BrokerName-Live1",
        "BrokerName-Live2"
      ]
    },
    "mt5": {
      "available": true,
      "demo_server": "BrokerName-MT5-Demo",
      "live_servers": [
        "BrokerName-MT5-Live1"
      ]
    }
  },
  "features": {
    "min_deposit": 100.0,
    "max_leverage": 500,
    "currencies": ["USD", "EUR", "GBP"],
    "instruments": ["forex", "commodities", "indices", "crypto"],
    "spreads": {
      "typical": "From 0.1 pips",
      "variable": true
    }
  },
  "trading_conditions": {
    "commission": "No commission on standard accounts",
    "swap_free": false,
    "micro_lots": true,
    "hedging_allowed": true,
    "scalping_allowed": true,
    "ea_allowed": true
  },
  "account_types": [
    {
      "name": "Standard",
      "min_deposit": 100,
      "spreads": "Variable from 1.0 pips",
      "commission": "None"
    },
    {
      "name": "ECN",
      "min_deposit": 500,
      "spreads": "Variable from 0.1 pips",
      "commission": "$3 per lot per side"
    }
  ],
  "contact": {
    "email": "support@broker.com",
    "phone": "+1-800-BROKER",
    "live_chat": "https://broker.com/chat"
  },
  "disclaimer": "CFDs are complex instruments and come with a high risk of losing money rapidly due to leverage. You should consider whether you understand how CFDs work and whether you can afford to take the high risk of losing your money."
}
```

### Index Catalog Format

```json
{
  "schema_version": "1.0.0",
  "last_updated": "2025-11-12T00:00:00Z",
  "total_catalogs": 3,
  "catalogs": [
    {
      "id": "sample-broker-1",
      "name": "Sample Broker One",
      "file": "sample-broker-1.json",
      "signature": "sample-broker-1.json.sig",
      "last_updated": "2025-11-12T00:00:00Z"
    },
    {
      "id": "sample-broker-2",
      "name": "Sample Broker Two",
      "file": "sample-broker-2.json",
      "signature": "sample-broker-2.json.sig",
      "last_updated": "2025-11-10T00:00:00Z"
    }
  ]
}
```

---

## 🛠️ Tools Implementation

### 1. Key Generation Tool

**File**: `tools/generate-keys.py`

```python
#!/usr/bin/env python3
"""Generate Ed25519 key pair for broker catalog signing."""

import nacl.signing
import base64
import sys

def generate_keypair():
    # Generate new Ed25519 key pair
    signing_key = nacl.signing.SigningKey.generate()
    verify_key = signing_key.verify_key

    # Encode to base64
    private_key_b64 = base64.b64encode(bytes(signing_key)).decode('utf-8')
    public_key_b64 = base64.b64encode(bytes(verify_key)).decode('utf-8')

    return private_key_b64, public_key_b64

if __name__ == "__main__":
    private, public = generate_keypair()

    print("="*60)
    print("BROKER CATALOG ED25519 KEY PAIR")
    print("="*60)
    print()
    print("PUBLIC KEY (commit to repository):")
    print(public)
    print()
    print("PRIVATE KEY (NEVER COMMIT - store securely):")
    print(private)
    print()
    print("="*60)
    print("SECURITY WARNING:")
    print("- Store private key in secure location")
    print("- Never commit private key to version control")
    print("- Public key goes in broker-catalogs/keys/public.key")
    print("="*60)
```

### 2. Catalog Signing Tool

**File**: `tools/sign-catalog.py`

```python
#!/usr/bin/env python3
"""Sign a broker catalog JSON file with Ed25519."""

import json
import nacl.signing
import base64
import sys
import argparse
from pathlib import Path

def sign_catalog(catalog_path, private_key_b64):
    # Read catalog JSON
    with open(catalog_path, 'r') as f:
        catalog_data = json.load(f)

    # Canonicalize JSON (sorted keys, no whitespace)
    canonical_json = json.dumps(catalog_data, sort_keys=True, separators=(',', ':'))

    # Decode private key
    private_key_bytes = base64.b64decode(private_key_b64)
    signing_key = nacl.signing.SigningKey(private_key_bytes)

    # Sign the canonical JSON
    signed = signing_key.sign(canonical_json.encode('utf-8'))
    signature = signed.signature

    # Encode signature to base64
    signature_b64 = base64.b64encode(signature).decode('utf-8')

    # Write signature file
    sig_path = Path(str(catalog_path) + '.sig')
    with open(sig_path, 'w') as f:
        f.write(signature_b64)

    return sig_path

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Sign broker catalog with Ed25519')
    parser.add_argument('catalog', help='Path to broker catalog JSON file')
    parser.add_argument('--private-key', required=True, help='Base64-encoded Ed25519 private key')

    args = parser.parse_args()

    sig_file = sign_catalog(args.catalog, args.private_key)
    print(f"✓ Signed: {args.catalog}")
    print(f"✓ Signature: {sig_file}")
```

### 3. Catalog Verification Tool

**File**: `tools/verify-catalog.py`

```python
#!/usr/bin/env python3
"""Verify Ed25519 signature of a broker catalog."""

import json
import nacl.signing
import nacl.exceptions
import base64
import argparse
from pathlib import Path

def verify_catalog(catalog_path, signature_path, public_key_b64):
    # Read catalog JSON
    with open(catalog_path, 'r') as f:
        catalog_data = json.load(f)

    # Canonicalize JSON
    canonical_json = json.dumps(catalog_data, sort_keys=True, separators=(',', ':'))

    # Read signature
    with open(signature_path, 'r') as f:
        signature_b64 = f.read().strip()

    signature = base64.b64decode(signature_b64)

    # Decode public key
    public_key_bytes = base64.b64decode(public_key_b64)
    verify_key = nacl.signing.VerifyKey(public_key_bytes)

    # Verify signature
    try:
        verify_key.verify(canonical_json.encode('utf-8'), signature)
        return True
    except nacl.exceptions.BadSignatureError:
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Verify broker catalog signature')
    parser.add_argument('catalog', help='Path to broker catalog JSON file')
    parser.add_argument('--signature', help='Path to signature file (default: catalog.json.sig)')
    parser.add_argument('--public-key', required=True, help='Base64-encoded Ed25519 public key')

    args = parser.parse_args()

    sig_path = args.signature or str(args.catalog) + '.sig'

    valid = verify_catalog(args.catalog, sig_path, args.public_key)

    if valid:
        print(f"✓ VALID: Signature verification passed for {args.catalog}")
        sys.exit(0)
    else:
        print(f"✗ INVALID: Signature verification FAILED for {args.catalog}")
        sys.exit(1)
```

---

## 📚 Verification Libraries

### Python Library

**File**: `lib/signature-verifier.py`

Reusable Python library for integrating signature verification into other tools.

### JavaScript Library

**File**: `lib/signature-verifier.js`

For Node.js bridge server or web-based verification.

### Dart Library

**File**: `lib/signature-verifier.dart`

For Flutter Android app integration (PR-3 will use this).

---

## 🧪 Testing Strategy

### Test Cases

1. **Key Generation**
   - Generate multiple key pairs
   - Verify keys are unique
   - Verify correct length (32 bytes public, 64 bytes private)

2. **Catalog Signing**
   - Sign sample catalogs
   - Verify signatures validate with public key
   - Verify signatures fail with wrong public key

3. **Tampering Detection**
   - Modify signed catalog JSON
   - Verify signature now fails
   - Confirm tamper-proof guarantee

4. **Cross-Platform Verification**
   - Sign with Python tool
   - Verify with JavaScript library
   - Verify with Dart library
   - Confirm cross-language compatibility

5. **Performance**
   - Benchmark signature verification speed
   - Target: <10ms per catalog verification
   - Memory efficient for mobile devices

---

## 🔗 Integration with PR-3 and PR-4

### PR-3 Dependencies
- PR-3 (Android Catalog Loader) will use `lib/signature-verifier.dart`
- Public key will be hardcoded in Android app
- App will download catalogs from GitHub raw URL
- Signature verification happens before catalog data is loaded

### PR-4 Dependencies
- PR-4 (Broker Selection UI) will display catalogs loaded by PR-3
- UI will show verification status (verified checkmark icon)
- UI will allow search/filter of verified broker catalogs

---

## 📖 Documentation Requirements

### README.md (Broker Catalog Repository)
- Overview of catalog system
- How to use catalogs
- Signature verification explanation
- Contributing new broker catalogs

### SIGNING.md
- How to generate keys
- How to sign catalogs
- Security best practices
- Key management procedures

### Schema Documentation
- JSON schema with examples
- Required vs optional fields
- Field validation rules
- Versioning strategy

---

## ⚠️ Security Considerations

### Threat Model

1. **Tampered Catalogs**: Attacker modifies catalog JSON
   - **Mitigation**: Ed25519 signature verification fails

2. **Malicious Catalog**: Attacker creates fake catalog
   - **Mitigation**: No valid signature (no access to private key)

3. **Man-in-the-Middle**: Network attacker intercepts catalog download
   - **Mitigation**: Signature verification detects tampering

4. **Compromised Private Key**: Private key leaked
   - **Mitigation**: Immediate key rotation, revoke old catalogs

### Trust Chain

```
Developer (trusted)
    ↓
    Generates Ed25519 key pair
    ↓
    Private key (secured) → Public key (in Android app)
    ↓
    Signs broker catalogs
    ↓
    Android app verifies with hardcoded public key
    ↓
    User trusts verified catalogs
```

---

## 🚀 Implementation Phases

### Phase 1: Core Infrastructure
- [x] Create PR-2 branch
- [ ] Create broker-catalogs directory structure
- [ ] Implement Ed25519 key generation tool
- [ ] Implement catalog signing tool
- [ ] Implement catalog verification tool

### Phase 2: Verification Libraries
- [ ] Python signature verification library
- [ ] JavaScript signature verification library
- [ ] Dart signature verification library
- [ ] Cross-platform testing

### Phase 3: Sample Catalogs
- [ ] Define JSON schema
- [ ] Create 3 sample broker catalogs
- [ ] Sign all sample catalogs
- [ ] Create index.json

### Phase 4: Documentation
- [ ] broker-catalogs/README.md
- [ ] broker-catalogs/SIGNING.md
- [ ] Schema documentation
- [ ] Key management guide

### Phase 5: Testing & Validation
- [ ] Test all tools
- [ ] Verify cross-platform compatibility
- [ ] Security review
- [ ] Performance benchmarks

### Phase 6: PR Creation
- [ ] Create PR-2.md documentation
- [ ] Commit all changes
- [ ] Create pull request
- [ ] Link to PR-1

---

## 📊 Success Metrics

- [ ] All tools functional (generate, sign, verify)
- [ ] 3+ sample broker catalogs with valid signatures
- [ ] JSON schema documented and validated
- [ ] Cross-platform verification works (Python, JS, Dart)
- [ ] Signature verification < 10ms
- [ ] Comprehensive documentation
- [ ] Zero security vulnerabilities
- [ ] No broker endorsements (all samples generic)

---

## 📝 Notes

- This PR does NOT modify the Android app (that's PR-3)
- This PR does NOT create UI for broker selection (that's PR-4)
- Focus: Infrastructure and tooling for broker catalogs
- Foundation for dynamic, cryptographically-verified broker selection

---

**Status**: Planning complete, beginning implementation...
