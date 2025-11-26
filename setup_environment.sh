#!/bin/bash

# QuantumTrader-Pro Environment Setup Script
# Automated setup for all components

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
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

# Header
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║        QuantumTrader-Pro Environment Setup            ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running from project root
if [ ! -f "pubspec.yaml" ]; then
    print_error "Please run this script from the QuantumTrader-Pro root directory"
    exit 1
fi

# Step 1: Python Environment
print_status "Setting up Python environment..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
    print_success "Virtual environment created"
else
    print_warning "Virtual environment already exists"
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate || . venv/Scripts/activate

# Upgrade pip
print_status "Upgrading pip..."
python -m pip install --upgrade pip

# Install Python dependencies
print_status "Installing Python dependencies..."

# ML dependencies
if [ -f "ml/requirements.txt" ]; then
    pip install -r ml/requirements.txt
    print_success "ML dependencies installed"
fi

# Bridge Python dependencies
if [ -f "bridge/requirements.txt" ]; then
    pip install -r bridge/requirements.txt
    print_success "Bridge Python dependencies installed"
fi

# Development dependencies
pip install pytest pytest-cov flake8 black psutil
print_success "Development dependencies installed"

# Step 2: Node.js Dependencies
print_status "Setting up Node.js environment..."

# Check Node version
NODE_VERSION=$(node --version 2>/dev/null || echo "not installed")
print_status "Node.js version: $NODE_VERSION"

if [[ "$NODE_VERSION" == "not installed" ]]; then
    print_error "Node.js is not installed. Please install Node.js 16+ first."
    exit 1
fi

# Install bridge dependencies
print_status "Installing bridge server dependencies..."
cd bridge
npm install
cd ..
print_success "Bridge dependencies installed"

# Step 3: Flutter Dependencies
print_status "Setting up Flutter environment..."

# Check Flutter
if command -v flutter &> /dev/null; then
    print_status "Flutter is installed"
    
    # Get dependencies
    print_status "Installing Flutter dependencies..."
    flutter pub get
    
    # Generate code
    print_status "Generating code (Freezed, JSON serialization)..."
    flutter pub run build_runner build --delete-conflicting-outputs
    
    print_success "Flutter setup complete"
else
    print_error "Flutter is not installed. Please install Flutter first."
    print_warning "Visit: https://flutter.dev/docs/get-started/install"
fi

# Step 4: Create Required Directories
print_status "Creating required directories..."

directories=(
    "bridge/data"
    "bridge/logs"
    "ml/logs"
    "ml/models"
    "predictions"
    "backtest/results"
    "logs"
    "certs"
)

for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    print_success "Created $dir"
done

# Step 5: Setup Configuration Files
print_status "Setting up configuration files..."

# Bridge .env
if [ ! -f "bridge/.env" ]; then
    if [ -f "bridge/.env.template" ]; then
        cp bridge/.env.template bridge/.env
        print_warning "Created bridge/.env from template - PLEASE CONFIGURE IT"
    fi
else
    print_success "bridge/.env already exists"
fi

# ML .env
if [ ! -f "ml/.env" ]; then
    if [ -f "ml/.env.template" ]; then
        cp ml/.env.template ml/.env
        print_warning "Created ml/.env from template - PLEASE CONFIGURE IT"
    fi
else
    print_success "ml/.env already exists"
fi

# Android keystore
if [ ! -f "android/key.properties" ]; then
    if [ -f "android/key.properties.template" ]; then
        cp android/key.properties.template android/key.properties
        print_warning "Created android/key.properties from template - PLEASE CONFIGURE IT"
    fi
else
    print_success "android/key.properties already exists"
fi

# Step 6: Generate Security Keys
print_status "Generating security keys..."

# Generate JWT secret if not configured
if grep -q "CHANGE_THIS" bridge/.env 2>/dev/null; then
    print_status "Generating secure JWT secret..."
    JWT_SECRET=$(openssl rand -base64 32)
    # Update .env file based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/CHANGE_THIS_TO_A_SECURE_RANDOM_STRING_MIN_32_CHARACTERS_LONG/$JWT_SECRET/" bridge/.env
    else
        sed -i "s/CHANGE_THIS_TO_A_SECURE_RANDOM_STRING_MIN_32_CHARACTERS_LONG/$JWT_SECRET/" bridge/.env
    fi
    print_success "JWT secret generated and saved"
fi

# Step 7: Download ML Models (if needed)
print_status "Checking ML models..."

# Create placeholder model
if [ ! -f "ml/models/quantum_model_v2.pkl" ]; then
    print_status "Creating placeholder ML models..."
    python -c "
import pickle
import os
os.makedirs('ml/models', exist_ok=True)
# Create placeholder model
model = {'type': 'placeholder', 'version': '2.0'}
with open('ml/models/quantum_model_v2.pkl', 'wb') as f:
    pickle.dump(model, f)
print('Placeholder model created')
"
fi

# Step 8: Setup Git Hooks (optional)
print_status "Setting up git hooks..."

# Pre-commit hook for code quality
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run linters before commit

# Python linting
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    flake8 ml/ --max-line-length=100 --exclude=venv,__pycache__
fi

# Flutter analyze
if command -v flutter &> /dev/null; then
    flutter analyze
fi
EOF

chmod +x .git/hooks/pre-commit
print_success "Git hooks configured"

# Step 9: System-specific Setup
print_status "Performing system-specific setup..."

# macOS specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_status "macOS detected"
    # Install certificates for Python on macOS
    if [ -f "/Applications/Python*/Install Certificates.command" ]; then
        bash "/Applications/Python*/Install Certificates.command"
    fi
fi

# Linux specific
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_status "Linux detected"
    # Ensure proper permissions
    chmod +x scripts/*.sh
    chmod +x start_system.sh
fi

# Windows specific (Git Bash)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    print_status "Windows detected"
    print_warning "Make sure to run scripts with proper permissions"
fi

# Step 10: Create Quick Start Script
print_status "Creating quick start script..."

cat > quick_start.sh << 'EOF'
#!/bin/bash
# Quick start script for QuantumTrader-Pro

echo "Starting QuantumTrader-Pro..."

# Start bridge server
echo "Starting bridge server..."
cd bridge && npm start &
BRIDGE_PID=$!

# Start ML predictor
echo "Starting ML predictor..."
cd ../ml && python predictor_daemon.py &
ML_PID=$!

# Wait for services to start
sleep 5

# Check if services are running
if ps -p $BRIDGE_PID > /dev/null && ps -p $ML_PID > /dev/null; then
    echo "✓ All services started successfully"
    echo "Bridge PID: $BRIDGE_PID"
    echo "ML PID: $ML_PID"
    echo ""
    echo "To stop: kill $BRIDGE_PID $ML_PID"
    echo "Bridge: http://localhost:8080"
else
    echo "✗ Failed to start services"
fi
EOF

chmod +x quick_start.sh
print_success "Quick start script created"

# Final validation
print_status "Running environment validation..."
python scripts/validate_environment.py

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           Environment Setup Complete!                  ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "1. Configure environment files:"
echo "   - bridge/.env (MT4/MT5 credentials)"
echo "   - ml/.env (ML settings)"
echo "   - android/key.properties (for APK signing)"
echo ""
echo "2. For MT4/MT5 demo credentials:"
echo "   Visit your broker's website to create a demo account"
echo ""
echo "3. To start the system:"
echo "   ./quick_start.sh"
echo ""
echo "4. To run on mobile:"
echo "   flutter run"
echo ""
print_warning "Remember to update the API endpoint in lib/services/mt4_service.dart"