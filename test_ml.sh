#!/bin/bash
# Local testing script for ML Quantum Predictor

set -e  # Exit on error

echo "🧪 QuantumTrader-Pro ML Testing Script"
echo "========================================"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed"
    exit 1
fi

echo "✅ Python $(python3 --version) found"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate || source venv/Scripts/activate 2>/dev/null

# Install dependencies
echo "📥 Installing ML dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r ml/requirements.txt

# Run syntax checks
echo ""
echo "🔍 Running syntax checks..."
python -m py_compile ml/quantum_predictor.py
echo "✅ quantum_predictor.py syntax OK"

if [ -f "ml/adaptive_learner.py" ]; then
    python -m py_compile ml/adaptive_learner.py
    echo "✅ adaptive_learner.py syntax OK"
fi

# Test realistic base price function
echo ""
echo "🧮 Testing realistic base price function..."
python -c "
import sys
sys.path.insert(0, 'ml')
from quantum_predictor import get_realistic_base_price

symbols = {
    'XAUUSD': 2050.00,
    'EURUSD': 1.0800,
    'GBPUSD': 1.2700,
    'BTCUSD': 42000.00,
}

print('Symbol    | Expected  | Actual    | Status')
print('----------|-----------|-----------|--------')

all_passed = True
for symbol, expected in symbols.items():
    actual = get_realistic_base_price(symbol)
    status = '✅ PASS' if actual == expected else '❌ FAIL'
    if actual != expected:
        all_passed = False
    print(f'{symbol:9} | {expected:9.2f} | {actual:9.2f} | {status}')

if not all_passed:
    sys.exit(1)
"

# Test quantum predictor functionality
echo ""
echo "🔬 Testing quantum predictor functionality..."
python -c "
import sys
sys.path.insert(0, 'ml')
from quantum_predictor import QuantumMarketPredictor, ChaosTheoryAnalyzer
import pandas as pd
import numpy as np

print('  Testing QuantumMarketPredictor initialization...')
quantum = QuantumMarketPredictor()
print('  ✅ QuantumMarketPredictor created')

print('  Testing ChaosTheoryAnalyzer initialization...')
chaos = ChaosTheoryAnalyzer()
print('  ✅ ChaosTheoryAnalyzer created')

# Generate test data (XAUUSD-like)
print('  Generating test data...')
np.random.seed(42)
dates = pd.date_range('2024-01-01', periods=100, freq='1H')
price = pd.Series(2050 + np.cumsum(np.random.randn(100) * 2.0), index=dates)
print(f'  ✅ Generated 100 candles, price range: \${price.min():.2f} - \${price.max():.2f}')

# Test predictions
print('  Testing next candle predictions...')
predictions = quantum.predict_next_candles(price, n_candles=3)
assert len(predictions) == 3, 'Should return 3 predictions'
assert all('predicted_price' in p for p in predictions), 'Missing predicted_price field'
print(f'  ✅ Generated 3 predictions')
print(f'     Next candle: \${predictions[0][\"predicted_price\"]:.4f} (confidence: {predictions[0][\"confidence\"]:.1%})')

# Test superposition states
print('  Testing quantum superposition states...')
states = quantum.quantum_superposition_prediction(price)
assert len(states) == 5, 'Should have 5 states'
print('  ✅ Generated 5 quantum states')

# Test chaos analysis
print('  Testing chaos theory analysis...')
attractor = chaos.detect_strange_attractor(price)
assert 'fractal_dimension' in attractor, 'Missing fractal_dimension'
assert 'lyapunov_exponent' in attractor, 'Missing lyapunov_exponent'
assert 'predictability' in attractor, 'Missing predictability'
print(f'  ✅ Chaos analysis complete')
print(f'     Fractal dimension: {attractor[\"fractal_dimension\"]:.2f}')
print(f'     Predictability: {attractor[\"predictability\"]}')
"

echo ""
echo "🎉 All tests passed!"
echo ""
echo "To run the ML engine with XAUUSD:"
echo "  python ml/quantum_predictor.py --daemon --symbol XAUUSD --timeframe M1 --bridge-url http://localhost:8080"
