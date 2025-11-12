#!/usr/bin/env bash
#
# Branch Protection Verification Script
#
# This script checks and displays the current branch protection status for
# the main branch using the GitHub API via gh CLI.
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated
# - Read permissions on the repository
#
# Usage:
#   ./verify_branch_protection.sh [branch] [repo]
#
# Examples:
#   ./verify_branch_protection.sh main Dezirae-Stark/QuantumTrader-Pro
#   ./verify_branch_protection.sh           # Uses defaults
#
# Reference: docs/policies/branch-protection.md

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_BRANCH="${1:-main}"
DEFAULT_REPO="${2:-Dezirae-Stark/QuantumTrader-Pro}"

BRANCH="$DEFAULT_BRANCH"
REPO="$DEFAULT_REPO"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

print_header() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
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

print_section() {
    echo -e "${BOLD}$1${NC}"
}

check_protection_status() {
    print_header "Branch Protection Status"
    print_info "Repository: $REPO"
    print_info "Branch: $BRANCH"
    echo ""

    # Check if gh is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        echo "Install it from: https://cli.github.com/"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub CLI"
        echo "Run: gh auth login"
        exit 1
    fi

    # Fetch protection status
    print_info "Fetching protection configuration..."
    echo ""

    PROTECTION=$(gh api "repos/$REPO/branches/$BRANCH/protection" 2>&1 || echo "{\"error\": true}")

    if echo "$PROTECTION" | grep -q "Branch not protected"; then
        print_error "Branch is NOT protected"
        echo ""
        print_warning "No branch protection rules are currently enabled for this branch"
        print_info "Run ./apply_branch_protection.sh to enable protection"
        echo ""
        exit 1
    elif echo "$PROTECTION" | grep -q "error"; then
        print_error "Could not fetch protection status"
        echo ""
        print_warning "You may not have permission to view branch protection settings"
        echo ""
        exit 1
    fi

    print_success "Branch protection is enabled"
    echo ""
}

display_pr_reviews() {
    print_section "📝 Pull Request Reviews"
    echo ""

    # Extract PR review settings
    REQUIRED_REVIEWS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count' 2>/dev/null || echo "0")
    DISMISS_STALE=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews' 2>/dev/null || echo "false")
    REQUIRE_CODE_OWNERS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.require_code_owner_reviews' 2>/dev/null || echo "false")

    if [ "$REQUIRED_REVIEWS" -gt 0 ]; then
        print_success "Required approving reviews: $REQUIRED_REVIEWS"
    else
        print_error "No required approving reviews"
    fi

    if [ "$DISMISS_STALE" = "true" ]; then
        print_success "Dismiss stale pull request approvals: Enabled"
    else
        print_warning "Dismiss stale pull request approvals: Disabled"
    fi

    if [ "$REQUIRE_CODE_OWNERS" = "true" ]; then
        print_success "Require review from Code Owners: Enabled"
    else
        print_warning "Require review from Code Owners: Disabled"
    fi

    echo ""
}

display_status_checks() {
    print_section "🔍 Required Status Checks"
    echo ""

    # Extract status check settings
    STRICT=$(echo "$PROTECTION" | jq -r '.required_status_checks.strict' 2>/dev/null || echo "false")
    CONTEXTS=$(echo "$PROTECTION" | jq -r '.required_status_checks.contexts[]' 2>/dev/null || echo "")

    if [ "$STRICT" = "true" ]; then
        print_success "Require branches to be up to date: Enabled"
    else
        print_warning "Require branches to be up to date: Disabled"
    fi

    if [ -n "$CONTEXTS" ]; then
        print_success "Required status checks configured:"
        echo "$CONTEXTS" | while read -r context; do
            if [ -n "$context" ]; then
                echo "  - $context"
            fi
        done
    else
        print_warning "No required status checks configured"
    fi

    echo ""
}

