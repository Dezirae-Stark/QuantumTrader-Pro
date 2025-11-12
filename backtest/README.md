# QuantumTrader Pro - LHFX Backtest Engine

Python-based backtesting engine that connects to LHFX MT5 practice account to run historical strategy tests.

## Features

- **MetaTrader5 Integration** - Direct connection to LHFX demo server
- **Performance Metrics** - Win Rate, Profit Factor, Max Drawdown, Sharpe Ratio
- **HTML Report Generation** - Visual backtest results
- **Historical Data Analysis** - Tests on real market data
- **Risk Management** - Configurable risk per trade and daily limits

## Requirements

```bash
pip install MetaTrader5 pandas numpy
```

## Open Demo/Practice Account

**Login:** [Provided by your broker]
**Password:** [Provided by your broker]
**Server:** [Broker]Demo-Server

## Usage

### Run Backtest

```bash
python3 lhfx_backtest.py
```

### Configuration

Edit the script to modify:

```python
# Account credentials
LOGIN = [Provided by broker]
PASSWORD = "[Provided by broker]"
SERVER = "[Broker]Demo-Server"

# Backtest parameters
symbol = "EURUSD"
timeframe = MT5.TIMEFRAME_H1
bars = 2000  # Number of historical bars to analyze
```

### Strategy Configuration

```python
# Risk management
risk_percent = 0.02  # 2% risk per trade
initial_balance = 10000.0

# Technical indicators
rsi_period = 14
sma_fast = 20
sma_slow = 50
```

## Output

### Console Output

```
==========================================================
QUANTUMTRADER PRO - LHFX BACKTEST
==========================================================
Account: 194302
Server: LHFXDemo-Server
Fetching 2000 bars of EURUSD H1 data...
Running backtest simulation...

==========================================================
BACKTEST RESULTS
==========================================================
Total Trades:      127
Winning Trades:    83
Losing Trades:     44
Win Rate:          65.35%
Profit Factor:     2.14
Net Profit:        $4,823.50 (48.24%)
Max Drawdown:      12.67%
Sharpe Ratio:      1.87
==========================================================
```

### Generated Files

1. **backtest_results.json** - Raw data in JSON format
2. **backtest_report.html** - Visual HTML report

## Performance Metrics Explained

### Win Rate
Percentage of profitable trades:
```
Win Rate = (Winning Trades / Total Trades) × 100
```

### Profit Factor
Ratio of gross profit to gross loss:
```
Profit Factor = Gross Profit / Gross Loss
```
- **> 2.0:** Excellent
- **1.5-2.0:** Good
- **1.0-1.5:** Acceptable
- **< 1.0:** Losing strategy

### Max Drawdown
Largest peak-to-trough decline in account equity:
```
Drawdown = (Peak Balance - Trough Balance) / Peak Balance × 100
```
- **< 10%:** Excellent
- **10-20%:** Acceptable
- **> 20%:** High risk

### Sharpe Ratio
Risk-adjusted return measure:
```
Sharpe Ratio = (Mean Return - Risk-Free Rate) / Standard Deviation
```
- **> 2.0:** Excellent
- **1.0-2.0:** Good
- **< 1.0:** Poor

## Strategy Logic

The backtest implements a simplified RSI-based strategy:

### Entry Signals
- **BUY:** RSI crosses below 30 (oversold)
- **SELL:** RSI crosses above 70 (overbought)

### Risk Management
- **Risk per Trade:** 2% of account balance
- **Risk:Reward Ratio:** 1.5:1 to 3:1
- **Maximum Open Trades:** Configurable
- **Daily Loss Limit:** 5% max

### Technical Indicators
- **RSI (14)** - Relative Strength Index
- **SMA (20, 50)** - Simple Moving Averages
- **Bollinger Bands (20, 2)** - Volatility bands

## Running Real Backtest

To run with actual LHFX connection:

1. **Install MetaTrader5**
   ```bash
   # Linux/Termux
   pip install MetaTrader5

   # You may need Wine for MT5 terminal on Linux
   ```

2. **Connect to LHFX**
   ```bash
   python3 lhfx_backtest.py
   ```

3. **View Results**
   - Open `backtest_report.html` in browser
   - Review `backtest_results.json` for raw data

## Customization

### Add Custom Indicators

```python
def calculate_indicators(self, df):
    # Your custom indicator logic
    df['custom_indicator'] = ...
    return df
```

### Modify Trade Logic

```python
def simulate_trade(self, trade_type, bar, balance):
    # Your custom trade logic
    return trade_dict
```

### Change Symbols/Timeframes

```python
# Test multiple symbols
for symbol in ['EURUSD', 'GBPUSD', 'USDJPY']:
    results = backtester.run_backtest(symbol=symbol)
```

## HTML Report

The generated HTML report includes:

- Overall performance summary
- Win rate visualization
- Profit factor chart
- Max drawdown graph
- Sharpe ratio display
- Trade distribution

Access the report after running:
```bash
open backtest_report.html  # Mac/Linux
start backtest_report.html # Windows
```

## Troubleshooting

### MT5 Connection Failed

1. Verify LHFX server is accessible
2. Check credentials are correct
3. Ensure MT5 terminal is running
4. Try restarting MT5

### No Historical Data

1. Check symbol name is correct
2. Verify timeframe is supported
3. Ensure sufficient data is available
4. Try reducing number of bars

### Python Errors

```bash
# Install missing dependencies
pip install --upgrade MetaTrader5 pandas numpy
```

## Next Steps

After backtesting:

1. **Analyze Results** - Review metrics and identify improvements
2. **Optimize Parameters** - Test different indicator settings
3. **Forward Test** - Run on paper trading account
4. **Live Deploy** - Use Expert Advisor on real account

## Disclaimer

**This is for educational purposes only. Past performance does not guarantee future results. Always test thoroughly before live trading.**

## License

MIT - QuantumTrader Pro

## Support

For issues and questions, visit: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
