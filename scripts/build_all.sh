#!/bin/bash

# QuantumTrader-Pro Complete Build Script
# Builds all components: Flutter app, bridge server, ML engine

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_status() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Build timestamp
BUILD_DATE=$(date +%Y%m%d_%H%M%S)
BUILD_DIR="builds/$BUILD_DATE"

# Header
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║          QuantumTrader-Pro Build System               ║"
echo "║                Build: $BUILD_DATE                     ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Create build directory
print_status "Creating build directory..."
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/logs"

# Step 1: Validate Environment
print_status "Validating environment..."
if python scripts/validate_environment.py > "$BUILD_DIR/logs/validation.log" 2>&1; then
    print_success "Environment validation passed"
else
    print_error "Environment validation failed. Check $BUILD_DIR/logs/validation.log"
    exit 1
fi

# Step 2: Clean Previous Builds
print_status "Cleaning previous builds..."
flutter clean
cd bridge && npm run clean 2>/dev/null || true && cd ..
rm -rf build/
print_success "Clean complete"

# Step 3: Generate Flutter Code
print_status "Generating Flutter code..."
if flutter pub run build_runner build --delete-conflicting-outputs > "$BUILD_DIR/logs/flutter_gen.log" 2>&1; then
    print_success "Code generation complete"
else
    print_error "Code generation failed. Check $BUILD_DIR/logs/flutter_gen.log"
    exit 1
fi

# Step 4: Run Tests
print_status "Running tests..."

# Flutter tests
print_status "Running Flutter tests..."
if flutter test > "$BUILD_DIR/logs/flutter_test.log" 2>&1; then
    print_success "Flutter tests passed"
else
    print_warning "Flutter tests failed. Check $BUILD_DIR/logs/flutter_test.log"
fi

# Python tests
print_status "Running Python tests..."
if python -m pytest ml/tests/ -v > "$BUILD_DIR/logs/python_test.log" 2>&1; then
    print_success "Python tests passed"
else
    print_warning "Python tests failed. Check $BUILD_DIR/logs/python_test.log"
fi

# Node tests
print_status "Running Node.js tests..."
cd bridge
if npm test > "../$BUILD_DIR/logs/node_test.log" 2>&1; then
    print_success "Node.js tests passed"
else
    print_warning "Node.js tests failed. Check $BUILD_DIR/logs/node_test.log"
fi
cd ..

# Step 5: Build Flutter App
print_status "Building Flutter app..."

# Debug APK
print_status "Building debug APK..."
if flutter build apk --debug > "$BUILD_DIR/logs/flutter_debug.log" 2>&1; then
    cp build/app/outputs/flutter-apk/app-debug.apk "$BUILD_DIR/"
    print_success "Debug APK built: $BUILD_DIR/app-debug.apk"
else
    print_error "Debug APK build failed. Check $BUILD_DIR/logs/flutter_debug.log"
fi

# Release APK
print_status "Building release APK..."
if [ -f "android/key.properties" ] && ! grep -q "YOUR_" android/key.properties; then
    if flutter build apk --release > "$BUILD_DIR/logs/flutter_release.log" 2>&1; then
        cp build/app/outputs/flutter-apk/app-release.apk "$BUILD_DIR/"
        print_success "Release APK built: $BUILD_DIR/app-release.apk"
    else
        print_error "Release APK build failed. Check $BUILD_DIR/logs/flutter_release.log"
    fi
else
    print_warning "Skipping release build - keystore not configured"
fi

# App Bundle
print_status "Building app bundle..."
if [ -f "android/key.properties" ] && ! grep -q "YOUR_" android/key.properties; then
    if flutter build appbundle --release > "$BUILD_DIR/logs/flutter_bundle.log" 2>&1; then
        cp build/app/outputs/bundle/release/app-release.aab "$BUILD_DIR/"
        print_success "App bundle built: $BUILD_DIR/app-release.aab"
    else
        print_error "App bundle build failed. Check $BUILD_DIR/logs/flutter_bundle.log"
    fi
fi

# Step 6: Package Bridge Server
print_status "Packaging bridge server..."
cd bridge
tar -czf "../$BUILD_DIR/bridge-server.tar.gz" \
    *.js \
    *.json \
    middleware/ \
    .env.template \
    README.md \
    --exclude=node_modules \
    --exclude=.env \
    --exclude=logs
