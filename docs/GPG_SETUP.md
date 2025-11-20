# GPG Commit Signing Setup Guide

## Overview

This guide explains how to set up GPG (GNU Privacy Guard) commit signing for QuantumTrader Pro. GPG-signed commits provide cryptographic verification that commits genuinely come from you, adding an extra layer of security and trust to your contributions.

## Table of Contents

- [Why Sign Commits?](#why-sign-commits)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [GPG Key Generation](#gpg-key-generation)
- [Git Configuration](#git-configuration)
- [GitHub Configuration](#github-configuration)
- [Signing Commits](#signing-commits)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Why Sign Commits?

### Benefits

1. **Identity Verification**: Cryptographically proves commits are from you
2. **Security**: Prevents commit forgery and impersonation
3. **Trust**: GitHub displays "Verified" badge on signed commits
4. **Compliance**: Required for many enterprise and open-source projects
5. **Integrity**: Ensures commit history hasn't been tampered with

### GitHub Verified Badge

When you sign commits with GPG, GitHub displays a green "Verified" badge:

```
✓ Verified - This commit was signed with the contributor's verified signature
```

## Prerequisites

### Required Software

- **Git** 2.x or higher
- **GPG** (GnuPG) 2.x or higher
- **GitHub account** with email verified

### Check Existing Installation

```bash
# Check Git version
git --version

# Check GPG version
gpg --version

# Check for existing GPG keys
gpg --list-secret-keys --keyid-format=long
```

## Installation

### Linux (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install gnupg
```

### Linux (Fedora/RHEL)

```bash
sudo dnf install gnupg2
```

### macOS

```bash
# Using Homebrew
brew install gnupg

# Using MacPorts
sudo port install gnupg2
```

### Windows

Download and install from: https://www.gnupg.org/download/

Or using Chocolatey:
```powershell
choco install gnupg
```

### Termux (Android)

```bash
pkg install gnupg
```

## GPG Key Generation

### Method 1: Interactive Generation (Recommended for Beginners)

```bash
# Start key generation wizard
gpg --full-generate-key
```

Follow the prompts:
1. **Key type**: Choose `(1) RSA and RSA`
2. **Key size**: Enter `4096` (maximum security)
3. **Expiration**:
   - `0` = never expires (easiest)
   - `1y` = expires in 1 year (more secure, requires renewal)
4. **Name**: Enter your full name (must match GitHub)
5. **Email**: Enter your GitHub email address
6. **Comment**: Optional (e.g., "GPG signing key")
7. **Passphrase**: Enter a strong passphrase (or leave empty for no passphrase)

### Method 2: Batch Generation (Automated)

Create a configuration file:

```bash
cat > ~/gpg-key-config << 'EOF'
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Your Full Name
Name-Email: your.email@example.com
Expire-Date: 0
%commit
EOF
```

Generate the key:

```bash
gpg --batch --generate-key ~/gpg-key-config
rm ~/gpg-key-config  # Clean up
```

### Verify Key Creation

```bash
# List all GPG keys
gpg --list-secret-keys --keyid-format=long
```

Expected output:
```
sec   rsa4096/392CEB43F95C0CEB 2025-11-20 [SCEAR]
      17301BA9EDA93D14864DF0CA392CEB43F95C0CEB
uid                 [ultimate] Your Name <your.email@example.com>
ssb   rsa4096/005BE8B097E4F177 2025-11-20 [SEA]
```

The key ID is after `rsa4096/`: **392CEB43F95C0CEB**

## Git Configuration

### Configure Git to Use GPG Key

```bash
# Set your GPG key (replace with your key ID)
git config --global user.signingkey 392CEB43F95C0CEB

# Enable automatic commit signing
git config --global commit.gpgsign true

# Set GPG program path
git config --global gpg.program gpg
```

### Verify Configuration

```bash
# Check GPG settings
git config --global --list | grep gpg
```

Expected output:
```
user.signingkey=392CEB43F95C0CEB
commit.gpgsign=true
gpg.program=gpg
```

### Per-Repository Configuration (Optional)

To enable signing for specific repository only:

```bash
cd /path/to/repository
git config user.signingkey 392CEB43F95C0CEB
git config commit.gpgsign true
```

## GitHub Configuration

### Step 1: Export Your Public Key

```bash
# Export public key to file
gpg --armor --export 392CEB43F95C0CEB > gpg-public-key.asc

# Or print to terminal
gpg --armor --export 392CEB43F95C0CEB
```

This outputs your public key in ASCII-armored format:
```
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBGc99...
...
-----END PGP PUBLIC KEY BLOCK-----
```

### Step 2: Add Key to GitHub

1. **Copy your public key:**
   ```bash
   cat gpg-public-key.asc
   ```

2. **Go to GitHub Settings:**
   - Navigate to https://github.com/settings/keys
   - Or: GitHub → Settings → SSH and GPG keys

3. **Add GPG Key:**
   - Click **"New GPG key"**
   - Paste your entire public key (including BEGIN and END lines)
   - Click **"Add GPG key"**

4. **Verify email address:**
   - The email in your GPG key must match a verified email on GitHub
   - Go to https://github.com/settings/emails
   - Verify your email if not already verified

### Step 3: Verify on GitHub

After adding your key, you should see:
- Your key listed in GPG keys section
- Key ID displayed
- Associated email address

## Signing Commits

### Automatic Signing

With `commit.gpgsign=true`, all commits are automatically signed:

```bash
# Regular commit (automatically signed)
git commit -m "feat: Add new feature"

# Amend commit (automatically signed)
git commit --amend
```

### Manual Signing

If automatic signing is disabled:

```bash
# Sign a specific commit
git commit -S -m "feat: Add new feature"

# Sign during amend
git commit --amend -S
```

### Signing Previous Commits

To sign commits retroactively:

```bash
# Sign and rewrite last commit
git commit --amend --no-edit -S

# Sign and rewrite multiple commits (interactive rebase)
git rebase -i HEAD~5 --exec "git commit --amend --no-edit -S"
```

**Warning:** This rewrites history. Only do this on branches you control.

### Signing Tags

```bash
# Create signed tag
git tag -s v1.0.0 -m "Release version 1.0.0"

# Verify signed tag
git tag -v v1.0.0
```

## Verification

### Verify Local Commits

```bash
# Show commit signature
git log --show-signature -1

# Or shorter format
git verify-commit HEAD
```

Expected output:
```
gpg: Signature made Wed 20 Nov 2025 12:00:00 AM UTC
gpg:                using RSA key 392CEB43F95C0CEB
gpg: Good signature from "Your Name <your.email@example.com>"
```

### Verify on GitHub

1. Go to your repository on GitHub
2. View commit history
3. Signed commits show **"Verified"** badge
4. Click badge to see signature details

### Verify Signatures in Git Log

```bash
# Show signatures with oneline format
git log --pretty=format:"%h %G? %aN  %s" --graph

# Signature indicators:
# G = Good signature
# B = Bad signature
# U = Good signature, unknown validity
# X = Good signature, expired
# Y = Good signature, expired key
# R = Good signature, revoked key
# E = Cannot check signature
# N = No signature
```

## Troubleshooting

### GPG Agent Issues

**Problem:** GPG asks for passphrase every time

**Solution:** Configure GPG agent

```bash
# Create or edit ~/.gnupg/gpg-agent.conf
cat > ~/.gnupg/gpg-agent.conf << 'EOF'
default-cache-ttl 3600
max-cache-ttl 86400
EOF

# Reload GPG agent
gpg-connect-agent reloadagent /bye
```

### Commits Not Signed

**Problem:** Commits show as unverified

**Check 1 - GPG signing enabled:**
```bash
git config --global commit.gpgsign
# Should return: true
```

**Check 2 - Signing key configured:**
```bash
git config --global user.signingkey
# Should return your key ID
```

**Check 3 - GPG key exists:**
```bash
gpg --list-secret-keys --keyid-format=long
# Should show your key
```

**Check 4 - Test signing:**
```bash
echo "test" | gpg --clearsign
# Should sign successfully
```

### "gpg: signing failed: Inappropriate ioctl for device"

**Problem:** TTY issues in some terminals

**Solution 1:**
```bash
export GPG_TTY=$(tty)
```

Add to your shell profile (`~/.bashrc`, `~/.zshrc`):
```bash
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
source ~/.bashrc
```

**Solution 2:**
```bash
# Disable use of terminal
echo "use-agent" >> ~/.gnupg/gpg.conf
echo "pinentry-mode loopback" >> ~/.gnupg/gpg.conf
```

### "gpg: signing failed: No secret key"

**Problem:** Git can't find your GPG key

**Solution:**
```bash
# List your keys
gpg --list-secret-keys --keyid-format=long

# Configure Git with correct key ID
git config --global user.signingkey YOUR_KEY_ID
```

### "error: gpg failed to sign the data"

**Problem:** GPG program not found or not working

**Solution 1 - Find GPG path:**
```bash
which gpg
# Usually: /usr/bin/gpg or /usr/local/bin/gpg

# Configure Git
git config --global gpg.program $(which gpg)
```

**Solution 2 - Test GPG:**
```bash
# Test signing
echo "test" | gpg --clearsign

# If this fails, reinstall GPG
```

### Unverified on GitHub

**Problem:** Commits signed locally but show "Unverified" on GitHub

**Check 1 - Email matches:**
```bash
# Check email in GPG key
gpg --list-keys

# Check Git email
git config user.email

# They must match exactly
```

**Check 2 - Key added to GitHub:**
- Go to https://github.com/settings/keys
- Verify your GPG key is listed
- Key ID should match: `gpg --list-secret-keys --keyid-format=long`

**Check 3 - Email verified on GitHub:**
- Go to https://github.com/settings/emails
- Email from GPG key must be verified

### Key Expired

**Problem:** Signature shows expired

**Solution - Extend expiration:**
```bash
# Edit key
gpg --edit-key YOUR_KEY_ID

# At gpg> prompt:
expire
# Follow prompts to set new expiration

# Save
save
```

**Re-export and update GitHub:**
```bash
# Export updated key
gpg --armor --export YOUR_KEY_ID > gpg-public-key-updated.asc

# Update on GitHub (delete old, add new)
```

## Best Practices

### Security

1. **Use strong passphrase:**
   - Minimum 20 characters
   - Include upper, lower, numbers, symbols
   - Store in password manager

2. **Backup your keys:**
   ```bash
   # Export private key (keep secure!)
   gpg --export-secret-keys --armor YOUR_KEY_ID > gpg-private-key.asc

   # Store in secure location (encrypted USB, password manager)
   chmod 600 gpg-private-key.asc
   ```

3. **Revocation certificate:**
   ```bash
   # Generate revocation certificate
   gpg --gen-revoke YOUR_KEY_ID > revocation-cert.asc

   # Store securely (separate from private key)
   ```

4. **Set expiration date:**
   - Keys should expire (1-2 years recommended)
   - Prevents long-term compromise
   - Extend expiration before it expires

### Key Management

1. **One key per identity:**
   - Separate keys for work and personal
   - Different keys for different email addresses

2. **Document your key:**
   ```bash
   # Create key info file
   cat > GPG_KEY_INFO.txt << EOF
   Key ID: YOUR_KEY_ID
   Fingerprint: YOUR_FULL_FINGERPRINT
   Created: $(date)
   Email: your.email@example.com
   Expires: Never (or date)
   Backed up: Yes (location)
   EOF
   ```

3. **Keep keys updated:**
   - Update expiration dates before they expire
   - Re-export and update on GitHub after changes

### Workflow

1. **Verify before pushing:**
   ```bash
   # Check signatures
   git log --show-signature -5

   # Ensure all commits signed
   git log --pretty="%H %G?" | grep " N$"
   # Should be empty
   ```

2. **Sign tags:**
   ```bash
   # Always sign release tags
   git tag -s v2.1.0 -m "Release 2.1.0"
   git push origin v2.1.0
   ```

3. **Maintain trust:**
   - Never share private key
   - Revoke if compromised
   - Keep GitHub key list updated

### Team Collaboration

1. **Require signed commits:**
   - Repository settings → Branches → Require signed commits
   - Enforces GPG signing for all contributors

2. **Verify contributor signatures:**
   ```bash
   # Check commit signatures in PR
   git log --show-signature origin/feature-branch
   ```

3. **Document requirements:**
   - Add GPG setup to CONTRIBUTING.md
   - Link to this guide
   - Provide support for setup issues

## Advanced Topics

### Multiple GPG Keys

If you have multiple keys (work, personal):

```bash
# List all keys
gpg --list-secret-keys --keyid-format=long

# Configure per repository
cd ~/work-project
git config user.email work@company.com
git config user.signingkey WORK_KEY_ID

cd ~/personal-project
git config user.email personal@email.com
git config user.signingkey PERSONAL_KEY_ID
```

### Subkeys

Use subkeys for enhanced security:

```bash
# Create signing subkey
gpg --edit-key YOUR_KEY_ID

# At gpg> prompt:
addkey
# Choose: (4) RSA (sign only)
# Key size: 4096
# Expiration: 1y

save
```

### Hardware Keys

Use hardware security keys (YubiKey):

```bash
# Check if key is on hardware
gpg --card-status

# Import key to hardware (if supported)
# Follow YubiKey documentation
```

### Automated Key Rotation

Create a script for annual key rotation:

```bash
#!/bin/bash
# scripts/rotate-gpg-key.sh

OLD_KEY_ID="YOUR_OLD_KEY"
NEW_KEY_ID="YOUR_NEW_KEY"

# Generate new key
gpg --batch --generate-key gpg-key-config

# Export new public key
gpg --armor --export $NEW_KEY_ID > new-gpg-public-key.asc

# Update Git config
git config --global user.signingkey $NEW_KEY_ID

echo "New key generated: $NEW_KEY_ID"
echo "Update GitHub at: https://github.com/settings/keys"
echo "Revoke old key: gpg --gen-revoke $OLD_KEY_ID"
```

## Quick Reference

### Common Commands

```bash
# List keys
gpg --list-keys
gpg --list-secret-keys --keyid-format=long

# Export public key
gpg --armor --export KEY_ID

# Import key
gpg --import public-key.asc

# Delete key
gpg --delete-secret-key KEY_ID
gpg --delete-key KEY_ID

# Sign commit
git commit -S -m "message"

# Verify commit
git verify-commit COMMIT_HASH

# Show signature
git log --show-signature -1
```

### Configuration Files

```bash
# Git global config
~/.gitconfig

# GPG config
~/.gnupg/gpg.conf

# GPG agent config
~/.gnupg/gpg-agent.conf
```

### Environment Variables

```bash
# Set TTY for GPG
export GPG_TTY=$(tty)

# Override GPG program
export GIT_GPG_PROGRAM=/usr/bin/gpg2
```

## Additional Resources

- **GnuPG Official**: https://gnupg.org/
- **GitHub GPG Docs**: https://docs.github.com/en/authentication/managing-commit-signature-verification
- **Git Signing Docs**: https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work
- **GPG Best Practices**: https://riseup.net/en/security/message-security/openpgp/best-practices

## Support

If you encounter issues not covered in this guide:

1. **Check GitHub docs**: https://docs.github.com/en/authentication/managing-commit-signature-verification
2. **GPG mailing list**: gnupg-users@gnupg.org
3. **Project issues**: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

---

**Last Updated:** 2025-11-20
**Version:** 2.1.0
**Key ID:** 392CEB43F95C0CEB
