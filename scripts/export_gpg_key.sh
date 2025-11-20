#!/bin/bash
# export_gpg_key.sh - Export GPG public key for GitHub

set -e

echo "========================================"
echo "GPG Public Key Export"
echo "========================================"
echo ""

# Get signing key from Git config
SIGNING_KEY=$(git config --global user.signingkey 2>/dev/null || echo "")

if [ -z "$SIGNING_KEY" ]; then
    echo "Error: No signing key configured"
    echo "Run: git config --global user.signingkey YOUR_KEY_ID"
    exit 1
fi

echo "Signing Key ID: $SIGNING_KEY"
echo ""

# Verify key exists
if ! gpg --list-secret-keys "$SIGNING_KEY" &> /dev/null; then
    echo "Error: Key $SIGNING_KEY not found in GPG keyring"
    echo "Available keys:"
    gpg --list-secret-keys --keyid-format=long
    exit 1
fi

# Show key info
echo "Key Information:"
gpg --list-keys "$SIGNING_KEY" 2>/dev/null | grep -A 2 "^pub"
echo ""

# Export public key
echo "========================================"
echo "Public Key (copy to GitHub)"
echo "========================================"
echo ""

gpg --armor --export "$SIGNING_KEY"

echo ""
echo "========================================"
echo "Instructions"
echo "========================================"
echo "1. Copy the entire key above (including BEGIN and END lines)"
echo "2. Go to: https://github.com/settings/keys"
echo "3. Click 'New GPG key'"
echo "4. Paste the key and click 'Add GPG key'"
echo "5. Verify your email at: https://github.com/settings/emails"
echo ""
echo "After adding the key to GitHub, your commits will show"
echo "a green 'Verified' badge."
echo ""
