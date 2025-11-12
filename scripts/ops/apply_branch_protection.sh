#!/usr/bin/env bash
#
# Branch Protection Automation Script
#
# This script applies comprehensive branch protection rules to the main branch
# using the GitHub API via gh CLI.
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Admin permissions on the repository
# - Token with 'repo' scope
#
# Usage:
#   ./apply_branch_protection.sh [branch] [repo]
#
# Examples:
#   ./apply_branch_protection.sh main Dezirae-Stark/QuantumTrader-Pro
#   ./apply_branch_protection.sh           # Uses defaults
#
# Reference: docs/policies/branch-protection.md

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_BRANCH="${1:-main}"
DEFAULT_REPO="${2:-Dezirae-Stark/QuantumTrader-Pro}"

BRANCH="$DEFAULT_BRANCH"
REPO="$DEFAULT_REPO"

# Required status checks (adjust based on actual workflow job names)
# These should match the job names in .github/workflows/*.yml
STATUS_CHECKS='["build","codeql","secret-scan","flutter-analyze","wrapper-validation"]'

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if gh is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi
    print_success "GitHub CLI (gh) is installed"

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub CLI"
        echo "Run: gh auth login"
        exit 1
    fi
    print_success "Authenticated with GitHub CLI"

    # Check if user has admin permissions
    print_info "Checking repository permissions..."
    REPO_INFO=$(gh api "repos/$REPO" --jq '.permissions.admin' 2>&1 || echo "false")
    if [ "$REPO_INFO" != "true" ]; then
        print_warning "Admin permissions required to apply branch protection"
        print_warning "You may need to request admin access or run this as repository owner"
    else
        print_success "Admin permissions confirmed"
    fi

    echo ""
}

apply_protection_rules() {
    print_header "Applying Branch Protection Rules"
    print_info "Repository: $REPO"
    print_info "Branch: $BRANCH"
    echo ""

    # Apply main protection rules
    print_info "Applying protection rules via GitHub API..."

    gh api -X PUT "repos/$REPO/branches/$BRANCH/protection" \
        --field required_status_checks="$(cat <<EOF
{
  "strict": true,
  "contexts": $STATUS_CHECKS
}
EOF
)" \
        --field enforce_admins=true \
        --field required_pull_request_reviews="$(cat <<EOF
{
  "required_approving_review_count": 1,
  "dismiss_stale_reviews": true,
  "require_code_owner_reviews": true,
  "require_last_push_approval": false
}
EOF
)" \
        --field restrictions=null \
        --field required_linear_history=true \
        --field required_conversation_resolution=true \
        --field allow_force_pushes=false \
        --field allow_deletions=false \
        -H "Accept: application/vnd.github+json" 2>&1 | tee /tmp/branch_protection_output.txt

    if [ $? -eq 0 ]; then
        print_success "Branch protection rules applied successfully"
    else
        print_error "Failed to apply branch protection rules"
        print_info "Check /tmp/branch_protection_output.txt for details"
        return 1
    fi

    echo ""
}

apply_signed_commits() {
    print_header "Requiring Signed Commits"

    print_info "Enabling signed commit requirement..."

    gh api -X POST "repos/$REPO/branches/$BRANCH/protection/required_signatures" \
        -H "Accept: application/vnd.github+json" 2>&1 || {
        # Check if already enabled
        if gh api "repos/$REPO/branches/$BRANCH/protection/required_signatures" --jq '.enabled' 2>/dev/null | grep -q "true"; then
            print_success "Signed commits already required (no changes needed)"
        else
            print_error "Failed to enable signed commit requirement"
            return 1
        fi
    }

    print_success "Signed commits are now required"
    echo ""
}

