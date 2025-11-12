# QuantumTrader-Pro Backtesting Guide

**Version:** 1.0
**Last Updated:** 2025-01-12
**Maintainer:** @Dezirae-Stark

---

## Table of Contents

1. [Overview](#overview)
2. [Credential-Safe Backtesting](#credential-safe-backtesting)
3. [Historical Data Management](#historical-data-management)
4. [Test Environment Setup](#test-environment-setup)
5. [Backtesting Workflow](#backtesting-workflow)
6. [Best Practices](#best-practices)
7. [Common Pitfalls](#common-pitfalls)
8. [Performance Metrics](#performance-metrics)

---

## Overview

Backtesting is the process of testing a trading strategy against historical market data to evaluate its performance before risking real capital. This guide covers secure, credential-safe backtesting procedures for QuantumTrader-Pro.

### Why Backtest?

- **Validate Strategy**: Confirm ML models perform as expected
- **Risk Assessment**: Understand potential drawdowns and volatility
- **Parameter Optimization**: Fine-tune strategy parameters
- **Confidence Building**: Gain confidence before live trading

### Security First

**CRITICAL**: Never use real trading credentials for backtesting. Always use:
- Demo accounts with test credentials
- Isolated test environments
- Separate databases for historical data
- No connection to production systems

---

## Credential-Safe Backtesting

### Using Demo Accounts

QuantumTrader-Pro supports LHFX demo accounts for backtesting:

```bash
# Demo account credentials (EXAMPLE ONLY)
LHFX_DEMO_ACCOUNT=194302
LHFX_DEMO_PASSWORD=demo_password
LHFX_DEMO_SERVER=LHFXDemo-Server
```

#### Setting Up Demo Account

1. **Create separate `.env.test` file:**
```bash
cp bridge/.env.example bridge/.env.test
```

2. **Configure test credentials:**
```bash
# bridge/.env.test
NODE_ENV=test
PORT=8081  # Different port from production

# Demo account (NEVER use real credentials)
LHFX_SERVER=LHFXDemo-Server
LHFX_ACCOUNT=194302
LHFX_PASSWORD=your_demo_password

# Test database (isolated from production)
DB_NAME=quantumtrader_test

# Disable production features
ENABLE_LIVE_TRADING=false
ENABLE_REAL_ORDERS=false
```

3. **Use separate configuration:**
```dart
// lib/config/environment.dart
class Environment {
  static bool get isTest => const String.fromEnvironment('ENV') == 'test';
  static bool get isProduction => const String.fromEnvironment('ENV') == 'production';

  static String get apiEndpoint {
    if (isTest) return 'http://localhost:8081';
    return 'http://localhost:8080';
  }
}
```

### Isolation Best Practices

**DO:**
- ✅ Use dedicated demo accounts for testing
- ✅ Run tests on different ports (8081 vs 8080)
- ✅ Store test data in separate databases
- ✅ Use environment variables to toggle test mode
- ✅ Clear test data between runs

**DON'T:**
- ❌ Never use production credentials
- ❌ Never connect to production broker APIs
- ❌ Never test with real money
- ❌ Never share credentials in code or version control

---

## Historical Data Management

### Data Sources

#### 1. Broker Historical Data

Most brokers (including LHFX) provide historical price data via MT4/MT5:

```mql4
// MT4 Expert Advisor: Export historical data
int start()
{
   string symbol = "EURUSD";
   int period = PERIOD_M15;
   int bars = 10000;

   FileWrite(handle, "timestamp,open,high,low,close,volume");

   for(int i = bars-1; i >= 0; i--)
   {
      datetime time = iTime(symbol, period, i);
      double open = iOpen(symbol, period, i);
      double high = iHigh(symbol, period, i);
      double low = iLow(symbol, period, i);
      double close = iClose(symbol, period, i);
      double volume = iVolume(symbol, period, i);

      FileWrite(handle, TimeToStr(time), open, high, low, close, volume);
   }
}
```

#### 2. Third-Party Data Providers

Free and paid historical data sources:

**Free:**
- Yahoo Finance (yfinance Python library)
- Alpha Vantage (limited API calls)
- OANDA fxTrade Practice API

**Paid:**
- Quandl/NASDAQ Data Link
- Interactive Brokers
- Dukascopy

#### 3. Data Format

Store historical data in standardized CSV format:

```csv
timestamp,open,high,low,close,volume
2025-01-01 00:00:00,1.08451,1.08495,1.08420,1.08470,1250
2025-01-01 00:15:00,1.08470,1.08510,1.08455,1.08490,1180
```

### Data Storage

#### Directory Structure

```
backtest_data/
├── raw/                    # Raw downloaded data
│   ├── EURUSD_M15.csv
│   ├── GBPUSD_M15.csv
│   └── USDJPY_M15.csv
├── processed/              # Cleaned and normalized
│   ├── EURUSD_M15_clean.csv
│   └── features/          # ML features extracted
└── metadata.json          # Data provenance and quality metrics
```

#### Python Data Downloader

```python
# scripts/download_historical_data.py
import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta

def download_forex_data(symbol, period='1y', interval='15m'):
    """Download historical forex data"""
    # Convert forex symbol (EURUSD -> EURUSD=X for Yahoo)
    ticker = f"{symbol}=X"

    # Download data
    data = yf.download(ticker, period=period, interval=interval)

    # Save to CSV
    filename = f"backtest_data/raw/{symbol}_{interval}.csv"
    data.to_csv(filename)

    print(f"Downloaded {len(data)} bars for {symbol}")
    return data

if __name__ == "__main__":
    symbols = ['EURUSD', 'GBPUSD', 'USDJPY']
    for symbol in symbols:
        download_forex_data(symbol)
```

### Data Quality Checks

Always validate historical data before backtesting:

```python
def validate_data(df):
    """Validate historical data quality"""
    issues = []

    # Check for missing values
    if df.isnull().any().any():
        issues.append("Missing values detected")

    # Check for duplicate timestamps
    if df.index.duplicated().any():
        issues.append("Duplicate timestamps found")

    # Check for unrealistic prices
    if (df['high'] < df['low']).any():
        issues.append("High < Low anomaly detected")

    # Check for gaps in data
    time_diff = df.index.to_series().diff()
    expected_interval = pd.Timedelta(minutes=15)
    gaps = time_diff[time_diff > expected_interval * 1.5]
    if len(gaps) > 0:
        issues.append(f"{len(gaps)} gaps in data")

    return issues

# Usage
df = pd.read_csv('backtest_data/raw/EURUSD_M15.csv', index_col='timestamp', parse_dates=True)
issues = validate_data(df)

if issues:
    print("Data quality issues:", issues)
else:
    print("Data quality: PASS")
```

---

## Test Environment Setup

### 1. Isolated Development Environment

Create a completely isolated test environment:

```bash
# Create test directory
mkdir -p ~/quantumtrader-test
cd ~/quantumtrader-test

# Clone repository to test location
git clone https://github.com/YOUR_USERNAME/QuantumTrader-Pro.git .

# Create test configuration
cp bridge/.env.example bridge/.env.test

# Use separate database
export DB_NAME=quantumtrader_test
```

### 2. Docker Test Environment (Recommended)

Use Docker for complete isolation:

```dockerfile
# Dockerfile.test
FROM node:20-alpine

WORKDIR /app

# Copy bridge server
COPY bridge/ ./bridge/
WORKDIR /app/bridge

# Install dependencies
RUN npm ci --production

# Test configuration
ENV NODE_ENV=test
ENV PORT=8081
ENV ENABLE_LIVE_TRADING=false

EXPOSE 8081

CMD ["node", "websocket_bridge.js"]
```

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  bridge-test:
    build:
      context: .
      dockerfile: Dockerfile.test
    ports:
      - "8081:8081"
    environment:
      - NODE_ENV=test
      - LHFX_SERVER=LHFXDemo-Server
      - LHFX_ACCOUNT=194302
    networks:
      - test-network

  db-test:
    image: postgres:15
    environment:
      - POSTGRES_DB=quantumtrader_test
      - POSTGRES_USER=test_user
      - POSTGRES_PASSWORD=test_password
    networks:
      - test-network

networks:
  test-network:
    driver: bridge
```

### 3. Python Backtesting Environment

```bash
# Create virtual environment
python3 -m venv venv-backtest
source venv-backtest/bin/activate

# Install dependencies
pip install -r requirements-test.txt
```

```python
# requirements-test.txt
pandas==2.1.0
numpy==1.24.3
scikit-learn==1.3.0
matplotlib==3.7.2
yfinance==0.2.28
backtrader==1.9.78.123  # Popular backtesting framework
pytest==7.4.0
```

---

## Backtesting Workflow

### Step 1: Data Preparation

```python
import pandas as pd
import numpy as np

# Load historical data
df = pd.read_csv('backtest_data/raw/EURUSD_M15.csv',
                 index_col='timestamp',
                 parse_dates=True)

# Calculate technical indicators
df['SMA_20'] = df['close'].rolling(20).mean()
df['SMA_50'] = df['close'].rolling(50).mean()
df['RSI'] = calculate_rsi(df['close'], period=14)

# Feature engineering for ML
df['returns'] = df['close'].pct_change()
df['volatility'] = df['returns'].rolling(20).std()

# Drop NaN values
df = df.dropna()

print(f"Prepared {len(df)} bars for backtesting")
```

### Step 2: Define Strategy

```python
class QuantumTradingStrategy:
    def __init__(self, model_path='models/trained_model.pkl'):
        self.model = load_model(model_path)
        self.position = None
        self.entry_price = 0

    def generate_signal(self, data):
        """Generate trading signal from ML model"""
        features = self.extract_features(data)
        prediction = self.model.predict([features])[0]
        confidence = self.model.predict_proba([features]).max()

        if prediction == 1 and confidence > 0.7:
            return 'BUY'
        elif prediction == -1 and confidence > 0.7:
            return 'SELL'
        return 'HOLD'

    def extract_features(self, data):
        """Extract ML features from current data"""
        return [
            data['SMA_20'].iloc[-1],
            data['SMA_50'].iloc[-1],
            data['RSI'].iloc[-1],
            data['volatility'].iloc[-1]
        ]
```

### Step 3: Run Backtest

```python
def backtest(strategy, data, initial_capital=10000, position_size=0.1):
    """Execute backtest"""
    capital = initial_capital
    positions = []
    equity_curve = []

    for i in range(100, len(data)):  # Start after warmup period
        current_data = data.iloc[:i]
        signal = strategy.generate_signal(current_data)
        current_price = data.iloc[i]['close']

        # Process signal
        if signal == 'BUY' and strategy.position is None:
            # Open long position
            strategy.position = 'LONG'
            strategy.entry_price = current_price
            position_size_lots = capital * position_size / current_price

        elif signal == 'SELL' and strategy.position == 'LONG':
            # Close long position
            profit = (current_price - strategy.entry_price) * position_size_lots
            capital += profit
            strategy.position = None

            positions.append({
                'entry': strategy.entry_price,
                'exit': current_price,
                'profit': profit,
                'timestamp': data.index[i]
            })

        equity_curve.append(capital)

    return {
        'final_capital': capital,
        'return': (capital - initial_capital) / initial_capital * 100,
        'trades': positions,
        'equity_curve': equity_curve
    }

# Run backtest
strategy = QuantumTradingStrategy()
results = backtest(strategy, df)

print(f"Final Capital: ${results['final_capital']:.2f}")
print(f"Return: {results['return']:.2f}%")
print(f"Total Trades: {len(results['trades'])}")
```

### Step 4: Analyze Results

```python
import matplotlib.pyplot as plt

def analyze_results(results):
    """Analyze backtest results"""
    trades = pd.DataFrame(results['trades'])

    # Calculate metrics
    win_rate = (trades['profit'] > 0).sum() / len(trades) * 100
    avg_win = trades[trades['profit'] > 0]['profit'].mean()
    avg_loss = trades[trades['profit'] < 0]['profit'].mean()
    profit_factor = abs(avg_win / avg_loss) if avg_loss != 0 else 0

    max_drawdown = calculate_max_drawdown(results['equity_curve'])
    sharpe_ratio = calculate_sharpe_ratio(results['equity_curve'])

    # Print metrics
    print(f"Win Rate: {win_rate:.2f}%")
    print(f"Profit Factor: {profit_factor:.2f}")
    print(f"Max Drawdown: {max_drawdown:.2f}%")
    print(f"Sharpe Ratio: {sharpe_ratio:.2f}")

    # Plot equity curve
    plt.figure(figsize=(12, 6))
    plt.plot(results['equity_curve'])
    plt.title('Equity Curve')
    plt.xlabel('Time')
    plt.ylabel('Capital ($)')
    plt.grid(True)
    plt.savefig('backtest_results/equity_curve.png')

    return {
        'win_rate': win_rate,
        'profit_factor': profit_factor,
        'max_drawdown': max_drawdown,
        'sharpe_ratio': sharpe_ratio
    }
```

---

## Best Practices

### 1. Data Integrity

- ✅ Always validate data before backtesting
- ✅ Use clean, gap-free historical data
- ✅ Account for timezone differences
- ✅ Include transaction costs in simulations

### 2. Realistic Assumptions

- ✅ Include spread costs (typical: 2-3 pips for major pairs)
- ✅ Add slippage (typical: 1-2 pips)
- ✅ Account for overnight swap fees
- ✅ Use realistic position sizing

```python
def calculate_realistic_profit(entry, exit, lots, spread_pips=2, slippage_pips=1):
    """Calculate profit with realistic costs"""
    pip_value = 10  # For standard lot
    gross_profit = (exit - entry) * lots * pip_value

    # Subtract costs
    spread_cost = spread_pips * lots * pip_value
    slippage_cost = slippage_pips * lots * pip_value

    net_profit = gross_profit - spread_cost - slippage_cost
    return net_profit
```

### 3. Avoid Overfitting

- ✅ Use train/validation/test split (60/20/20)
- ✅ Test on out-of-sample data
- ✅ Avoid excessive parameter optimization
- ✅ Use walk-forward analysis

```python
# Train/validation/test split
train_size = int(len(df) * 0.6)
val_size = int(len(df) * 0.2)

train_data = df[:train_size]
val_data = df[train_size:train_size+val_size]
test_data = df[train_size+val_size:]

# Train on train set
model = train_model(train_data)

# Validate on validation set
val_results = backtest(model, val_data)

# Final test on unseen data
test_results = backtest(model, test_data)
```

### 4. Document Everything

- ✅ Record backtest parameters
- ✅ Save results and metrics
- ✅ Document assumptions and limitations
- ✅ Version control your strategies

```python
# Save backtest metadata
metadata = {
    'strategy': 'QuantumTradingStrategy v1.0',
    'data_source': 'Yahoo Finance',
    'symbol': 'EURUSD',
    'timeframe': 'M15',
    'period': '2023-01-01 to 2024-12-31',
    'initial_capital': 10000,
    'parameters': {
        'confidence_threshold': 0.7,
        'position_size': 0.1
    },
    'results': results,
    'timestamp': datetime.now().isoformat()
}

with open('backtest_results/metadata.json', 'w') as f:
    json.dump(metadata, f, indent=2)
```

---

## Common Pitfalls

### 1. Look-Ahead Bias

**Problem:** Using future information not available at trade time.

**Example:**
```python
# ❌ WRONG: Uses future data
df['signal'] = (df['close'].shift(-1) > df['close']).astype(int)

# ✅ CORRECT: Uses only past data
df['signal'] = (df['close'] > df['close'].shift(1)).astype(int)
```

### 2. Survivorship Bias

**Problem:** Only testing on currently tradable pairs, ignoring delisted/failed pairs.

**Solution:**
- Include historical pairs that are no longer traded
- Be aware of broker changes over time

### 3. Data Snooping

**Problem:** Repeatedly testing until finding "good" results.

**Solution:**
- Define strategy before seeing data
- Use separate test set only once
- Document all tests performed

### 4. Ignoring Market Conditions

**Problem:** Backtesting only in trending or ranging markets.

**Solution:**
```python
# Test in different market conditions
bull_market = df['2020-01':'2021-12']  # Strong uptrend
bear_market = df['2022-01':'2022-12']  # Downtrend
ranging_market = df['2023-01':'2023-12']  # Sideways

results_bull = backtest(strategy, bull_market)
results_bear = backtest(strategy, bear_market)
results_ranging = backtest(strategy, ranging_market)
```

---

## Performance Metrics

### Key Metrics to Track

#### 1. Return Metrics

```python
def calculate_returns(initial, final):
    """Calculate various return metrics"""
    return {
        'absolute_return': final - initial,
        'percentage_return': (final - initial) / initial * 100,
        'annualized_return': ((final / initial) ** (365 / days)) - 1
    }
```

#### 2. Risk Metrics

```python
def calculate_risk_metrics(equity_curve):
    """Calculate risk metrics"""
    returns = pd.Series(equity_curve).pct_change().dropna()

    return {
        'volatility': returns.std() * np.sqrt(252),  # Annualized
        'max_drawdown': calculate_max_drawdown(equity_curve),
        'sharpe_ratio': returns.mean() / returns.std() * np.sqrt(252),
        'sortino_ratio': calculate_sortino_ratio(returns)
    }

def calculate_max_drawdown(equity_curve):
    """Calculate maximum drawdown"""
    peak = equity_curve[0]
    max_dd = 0

    for value in equity_curve:
        if value > peak:
            peak = value
        drawdown = (peak - value) / peak * 100
        max_dd = max(max_dd, drawdown)

    return max_dd
```

#### 3. Trade Metrics

```python
def calculate_trade_metrics(trades):
    """Calculate trade-level metrics"""
    profits = [t['profit'] for t in trades]
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]

    return {
        'total_trades': len(trades),
        'winning_trades': len(wins),
        'losing_trades': len(losses),
        'win_rate': len(wins) / len(trades) * 100,
        'avg_win': np.mean(wins) if wins else 0,
        'avg_loss': np.mean(losses) if losses else 0,
        'profit_factor': abs(sum(wins) / sum(losses)) if losses else float('inf'),
        'largest_win': max(wins) if wins else 0,
        'largest_loss': min(losses) if losses else 0,
        'avg_trade_duration': calculate_avg_duration(trades)
    }
```

### Reporting Template

```python
def generate_backtest_report(results, metrics):
    """Generate comprehensive backtest report"""
    report = f"""
    BACKTESTING REPORT
    ==================

    Strategy: {results['strategy_name']}
    Period: {results['start_date']} to {results['end_date']}

    CAPITAL
    -------
    Initial Capital: ${results['initial_capital']:,.2f}
    Final Capital: ${results['final_capital']:,.2f}
    Net Profit: ${results['net_profit']:,.2f}
    Return: {results['return']:.2f}%

    RISK METRICS
    ------------
    Max Drawdown: {metrics['max_drawdown']:.2f}%
    Sharpe Ratio: {metrics['sharpe_ratio']:.2f}
    Volatility: {metrics['volatility']:.2f}%

    TRADE STATISTICS
    ----------------
    Total Trades: {metrics['total_trades']}
    Win Rate: {metrics['win_rate']:.2f}%
    Profit Factor: {metrics['profit_factor']:.2f}
    Avg Win: ${metrics['avg_win']:.2f}
    Avg Loss: ${metrics['avg_loss']:.2f}

    CONCLUSION
    ----------
    [Add manual analysis and recommendations]
    """

    return report
```

---

## Support

For questions about backtesting:
- Open an issue with the `backtesting` label
- Review existing backtest results in `/backtest_results/`
- Consult strategy documentation in `/docs/strategies/`

**Remember:** Backtest results do not guarantee future performance. Always start with paper trading before live trading.

---

**Document Version:** 1.0
**Last Updated:** 2025-01-12
**Next Review:** 2025-04-12
