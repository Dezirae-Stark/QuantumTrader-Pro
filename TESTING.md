# Testing Guide for QuantumTrader-Pro

This guide covers all available testing methods for the ML Quantum Predictor and Bridge Server.

## Quick Start

### Method 1: Automated Testing Script (Easiest) ⭐

Run the comprehensive test script:

```bash
./test_ml.sh
```

This will:
- Create/activate a Python virtual environment
- Install all dependencies
- Run syntax checks
- Test all major components
- Display detailed results

### Method 2: GitHub Actions (Automatic)

Tests run automatically on every push to `main`, `desktop`, or `develop` branches.

View results at: https://github.com/Dezirae-Stark/QuantumTrader-Pro/actions

The CI/CD pipeline tests:
- Python syntax validation
- Realistic base price function
- Quantum predictor functionality
- Bridge server startup
- Multiple Python versions (3.10, 3.11, 3.12)

### Method 3: Docker (Isolated Environment)

Build and run in containers:

```bash
# Build and start all services
docker-compose -f docker-compose.test.yml up --build

# View ML engine logs
docker-compose -f docker-compose.test.yml logs -f ml-engine

# Stop services
docker-compose -f docker-compose.test.yml down
```

## Manual Testing

### Setup Python Environment

```bash
# Create virtual environment
python3 -m venv venv

# Activate (Linux/Mac)
source venv/bin/activate

# Activate (Windows)
venv\Scripts\activate

# Install dependencies
pip install -r ml/requirements.txt
```

### Test Individual Components

#### 1. Syntax Check

```bash
python -m py_compile ml/quantum_predictor.py
```

#### 2. Test Realistic Base Prices

```python
from quantum_predictor import get_realistic_base_price

# Should return 2050.00 for XAUUSD
price = get_realistic_base_price('XAUUSD')
print(f"XAUUSD: ${price}")
```

#### 3. Test Quantum Predictor

```python
from quantum_predictor import QuantumMarketPredictor
import pandas as pd
import numpy as np

quantum = QuantumMarketPredictor()

# Generate test data
dates = pd.date_range('2024-01-01', periods=100, freq='1H')
price = pd.Series(2050 + np.cumsum(np.random.randn(100) * 2.0), index=dates)

# Get predictions
predictions = quantum.predict_next_candles(price, n_candles=3)
print(f"Next candle: ${predictions[0]['predicted_price']:.4f}")
```

#### 4. Test with Different Symbols

```bash
# Test XAUUSD (Gold)
python ml/quantum_predictor.py --daemon --symbol XAUUSD --timeframe M1 --interval 60

# Test EURUSD (Forex)
python ml/quantum_predictor.py --daemon --symbol EURUSD --timeframe H1 --interval 60

# Test BTCUSD (Crypto)
python ml/quantum_predictor.py --daemon --symbol BTCUSD --timeframe M5 --interval 60
```

Expected outputs:
- **XAUUSD**: Predictions around $2040-$2060
- **EURUSD**: Predictions around $1.07-$1.09
- **BTCUSD**: Predictions around $41,000-$43,000

## Bridge Server Testing

### Setup Node.js Environment

```bash
cd bridge
npm install
```

### Test Bridge Server

```bash
# Start server
node websocket_bridge.js

# In another terminal, test health endpoint
curl http://localhost:8080/api/health
```

## Expected Test Results

### ✅ Successful Test Output

```
🧪 QuantumTrader-Pro ML Testing Script
========================================
✅ Python 3.11.x found
🔄 Activating virtual environment...
📥 Installing ML dependencies...
🔍 Running syntax checks...
✅ quantum_predictor.py syntax OK

🧮 Testing realistic base price function...
Symbol    | Expected  | Actual    | Status
----------|-----------|-----------|--------
XAUUSD    |   2050.00 |   2050.00 | ✅ PASS
EURUSD    |      1.08 |      1.08 | ✅ PASS
GBPUSD    |      1.27 |      1.27 | ✅ PASS
BTCUSD    |  42000.00 |  42000.00 | ✅ PASS

🔬 Testing quantum predictor functionality...
  ✅ QuantumMarketPredictor created
  ✅ ChaosTheoryAnalyzer created
  ✅ Generated 100 candles
  ✅ Generated 3 predictions
     Next candle: $2048.3421 (confidence: 82.4%)
  ✅ Chaos analysis complete

🎉 All tests passed!
```

## Troubleshooting

### Missing Dependencies

```bash
# Reinstall all dependencies
pip install --upgrade -r ml/requirements.txt
```

### ImportError

Make sure you're in the project root and PYTHONPATH is set:

```bash
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
```

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

## Continuous Integration

The project uses GitHub Actions for CI/CD. The workflow file is located at:
`.github/workflows/ml-tests.yml`

It automatically:
1. Checks out code
2. Sets up Python 3.10, 3.11, and 3.12
3. Installs dependencies
4. Runs all tests
5. Reports results

## Contributing Tests

When adding new features, please:

1. Add tests to `test_ml.sh`
2. Update this documentation
3. Ensure GitHub Actions pass
4. Test locally before pushing

## References

- [Python Testing Best Practices](https://docs.python.org/3/library/unittest.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Testing Guide](https://docs.docker.com/get-started/)
