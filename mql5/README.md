# MetaTrader 5 Expert Advisors & Indicators

This directory contains MetaTrader 5 (MQL5) versions of all QuantumTrader Pro Expert Advisors and Indicators.

## 📂 Files

### Expert Advisors

#### `QuantumTraderPro.mq5`
Main automated trading Expert Advisor with quantum algorithms.

**Features:**
- Quantum market state analysis
- Automatic position management
- Cantilever trailing stops
- ML signal integration
- Risk management (configurable lot sizing)
- Bridge server integration
- Telegram notifications

**Input Parameters:**
- `BridgeURL` - Bridge server endpoint
- `AccountLogin` - LHFX demo account number
- `RiskPercent` - Risk percentage per trade (0.1-10%)
- `MaxDailyLoss` - Maximum daily loss limit (%)
- `MagicNumber` - Unique EA identifier
- `EnableQuantumSignals` - Toggle quantum predictions
- `EnableMLSignals` - Toggle ML predictions
- `EnableCantileverHedge` - Toggle cantilever trailing stop

#### `QuickHedge.mq5`
Counter-hedge recovery system that automatically opens opposite positions when stop loss is hit.

**Features:**
- Automatic SL hit detection
- Counter-hedge with 1.5x multiplier
- ML-guided leg-out timing
- Combined P&L tracking
- Breakeven recovery strategy

**Input Parameters:**
- `HedgeMultiplier` - Position size multiplier (default: 1.5x)
- `EnableMLLegOut` - Use ML for leg-out timing
- `BreakevenThreshold` - Combined P&L target for leg-out
- `AutoLegOut` - Automatic leg-out when profitable

### Indicators

#### `QuantumTrendIndicator.mq5`
Visualizes quantum market states and trends in separate window.

**Features:**
- Quantum superposition visualization
- Probability-weighted trends
- Bullish/Bearish/Neutral states
- Trend strength indicator
- Audio alerts
- Multi-timeframe analysis

**Input Parameters:**
- `QuantumPeriod` - Quantum calculation period (default: 20)
- `ThresholdBullish` - Bullish threshold (default: 0.6)
- `ThresholdBearish` - Bearish threshold (default: -0.6)
- `EnableAlerts` - Enable audio alerts

#### `MLSignalOverlay.mq5`
Displays ML predictions as arrows and prediction bands on price chart.

**Features:**
- Buy/Sell signal arrows
- 3-8 candle ahead predictions
- Confidence score visualization
- Prediction bands (high/low ranges)
- Real-time updates from ML engine

**Input Parameters:**
- `PredictionHorizon` - Prediction candles ahead (3-8)
- `MinConfidence` - Minimum confidence threshold (0.0-1.0)
- `ShowPredictionBands` - Display prediction bands
- `UpdateIntervalSeconds` - Bridge polling interval

---

## 🚀 Installation

### Step 1: Copy Files to MT5

**Windows MT5:**
```bash
# Expert Advisors
copy *.mq5 "C:\Program Files\MetaTrader 5\MQL5\Experts\"

# Indicators
copy QuantumTrendIndicator.mq5 "C:\Program Files\MetaTrader 5\MQL5\Indicators\"
copy MLSignalOverlay.mq5 "C:\Program Files\MetaTrader 5\MQL5\Indicators\"
```

**Linux/Wine MT5:**
```bash
# Adjust path to your Wine prefix
cp *.mq5 ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/
cp *Indicator*.mq5 ~/.wine/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Indicators/
```

**macOS MT5:**
```bash
# Adjust path to your MT5 installation
cp *.mq5 ~/Library/Application\ Support/MetaTrader\ 5/MQL5/Experts/
cp *Indicator*.mq5 ~/Library/Application\ Support/MetaTrader\ 5/MQL5/Indicators/
```

### Step 2: Compile in MetaEditor

1. Open MetaEditor (F4 in MT5)
2. Navigate to `MQL5/Experts` folder
3. Right-click each `.mq5` file → Compile
4. Verify no errors in Toolbox window
5. Compiled files will have `.ex5` extension

### Step 3: Configure Expert Advisor

1. Drag `QuantumTraderPro.ex5` onto a chart
2. Configure parameters in Inputs tab:
   - Set `BridgeURL` to your bridge server (e.g., `http://192.168.1.100:8080`)
   - Set `AccountLogin` to your demo account
   - Adjust `RiskPercent` (recommended: 1.0-2.0%)
   - Set `MagicNumber` to unique value
3. Enable "Allow DLL imports" and "Allow WebRequest for listed URL"
4. Click OK

### Step 4: Add Allowed URLs

**Critical for Bridge Communication:**

