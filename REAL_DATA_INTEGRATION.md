# Real Market Data Integration - Issue #20 Resolution

## Problem Summary

As reported in [Issue #20](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues/20), the system was using synthetic data instead of real market data from the EA, and positions were not being opened.

## Root Causes

### 1. **No Real Data Flow**
- EA was sending market data to `/api/market` endpoint
- Bridge server had **no handler** for this endpoint
- Market data was being sent into the void

### 2. **ML Predictor Used Synthetic Data**
- Quantum predictor generated its own fake data
- No integration with real market prices from EA

### 3. **EA Signal Parsing Bug**
- **Critical bug in `QuantumTraderPro.mq4:236, 249`:**
  ```mql4
  double confidence = 0;  // ← HARDCODED TO ZERO!
  if(confidence > 70) {   // ← NEVER TRUE!
      ExecuteBuyOrder(...);
  }
  ```
- Confidence was never parsed from JSON response
- Since trades only execute when `confidence > 70`, **no positions were ever opened**

### 4. **No Real-Time Signal Generation**
- Bridge loaded static predictions from CSV/JSON files
- No live predictions based on real market data

## Solution Implemented

### 1. **Bridge Server Enhancements** (`bridge/mt4_bridge.py`)

Added three new POST endpoint handlers:

#### `/api/market` - Receive Market Data from EA
```python
@app.route('/api/market', methods=['POST'])
def receive_market_data():
    """Receive real-time market data from EA"""
    # Store market data in memory
    # Save to bridge/data/{SYMBOL}_market.json for ML predictor
    # Keep last 500 candles per symbol
```

#### `/api/account` - Receive Account Data from EA
```python
@app.route('/api/account', methods=['POST'])
def receive_account_data():
    """Receive account data from EA"""
    # Store account info (balance, equity, margin, leverage)
    # Save to bridge/data/account.json
```

#### `/api/positions` - Receive Open Positions from EA
```python
@app.route('/api/positions', methods=['POST'])
def receive_positions():
    """Receive open positions from EA"""
    # Store current open trades
    # Save to predictions/trades.json
```

### 2. **ML Predictor Daemon** (`ml/predictor_daemon.py`)

Created new daemon service that:

1. **Monitors bridge/data/ directory** for real market data files
2. **Loads real market data** (bid, ask, spread, timestamp)
3. **Generates predictions** using QuantumMarketPredictor
4. **Writes signals** to `predictions/signal_output.json`
5. **Runs continuously** with configurable poll interval

**Key Features:**
- Uses real market data instead of synthetic
- Calculates confidence scores based on quantum analysis
- Generates BUY/SELL/HOLD signals
- Includes chaos theory analysis
- Outputs structured JSON for EA consumption

**Usage:**
```bash
python3 ml/predictor_daemon.py \
    --symbols EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD \
    --interval 10
```

### 3. **EA Signal Parsing Fix** (`mql4/QuantumTraderPro.mq4`)

#### Added JSON Parsing Functions:
```mql4
double ExtractJSONDouble(string json, string field)
string ExtractJSONString(string json, string field)
```

#### Fixed ProcessSignalsJSON():
- **Now properly parses confidence from JSON response**
- Extracts prediction bounds (upper_bound, lower_bound)
- Uses bounds for SL/TP calculation
- Checks for existing positions before opening new ones
- Only executes trades when `confidence >= 70%`

**Before (BROKEN):**
```mql4
int confidence = 0;  // Always 0!
if(confidence > 70) {
    ExecuteBuyOrder(...);  // Never executes
}
```

**After (FIXED):**
```mql4
double confidence = ExtractJSONDouble(signal, "confidence");
Print("Signal parsed: Confidence=", confidence, "%");
if(confidence >= 70) {
    Print("✅ BUY signal confirmed!");
    ExecuteBuyOrder(...);  // Now executes when confidence is high
}
```

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      MT4/MT5 Terminal                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         QuantumTraderPro.mq4 EA                       │  │
│  │                                                        │  │
│  │  • Reads market data (bid, ask, spread)               │  │
│  │  • Sends to bridge: POST /api/market                  │  │
│  │  • Fetches signals: GET /api/signals                  │  │
│  │  • Parses confidence from JSON                        │  │
│  │  • Opens positions when confidence >= 70%             │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↓ HTTP
                              ↓ POST /api/market
                              ↓ GET /api/signals
┌─────────────────────────────────────────────────────────────┐
│               Bridge Server (mt4_bridge.py)                  │
│               Running on http://localhost:8080              │
│                                                              │
│  • Receives market data from EA                             │
│  • Stores in bridge/data/{SYMBOL}_market.json               │
│  • Serves signals from predictions/signal_output.json       │
│  • 500 candles history per symbol                           │
└─────────────────────────────────────────────────────────────┘
                              ↑                ↓
                              │                │
                    Reads     │                │  Writes
              market data     │                │  signals
                              │                │
┌─────────────────────────────────────────────────────────────┐
│          ML Predictor Daemon (predictor_daemon.py)          │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Every 10 seconds:                                   │   │
│  │  1. Load real market data from bridge/data/         │   │
│  │  2. Run quantum analysis (wave function, chaos)     │   │
│  │  3. Calculate confidence scores                      │   │
│  │  4. Generate BUY/SELL/HOLD signals                   │   │
│  │  5. Save to predictions/signal_output.json           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Uses: QuantumMarketPredictor + ChaosTheoryAnalyzer         │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Step 1: EA Sends Market Data
```json
POST /api/market
{
  "symbol": "EURUSD",
  "bid": 1.08456,
  "ask": 1.08458,
  "spread": 2,
  "timestamp": 1731844800
}
```

### Step 2: Bridge Stores Data
Saves to `bridge/data/EURUSD_market.json`:
```json
[
  {
    "symbol": "EURUSD",
    "bid": 1.08456,
    "ask": 1.08458,
    "spread": 2,
    "timestamp": 1731844800
  },
  ...
]
```

### Step 3: ML Predictor Analyzes
Reads market data, runs quantum analysis, generates signal:
```json
{
  "symbol": "EURUSD",
  "type": "BUY",
  "action": "BUY",
  "confidence": 85.5,
  "ml_prediction": {
    "next_price": 1.08512,
    "upper_bound": 1.08580,
    "lower_bound": 1.08390,
    "entry_probability": 0.855,
    "confidence_score": 82.3
  }
}
```

### Step 4: EA Fetches and Executes
```mql4
GET /api/signals
// Parse JSON
// confidence = 85.5% >= 70%
// ✅ Execute BUY order
ExecuteBuyOrder(EURUSD, lots, SL=1.08390, TP=1.08580)
```

## Setup Instructions

### 1. Install Dependencies
```bash
cd QuantumTrader-Pro
pip install -r ml/requirements.txt
```

### 2. Start System (Automated)
```bash
./start_system.sh
```

This starts:
- Bridge server on http://localhost:8080
- ML predictor daemon monitoring 5 symbols

### 3. Start System (Manual)

#### Terminal 1: Bridge Server
```bash
cd bridge
python3 mt4_bridge.py
```

#### Terminal 2: ML Predictor
```bash
python3 ml/predictor_daemon.py \
    --symbols EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD \
    --interval 10
```

### 4. Configure EA in MT4/MT5

1. Copy `mql4/QuantumTraderPro.mq4` to your MT4 Experts folder
2. Compile in MetaEditor
3. Attach to any chart
4. Set parameters:
   - **BridgeURL**: `http://YOUR_SERVER_IP:8080`
   - **PollingIntervalSeconds**: `5`
   - **RiskPercent**: `2.0`
   - Enable URL trading in MT4: Tools → Options → Expert Advisors → "Allow WebRequest for listed URL"
   - Add: `http://YOUR_SERVER_IP:8080`

### 5. Verify Data Flow

Check logs:
```bash
# Bridge log
tail -f ml/logs/bridge.log

# Predictor log
tail -f ml/logs/daemon.log

# Predictor detailed log
tail -f ml/logs/predictor.log
```

Expected output:
```
[Bridge] Received market data: EURUSD (500 datapoints)
[Predictor] Generating predictions for EURUSD
[Predictor] EURUSD: BUY signal (confidence: 85.5%)
[EA] Signal parsed: Type=BUY, Confidence=85.5%
[EA] ✅ BUY signal confirmed! Confidence: 85.5%
[EA] BUY order opened: Ticket=123456
```

## Testing

### Test Real Data Flow:
```bash
# 1. Start system
./start_system.sh

# 2. Check bridge receives data
curl http://localhost:8080/api/health

# 3. Manually send test market data
curl -X POST http://localhost:8080/api/market \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "bid": 1.08456,
    "ask": 1.08458,
    "spread": 2,
    "timestamp": '$(date +%s)'
  }'

# 4. Check data was saved
cat bridge/data/EURUSD_market.json

# 5. Wait 10 seconds for predictor cycle

# 6. Check signals were generated
cat predictions/signal_output.json
```

## Broker Compatibility

The system now works with **any broker** that supports MT4/MT5:
- ✅ Tickmill
- ✅ EC Markets
- ✅ Pepperstone
- ✅ IC Markets
- ✅ Any MT4/MT5 broker

**No longer requires LHFX** - you can use your preferred broker.

## Configuration Options

### ML Predictor Daemon:
```bash
python3 ml/predictor_daemon.py \
    --symbols EURUSD,GBPUSD,USDJPY  # Symbols to monitor \
    --interval 10                    # Poll interval (seconds) \
    --bridge-data bridge/data        # Bridge data directory \
    --predictions predictions        # Output directory
```

### EA Parameters:
- **BridgeURL**: Bridge server address
- **PollingIntervalSeconds**: How often to fetch signals (5-30s)
- **RiskPercent**: Risk per trade (1-5%)
- **MaxDailyLoss**: Stop trading if loss exceeds % (3-10%)
- **MagicNumber**: Unique EA identifier

## Troubleshooting

### No Positions Opening?
1. **Check EA logs** in MT4 Experts tab:
   - Is bridge connection successful?
   - Are signals being received?
   - What is the confidence level?

2. **Check signal confidence**:
   ```bash
   cat predictions/signal_output.json | grep confidence
   ```
   - Confidence must be >= 70% to open positions

3. **Check bridge logs**:
   ```bash
   tail -f ml/logs/bridge.log
   ```
   - Is EA sending market data?

### No Signals Generated?
1. **Check predictor has enough data**:
   ```bash
   cat bridge/data/EURUSD_market.json | jq length
   ```
   - Need at least 50 candles

2. **Check predictor logs**:
   ```bash
   tail -f ml/logs/daemon.log
   ```

### Bridge Connection Failed?
1. **Check firewall**: Allow port 8080
2. **Check IP address**: Use correct server IP in EA
3. **Check WebRequest**: Must be enabled in MT4 for bridge URL

## Performance Notes

- **Memory**: Bridge stores max 500 candles per symbol (~250KB each)
- **CPU**: ML predictions run every 10 seconds (configurable)
- **Network**: EA sends data every tick (filtered by polling interval)
- **Disk**: Logs rotate automatically (TODO: implement rotation)

## Credits

**Fix implemented by:** Dezirae Stark (@Dezirae-Stark)
**Issue reported by:** C.L.STARK (@C-L-STARK)
**Commit:** [To be added after commit]

## Next Steps

Future enhancements:
1. ✅ Use real market data (DONE)
2. ✅ Fix position opening (DONE)
3. ✅ Support any broker (DONE)
4. 🔄 Add backtesting with real historical data
5. 🔄 Implement adaptive confidence thresholds
6. 🔄 Add multi-timeframe analysis
7. 🔄 Web dashboard for monitoring

## References

- [Issue #20: Why not use EAs to feed real-time market data?](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues/20)
- [Issue #19: Synthetic data showing unrealistic prices](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues/19)
