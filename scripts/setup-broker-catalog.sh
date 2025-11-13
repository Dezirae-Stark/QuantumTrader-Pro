#!/bin/bash
#
# Broker Catalog Infrastructure Setup Script
# QuantumTrader Pro - Dynamic Broker Catalog Deployment
#
# This script helps you set up the broker catalog infrastructure step-by-step.
# Run: bash scripts/setup-broker-catalog.sh
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DATA_REPO="Dezirae-Stark/QuantumTrader-Pro-data"
KEYS_DIR="$HOME/broker-keys"
BACKUP_DIR="$HOME/broker-keys-backup"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     QuantumTrader Pro - Broker Catalog Setup              ║${NC}"
echo -e "${BLUE}║     Dynamic Catalog with Ed25519 Signing                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print step headers
step() {
    echo -e "\n${GREEN}▶ $1${NC}"
    echo "────────────────────────────────────────────────────────"
}

# Function to print info
info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Function to print warning
warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error
error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print success
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Check prerequisites
step "Checking Prerequisites"

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    error "GitHub CLI (gh) not found. Install: pkg install gh"
    exit 1
fi
success "GitHub CLI found"

# Check for jq
if ! command -v jq &> /dev/null; then
    warn "jq not found. Install: pkg install jq (recommended for validation)"
else
    success "jq found"
fi

# Check for git
if ! command -v git &> /dev/null; then
    error "git not found"
    exit 1
fi
success "git found"

# Check gh auth status
if ! gh auth status &> /dev/null; then
    error "Not authenticated with GitHub. Run: gh auth login"
    exit 1
fi
success "GitHub authenticated"

# Phase 1: Generate Signing Keys
step "Phase 1: Generate Ed25519 Signing Keys"

if command -v minisign &> /dev/null; then
    success "minisign found"

    if [ -f "$KEYS_DIR/broker_catalog.key" ]; then
        warn "Keys already exist at $KEYS_DIR"
        read -p "Regenerate keys? This will overwrite existing keys! (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Skipping key generation"
        else
            mkdir -p "$KEYS_DIR"
            cd "$KEYS_DIR"
            info "Generating Ed25519 keypair..."
            minisign -G -p broker_catalog.pub -s broker_catalog.key
            success "Keys generated in $KEYS_DIR"
        fi
    else
        mkdir -p "$KEYS_DIR"
        cd "$KEYS_DIR"
        info "Generating Ed25519 keypair..."
        info "You'll be prompted for a password. SAVE IT SECURELY!"
        minisign -G -p broker_catalog.pub -s broker_catalog.key
        success "Keys generated in $KEYS_DIR"
    fi

    # Backup keys
    step "Creating Encrypted Backup"
    mkdir -p "$BACKUP_DIR"
    cd "$KEYS_DIR"

    info "Creating tarball..."
    tar czf "$BACKUP_DIR/broker-keys-$(date +%Y%m%d-%H%M%S).tar.gz" broker_catalog.*

    if command -v gpg &> /dev/null; then
        info "Encrypting backup with GPG..."
        gpg -c "$BACKUP_DIR/broker-keys-$(date +%Y%m%d-%H%M%S).tar.gz"
        success "Encrypted backup: $BACKUP_DIR/broker-keys-*.tar.gz.gpg"
        warn "STORE THIS BACKUP SECURELY (hardware key, encrypted cloud, safe)"
    else
        warn "GPG not found. Backup is NOT encrypted."
        success "Backup: $BACKUP_DIR/broker-keys-*.tar.gz"
        warn "Consider encrypting this backup manually!"
    fi

else
    warn "minisign not found"
    info "Install minisign for key generation:"
    info "  Ubuntu/Debian: sudo apt install minisign"
    info "  macOS: brew install minisign"
    info "  Termux: Currently not available, use desktop environment"
    info ""
    info "Alternative: Generate keys on another system and transfer securely"
    warn "Skipping key generation..."
fi

# Phase 2: Create Data Repository
step "Phase 2: Create Data Repository"

