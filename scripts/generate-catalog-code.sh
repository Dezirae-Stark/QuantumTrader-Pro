#!/bin/bash
# Generate Freezed and Hive code for catalog models
#
# This script generates the required code for catalog services to work.
# Must be run before building the Android app.
#
# Usage:
#   ./scripts/generate-catalog-code.sh
#
# Requirements:
#   - Flutter SDK installed
#   - Dependencies in pubspec.yaml already added

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Catalog Code Generation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Error: Flutter is not installed or not in PATH${NC}"
    echo ""
    echo "Please install Flutter:"
    echo "  https://docs.flutter.dev/get-started/install"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Flutter found: $(flutter --version | head -n 1)${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: pubspec.yaml not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo -e "${BLUE}📦 Installing dependencies...${NC}"
flutter pub get

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Check if build_runner is available
if ! flutter pub run build_runner --help &> /dev/null; then
    echo -e "${RED}❌ Error: build_runner not found${NC}"
    echo "Make sure build_runner is in dev_dependencies in pubspec.yaml"
    exit 1
fi

echo -e "${BLUE}🔨 Generating code with build_runner...${NC}"
echo ""
echo "This will generate:"
echo "  - Freezed models (*.freezed.dart)"
echo "  - JSON serialization (*.g.dart)"
echo "  - Hive adapters (*.g.dart)"
echo ""

# Run build_runner with delete-conflicting-outputs flag
dart run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Code generation failed${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. Syntax errors in model files"
    echo "  2. Missing imports"
    echo "  3. Conflicting generated files (try: flutter clean)"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Code generation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# List generated files
echo -e "${BLUE}Generated files:${NC}"
echo ""

GENERATED_FILES=(
    "lib/models/catalog/broker_catalog.freezed.dart"
    "lib/models/catalog/broker_catalog.g.dart"
    "lib/models/catalog/catalog_metadata.freezed.dart"
    "lib/models/catalog/catalog_metadata.g.dart"
    "lib/models/catalog/cached_catalog.g.dart"
)

for file in "${GENERATED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}  ✓ $file${NC}"
    else
        echo -e "${YELLOW}  ⚠ $file (not found)${NC}"
    fi
done

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run: flutter analyze"
echo "  2. Fix any warnings/errors"
echo "  3. Test catalog loading with: flutter run"
echo ""
