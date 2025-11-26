# QuantumTrader-Pro Desktop Environment Setup

## Overview

This document provides complete setup instructions for the QuantumTrader-Pro desktop components including the bridge server, ML engine, and development environment.

## System Requirements

### Minimum Requirements
- **OS:** Windows 10+, macOS 11+, Ubuntu 20.04+
- **CPU:** 4 cores, 2.5GHz+
- **RAM:** 8GB
- **Storage:** 10GB free space
- **Network:** Stable internet connection

### Recommended Requirements
- **OS:** Latest stable version
- **CPU:** 8+ cores, 3.0GHz+
- **RAM:** 16GB+
- **GPU:** NVIDIA GPU with CUDA support (for ML acceleration)
- **Storage:** 20GB+ free space (SSD recommended)

## Prerequisites Installation

### 1. Python Environment (3.10+)

**Windows:**
```powershell
# Download Python from python.org
# Or use Chocolatey:
choco install python310

# Verify installation
python --version
pip --version
```

**macOS:**
```bash
# Using Homebrew
brew install python@3.10

# Or using pyenv
brew install pyenv
pyenv install 3.10.13
pyenv global 3.10.13
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install python3.10 python3.10-venv python3-pip

# Fedora
sudo dnf install python3.10 python3.10-pip
```

### 2. Node.js Environment (16+)

**All Platforms:**
```bash
# Using Node Version Manager (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
nvm use 20

# Verify
node --version
npm --version
```

### 3. Git

```bash
# Windows (Git Bash)
# Download from git-scm.com

# macOS
brew install git

# Linux
sudo apt install git  # Ubuntu/Debian
sudo dnf install git  # Fedora
```

## QuantumTrader-Pro Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/QuantumTrader-Pro.git
cd QuantumTrader-Pro
```

### 2. Python Virtual Environment

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

### 3. Install Python Dependencies

```bash
# Install ML dependencies
pip install -r ml/requirements.txt

# Install bridge dependencies
pip install -r bridge/requirements.txt

# Install development dependencies
pip install -r requirements-dev.txt
```

### 4. Install Node.js Dependencies

```bash
# Navigate to bridge directory
cd bridge

# Install dependencies
npm install

# Return to root
cd ..
```

### 5. Environment Configuration

**Create Bridge Server Configuration:**
```bash
# Copy template
cp bridge/.env.example bridge/.env

# Edit with your settings
# Use your preferred editor (nano, vim, code, etc.)
nano bridge/.env
```

**Required .env Settings:**
```env
# Server Configuration
PORT=8080
HOST=0.0.0.0

# Security
JWT_SECRET=your-very-secure-random-string-min-32-chars
JWT_EXPIRY=24h

# MT4/MT5 Configuration
MT_PLATFORM=MT5  # or MT4
MT_SERVER=your.broker.server:443
MT_ACCOUNT=your-demo-account-number
MT_PASSWORD=your-demo-password

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# Rate Limiting
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX_REQUESTS=100

# Logging
LOG_LEVEL=info
LOG_FILE=logs/bridge.log

# Optional: Database (for production)
# DATABASE_URL=postgresql://user:password@localhost/quantumtrader
```

**Create ML Configuration:**
```bash
# Create ML config directory
mkdir -p ml/config

# Create config file
cat > ml/config/ml_config.yaml << EOF
# ML Engine Configuration
predictor:
  symbols:
    - EURUSD
    - GBPUSD
    - XAUUSD
  
  update_interval: 10  # seconds
  
  model_params:
    lookback_period: 100
    prediction_horizon: 5
    confidence_threshold: 0.7
    
  paths:
    market_data: bridge/data/
    predictions: predictions/
    models: ml/models/
    logs: ml/logs/

performance:
  use_gpu: true  # Enable if CUDA available
  batch_size: 32
  num_workers: 4
EOF
```

### 6. Directory Structure Setup

```bash
# Create required directories
mkdir -p bridge/data
mkdir -p bridge/logs
mkdir -p ml/models
mkdir -p ml/logs
mkdir -p predictions
mkdir -p backtest/results
```

### 7. MetaTrader Setup

**MT4 Configuration:**
1. Open MT4 terminal
2. Tools → Options → Expert Advisors
3. Enable:
   - Allow automated trading
   - Allow WebRequests
   - Add URL: http://localhost:8080

**MT5 Configuration:**
1. Open MT5 terminal
2. Tools → Options → Expert Advisors
3. Same settings as MT4

**Install Expert Advisor:**
```bash
# Copy EA to MT platform
# MT4
cp mql4/QuantumTraderPro.mq4 "C:/Program Files/MetaTrader 4/MQL4/Experts/"