# Check if repo exists
if gh repo view "$DATA_REPO" &> /dev/null; then
    warn "Repository $DATA_REPO already exists"
    read -p "Continue with existing repository? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        error "Aborted"
        exit 1
    fi
    info "Using existing repository"
else
    info "Creating repository: $DATA_REPO"
    gh repo create "$DATA_REPO" \
        --public \
        --description "Dynamic broker catalog for QuantumTrader Pro (cryptographically signed)" \
        --clone
    success "Repository created"
fi

# Clone or pull repo
DATA_REPO_DIR="$HOME/QuantumTrader-Pro-data"
if [ -d "$DATA_REPO_DIR" ]; then
    info "Repository directory exists, pulling latest..."
    cd "$DATA_REPO_DIR"
    git pull origin main || true
else
    info "Cloning repository..."
    cd "$HOME"
    gh repo clone "$DATA_REPO"
fi

cd "$DATA_REPO_DIR"

# Copy template files
step "Copying Template Files"

TEMPLATE_DIR="$HOME/QuantumTrader-Pro/docs/data-repo-template"

if [ -d "$TEMPLATE_DIR" ]; then
    info "Copying workflow..."
    mkdir -p .github/workflows
    cp "$TEMPLATE_DIR/.github/workflows/publish-brokers.yml" .github/workflows/

    info "Copying README..."
    cp "$TEMPLATE_DIR/README.md" .

    info "Copying schema..."
    cp "$HOME/QuantumTrader-Pro/docs/brokers.schema.json" .

    info "Copying initial broker list..."
    cp "$HOME/QuantumTrader-Pro/android/app/src/main/assets/brokers.json" .

    info "Creating index.html..."
    cat > index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QuantumTrader Pro - Broker Catalog</title>
    <style>
        body { font-family: system-ui; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #2563eb; }
        .status { padding: 10px; background: #f0f9ff; border-left: 4px solid #2563eb; margin: 20px 0; }
        code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
        a { color: #2563eb; }
    </style>
</head>
<body>
    <h1>🏦 QuantumTrader Pro - Broker Catalog</h1>
    <div class="status">
        <strong>Status:</strong> Active<br>
        <strong>Format:</strong> JSON with Ed25519 signatures<br>
        <strong>Update Schedule:</strong> As needed (via GitHub Actions)
    </div>

    <h2>📍 Endpoints</h2>
    <ul>
        <li><a href="brokers.json">brokers.json</a> - Broker catalog</li>
        <li><a href="brokers.json.sig">brokers.json.sig</a> - Ed25519 signature</li>
        <li><a href="catalog_metadata.json">catalog_metadata.json</a> - Metadata</li>
        <li><a href="brokers.schema.json">brokers.schema.json</a> - JSON schema</li>
    </ul>

    <h2>🔒 Security</h2>
    <p>All catalogs are cryptographically signed with Ed25519. The QuantumTrader Pro app verifies signatures before accepting updates.</p>

    <h2>📝 Contributing</h2>
    <p>To add or update a broker, submit a pull request to this repository. See <a href="https://github.com/Dezirae-Stark/QuantumTrader-Pro-data">README</a> for guidelines.</p>

    <h2>📚 Documentation</h2>
    <ul>
        <li><a href="https://github.com/Dezirae-Stark/QuantumTrader-Pro/blob/main/docs/user/broker-setup.md">User Guide</a></li>
        <li><a href="https://github.com/Dezirae-Stark/QuantumTrader-Pro/blob/main/docs/dev/broker-catalog.md">Developer Guide</a></li>
        <li><a href="https://github.com/Dezirae-Stark/QuantumTrader-Pro/blob/main/docs/security/broker-signing.md">Security Guide</a></li>
    </ul>
</body>
</html>
EOF

    success "Template files copied"

    # Commit if changes
    if [[ -n $(git status -s) ]]; then
        info "Committing changes..."
        git add .
        git commit -m "Initial broker catalog setup

- Add publish-brokers.yml workflow
- Add README and index.html
- Add initial brokers.json (8 brokers)
- Add JSON schema for validation

Ready for GitHub Pages deployment and signing workflow configuration."
        git push origin main
        success "Changes committed and pushed"
    else
        info "No changes to commit"
    fi
else
    error "Template directory not found: $TEMPLATE_DIR"
    error "Make sure QuantumTrader-Pro repository is cloned"
fi

# Phase 3: Enable GitHub Pages
step "Phase 3: Enable GitHub Pages"

info "Enabling GitHub Pages..."
gh api repos/"$DATA_REPO"/pages \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -f source[branch]=main \
    -f source[path]=/ 2>/dev/null && success "GitHub Pages enabled" || warn "Pages may already be enabled or API call failed"

info "GitHub Pages will be available at:"
echo "  https://dezirae-stark.github.io/QuantumTrader-Pro-data/"
warn "Wait 2-3 minutes for initial deployment"

# Phase 4: Configure Secrets
step "Phase 4: Configure GitHub Secrets"

warn "GitHub Secrets must be configured manually via web UI"
info ""
info "Follow these steps:"
info "1. Go to: https://github.com/$DATA_REPO/settings/environments"
info "2. Click 'New environment'"
info "3. Name: broker-pages"
info "4. Click 'Add secret' and add:"
info ""
info "   Secret 1: BROKER_SIGNING_PRIVATE_KEY"
if [ -f "$KEYS_DIR/broker_catalog.key" ]; then
    info "   Value: (Copy contents below)"
    echo ""
    echo "   ┌─────────────────────────────────────────┐"
    cat "$KEYS_DIR/broker_catalog.key" | sed 's/^/   │ /'
    echo "   └─────────────────────────────────────────┘"
    echo ""
else
    warn "   Key file not found: $KEYS_DIR/broker_catalog.key"
fi
info ""
info "   Secret 2: BROKER_SIGNING_PASSWORD"
info "   Value: (The password you entered when generating the key)"
info ""

read -p "Press Enter when secrets are configured..."

# Phase 5: Update App with Public Key
step "Phase 5: Update App with Public Key"

if [ -f "$KEYS_DIR/broker_catalog.pub" ]; then
    info "Public key:"
    echo ""
    echo "   ┌─────────────────────────────────────────┐"
    cat "$KEYS_DIR/broker_catalog.pub" | sed 's/^/   │ /'
    echo "   └─────────────────────────────────────────┘"
    echo ""

    PUBLIC_KEY=$(tail -n 1 "$KEYS_DIR/broker_catalog.pub")

    info "Update SignatureVerifier.kt with this public key:"
    echo "   File: android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/SignatureVerifier.kt"
    echo "   Line: ~43"
    echo ""
    echo "   private const val PUBLIC_KEY_BASE64 = \"$PUBLIC_KEY\""
    echo ""

    warn "This must be done manually and committed to the app repository"

    read -p "Press Enter when public key is updated in app..."
else
    warn "Public key file not found: $KEYS_DIR/broker_catalog.pub"
fi

# Final Steps
step "Summary & Next Steps"

success "Infrastructure setup complete!"
echo ""
info "✅ Data repository created: $DATA_REPO"
info "✅ GitHub Pages enabled"
info "✅ Template files deployed"
info "✅ Signing keys generated (if minisign available)"
echo ""

warn "TODO (Manual Steps):"
echo "  [ ] Configure GitHub Secrets (BROKER_SIGNING_PRIVATE_KEY, BROKER_SIGNING_PASSWORD)"
echo "  [ ] Update SignatureVerifier.kt with public key"
echo "  [ ] Commit and push SignatureVerifier.kt changes"
echo "  [ ] Merge PR #12 in QuantumTrader-Pro repository"
echo "  [ ] Test workflow: Push change to data repo"
echo "  [ ] Verify signature: minisign -V -p broker_catalog.pub -m brokers.json"
echo "  [ ] Test app on device"
echo ""

info "📚 Detailed instructions: docs/BROKER_CATALOG_SETUP.md"
info "🔒 Security guide: docs/security/broker-signing.md"
info "👨‍💻 Developer guide: docs/dev/broker-catalog.md"
echo ""

success "Setup script complete! 🎉"