cd ..
print_success "Bridge server packaged"

# Step 7: Package ML Engine
print_status "Packaging ML engine..."
cd ml
tar -czf "../$BUILD_DIR/ml-engine.tar.gz" \
    *.py \
    requirements*.txt \
    .env.template \
    config/ \
    --exclude=__pycache__ \
    --exclude=.env \
    --exclude=logs \
    --exclude=models/*.pkl
cd ..
print_success "ML engine packaged"

# Step 8: Create Documentation
print_status "Generating build documentation..."

cat > "$BUILD_DIR/BUILD_INFO.md" << EOF
# QuantumTrader-Pro Build Information

**Build Date:** $BUILD_DATE
**Build Machine:** $(hostname)
**Build User:** $(whoami)

## Build Artifacts

- \`app-debug.apk\` - Debug build for testing
- \`app-release.apk\` - Signed release build (if keystore configured)
- \`app-release.aab\` - App bundle for Play Store
- \`bridge-server.tar.gz\` - Bridge server package
- \`ml-engine.tar.gz\` - ML engine package

## Version Information

### Flutter
\`\`\`
$(flutter --version)
\`\`\`

### Node.js
\`\`\`
Node: $(node --version)
npm: $(npm --version)
\`\`\`

### Python
\`\`\`
Python: $(python --version 2>&1)
\`\`\`

## Git Information
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Status: $(git status --porcelain | wc -l) uncommitted changes

## Test Results
- Flutter Tests: $(grep -c "All tests passed" "$BUILD_DIR/logs/flutter_test.log" 2>/dev/null || echo "Failed/Not Run")
- Python Tests: $(grep -c "passed" "$BUILD_DIR/logs/python_test.log" 2>/dev/null || echo "Failed/Not Run")
- Node Tests: $(grep -c "passing" "$BUILD_DIR/logs/node_test.log" 2>/dev/null || echo "Failed/Not Run")

## Deployment Instructions

### Android App
1. Install APK: \`adb install app-release.apk\`
2. Or upload AAB to Play Store Console

### Bridge Server
1. Extract: \`tar -xzf bridge-server.tar.gz\`
2. Install deps: \`npm install\`
3. Configure: Copy \`.env.template\` to \`.env\` and configure
4. Run: \`npm start\`

### ML Engine
1. Extract: \`tar -xzf ml-engine.tar.gz\`
2. Install deps: \`pip install -r requirements.txt\`
3. Configure: Copy \`.env.template\` to \`.env\` and configure
4. Run: \`python predictor_daemon.py\`
EOF

print_success "Build documentation created"

# Step 9: Calculate checksums
print_status "Calculating checksums..."
cd "$BUILD_DIR"
sha256sum *.apk *.aab *.tar.gz 2>/dev/null > checksums.sha256 || true
cd - > /dev/null
print_success "Checksums calculated"

# Step 10: Create deployment script
print_status "Creating deployment script..."

cat > "$BUILD_DIR/deploy.sh" << 'EOF'
#!/bin/bash
# Quick deployment script

echo "QuantumTrader-Pro Deployment"
echo "==========================="

# Deploy to device
if [ -f "app-release.apk" ]; then
    echo "Installing APK..."
    adb install -r app-release.apk
fi

# Extract servers
if [ -f "bridge-server.tar.gz" ]; then
    echo "Extracting bridge server..."
    mkdir -p deploy/bridge
    tar -xzf bridge-server.tar.gz -C deploy/bridge/
fi

if [ -f "ml-engine.tar.gz" ]; then
    echo "Extracting ML engine..."
    mkdir -p deploy/ml
    tar -xzf ml-engine.tar.gz -C deploy/ml/
fi

echo "Deployment complete!"
EOF

chmod +x "$BUILD_DIR/deploy.sh"

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              Build Complete!                           ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Build artifacts saved to: $BUILD_DIR"
echo ""
ls -la "$BUILD_DIR" | grep -E "\.(apk|aab|tar\.gz)$"
echo ""
echo "Next steps:"
echo "1. Review test results in $BUILD_DIR/logs/"
echo "2. Deploy using $BUILD_DIR/deploy.sh"
echo "3. Configure .env files before running servers"
echo ""

# Create latest symlink
ln -sfn "$BUILD_DIR" builds/latest
print_success "Created 'latest' symlink"