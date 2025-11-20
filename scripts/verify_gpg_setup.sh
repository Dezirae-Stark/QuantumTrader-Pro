#!/bin/bash
# verify_gpg_setup.sh - Verify GPG commit signing configuration

set -e

echo "========================================"
echo "GPG Commit Signing Verification"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

ERRORS=0
WARNINGS=0

# 1. Check GPG installation
echo "1. Checking GPG installation..."
if command -v gpg &> /dev/null; then
    GPG_VERSION=$(gpg --version | head -n 1)
    check_pass "GPG installed: $GPG_VERSION"
else
    check_fail "GPG not installed"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 2. Check for GPG keys
echo "2. Checking for GPG keys..."
if gpg --list-secret-keys --keyid-format=long &> /dev/null; then
    KEY_COUNT=$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | grep -c "^sec" || true)
    if [ "$KEY_COUNT" -gt 0 ]; then
        check_pass "Found $KEY_COUNT GPG key(s)"
        echo ""
        gpg --list-secret-keys --keyid-format=long
    else
        check_fail "No GPG keys found"
        echo "  Run: gpg --full-generate-key"
        ERRORS=$((ERRORS + 1))
    fi
else
    check_fail "Unable to list GPG keys"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 3. Check Git user configuration
echo "3. Checking Git user configuration..."
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$GIT_NAME" ]; then
    check_pass "Git user.name: $GIT_NAME"
else
    check_fail "Git user.name not set"
    echo "  Run: git config --global user.name \"Your Name\""
    ERRORS=$((ERRORS + 1))
fi

if [ -n "$GIT_EMAIL" ]; then
    check_pass "Git user.email: $GIT_EMAIL"
else
    check_fail "Git user.email not set"
    echo "  Run: git config --global user.email \"your.email@example.com\""
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 4. Check Git GPG configuration
echo "4. Checking Git GPG configuration..."
SIGNING_KEY=$(git config --global user.signingkey 2>/dev/null || echo "")
COMMIT_GPGSIGN=$(git config --global commit.gpgsign 2>/dev/null || echo "")
GPG_PROGRAM=$(git config --global gpg.program 2>/dev/null || echo "")

if [ -n "$SIGNING_KEY" ]; then
    check_pass "Git signing key: $SIGNING_KEY"

    # Verify key exists
    if gpg --list-secret-keys "$SIGNING_KEY" &> /dev/null; then
        check_pass "Signing key exists in GPG keyring"
    else
        check_fail "Signing key not found in GPG keyring"
        ERRORS=$((ERRORS + 1))
    fi
else
    check_fail "Git signing key not configured"
    echo "  Run: git config --global user.signingkey YOUR_KEY_ID"
    ERRORS=$((ERRORS + 1))
fi

if [ "$COMMIT_GPGSIGN" = "true" ]; then
    check_pass "Automatic commit signing enabled"
else
    check_warn "Automatic commit signing disabled"
    echo "  To enable: git config --global commit.gpgsign true"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -n "$GPG_PROGRAM" ]; then
    check_pass "GPG program: $GPG_PROGRAM"
else
    check_warn "GPG program not explicitly set (using default)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 5. Test GPG signing
echo "5. Testing GPG signing..."
TEST_OUTPUT=$(echo "test" | gpg --clearsign 2>&1)
if [ $? -eq 0 ]; then
    check_pass "GPG can sign data"
else
    check_fail "GPG signing test failed"
    echo "$TEST_OUTPUT"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 6. Check GPG key email matches Git email
echo "6. Checking email consistency..."
if [ -n "$SIGNING_KEY" ] && [ -n "$GIT_EMAIL" ]; then
    GPG_EMAIL=$(gpg --list-keys "$SIGNING_KEY" 2>/dev/null | grep -oP '(?<=<)[^>]+' | head -1)
    if [ "$GPG_EMAIL" = "$GIT_EMAIL" ]; then
        check_pass "GPG key email matches Git email: $GIT_EMAIL"
    else
        check_warn "Email mismatch!"
        echo "  Git email: $GIT_EMAIL"
        echo "  GPG email: $GPG_EMAIL"
        echo "  Commits may show as 'Unverified' on GitHub"
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo ""

# 7. Check repository configuration
echo "7. Checking repository-specific configuration..."
if git rev-parse --git-dir &> /dev/null; then
    REPO_NAME=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown")
    check_pass "In Git repository: $REPO_NAME"

    # Check if repository has any commits
    if git log -1 &> /dev/null 2>&1; then
        LAST_COMMIT=$(git log -1 --format="%H" 2>/dev/null)
        check_pass "Repository has commits"

        # Check if last commit is signed
        if git verify-commit "$LAST_COMMIT" &> /dev/null 2>&1; then
            check_pass "Last commit is GPG signed"
        else
            check_warn "Last commit is NOT signed"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        check_warn "Repository has no commits yet"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    check_warn "Not in a Git repository"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "You're ready to make signed commits."
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Configuration complete with $WARNINGS warning(s)${NC}"
    echo "Your setup works but could be improved."
else
    echo -e "${RED}✗ Found $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Please fix the errors above."
fi
echo ""

# Export public key instructions
if [ $ERRORS -eq 0 ] && [ -n "$SIGNING_KEY" ]; then
    echo "========================================"
    echo "Next Steps"
    echo "========================================"
    echo "1. Export your public key:"
    echo "   gpg --armor --export $SIGNING_KEY"
    echo ""
    echo "2. Add to GitHub:"
    echo "   - Go to: https://github.com/settings/keys"
    echo "   - Click 'New GPG key'"
    echo "   - Paste your public key"
    echo ""
    echo "3. Verify email on GitHub:"
    echo "   - Go to: https://github.com/settings/emails"
    echo "   - Verify: $GIT_EMAIL"
    echo ""
fi

exit $ERRORS