# MT5
cp mql5/QuantumTraderPro.mq5 "C:/Program Files/MetaTrader 5/MQL5/Experts/"
```

### 8. GPU Setup (Optional)

**NVIDIA CUDA Setup:**
```bash
# Check CUDA availability
python -c "import torch; print(torch.cuda.is_available())"

# If false, install CUDA toolkit
# Visit: https://developer.nvidia.com/cuda-downloads

# Install PyTorch with CUDA
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

## Running the System

### 1. Start All Components

```bash
# Use the provided startup script
chmod +x start_system.sh
./start_system.sh

# Or start manually...
```

### 2. Manual Component Start

**Terminal 1 - Bridge Server:**
```bash
cd bridge
npm start
# Server runs on http://localhost:8080
```

**Terminal 2 - ML Predictor:**
```bash
cd ml
python predictor_daemon.py
# Watches for data and generates predictions
```

**Terminal 3 - System Monitor (Optional):**
```bash
# Monitor logs
tail -f bridge/logs/bridge.log ml/logs/predictor.log
```

### 3. Verify System Health

```bash
# Check bridge server
curl http://localhost:8080/api/health

# Expected response:
# {
#   "status": "healthy",
#   "bridge": "connected",
#   "ml": "active",
#   "uptime": 120
# }
```

## Development Tools Setup

### 1. VS Code Configuration

```bash
# Install recommended extensions
code --install-extension ms-python.python
code --install-extension ms-vscode.cpptools
code --install-extension Dart-Code.flutter
code --install-extension dbaeumer.vscode-eslint
```

**Create workspace settings:**
```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/venv/bin/python",
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black",
  "editor.formatOnSave": true,
  "files.exclude": {
    "**/__pycache__": true,
    "**/*.pyc": true
  }
}
```

### 2. Testing Environment

```bash
# Run Python tests
python -m pytest ml/tests/ -v

# Run Node.js tests
cd bridge
npm test

# Run linting
python -m flake8 ml/
cd bridge && npm run lint
```

## Troubleshooting

### Common Issues

**1. Port Already in Use:**
```bash
# Find process using port 8080
# Windows
netstat -ano | findstr :8080

# macOS/Linux
lsof -i :8080

# Kill process
kill -9 <PID>
```

**2. Python Module Not Found:**
```bash
# Ensure virtual environment is activated
which python  # Should show venv path

# Reinstall dependencies
pip install -r ml/requirements.txt --force-reinstall
```

**3. WebSocket Connection Failed:**
- Check firewall settings
- Verify CORS configuration in .env
- Ensure MT4/MT5 allows WebRequests

**4. GPU Not Detected:**
```bash
# Check CUDA version
nvidia-smi

# Reinstall PyTorch with correct CUDA version
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

## Performance Optimization

### 1. CPU Optimization
```bash
# Set number of threads
export OMP_NUM_THREADS=4
export MKL_NUM_THREADS=4
```

### 2. Memory Optimization
```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=4096"
```

### 3. Disk I/O Optimization
- Use SSD for `bridge/data/` directory
- Enable write caching
- Regular cleanup of old logs

## Security Hardening

### 1. Production Environment Variables
```bash
# Generate secure JWT secret
openssl rand -base64 32

# Set restrictive file permissions
chmod 600 bridge/.env
chmod 700 bridge/data/
```

### 2. SSL/TLS Setup
```bash
# Generate self-signed certificate (development)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Configure in .env
SSL_CERT=cert.pem
SSL_KEY=key.pem
```

### 3. Firewall Configuration
```bash
# Allow only required ports
sudo ufw allow 8080/tcp  # Bridge server
sudo ufw allow 443/tcp   # MT4/MT5
```

## Monitoring Setup

### 1. System Metrics
```bash
# Install monitoring tools
pip install psutil prometheus-client

# Run metrics exporter
python scripts/metrics_exporter.py
```

### 2. Log Aggregation
```bash
# Configure centralized logging
# Edit ml/config/logging.yaml
handlers:
  file:
    filename: logs/quantum_trader.log
    maxBytes: 10485760  # 10MB
    backupCount: 5
```

## Backup & Recovery

### 1. Data Backup
```bash
# Create backup script
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup data
cp -r bridge/data/ "$BACKUP_DIR/"
cp -r ml/models/ "$BACKUP_DIR/"
cp -r predictions/ "$BACKUP_DIR/"

# Compress
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup completed: $BACKUP_DIR.tar.gz"
EOF

chmod +x backup.sh
```

### 2. Recovery Procedure
```bash
# Extract backup
tar -xzf backups/20240101_120000.tar.gz

# Restore data
cp -r backups/20240101_120000/* .
```

## Next Steps

1. Configure MT4/MT5 demo account
2. Run system validation tests
3. Start paper trading
4. Monitor system performance
5. Proceed to Android environment setup