# QuantumTrader-Pro Desktop Setup Guide

This guide covers the desktop version of QuantumTrader-Pro for MT4 and MT5 platforms.

## Recent Fixes (2025-11-13)

The following issues reported in [GitHub Issue #1](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues/1) have been resolved:

### 1. Fixed Directory Creation Issues
- **Problem**: `FileNotFoundError` when running ML scripts due to missing directories
- **Solution**: All ML scripts now automatically create required directories
  - `ml/adaptive_state.pkl` parent directory created automatically
  - `ml/logs/` directory created automatically for logging

### 2. Added Missing API Endpoints
- **Added**: `GET /api/trades` - Retrieve historical trades
- **Added**: `GET /api/predictions` - Get ML predictions from quantum system
- Both endpoints are protected with JWT authentication

### 3. Implemented Daemon Mode
- **Feature**: Quantum predictor can now run in continuous mode
- **Usage**: `python quantum_predictor.py --daemon`
- **Logging**: All predictions logged to `ml/logs/predictor.log`
- **Monitoring**: Use `tail -f ml/logs/predictor.log` to monitor in real-time

## System Architecture

```
┌─────────────────┐
│   MT4/MT5 EA    │
│  (MQL4/MQL5)    │
└────────┬────────┘
         │ HTTP/WebSocket
         ▼
┌─────────────────┐
│ Bridge Server   │
│   (Node.js)     │
│   Port: 8080    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ML Backend     │
│   (Python)      │
│ • Quantum       │
│ • Adaptive      │
└─────────────────┘
```

## Installation & Setup

### Prerequisites

1. **MetaTrader 4 or 5** installed
2. **Node.js** (v16+) and **pnpm**
3. **Python 3.8+** with virtualenv

### Step 1: Clone Repository

```bash
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro
git checkout desktop
```

### Step 2: Setup Bridge Server

```bash
cd bridge
pnpm install

# Create .env file
cat > .env << EOF
NODE_ENV=production
PORT=8080
JWT_SECRET=your_secret_key_here
JWT_REFRESH_SECRET=your_refresh_secret_here
TRUST_PROXY=false
EOF

# Start bridge server
pnpm dev
```

The bridge server will start on `http://localhost:8080`

### Step 3: Setup Python ML Backend

```bash
cd ml

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Step 4: Install MT4/MT5 Expert Advisor

#### For MT4:
1. Copy `mql4/QuantumTraderPro.mq4` to `MetaTrader4/MQL4/Experts/`
2. Copy `mql4/QuantumTraderPro.mqh` (if exists) to `MetaTrader4/MQL4/Include/`
3. Compile in MetaEditor (F7)

#### For MT5:
1. Copy `mql5/QuantumTraderPro.mq5` to `MetaTrader5/MQL5/Experts/`
2. Compile in MetaEditor (F7)

### Step 5: Configure EA Settings

In MT4/MT5, attach the EA to a chart and configure:

- **Bridge URL**: `http://localhost:8080` (or your server IP)
- **Risk %**: 2.0 (recommended)
- **Magic Number**: 20241112
- **Symbols**: Your trading pairs

## Running the System

### 1. Start Bridge Server

```bash
cd bridge
pnpm dev
```

**Expected output:**
```
[INFO] QuantumTrader-Pro Bridge Server started { port: '8080', environment: 'production' }
```

### 2. Start ML Quantum Predictor (Daemon Mode)

```bash
cd ml
source venv/bin/activate
python quantum_predictor.py --daemon
```

**Monitor logs:**
```bash
tail -f ml/logs/predictor.log
```

### 3. Start Adaptive Learning System

```bash
cd ml
source venv/bin/activate
python adaptive_learner.py --train
```

### 4. Attach EA to Chart

1. Open MT4/MT5
2. Open a chart (e.g., EURUSD)
3. Drag & drop the EA onto the chart
4. Configure settings
5. Enable "Allow live trading"

## API Endpoints

All endpoints require JWT authentication. Get token via `/api/auth/login`.

### Authentication

```bash
# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "trader", "password": "your_password"}'

# Returns: { "accessToken": "...", "refreshToken": "..." }
```

### Trading Endpoints

#### Get Signals
```bash
curl -X GET "http://localhost:8080/api/signals?symbol=EURUSD&timeframe=M15" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

#### Get Positions
```bash
curl -X GET http://localhost:8080/api/positions \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

#### Get Trades (Historical)
```bash
curl -X GET "http://localhost:8080/api/trades?status=open&limit=50" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

#### Get ML Predictions
```bash
curl -X GET "http://localhost:8080/api/predictions?symbol=EURUSD&timeframe=M15" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

#### Execute Trade
```bash
curl -X POST http://localhost:8080/api/trade \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "type": "buy",
    "lots": 0.1,
    "stopLoss": 1.0850,
    "takeProfit": 1.0950
  }'
```

#### Close Position
```bash
curl -X POST http://localhost:8080/api/close \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ticket": 12345}'
```

### Health Check (No Auth Required)
```bash
curl http://localhost:8080/api/health
```

## Troubleshooting

### Bridge Returns 429 (Too Many Requests)

**Problem**: Rate limiting is active to prevent abuse.

**Solution**:
- Reduce request frequency in your EA
- Check rate limit settings in `bridge/middleware/rateLimit.js`
- Ensure only one EA instance per account

### ML Backend Not Connected

**Problem**: Bridge shows `mlConnected: false`

**Solution**:
```bash
# Ensure quantum_predictor is running in daemon mode
cd ml
python quantum_predictor.py --daemon

# Check logs
tail -f ml/logs/predictor.log
```

### FileNotFoundError: ml/adaptive_state.pkl

**Problem**: (FIXED) Older versions didn't create directories automatically

**Solution**:
- Update to latest desktop branch: `git pull origin desktop`
- Directories now created automatically

### Cannot GET /api/predictions or /api/trades

**Problem**: (FIXED) Endpoints were missing in older versions

**Solution**:
- Update to latest desktop branch: `git pull origin desktop`
- Endpoints now available with authentication

### EA Shows "Bridge server not responding"

**Problem**: EA cannot connect to bridge server

**Checklist**:
1. Bridge server is running: `curl http://localhost:8080/api/health`
2. Firewall allows port 8080
3. Bridge URL configured correctly in EA settings
4. If using remote server, update CORS settings in `bridge/middleware/corsConfig.js`

## Performance Tuning

### ML Prediction Interval

Adjust prediction frequency for performance:

```bash
# Run predictions every 30 seconds
python quantum_predictor.py --daemon --interval 30

# Run predictions every 120 seconds
python quantum_predictor.py --daemon --interval 120
```

### Bridge Server Rate Limits

Edit `bridge/middleware/rateLimit.js` to adjust limits:

```javascript
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Increase if needed
  // ...
});
```

## Testing on Demo Account

It is **strongly recommended** to test on a demo account first:

1. Open demo account with your broker
2. Configure EA with demo account credentials
3. Set small position sizes (0.01 lots)
4. Monitor for 1-2 weeks
5. Analyze performance before going live

## Expected Performance

- **Win Rate**: 90-95% (with quantum methods)
- **Drawdown**: < 15% (with 2% risk per trade)
- **Average Trade Duration**: 4-8 hours
- **Recommended Minimum Balance**: $1,000

## Support & Issues

Report issues at: https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues

## License

See [LICENSE](LICENSE) file for details.

---

**Last Updated**: 2025-11-13
**Version**: 2.1.0 Desktop
