# Advanced Indicator System Documentation

## Overview

The advanced indicator system provides a modular, extensible framework for technical analysis with integrated probability assessment. It combines multiple proven indicators into a unified signal engine that generates trading signals with confidence levels and risk assessments.

## Architecture

### Core Components

1. **Base Classes** (`base.py`)
   - `Indicator`: Abstract base class for all indicators
   - `IndicatorResult`: Standardized result format
   - `SignalStrength`: Enum for signal types (STRONG_BUY, BUY, NEUTRAL, SELL, STRONG_SELL)
   - `CompositeIndicator`: Base for indicators that combine multiple sub-indicators

2. **Bill Williams Chaos Indicators** (`chaos_indicators.py`)
   - **AlligatorIndicator**: Trend-following indicator using 3 SMAs
   - **AwesomeOscillator**: Momentum indicator (5-period SMA - 34-period SMA)
   - **AcceleratorOscillator**: Acceleration/deceleration of momentum
   - **FractalsIndicator**: Market turning points
   - **WilliamsMFI**: Market facilitation index for efficiency
   - **ChaosSignalCombiner**: Combines all chaos indicators

3. **Elliott Wave Detector** (`elliott_wave.py`)
   - Identifies impulse (5-wave) and corrective (3-wave) patterns
   - Uses Fibonacci ratios for wave validation
   - Generates signals based on current wave position
   - Provides wave labeling and progress tracking

4. **Signal Engine** (`signal_engine.py`)
   - Integrates all indicators into a probability layer
   - Adaptive weighting based on market conditions
   - Risk assessment and position sizing recommendations
   - Historical statistics and performance tracking

## Usage

### Basic Example

```python
from indicators.signal_engine import SignalEngine
import pandas as pd

# Create signal engine with custom weights
engine = SignalEngine(custom_weights={
    "Alligator": 1.0,      # Primary trend
    "Elliott Wave": 0.9,    # Pattern recognition
    "Awesome Oscillator": 0.7,
    "Fractals": 0.8
})

# Analyze market data (requires OHLCV DataFrame)
df = pd.DataFrame({
    'open': [...],
    'high': [...],
    'low': [...],
    'close': [...],
    'volume': [...]
})

# Get comprehensive analysis
analysis = engine.analyze(df, 'EURUSD')

print(f"Signal: {analysis.signal}")
print(f"Probability: {analysis.probability}%")
print(f"Risk Level: {analysis.risk_level}")
print(f"Action: {analysis.recommended_action}")
```

### Indicator Management

```python
# Toggle indicators on/off
engine.toggle_indicator("Williams MFI", enabled=False)

# Add custom indicator
from indicators.base import Indicator
class MyCustomIndicator(Indicator):
    # ... implementation
    
engine.add_indicator(MyCustomIndicator(), weight=0.6)

# Remove indicator
engine.remove_indicator("Fractals")
```

## Signal Interpretation

### Signal Strengths
- **STRONG_BUY**: High probability upward movement, enter long position
- **BUY**: Moderate bullish signal, consider smaller position
- **NEUTRAL**: No clear direction, stay out or close positions
- **SELL**: Moderate bearish signal, consider short position
- **STRONG_SELL**: High probability downward movement, enter short

### Confidence Levels
- **> 80%**: Very high confidence, strong signal
- **60-80%**: Good confidence, reliable signal
- **40-60%**: Moderate confidence, use with caution
- **< 40%**: Low confidence, avoid trading

### Risk Levels
- **Low Risk**: Confidence > 70%, strong indicator agreement
- **Medium Risk**: Confidence 50-70%, moderate agreement
- **High Risk**: Confidence < 50%, conflicting signals

## Market Conditions

The signal engine adapts to four market conditions:

1. **Trending**: Strong directional movement
   - Boost trend indicators (Alligator)
   - Reduce oscillators
   
2. **Ranging**: Sideways movement
   - Boost oscillators (AO, AC)
   - Reduce trend indicators
   
3. **Volatile**: High price fluctuations
   - Increase risk multipliers
   - Focus on volume indicators
   
4. **Calm**: Low volatility
   - Tighten risk parameters
   - Standard weightings

## Technical Details

### Indicator Requirements
- Minimum periods: 50-100 depending on indicators
- Data format: OHLCV pandas DataFrame
- Time resolution: Any (designed for hourly+)

### Performance Considerations
- Calculation time: ~100-200ms for full analysis
- Memory usage: Minimal, indicators calculate on-demand
- Caching: Results cached per calculation cycle

### Integration with ML Predictor

The signal engine is integrated with the `TechnicalPredictor` class:

```python
from technical_predictor import TechnicalPredictor

predictor = TechnicalPredictor()

# Get predictions with signal engine analysis
predictions = predictor.predict_next_candles(df, n_candles=5)

# Each prediction includes signal engine data
for pred in predictions:
    print(f"Price: {pred['predicted_price']}")
    print(f"Signal: {pred['signal_engine']['signal']}")
    print(f"Probability: {pred['signal_engine']['probability']}%")
```

## Extending the System

### Creating Custom Indicators

```python
from indicators.base import Indicator, IndicatorResult, SignalStrength
from datetime import datetime

class MyIndicator(Indicator):
    def __init__(self):
        super().__init__("My Indicator")
        
    def get_required_periods(self) -> int:
        return 20
        
    def calculate(self, df, symbol) -> IndicatorResult:
        # Your calculation logic
        value = df['close'].iloc[-1]
        signal = SignalStrength.BUY
        confidence = 0.75
        
        return IndicatorResult(
            timestamp=datetime.now(),
            symbol=symbol,
            indicator_name=self.name,
            signal=signal,
            confidence=confidence,
            value=value,
            components={},
            metadata={}
        )
```

### Best Practices

1. **Data Quality**: Ensure clean OHLCV data
2. **Sufficient History**: Provide at least 100 periods
3. **Risk Management**: Never trade solely on signals
4. **Backtesting**: Test strategies before live trading
5. **Position Sizing**: Use confidence for position sizing
6. **Stop Losses**: Always use appropriate stops

## Testing

Run the test suite:

```bash
# Full test (requires dependencies)
cd ml && python test_signal_engine.py

# Structure test (no dependencies)
cd ml && python test_signal_engine_simple.py
```

## Future Enhancements

1. **Additional Indicators**
   - Ichimoku Cloud
   - Market Profile
   - Order Flow indicators
   
2. **Machine Learning Integration**
   - Feature extraction for ML models
   - Signal validation with ML
   - Adaptive weight optimization
   
3. **Performance Analytics**
   - Signal accuracy tracking
   - P&L attribution
   - Indicator effectiveness scoring