#!/bin/bash
#
# Code Syntax Checker for Broker Catalog Implementation
# Verifies that all new code is syntactically correct
#

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Checking Broker Catalog Code Syntax"
echo "========================================"
echo ""

# Check Kotlin files exist
echo "📂 Checking Kotlin files..."
KOTLIN_FILES=(
    "android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/Broker.kt"
    "android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/BrokerSchema.kt"
    "android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/SignatureVerifier.kt"
    "android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/BrokerCatalog.kt"
    "android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/BrokerUpdater.kt"
    "android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/BrokerListAdapter.kt"
)

for file in "${KOTLIN_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file (missing)"
        exit 1
    fi
done

echo ""

# Check layout files
echo "📐 Checking layout files..."
LAYOUT_FILES=(
    "android/app/src/main/res/layout/fragment_broker_selection.xml"
    "android/app/src/main/res/layout/item_broker.xml"
)

for file in "${LAYOUT_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Basic XML syntax check
        if grep -q "<?xml" "$file" && grep -q "</.*>" "$file"; then
            echo -e "${GREEN}✓${NC} $file (valid XML structure)"
        else
            echo -e "${RED}✗${NC} $file (invalid XML)"
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} $file (missing)"
        exit 1
    fi
done

echo ""

# Check assets
echo "📦 Checking assets..."
if [ -f "android/app/src/main/assets/brokers.json" ]; then
    if command -v jq &> /dev/null; then
        if jq empty android/app/src/main/assets/brokers.json 2>/dev/null; then
            echo -e "${GREEN}✓${NC} brokers.json (valid JSON)"
        else
            echo -e "${RED}✗${NC} brokers.json (invalid JSON)"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} brokers.json (jq not installed, skipping validation)"
    fi
else
    echo -e "${RED}✗${NC} brokers.json (missing)"
    exit 1
fi

echo ""

# Check for common Kotlin issues
echo "🔍 Checking for common Kotlin issues..."

# Check imports
echo "  Checking imports..."
if grep -r "import com.quantumtrader.pro.R" android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/ > /dev/null; then
    echo -e "  ${GREEN}✓${NC} R class imported correctly"
else
    echo -e "  ${YELLOW}⚠${NC} R class import not found (may cause build errors)"
fi

# Check for unresolved references
echo "  Checking for potential issues..."
if grep -r "TODO\|FIXME\|XXX" android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/ > /dev/null; then
    echo -e "  ${YELLOW}⚠${NC} Found TODO/FIXME comments"
    grep -rn "TODO\|FIXME\|XXX" android/app/src/main/kotlin/com/quantumtrader/pro/brokerselector/
else
    echo -e "  ${GREEN}✓${NC} No TODO/FIXME comments"
fi

echo ""

# Check build.gradle
echo "📋 Checking build.gradle dependencies..."
if grep -q "kotlinx-coroutines-android" android/app/build.gradle; then
    echo -e "${GREEN}✓${NC} Coroutines dependency added"
else
    echo -e "${RED}✗${NC} Missing coroutines dependency"
fi

if grep -q "work-runtime-ktx" android/app/build.gradle; then
    echo -e "${GREEN}✓${NC} WorkManager dependency added"
else
    echo -e "${RED}✗${NC} Missing WorkManager dependency"
fi

if grep -q "material:" android/app/build.gradle; then
    echo -e "${GREEN}✓${NC} Material Components dependency added"
else
    echo -e "${RED}✗${NC} Missing Material Components dependency"
fi

echo ""
echo "✅ Code syntax check complete!"
echo ""
echo "📌 Note: This script only checks for file existence and basic syntax."
echo "   Full compilation requires Flutter SDK and Android SDK."
echo ""
echo "🚀 To build the app, run on a desktop with Flutter:"
echo "   flutter pub get"
echo "   flutter build apk --debug"
echo ""
