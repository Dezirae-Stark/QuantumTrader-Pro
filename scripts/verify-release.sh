#!/bin/bash
# Verify QuantumTrader-Pro Release Integrity
#
# This script verifies downloaded APK files using SHA256 checksums.
# Run this before installing any APK to ensure it hasn't been tampered with.
#
# Usage:
#   ./scripts/verify-release.sh QuantumTrader-Pro-v2.1.0-arm64.apk
#
# Requirements:
#   - sha256sum command (pre-installed on most Linux systems)
#   - Downloaded APK file
#   - SHA256SUMS.txt file (from GitHub release)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ASCII Art Banner
print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║         QuantumTrader-Pro Release Verification           ║
║                 APK Integrity Check                       ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Print colored message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main verification function
verify_apk() {
    local APK_FILE="$1"
    local CHECKSUMS_FILE="SHA256SUMS.txt"

    print_banner

    print_info "Starting verification..."
    echo ""

    # Check if APK file exists
    if [ ! -f "$APK_FILE" ]; then
        print_error "APK file not found: $APK_FILE"
        echo ""
        echo "Usage: $0 <apk-file>"
        echo ""
        echo "Example:"
        echo "  $0 QuantumTrader-Pro-v2.1.0-arm64.apk"
        exit 1
    fi

    print_info "APK file: $(basename "$APK_FILE")"
    print_info "File size: $(du -h "$APK_FILE" | cut -f1)"
    echo ""

    # Check if sha256sum is available
    if ! command_exists sha256sum; then
        print_error "sha256sum command not found!"
        echo ""
        echo "Please install it:"
        echo "  - Debian/Ubuntu: apt-get install coreutils"
        echo "  - macOS: brew install coreutils"
        exit 1
    fi

    # Check if checksums file exists
    if [ ! -f "$CHECKSUMS_FILE" ]; then
        print_warning "SHA256SUMS.txt not found"
        echo ""
        echo "Download it from the same GitHub release as your APK:"
        echo "  https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases"
        echo ""
        print_info "Calculating checksum without verification..."

        # Calculate checksum
        CALCULATED_CHECKSUM=$(sha256sum "$APK_FILE" | cut -d' ' -f1)

        echo ""
        print_info "APK SHA256 checksum:"
        echo "  $CALCULATED_CHECKSUM"
        echo ""
        print_warning "Verify this checksum manually against SHA256SUMS.txt"

        exit 2
    fi

    # Verify checksum
    print_info "Verifying SHA256 checksum..."
    echo ""

    # Extract expected checksum for this file
    EXPECTED_CHECKSUM=$(grep "$(basename "$APK_FILE")" "$CHECKSUMS_FILE" | cut -d' ' -f1)

    if [ -z "$EXPECTED_CHECKSUM" ]; then
        print_error "No checksum found for $(basename "$APK_FILE") in SHA256SUMS.txt"
        echo ""
        print_info "Available checksums:"
        cat "$CHECKSUMS_FILE"
        exit 1
    fi

    # Calculate actual checksum
    CALCULATED_CHECKSUM=$(sha256sum "$APK_FILE" | cut -d' ' -f1)

    # Compare checksums
    if [ "$EXPECTED_CHECKSUM" = "$CALCULATED_CHECKSUM" ]; then
        print_success "Checksum verified!"
        echo ""
        echo "  Expected:   $EXPECTED_CHECKSUM"
        echo "  Calculated: $CALCULATED_CHECKSUM"
        echo ""
        print_success "APK integrity verified - file is authentic"
        echo ""
        print_info "Safe to install: $APK_FILE"
        echo ""
        return 0
    else
        print_error "Checksum verification FAILED!"
        echo ""
        echo "  Expected:   $EXPECTED_CHECKSUM"
        echo "  Calculated: $CALCULATED_CHECKSUM"
        echo ""
        print_error "⛔ DO NOT INSTALL THIS APK ⛔"
        print_error "The file may have been corrupted or tampered with!"
        echo ""
        print_info "Recommendations:"
        echo "  1. Re-download the APK from official GitHub releases"
        echo "  2. Re-download SHA256SUMS.txt"
        echo "  3. Verify again"
        echo "  4. Report the issue if problem persists"
        echo ""
        exit 1
    fi
}

# Show help
show_help() {
    print_banner

    cat << EOF
Verify the integrity of QuantumTrader-Pro APK releases.

USAGE:
    $0 <apk-file>

EXAMPLES:
    # Verify ARM64 APK
    $0 QuantumTrader-Pro-v2.1.0-arm64.apk

    # Verify ARM32 APK
    $0 QuantumTrader-Pro-v2.1.0-arm32.apk

    # Verify x86_64 APK
    $0 QuantumTrader-Pro-v2.1.0-x86_64.apk

REQUIREMENTS:
    - sha256sum command (usually pre-installed)
    - Downloaded APK file
    - SHA256SUMS.txt from the same release

HOW IT WORKS:
    1. Calculates SHA256 checksum of your APK
    2. Compares with official checksum from SHA256SUMS.txt
    3. Verifies file hasn't been modified or corrupted

DOWNLOAD:
    Download APKs and checksums from:
    https://github.com/Dezirae-Stark/QuantumTrader-Pro/releases

SECURITY:
    ✅ Always verify checksums before installing
    ✅ Download only from official GitHub releases
    ✅ Check the release is from Dezirae-Stark/QuantumTrader-Pro
    ⚠️  Never install APKs from unknown sources
    ⚠️  Never skip verification

SUPPORT:
    For help or to report issues:
    https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

EOF
}

# Main script logic
main() {
    # Check for help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        show_help
        exit 0
    fi

    # Check if APK file provided
    if [ -z "$1" ]; then
        print_error "No APK file specified"
        echo ""
        echo "Usage: $0 <apk-file>"
        echo ""
        echo "For help: $0 --help"
        exit 1
    fi

    # Run verification
    verify_apk "$1"
}

# Run main function
main "$@"
