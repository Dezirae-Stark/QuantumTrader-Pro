# QuantumTrader Pro - Backtesting Engine

**Broker-agnostic backtesting engine** supporting any MT4/MT5 broker via environment-based configuration.

## 🎯 Overview

Run historical strategy backtests on your preferred MT4/MT5 broker without hardcoding credentials or broker-specific logic.

## ✨ Features

- ✅ **Broker-Agnostic** - Works with any MT4/MT5 broker
- ✅ **Environment-Based Config** - Secure credential management via `.env`
- ✅ **Comprehensive Metrics** - Win Rate, Profit Factor, Max Drawdown, Sharpe Ratio
- ✅ **HTML Reports** - Visual backtest results
- ✅ **Historical Data Analysis** - Tests on real market data
- ✅ **Risk Management** - Configurable risk per trade and daily limits

## 📋 Requirements

```bash
pip install -r requirements.txt
```

**Required packages:**
- MetaTrader5
- pandas
- numpy
- python-dotenv

## ⚙️ Configuration

### Step 1: Create .env File

```bash
# Copy the example configuration
cp .env.example .env
```

### Step 2: Configure Your Broker

Edit `.env` with your MT4/MT5 broker credentials:

```bash
# Your MT4/MT5 broker credentials
MT_LOGIN=YOUR_ACCOUNT_NUMBER
MT_PASSWORD=YOUR_ACCOUNT_PASSWORD
MT_SERVER=YOUR_BROKER_SERVER
MT_PLATFORM=MT5

# Backtest parameters
BACKTEST_SYMBOL=EURUSD
BACKTEST_TIMEFRAME=H1
BACKTEST_BARS=2000

# Risk management
RISK_PER_TRADE=0.02
INITIAL_BALANCE=10000.0
```

**Finding Your Broker Server:**
1. Open MT4/MT5 terminal
2. File → Open an Account
3. Find your broker in the list
4. Note the server name (e.g., "YourBroker-Live" or "YourBroker-Demo")

### Step 3: Run Backtest

```bash
python3 mt_backtest.py
```

## 📊 Example Output

```
==============================================================
QUANTUMTRADER PRO - BROKER-AGNOSTIC BACKTEST
==============================================================
Broker Server: YourBroker-Demo
Account: 123456
Symbol: EURUSD
Timeframe: H1
Bars: 2000
==============================================================

Connecting to MT5 server: YourBroker-Demo...
✓ Connected to Your Broker Company
  Balance: $10,000.00
  Leverage: 1:500

Fetching 2000 bars of EURUSD H1 data...
✓ Fetched 2000 bars
  Date range: 2024-01-01 to 2024-11-12

Calculating technical indicators...
Running backtest simulation...

==============================================================
BACKTEST RESULTS
==============================================================
Total Trades:      127
Winning Trades:    83
Losing Trades:     44
Win Rate:          65.35%
Profit Factor:     2.14
Net Profit:        $4,823.50 (48.24%)
Max Drawdown:      12.67%
Sharpe Ratio:      1.87
==============================================================

✓ Results saved to backtest_results.json
✓ HTML report saved to backtest_results.html
```

## 📁 Generated Files

After running a backtest, you'll get:

1. **`backtest_results.json`** - Raw data in JSON format
2. **`backtest_results.html`** - Interactive visual report

## 🔧 Advanced Configuration

### Multiple Symbols

Test different currency pairs by changing `BACKTEST_SYMBOL` in `.env`:

```bash
BACKTEST_SYMBOL=GBPUSD  # British Pound / US Dollar
BACKTEST_SYMBOL=USDJPY  # US Dollar / Japanese Yen
BACKTEST_SYMBOL=AUDUSD  # Australian Dollar / US Dollar
```

### Different Timeframes

Adjust `BACKTEST_TIMEFRAME` for different analysis periods:

```bash
BACKTEST_TIMEFRAME=M5   # 5 minutes
BACKTEST_TIMEFRAME=M15  # 15 minutes
BACKTEST_TIMEFRAME=H1   # 1 hour
BACKTEST_TIMEFRAME=H4   # 4 hours
BACKTEST_TIMEFRAME=D1   # Daily
```

### Risk Settings

Customize risk management parameters:

```bash
RISK_PER_TRADE=0.01     # 1% risk per trade (conservative)
RISK_PER_TRADE=0.02     # 2% risk per trade (moderate)
RISK_PER_TRADE=0.05     # 5% risk per trade (aggressive)

MAX_DAILY_RISK=0.05     # Maximum 5% daily risk
INITIAL_BALANCE=10000.0 # Starting balance for simulation
```

### Technical Indicators

Adjust indicator parameters in `.env`:

```bash
RSI_PERIOD=14       # RSI calculation period
SMA_FAST=20         # Fast moving average period
SMA_SLOW=50         # Slow moving average period
BB_PERIOD=20        # Bollinger Bands period
BB_DEVIATION=2      # Bollinger Bands standard deviation
```

## 📈 Performance Metrics Explained

### Win Rate
Percentage of profitable trades:
```
Win Rate = (Winning Trades / Total Trades) × 100
```

**Interpretation:**
- **> 60%:** Excellent
- **50-60%:** Good
- **40-50%:** Acceptable
- **< 40%:** Needs improvement

### Profit Factor
Ratio of gross profit to gross loss:
```
Profit Factor = Gross Profit / Gross Loss
```