print_manual_steps() {
    print_header "Manual Configuration Required"

    print_warning "The following settings require manual configuration via Web UI:"
    echo ""
    echo "1. Navigate to: https://github.com/$REPO/settings/branches"
    echo "2. Edit the branch protection rule for '$BRANCH'"
    echo "3. Verify the following settings:"
    echo ""
    echo "   ✓ Require a pull request before merging"
    echo "     - Required approvals: 1"
    echo "     - Dismiss stale pull request approvals when new commits are pushed"
    echo "     - Require review from Code Owners"
    echo ""
    echo "   ✓ Require status checks to pass before merging"
    echo "     - Require branches to be up to date before merging"
    echo "     - Status checks: build, codeql, secret-scan, flutter-analyze, wrapper-validation"
    echo ""
    echo "   ✓ Require conversation resolution before merging"
    echo ""
    echo "   ✓ Require signed commits"
    echo ""
    echo "   ✓ Require linear history"
    echo ""
    echo "   ✓ Include administrators"
    echo ""
    echo "   ✓ Allow force pushes: ${RED}DISABLED${NC}"
    echo "   ✓ Allow deletions: ${RED}DISABLED${NC}"
    echo ""
    print_info "Force push and deletion settings may need Web UI verification"
    echo ""
}

verify_protection() {
    print_header "Verifying Branch Protection"

    print_info "Fetching current protection status..."

    # Fetch and display protection settings
    PROTECTION=$(gh api "repos/$REPO/branches/$BRANCH/protection" 2>&1 || echo "{}")

    if echo "$PROTECTION" | grep -q "error"; then
        print_error "Could not fetch protection status"
        print_info "Protection may not be fully enabled yet"
        return 1
    fi

    # Check key settings
    echo ""
    print_info "Protection status:"

    # Required PR reviews
    if echo "$PROTECTION" | grep -q "required_pull_request_reviews"; then
        print_success "Pull request reviews required"
    else
        print_warning "Pull request reviews not configured"
    fi

    # Required status checks
    if echo "$PROTECTION" | grep -q "required_status_checks"; then
        print_success "Status checks required"
    else
        print_warning "Status checks not configured"
    fi

    # Enforce admins
    if echo "$PROTECTION" | grep -q '"enabled":true' | grep -q "enforce_admins"; then
        print_success "Enforce admins enabled"
    else
        print_warning "Enforce admins may not be enabled"
    fi

    # Linear history
    if echo "$PROTECTION" | grep -q '"required":true' | grep -q "required_linear_history"; then
        print_success "Linear history required"
    else
        print_warning "Linear history may not be required"
    fi

    # Signed commits (separate endpoint)
    SIGNATURES=$(gh api "repos/$REPO/branches/$BRANCH/protection/required_signatures" --jq '.enabled' 2>/dev/null || echo "false")
    if [ "$SIGNATURES" = "true" ]; then
        print_success "Signed commits required"
    else
        print_warning "Signed commits may not be required"
    fi

    echo ""
    print_info "Full protection details saved to: /tmp/branch_protection_status.json"
    echo "$PROTECTION" | jq '.' > /tmp/branch_protection_status.json 2>/dev/null || echo "$PROTECTION" > /tmp/branch_protection_status.json
    echo ""
}

print_summary() {
    print_header "Summary"

    echo "Branch protection has been configured for:"
    echo "  Repository: $REPO"
    echo "  Branch: $BRANCH"
    echo ""
    echo "Applied settings:"
    echo "  ✓ Required PR reviews (1 approval minimum)"
    echo "  ✓ Required status checks (must pass before merge)"
    echo "  ✓ Signed commits required (GPG)"
    echo "  ✓ Linear history enforced"
    echo "  ✓ Conversation resolution required"
    echo "  ✓ Administrators included in rules"
    echo "  ✓ Force pushes blocked"
    echo "  ✓ Branch deletions blocked"
    echo ""
    print_info "Next steps:"
    echo "  1. Review settings at: https://github.com/$REPO/settings/branches"
    echo "  2. Test protection by attempting a direct push (should be rejected)"
    echo "  3. Verify workflows provide required status checks"
    echo ""
    print_success "Branch protection setup complete!"
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------

main() {
    echo ""
    print_header "QuantumTrader Pro - Branch Protection Setup"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Apply protection rules
    apply_protection_rules || {
        print_error "Failed to apply protection rules"
        exit 1
    }

    # Require signed commits
    apply_signed_commits || {
        print_warning "Signed commits may not be fully configured"
    }

    # Verify what was applied
    verify_protection || {
        print_warning "Verification incomplete"
    }

    # Print manual steps
    print_manual_steps

    # Print summary
    print_summary
}

# Run main function
main "$@"