display_additional_settings() {
    print_section "⚙️  Additional Settings"
    echo ""

    # Enforce admins
    ENFORCE_ADMINS=$(echo "$PROTECTION" | jq -r '.enforce_admins.enabled' 2>/dev/null || echo "false")
    if [ "$ENFORCE_ADMINS" = "true" ]; then
        print_success "Include administrators: Enabled"
    else
        print_warning "Include administrators: Disabled (admins can bypass rules)"
    fi

    # Linear history
    LINEAR_HISTORY=$(echo "$PROTECTION" | jq -r '.required_linear_history.enabled' 2>/dev/null || echo "false")
    if [ "$LINEAR_HISTORY" = "true" ]; then
        print_success "Require linear history: Enabled"
    else
        print_warning "Require linear history: Disabled"
    fi

    # Conversation resolution
    CONVERSATION_RESOLUTION=$(echo "$PROTECTION" | jq -r '.required_conversation_resolution.enabled' 2>/dev/null || echo "false")
    if [ "$CONVERSATION_RESOLUTION" = "true" ]; then
        print_success "Require conversation resolution: Enabled"
    else
        print_warning "Require conversation resolution: Disabled"
    fi

    # Force pushes
    ALLOW_FORCE_PUSHES=$(echo "$PROTECTION" | jq -r '.allow_force_pushes.enabled' 2>/dev/null || echo "true")
    if [ "$ALLOW_FORCE_PUSHES" = "false" ]; then
        print_success "Allow force pushes: Disabled (force pushes blocked)"
    else
        print_error "Allow force pushes: Enabled (force pushes allowed)"
    fi

    # Deletions
    ALLOW_DELETIONS=$(echo "$PROTECTION" | jq -r '.allow_deletions.enabled' 2>/dev/null || echo "true")
    if [ "$ALLOW_DELETIONS" = "false" ]; then
        print_success "Allow deletions: Disabled (branch protected from deletion)"
    else
        print_error "Allow deletions: Enabled (branch can be deleted)"
    fi

    echo ""
}

display_signed_commits() {
    print_section "🔐 Signed Commits"
    echo ""

    # Check signed commits (separate endpoint)
    SIGNATURES=$(gh api "repos/$REPO/branches/$BRANCH/protection/required_signatures" --jq '.enabled' 2>/dev/null || echo "false")

    if [ "$SIGNATURES" = "true" ]; then
        print_success "Require signed commits: Enabled"
        print_info "All commits must be signed with GPG"
    else
        print_warning "Require signed commits: Disabled"
        print_info "Commits can be unsigned (supply chain risk)"
    fi

    echo ""
}

display_summary() {
    print_header "Security Score"

    # Calculate score based on enabled protections
    SCORE=0
    MAX_SCORE=10

    # Required PR reviews (2 points)
    if [ "$REQUIRED_REVIEWS" -gt 0 ]; then ((SCORE++)); fi
    if [ "$DISMISS_STALE" = "true" ]; then ((SCORE++)); fi

    # Status checks (2 points)
    if [ "$STRICT" = "true" ]; then ((SCORE++)); fi
    if [ -n "$CONTEXTS" ]; then ((SCORE++)); fi

    # Additional settings (5 points)
    if [ "$ENFORCE_ADMINS" = "true" ]; then ((SCORE++)); fi
    if [ "$LINEAR_HISTORY" = "true" ]; then ((SCORE++)); fi
    if [ "$CONVERSATION_RESOLUTION" = "true" ]; then ((SCORE++)); fi
    if [ "$ALLOW_FORCE_PUSHES" = "false" ]; then ((SCORE++)); fi
    if [ "$ALLOW_DELETIONS" = "false" ]; then ((SCORE++)); fi

    # Signed commits (1 point)
    if [ "$SIGNATURES" = "true" ]; then ((SCORE++)); fi

    echo ""
    echo -e "  Branch Protection Score: ${BOLD}$SCORE / $MAX_SCORE${NC}"
    echo ""

    if [ "$SCORE" -eq "$MAX_SCORE" ]; then
        print_success "Excellent! All recommended protections are enabled"
    elif [ "$SCORE" -ge 8 ]; then
        print_warning "Good, but some protections could be improved"
    elif [ "$SCORE" -ge 5 ]; then
        print_warning "Moderate protection. Consider enabling more rules"
    else
        print_error "Insufficient protection. Branch is vulnerable"
    fi

    echo ""
    print_info "Policy reference: docs/policies/branch-protection.md"
    echo ""
}

display_raw_json() {
    print_header "Raw Protection Data"
    echo ""
    print_info "Full JSON output saved to: /tmp/branch_protection_status.json"
    echo ""

    echo "$PROTECTION" | jq '.' > /tmp/branch_protection_status.json 2>/dev/null || echo "$PROTECTION" > /tmp/branch_protection_status.json

    if command -v jq &> /dev/null; then
        echo "$PROTECTION" | jq '.'
    else
        echo "$PROTECTION"
        print_warning "Install 'jq' for prettier JSON output"
    fi

    echo ""
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------

main() {
    echo ""
    print_header "Branch Protection Verification"
    echo ""

    # Check if protection is enabled
    check_protection_status

    # Display protection settings
    display_pr_reviews
    display_status_checks
    display_additional_settings
    display_signed_commits

    # Display summary
    display_summary

    # Display raw JSON (optional)
    if [ "${SHOW_RAW:-}" = "true" ]; then
        display_raw_json
    else
        print_info "Run with SHOW_RAW=true to see full JSON output"
        echo ""
    fi
}

# Run main function
main "$@"
