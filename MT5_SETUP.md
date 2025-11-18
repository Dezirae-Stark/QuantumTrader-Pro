# MT5 Setup Guide - QuantumTrader Pro

## Quick Setup for MT5 Users

This guide is specifically for MT5 users who want real-time market data integration with the quantum ML predictor.

---

## Prerequisites

- MetaTrader 5 terminal
- Python 3.8+ (for bridge server)
- Broker account (Tickmill, EC Markets, Pepperstone, IC Markets, etc.)

---

## Step 1: Install Bridge Server

```bash
# Clone repository
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro

# Install Python dependencies
pip install -r ml/requirements.txt

# Option A: HTTP Bridge (Simple - 5-10s latency)
python3 bridge/mt4_bridge.py

# Option B: WebSocket Bridge (Recommended - <100ms latency)
pip install flask-socketio python-socketio
python3 bridge/mt4_bridge_websocket.py
```

**Note:** WebSocket provides real-time push notifications vs HTTP polling delay!

---

## Step 2: Start ML Predictor Daemon

```bash
# In a new terminal
python3 ml/predictor_daemon.py \
    --symbols EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD \
    --interval 10
```

This daemon:
- ✅ Reads **real market data** from bridge (no synthetic data!)
- ✅ Runs quantum analysis every 10 seconds
- ✅ Generates BUY/SELL signals with confidence scores
- ✅ Saves signals to `predictions/signal_output.json`

---

## Step 3: Configure MT5 EA

### 3.1 Copy EA File

```bash
# Copy to MT5 Experts folder
cp mql5/QuantumTraderPro.mq5 ~/MetaTrader5/MQL5/Experts/
```

**Or manually:**
1. Open MetaEditor (F4 in MT5)
2. File → Open Data Folder
3. Navigate to `MQL5/Experts/`
4. Copy `QuantumTraderPro.mq5` here

### 3.2 Compile EA

1. Open `QuantumTraderPro.mq5` in MetaEditor
2. Click "Compile" (F7)
3. Check for errors in "Errors" tab
4. Should see: `0 error(s), 0 warning(s)`

### 3.3 Enable WebRequest

**CRITICAL:** MT5 must allow URL access to bridge server!

1. Tools → Options → Expert Advisors
2. Check **"Allow WebRequest for listed URL:"**
3. Add your bridge URL:
   - `http://localhost:8080`
   - `http://192.168.1.100:8080` (if bridge on another machine)
4. Click OK

### 3.4 Attach EA to Chart

1. In MT5, open a chart (EURUSD, GBPUSD, etc.)
2. Navigator → Expert Advisors → QuantumTraderPro
3. Drag EA onto chart
4. Configure parameters:

**Bridge Server Settings:**
```
BridgeURL: http://192.168.1.100:8080  (or localhost:8080)
```

**Account Settings:**
```
AccountLogin: 123456  (your MT5 account number)
AccountServer: YourBroker-Live  (or YourBroker-Demo)
```

**Risk Management:**
```
RiskPercent: 2.0  (2% risk per trade)
MaxDailyLoss: 5.0  (stop trading if lose 5% in a day)
MagicNumber: 20241112  (unique ID for this EA)
```

**Trading Features:**
```
EnableQuantumSignals: true
EnableMLSignals: true
PollingIntervalSeconds: 5  (how often to check for signals)
```

5. Check "Allow live trading"
6. Check "Allow DLL imports" (if using WebSocket DLL)
7. Click OK

---

## Step 4: Verify Data Flow

### 4.1 Check EA Log

In MT5 Experts tab, you should see:
```
QuantumTrader Pro v2.1.0 (MT5) Initializing...
Account: 123456
Bridge URL: http://192.168.1.100:8080
Bridge connection successful!
QuantumTrader Pro initialized successfully!
```

### 4.2 Check Bridge Log

```bash
tail -f ml/logs/bridge.log
```

Expected output:
```
[Bridge] Received market data: EURUSD (bid=1.08456, ask=1.08458)
[Bridge] Stored 50 datapoints for EURUSD
[Bridge] Stored 100 datapoints for EURUSD
```

### 4.3 Check ML Predictor Log

```bash
tail -f ml/logs/daemon.log
```

Expected output (after 50+ candles):
```
[Predictor] Generating predictions for EURUSD
[Predictor] EURUSD: BUY signal (confidence: 85.5%)
[Predictor] Saved 1 signals to predictions/signal_output.json
```

### 4.4 Check Signal Received by EA

In MT5 Experts tab:
```
Signal parsed: Type=BUY, Action=BUY, Confidence=85.5%
✅ BUY signal confirmed! Confidence: 85.5%
BUY order opened: Ticket #123456
```

---

## Troubleshooting MT5

### Problem: "WebRequest error 4060"

**Solution:**
```
1. Tools → Options → Expert Advisors
2. Add bridge URL to allowed list
3. Restart MT5
```

### Problem: "Bridge connection failed"

**Checks:**
```bash
# Is bridge running?
curl http://localhost:8080/api/health

# Firewall blocking port 8080?
sudo ufw allow 8080/tcp  # Linux
netsh advfirewall firewall add rule name="Bridge" dir=in action=allow protocol=TCP localport=8080  # Windows
```

### Problem: "No signals for current symbol"

**Checks:**
1. Has EA sent enough data? (need 50+ candles)
   ```bash
   cat bridge/data/EURUSD_market.json | jq length
   ```
   Should show >= 50

