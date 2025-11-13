# 🚀 Broker Catalog Deployment Quickstart

**For**: QuantumTrader Pro Dynamic Broker Catalog
**Status**: PR #12 Open - Ready for Deployment
**Time**: ~30 minutes

---

## 📋 Prerequisites

- [x] PR #12 reviewed and ready to merge
- [ ] Access to Dezirae-Stark GitHub organization
- [ ] Desktop environment with minisign (for key generation)
- [ ] GitHub CLI (`gh`) authenticated

---

## 🎯 Quick Deployment (5 Steps)

### Step 1: Generate Keys (Desktop Required)

```bash
# Install minisign
sudo apt install minisign  # Ubuntu/Debian
brew install minisign      # macOS

# Generate keypair
mkdir ~/broker-keys && cd ~/broker-keys
minisign -G -p broker_catalog.pub -s broker_catalog.key

# IMPORTANT: Save the password securely!
# Backup the keys immediately
```

**⏱️ Time: 5 minutes**

### Step 2: Run Setup Script

```bash
cd ~/QuantumTrader-Pro
bash scripts/setup-broker-catalog.sh
```

This script will:
- ✅ Check prerequisites
- ✅ Create QuantumTrader-Pro-data repository
- ✅ Enable GitHub Pages
- ✅ Copy template files
- ✅ Deploy initial broker list

**⏱️ Time: 5 minutes**

### Step 3: Configure Secrets (Manual)

1. Go to: https://github.com/Dezirae-Stark/QuantumTrader-Pro-data/settings/environments
2. Create environment: `broker-pages`
3. Add secrets:
   - `BROKER_SIGNING_PRIVATE_KEY` → Contents of `broker_catalog.key`
   - `BROKER_SIGNING_PASSWORD` → Password from Step 1

**⏱️ Time: 5 minutes**

### Step 4: Update App Public Key

```bash
# Get public key (second line)
tail -n 1 ~/broker-keys/broker_catalog.pub

# Edit SignatureVerifier.kt
nano android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/SignatureVerifier.kt

# Replace line ~43:
private const val PUBLIC_KEY_BASE64 = "RWQy...YOUR_KEY_HERE..."

# Commit
git add android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/SignatureVerifier.kt
git commit -m "chore: Add production broker catalog public key"
git push origin feature/broker-selector-pr1
```

**⏱️ Time: 5 minutes**

### Step 5: Merge & Test

```bash
# Merge PR #12
gh pr merge 12 --squash

# Test workflow
cd ~/QuantumTrader-Pro-data
echo "Test" >> README.md
git add README.md && git commit -m "test: Trigger signing workflow"
git push

# Watch workflow
gh run watch

# Verify deployment
curl -I https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json
curl -I https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json.sig

# Verify signature
cd ~/broker-keys
curl -o test.json https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json
curl -o test.json.sig https://dezirae-stark.github.io/QuantumTrader-Pro-data/brokers.json.sig
minisign -V -p broker_catalog.pub -m test.json
```

**⏱️ Time: 10 minutes**

---

## ✅ Verification Checklist

After deployment, verify:

- [ ] QuantumTrader-Pro-data repository exists and is public
- [ ] GitHub Pages enabled at https://dezirae-stark.github.io/QuantumTrader-Pro-data/
- [ ] brokers.json accessible via HTTPS
- [ ] brokers.json.sig accessible via HTTPS
- [ ] Signature verification passes with minisign
- [ ] Workflow runs successfully
- [ ] No secrets visible in logs
- [ ] Public key embedded in SignatureVerifier.kt
- [ ] App compiles with new public key
- [ ] Private key backed up securely

---

## 🔧 Troubleshooting

### "minisign: command not found"

Install minisign on a desktop system:
```bash
# Ubuntu/Debian
sudo apt install minisign

# macOS
brew install minisign

# Arch
sudo pacman -S minisign
```

Then transfer keys securely to Termux if needed.

### "Repository already exists"

If QuantumTrader-Pro-data exists:
```bash
cd ~/QuantumTrader-Pro-data
git pull origin main
# Continue with Step 2
```

### "Workflow failed: Signature error"

Check secrets are configured correctly:
1. Go to Environment settings
2. Verify both secrets exist
3. Re-create secrets if needed
4. Retry workflow

### "Pages not deploying"

1. Check Settings → Pages → Source is set to: `main` branch, `/ (root)`
2. Wait 2-3 minutes for first deployment
3. Check Actions tab for deployment status

---

## 📚 Full Documentation

**Quick Start**: You're reading it! 🎉

**Complete Setup**: [docs/BROKER_CATALOG_SETUP.md](docs/BROKER_CATALOG_SETUP.md) (comprehensive step-by-step)

**User Guide**: [docs/user/broker-setup.md](docs/user/broker-setup.md)

**Developer Guide**: [docs/dev/broker-catalog.md](docs/dev/broker-catalog.md)

**Security Guide**: [docs/security/broker-signing.md](docs/security/broker-signing.md)

**Implementation**: [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

---

## 🎯 What You'll Have After Deployment

✅ **Dynamic Broker Catalog**
- Auto-updates weekly in app
- Manual refresh available
- 8 brokers embedded as fallback

✅ **Cryptographic Security**
- Ed25519 signature verification
- Tamper-proof catalog updates
- Key rotation procedure ready

✅ **GitHub Pages Infrastructure**
- Automated signing workflow
- Public catalog at stable URL
- Metadata endpoint

✅ **Complete Documentation**
- User, developer, and security guides
- Troubleshooting resources
- Maintenance procedures

---

## 🚀 Post-Deployment

### Immediate (Day 1)
- [ ] Monitor GitHub Actions for workflow success
- [ ] Check Pages deployment
- [ ] Test signature verification
- [ ] Build and install app on test device
- [ ] Verify broker list loads
- [ ] Test search and filter

### Short-term (Week 1)
- [ ] Monitor for user feedback
- [ ] Check signature verification metrics
- [ ] Add more brokers if requested
- [ ] Review documentation for improvements

### Long-term (Ongoing)
- [ ] Weekly review of catalog updates
- [ ] Monthly security audit
- [ ] Annual key rotation (documented in security guide)
- [ ] Performance monitoring

---

## 📞 Need Help?

**Setup Issues**: See [docs/BROKER_CATALOG_SETUP.md](docs/BROKER_CATALOG_SETUP.md)

**Security Questions**: See [docs/security/broker-signing.md](docs/security/broker-signing.md)

**Technical Issues**: Open issue in QuantumTrader-Pro repo

---

**Ready?** Run: `bash scripts/setup-broker-catalog.sh`

**Time to Deploy**: ~30 minutes ⏱️
**Difficulty**: Intermediate 📊
**Success Rate**: 99% if following steps 🎯
