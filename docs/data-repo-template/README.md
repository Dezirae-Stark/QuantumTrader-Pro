# QuantumTrader-Pro Broker Catalog

This repository hosts the dynamic broker catalog for the QuantumTrader-Pro Android application.

## 📋 Contents

- `brokers.json` - The broker catalog (public data only, no secrets)
- `brokers.json.sig` - Ed25519 detached signature (auto-generated)
- `brokers.schema.json` - JSON schema for validation
- `catalog_metadata.json` - Catalog metadata (auto-generated)
- `index.html` - Simple landing page

## 🔒 Security

This catalog is cryptographically signed with Ed25519 to ensure authenticity:

1. All changes to `brokers.json` trigger automatic validation and signing
2. The signature is verified by the Android app before accepting updates
3. Only holders of the private key can publish valid catalogs

**Public Key** (embedded in app): See `docs/security/broker-signing.md` in the main repo

## 📝 Adding a Broker

To add or update a broker:

1. Fork this repository
2. Edit `brokers.json` following the schema
3. Submit a Pull Request
4. After review and merge, the workflow will automatically sign and publish

### Broker Entry Format

```json
{
  "name": "Broker Name",
  "server": "broker-server-id",
  "platform": "MT4",
  "webTerminalUrl": "https://trade.mql5.com/trade?servers=BrokerName-Live",
  "description": "Optional description",
  "demo": false
}
```

### Required Fields

- `name`: Display name (1-100 chars)
- `server`: MT4/MT5 server identifier
- `platform`: Must be "MT4" or "MT5"
- `webTerminalUrl`: Must use HTTPS

### Optional Fields

- `logo`: HTTPS URL to broker logo
- `description`: Brief description (max 500 chars)
- `demo`: Boolean, true for demo accounts

## ✅ Validation Rules

All entries must pass:

1. **JSON Syntax**: Valid JSON array
2. **Schema**: Matches `brokers.schema.json`
3. **Required Fields**: All required fields present and non-empty
4. **Platform**: Must be "MT4" or "MT5"
5. **HTTPS Only**: All URLs must use HTTPS
6. **No Secrets**: No credentials, API keys, or sensitive data

## 🚀 Deployment

- Hosted on GitHub Pages
- Auto-deploys on push to `main`
- Accessible at: `https://dezirae-stark.github.io/QuantumTrader-Pro-data/`

## 📍 URLs

- **Catalog**: https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json
- **Signature**: https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json.sig
- **Metadata**: https://dezirae-stark.github.io/QuantumTrader-Pro-data/catalog_metadata.json

## 🔄 Update Schedule

The Android app checks for updates:

- On app startup (if cache > 1 hour old)
- Weekly background sync (WorkManager)
- Manual refresh from Settings

## 🛡️ Threat Model

**Protected Against:**
- Unauthorized catalog modifications (signature verification)
- Man-in-the-middle attacks (HTTPS + signature)
- Malformed data (schema validation)

**Not Protected Against:**
- Compromise of private signing key (requires key rotation)
- GitHub infrastructure compromise (trust in GitHub)

**Mitigation:**
- Private key stored in GitHub Secrets (encrypted at rest)
- Key rotation plan documented
- Embedded fallback catalog in app

## 📞 Support

Questions? Open an issue in the main [QuantumTrader-Pro](https://github.com/Dezirae-Stark/QuantumTrader-Pro) repository.

## 📄 License

See LICENSE in the main repository.