1. Tools → Options → Expert Advisors tab
2. Check "Allow WebRequest for listed URL"
3. Add your bridge server URLs:
   ```
   http://localhost:8080
   http://192.168.1.100:8080
   https://yourdomain.com
   ```
4. Click OK and restart MT5

### Step 5: Enable Auto-Trading

- Click "Algo Trading" button in MT5 toolbar (or press Ctrl+E)
- Verify green "smiley face" icon appears on EA name in chart

---

## 🔧 Differences from MT4

MT5 versions include improvements over MT4:

### API Differences

| Feature | MT4 (MQL4) | MT5 (MQL5) |
|---------|-----------|-----------|
| Trade Execution | `OrderSend()` | `CTrade` class |
| Position Management | Order-based | Position-based |
| History Access | `OrderHistory()` | `HistorySelect()` + deals |
| Timeframes | 9 timeframes | 21 timeframes |
| Indicators | Buffer-based | OOP-based |

### Enhanced Features in MT5

✅ **Better Position Management**
- Position-based accounting (not order-based)
- Netting and hedging modes
- Improved order filling types

✅ **More Timeframes**
- M2, M3, M4, M6, M10, M12, M20, H2, H3, H4, H6, H8, H12

✅ **Improved Backtesting**
- Strategy Tester with visual mode
- Multi-currency testing
- Real tick data

✅ **Economic Calendar**
- Built-in economic calendar access
- Programmatic event filtering

---

## ⚙️ Configuration

### Bridge Server Requirements

Both MT4 and MT5 EAs require a running bridge server.

**Start bridge server:**
```bash
cd bridge
npm start
# or with PM2
pm2 start websocket_bridge.js --name quantum-bridge
```

**Verify bridge is running:**
```bash
curl http://localhost:8080/api/health
# Expected: {"status":"ok","timestamp":"..."}
```

### Demo Account Setup

**LHFX Demo Account:**
- Login: 194302
- Server: LHFXDemo-Server
- Password: (Set in EA parameters - encrypted)

### Risk Management

**Recommended Settings:**
- `RiskPercent`: 1.0-2.0% per trade
- `MaxDailyLoss`: 3.0-5.0% maximum daily loss
- `LotSize`: Calculated automatically based on risk
- `MagicNumber`: Unique per EA instance

---

## 📊 Usage

### Starting a Trading Session

1. **Start bridge server** on desktop
2. **Start ML prediction engine** (Python)
3. **Open MT5** and attach EA to chart
4. **Enable AutoTrading** (Algo Trading button)
5. **Monitor** via MT5 Terminal or mobile app

### Monitoring

**Via MT5 Terminal (Ctrl+T):**
- **Experts** tab: EA logs and messages
- **Trade** tab: Open positions
- **History** tab: Closed trades
- **Journal** tab: System events

**Via Bridge API:**
```bash
# Get open positions
curl http://localhost:8080/api/trades

# Get trading signals
curl http://localhost:8080/api/signals

# Get ML predictions
curl http://localhost:8080/api/predictions
```

### Emergency Stop

**Method 1: Disable AutoTrading**
- Click "Algo Trading" button to disable

**Method 2: Remove EA**
- Right-click EA name on chart
- Expert Advisors → Remove

**Method 3: Close All via API**
```bash
curl -X POST http://localhost:8080/api/trades/close-all \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 🐛 Troubleshooting

### EA Not Trading

**Check:**
1. AutoTrading is enabled (green icon)
2. Bridge server is running and accessible
3. Allowed URLs configured in Options
4. Account has sufficient margin
5. No connection errors in Experts log

**Logs:**
```
MQL5/Logs/YYYYMMDD.log
```

### WebRequest Errors

**Error 4060: URL not allowed**
```
Solution: Add bridge URL to allowed URLs in Tools → Options → Expert Advisors
```

**Error 4014: Function not allowed**
```
Solution: Check "Allow WebRequest for listed URL" in Options
```

### Indicator Not Displaying

**Check:**
1. Indicator compiled without errors
2. Bridge server responding
3. Prediction data available
4. Chart refresh (F5)

---

## 📝 Version History

- **v2.1.0** - MT5 compatibility, improved bridge integration
- **v2.0.0** - Initial quantum trading system
- **v1.0.0** - Basic ML trading signals

---

## 🔗 Related Files

- MT4 versions: `../mql4/`
- Bridge server: `../bridge/`
- ML engine: `../ml/`
- Documentation: `../docs/`

---

## 📄 License

MIT License - See [LICENSE](../LICENSE) for details.

---

## 👩‍💻 Support

For questions or issues with MT5 components:
- GitHub Issues: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
- Email: clockwork.halo@tutanota.de

---

**⚠️ Disclaimer:** Trading involves significant risk. Always test on demo accounts before live trading. Past performance does not guarantee future results.