**Interpretation:**
- **> 2.0:** Excellent
- **1.5-2.0:** Good
- **1.0-1.5:** Acceptable
- **< 1.0:** Losing strategy

### Max Drawdown
Largest peak-to-trough decline in account equity:
```
Drawdown = (Peak Balance - Trough Balance) / Peak Balance × 100
```

**Interpretation:**
- **< 10%:** Excellent risk control
- **10-20%:** Acceptable
- **20-30%:** High risk
- **> 30%:** Very high risk

### Sharpe Ratio
Risk-adjusted return measure:
```
Sharpe Ratio = (Mean Return - Risk-Free Rate) / Standard Deviation
```

**Interpretation:**
- **> 2.0:** Excellent risk-adjusted returns
- **1.0-2.0:** Good
- **0-1.0:** Poor
- **< 0:** Negative risk-adjusted returns

## 🎓 Strategy Logic

The backtest implements a simplified RSI-based strategy:

### Entry Signals
- **BUY:** RSI crosses below 30 (oversold condition)
- **SELL:** RSI crosses above 70 (overbought condition)

### Exit Signals
- **BUY Exit:** RSI rises above 50 or 2% stop loss triggered
- **SELL Exit:** RSI falls below 50 or 2% stop loss triggered

### Risk Management
- **Position Sizing:** Based on account risk percentage
- **Stop Loss:** 2% of entry price
- **Daily Limit:** Configurable maximum daily risk
- **Concurrent Trades:** Configurable maximum open positions

## 🔍 Troubleshooting

### Error: "Required environment variable not set"

**Solution:** Ensure your `.env` file exists and contains all required variables:

```bash
# Check if .env exists
ls -la .env

# If missing, copy from example
cp .env.example .env

# Edit with your broker credentials
nano .env
```

### Error: "MT5 initialize() failed"

**Solution:** Verify MetaTrader 5 is installed and accessible:

```bash
# Install MetaTrader5 Python package
pip install MetaTrader5

# On Linux/Termux, you may need Wine for MT5 terminal
```

### Error: "Login failed for account"

**Solution:** Check your credentials:

1. Verify `MT_LOGIN` is correct (your account number)
2. Verify `MT_PASSWORD` matches your MT4/MT5 password
3. Verify `MT_SERVER` exactly matches your broker's server name
4. Ensure account is active and not locked

### Error: "Failed to fetch data"

**Solution:** Check symbol and broker availability:

1. Verify `BACKTEST_SYMBOL` is available on your broker
2. Check symbol spelling (use MT4/MT5 terminal to confirm)
3. Ensure sufficient historical data exists
4. Try reducing `BACKTEST_BARS` if data is limited

### No trades executed

**Solution:** Adjust strategy parameters or check data:

1. Verify historical data was fetched successfully
2. Check if RSI thresholds are too strict
3. Increase `BACKTEST_BARS` for more opportunities
4. Review indicator calculations

## 🛡️ Security Best Practices

### Never Commit Credentials

The `.env` file is gitignored by default. **Never commit it to version control!**

```bash
# Verify .env is gitignored
git check-ignore .env
# Should output: .env
```

### Use Demo Accounts for Testing

Always test with demo accounts first:

```bash
# Example demo server names
MT_SERVER=YourBroker-Demo
MT_SERVER=YourBroker-Practice
MT_SERVER=YourBroker-Test
```

### Environment Variables

For production environments, use system environment variables instead of `.env`:

```bash
export MT_LOGIN=123456
export MT_PASSWORD="your_password"
export MT_SERVER="YourBroker-Live"
python3 mt_backtest.py
```

## 🔄 Migrating from lhfx_backtest.py

If you were using the old `lhfx_backtest.py` (now deprecated):

### Step 1: Create .env file

```bash
cp .env.example .env
```

### Step 2: Transfer your credentials

Old hardcoded values (example):
```python
BROKER_LOGIN = 123456
BROKER_PASSWORD = "your_password"
BROKER_SERVER = "YourBroker-Demo-Server"
```

New `.env` configuration (broker-agnostic):
```bash
MT_LOGIN=123456
MT_PASSWORD=your_password
MT_SERVER=YourBroker-Demo-Server
MT_PLATFORM=MT5
```

**Replace with YOUR actual broker credentials!**

### Step 3: Use new script

```bash
# Old way (deprecated)
python3 lhfx_backtest.py

# New way (recommended)
python3 mt_backtest.py
```

## 📚 Next Steps

After successful backtesting:

1. **Analyze Results** - Review metrics and identify areas for improvement
2. **Optimize Parameters** - Test different indicator settings and risk levels
3. **Forward Test** - Run on a paper trading account with live data
4. **Deploy Expert Advisor** - Use MQL4/MQL5 EA for automated trading

## ⚠️ Disclaimer

**This software is for educational and research purposes only.**

- Past performance does not guarantee future results
- Backtests may not reflect real trading conditions
- Always test thoroughly before live trading
- Never risk more than you can afford to lose
- Consult a licensed financial advisor before trading

## 📄 License

MIT - QuantumTrader Pro

## 🆘 Support

For issues, questions, or feature requests:

- **GitHub Issues:** https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
- **Documentation:** See `/docs` folder
- **Security Issues:** See `SECURITY.md`

## 🙏 Acknowledgments

This backtesting engine is broker-agnostic and works with any MT4/MT5 broker. No specific broker is recommended or endorsed.
