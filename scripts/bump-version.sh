#!/bin/bash
# Bump version numbers for QuantumTrader-Pro
#
# Usage:
#   ./scripts/bump-version.sh major  # 2.1.0 -> 3.0.0
#   ./scripts/bump-version.sh minor  # 2.1.0 -> 2.2.0
#   ./scripts/bump-version.sh patch  # 2.1.0 -> 2.1.1
#
# This script:
# 1. Updates version.properties
# 2. Increments VERSION_CODE
# 3. Displays next steps (update CHANGELOG.md, create git tag)

set -e

VERSION_FILE="version.properties"
CHANGELOG_FILE="CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if version file exists
if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${RED}❌ Error: $VERSION_FILE not found${NC}"
    exit 1
fi

# Read current version
source "$VERSION_FILE"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}QuantumTrader-Pro Version Bump${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "Current version: ${GREEN}${VERSION_NAME}${NC} (code: ${VERSION_CODE})"
echo ""

# Parse command
BUMP_TYPE="$1"
case "$BUMP_TYPE" in
  major)
    NEW_MAJOR=$((VERSION_MAJOR + 1))
    NEW_MINOR=0
    NEW_PATCH=0
    ;;
  minor)
    NEW_MAJOR=$VERSION_MAJOR
    NEW_MINOR=$((VERSION_MINOR + 1))
    NEW_PATCH=0
    ;;
  patch)
    NEW_MAJOR=$VERSION_MAJOR
    NEW_MINOR=$VERSION_MINOR
    NEW_PATCH=$((VERSION_PATCH + 1))
    ;;
  *)
    echo -e "${RED}❌ Error: Invalid bump type${NC}"
    echo ""
    echo "Usage: $0 {major|minor|patch}"
    echo ""
    echo "Examples:"
    echo "  $0 major  # Breaking changes: 2.1.0 -> 3.0.0"
    echo "  $0 minor  # New features:    2.1.0 -> 2.2.0"
    echo "  $0 patch  # Bug fixes:       2.1.0 -> 2.1.1"
    exit 1
    ;;
esac

# Increment build number and version code
NEW_BUILD=$((VERSION_BUILD + 1))
NEW_VERSION_CODE=$((VERSION_CODE + 1))
NEW_VERSION_NAME="$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"

echo -e "New version:     ${GREEN}${NEW_VERSION_NAME}${NC} (code: ${NEW_VERSION_CODE})"
echo -e "Bump type:       ${YELLOW}${BUMP_TYPE}${NC}"
echo ""

# Confirm
read -p "Continue with version bump? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}❌ Cancelled${NC}"
    exit 0
fi

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Write new version file
cat > "$VERSION_FILE" <<EOF
# QuantumTrader-Pro Version Configuration
#
# This file is managed by scripts/bump-version.sh
# Manual edits should be avoided - use the bump script instead
#
# Semantic Versioning: MAJOR.MINOR.PATCH
# - MAJOR: Breaking changes (incompatible API changes)
# - MINOR: New features (backwards-compatible)
# - PATCH: Bug fixes (backwards-compatible)
#
# Last Updated: $CURRENT_DATE

# Version components
VERSION_MAJOR=$NEW_MAJOR
VERSION_MINOR=$NEW_MINOR
VERSION_PATCH=$NEW_PATCH
VERSION_BUILD=$NEW_BUILD

# Semantic version string
VERSION_NAME=$NEW_VERSION_NAME

# Android version code (must increment with each release)
# Google Play requires this to be unique and increasing
VERSION_CODE=$NEW_VERSION_CODE

# Release notes
# Update CHANGELOG.md with detailed release notes before tagging
EOF

echo ""
echo -e "${GREEN}✅ Version bumped to ${NEW_VERSION_NAME} (build $NEW_BUILD, code $NEW_VERSION_CODE)${NC}"
echo ""

# Check if CHANGELOG.md exists
if [ ! -f "$CHANGELOG_FILE" ]; then
    echo -e "${YELLOW}⚠️  Warning: $CHANGELOG_FILE not found${NC}"
else
    echo -e "${BLUE}📝 Next steps:${NC}"
    echo ""
    echo "1. Update CHANGELOG.md with release notes:"
    echo -e "   ${YELLOW}nano $CHANGELOG_FILE${NC}"
    echo ""
    echo "   Add section for version $NEW_VERSION_NAME:"
    echo -e "   ${GREEN}## [$NEW_VERSION_NAME] - $CURRENT_DATE${NC}"
    echo ""
    echo "2. Commit the version bump:"
    echo -e "   ${YELLOW}git add $VERSION_FILE $CHANGELOG_FILE${NC}"
    echo -e "   ${YELLOW}git commit -m \"chore: Bump version to $NEW_VERSION_NAME\"${NC}"
    echo ""
    echo "3. Create git tag:"
    echo -e "   ${YELLOW}git tag -a v$NEW_VERSION_NAME -m \"Release v$NEW_VERSION_NAME\"${NC}"
    echo ""
    echo "4. Push changes and tag:"
    echo -e "   ${YELLOW}git push origin main${NC}"
    echo -e "   ${YELLOW}git push origin v$NEW_VERSION_NAME${NC}"
    echo ""
    echo "5. GitHub Actions will automatically:"
    echo "   • Run security scans"
    echo "   • Build signed APKs"
    echo "   • Create GitHub release"
    echo "   • Upload artifacts"
    echo ""
fi

echo -e "${GREEN}🎉 Version bump complete!${NC}"