2. Is predictor running?
   ```bash
   ps aux | grep predictor_daemon
   ```

3. Are signals being generated?
   ```bash
   cat predictions/signal_output.json
   ```

### Problem: "Signal confidence too low"

**Output:**
```
Signal parsed: Type=BUY, Confidence=45.3%
Signal confidence too low: 45.3% (minimum: 70%)
```

**Solution:** This is normal! EA only trades when ML confidence >= 70%. Wait for higher confidence signals.

### Problem: "Desktop branch not working"

**Solution:** Use `main` branch instead:
```bash
git checkout main
git pull origin main
```

The `main` branch has all the latest fixes:
- ✅ Real market data integration
- ✅ Fixed JSON parsing bug
- ✅ WebSocket support
- ✅ MT5 compatibility

---

## MT5 vs MT4 Differences

| Feature | MT4 | MT5 |
|---------|-----|-----|
| **Trade Objects** | OrderSend() | CTrade class |
| **Position Info** | OrderSelect() | CPositionInfo class |
| **Time Functions** | TimeCurrent() | TimeCurrent() ✅ same |
| **Symbol Info** | MarketInfo() | SymbolInfoDouble() |
| **Account Info** | Account*() functions | AccountInfoDouble() |
| **WebRequest** | ✅ Supported | ✅ Supported |

**Both MT4 and MT5 EAs are provided!**
- `mql4/QuantumTraderPro.mq4` - For MT4
- `mql5/QuantumTraderPro.mq5` - For MT5

---

## WebSocket for MT5 (Optional - Advanced)

For real-time trading with <100ms latency:

### Option 1: Pure MQL5 WebSocket (No DLL)

See: https://www.mql5.com/en/articles/8196

```mql5
#include <WebSocket.mqh>

WebSocket ws;

int OnInit() {
    ws.Connect("ws://192.168.1.100:8080");
}
```

### Option 2: Use lws2mql (DLL-Based)

See: https://github.com/krisn/lws2mql

Provides WebSocket client for both MT4 and MT5.

**Benefits:**
- ⚡ <100ms latency (vs 5-10s HTTP polling)
- 📡 Real-time push notifications
- 💾 Lower bandwidth usage
- 🚀 Better scalability

**See:** [WEBSOCKET_GUIDE.md](WEBSOCKET_GUIDE.md) for details

---

## Performance Tips

### 1. Use WebSocket for Production

HTTP polling is great for testing, but WebSocket is 50x faster:

```bash
# Start WebSocket bridge
python3 bridge/mt4_bridge_websocket.py
```

### 2. Optimize Polling Interval

**For HTTP:**
- Development: `PollingIntervalSeconds = 10`
- Production: `PollingIntervalSeconds = 5`

**For WebSocket:**
- Real-time push (no polling needed!)

### 3. Monitor System Resources

```bash
# CPU usage
top -p $(pgrep -f mt4_bridge)

# Memory usage
free -h

# Disk I/O
iostat -x 1
```

---

## MT5 Broker Compatibility

Tested and working with:
- ✅ **Tickmill** - Fast execution
- ✅ **EC Markets** - Low spreads
- ✅ **Pepperstone** - Good liquidity
- ✅ **IC Markets** - Popular choice
- ✅ **Any MT5 broker** - Should work!

**No longer requires LHFX!**

---

## Automated Startup (Optional)

Create `start_mt5_system.sh`:

```bash
#!/bin/bash

echo "Starting QuantumTrader Pro for MT5..."

# Start bridge
python3 bridge/mt4_bridge_websocket.py > bridge.log 2>&1 &
BRIDGE_PID=$!

# Start ML predictor
python3 ml/predictor_daemon.py \
    --symbols EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD \
    --interval 10 > predictor.log 2>&1 &
PREDICTOR_PID=$!

echo "✅ Bridge PID: $BRIDGE_PID"
echo "✅ Predictor PID: $PREDICTOR_PID"
echo "Attach QuantumTraderPro.mq5 EA to MT5 chart"
echo "To stop: kill $BRIDGE_PID $PREDICTOR_PID"

tail -f bridge.log predictor.log
```

Make executable:
```bash
chmod +x start_mt5_system.sh
./start_mt5_system.sh
```

---

## FAQ

**Q: Can I use MT5 with the desktop branch?**

A: The `main` branch is recommended. It has all the latest fixes and MT5 support.

**Q: Why are positions not opening?**

A: Check:
1. Confidence must be >= 70%
2. EA needs 50+ candles before predictions start
3. WebRequest must be enabled in MT5
4. Bridge must be running

**Q: Can I use custom broker instead of LHFX?**

A: Yes! Works with any MT5 broker (Tickmill, EC Markets, Pepperstone, etc.)

**Q: Should I use HTTP or WebSocket?**

A:
- **HTTP** - Simple, good for testing (5-10s latency)
- **WebSocket** - Real-time, optimal for production (<100ms latency)

**Q: Is MT5 better than MT4?**

A: MT5 has:
- Better order execution (CT rade class)
- More timeframes
- Better backtesting
- More indicators

But both work great with QuantumTrader Pro!

---

## Support

**Issues:** https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

**Telegram:** [Contact via issues]

---

**Author:** Dezirae Stark (@Dezirae-Stark)
**MT5 Support:** v2.1.0+
**Last Updated:** 2025-11-17
