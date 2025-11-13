#!/usr/bin/env bash
#
# Branch Protection Configuration Script
# 
# Applies branch protection rules to QuantumTrader Pro repository using GitHub CLI.
# 
# Usage:
#   ./branch_protection.sh <branch-name>
#   
# Example:
#   ./branch_protection.sh main
#   ./branch_protection.sh desktop
#
# Requirements:
#   - GitHub CLI (gh) installed: https://cli.github.com/
#   - Authenticated with admin permissions: gh auth login
#   - Repository must have workflows already merged (for status checks)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO="Dezirae-Stark/QuantumTrader-Pro"
BRANCH="${1:-}"

# Print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Display usage
usage() {
    cat <<USAGE
📋 Branch Protection Configuration Script

Usage: $0 <branch-name>

Branches:
  main        - Mobile app branch (requires Build APK + CodeQL Java/Kotlin)
  desktop     - Server components branch (requires CodeQL JavaScript)

Examples:
  $0 main
  $0 desktop

Requirements:
  - GitHub CLI (gh) installed: https://cli.github.com/
  - Authenticated with admin perms: gh auth login
USAGE
    exit 1
}

# Check prerequisites
check_prereqs() {
    print_info "Checking prerequisites..."
    
    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) not found"
        echo "Install from: https://cli.github.com/"
        exit 1
    fi
    print_success "GitHub CLI found: $(gh --version | head -1)"
    
    # Check authentication
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub"
        echo "Run: gh auth login"
        exit 1
    fi
    print_success "Authenticated with GitHub"
    
    # Verify repository access
    if ! gh repo view "$REPO" &> /dev/null; then
        print_error "Cannot access repository: $REPO"
        exit 1
    fi
    print_success "Repository accessible: $REPO"
}

# Apply branch protection for main branch
protect_main_branch() {
    print_info "Applying branch protection to: main"
    
    # Define protection rules for main branch
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/$REPO/branches/main/protection" \
        -f required_status_checks[strict]=true \
        -f required_status_checks[contexts][]=build-apk \
        -f required_status_checks[contexts][]="CodeQL / Analyze Java/Kotlin (Android)" \
        -f required_pull_request_reviews[dismiss_stale_reviews]=true \
        -f required_pull_request_reviews[require_code_owner_reviews]=false \
        -f required_pull_request_reviews[required_approving_review_count]=1 \
        -f required_pull_request_reviews[require_last_push_approval]=true \
        -f required_conversation_resolution=true \
        -f enforce_admins=true \
        -f restrictions=null \
        -f allow_force_pushes[enabled]=false \
        -f allow_deletions[enabled]=false \
        -f required_linear_history[enabled]=false \
        -f lock_branch[enabled]=false \
        > /dev/null 2>&1
    
    print_success "Main branch protection applied"
    print_info "Required status checks:"
    echo "  - build-apk"
    echo "  - CodeQL / Analyze Java/Kotlin (Android)"
    print_info "Pull request requirements:"
    echo "  - 1 approval required"
    echo "  - Dismiss stale reviews: Yes"
    echo "  - Require conversation resolution: Yes"
    print_info "Restrictions:"
    echo "  - Force pushes: Denied"
    echo "  - Branch deletion: Denied"
}

# Apply branch protection for desktop branch
protect_desktop_branch() {
    print_info "Applying branch protection to: desktop"
    
    # Define protection rules for desktop branch
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/$REPO/branches/desktop/protection" \
        -f required_status_checks[strict]=true \
        -f required_status_checks[contexts][]="CodeQL / Analyze JavaScript/TypeScript" \
        -f required_pull_request_reviews[dismiss_stale_reviews]=true \
        -f required_pull_request_reviews[require_code_owner_reviews]=false \
        -f required_pull_request_reviews[required_approving_review_count]=1 \
        -f required_pull_request_reviews[require_last_push_approval]=true \
        -f required_conversation_resolution=true \
        -f enforce_admins=true \
        -f restrictions=null \
        -f allow_force_pushes[enabled]=false \
        -f allow_deletions[enabled]=false \
        -f required_linear_history[enabled]=false \
        -f lock_branch[enabled]=false \
        > /dev/null 2>&1
    
    print_success "Desktop branch protection applied"
    print_info "Required status checks:"
    echo "  - CodeQL / Analyze JavaScript/TypeScript"
    print_info "Pull request requirements:"
    echo "  - 1 approval required"
    echo "  - Dismiss stale reviews: Yes"
    echo "  - Require conversation resolution: Yes"
    print_info "Restrictions:"
    echo "  - Force pushes: Denied"
    echo "  - Branch deletion: Denied"
}

# Verify protection is applied
verify_protection() {
    local branch="$1"
    print_info "Verifying branch protection for: $branch"
    
    local protection_status
    protection_status=$(gh api "/repos/$REPO/branches/$branch/protection" --jq '.url' 2>/dev/null || echo "")
    
    if [[ -n "$protection_status" ]]; then
        print_success "Branch protection verified for: $branch"
        
        # Show detailed protection status
        echo ""
        print_info "Current protection settings:"
        gh api "/repos/$REPO/branches/$branch/protection" --jq '{
            enforce_admins: .enforce_admins.enabled,
            required_pull_request_reviews: .required_pull_request_reviews.required_approving_review_count,
            required_status_checks: .required_status_checks.contexts,
            allow_force_pushes: .allow_force_pushes.enabled,
            allow_deletions: .allow_deletions.enabled
        }' | jq .
    else
        print_error "Failed to verify branch protection"
        exit 1
    fi
}

# Main execution
main() {
    echo "🔒 Branch Protection Configuration Script"
    echo "========================================="
    echo ""
    
    # Validate arguments
    if [[ -z "$BRANCH" ]]; then
        print_error "No branch specified"
        usage
    fi
    
    if [[ "$BRANCH" != "main" && "$BRANCH" != "desktop" ]]; then
        print_error "Invalid branch: $BRANCH"
        print_warning "Supported branches: main, desktop"
        usage
    fi
    
    # Check prerequisites
    check_prereqs
    echo ""
    
    # Apply protection based on branch
    case "$BRANCH" in
        main)
            protect_main_branch
            ;;
        desktop)
            protect_desktop_branch
            ;;
    esac
    
    echo ""
    verify_protection "$BRANCH"
    
    echo ""
    print_success "Branch protection configuration complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Verify settings in GitHub: https://github.com/$REPO/settings/branches"
    echo "  2. Create a test PR to verify status checks run correctly"
    echo "  3. Document any custom changes in: docs/policies/branch-protection.md"
}

# Run main function
main "$@"
