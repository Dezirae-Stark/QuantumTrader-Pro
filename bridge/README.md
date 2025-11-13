# QuantumTrader Pro - WebSocket Bridge Server

**Broker-Agnostic** WebSocket Bridge Server that connects the QuantumTrader Pro mobile app to **any MT4/MT5 trading terminal**.

## 🎯 Overview

The bridge server provides real-time communication between your mobile app and MT4/MT5 platform, supporting **any broker** that offers MT4/MT5 access.

## ✨ Features

- ✅ **Broker-Agnostic** - Works with any MT4/MT5 broker
- ✅ **Environment-Based Config** - Secure credential management via `.env`
- ✅ **REST API Endpoints** - Account management, signals, trade execution
- ✅ **WebSocket Support** - Real-time price updates and live trading
- ✅ **Production-Ready** - Comprehensive error handling, logging, and security
- ✅ **Rate Limiting** - Protection against API abuse
- ✅ **JWT Authentication** - Secure API access

## 📋 Installation

```bash
cd bridge
npm install
```

## 📦 Dependencies

- `express` - Web server framework
- `ws` - WebSocket implementation
- `cors` - Cross-origin resource sharing
- `helmet` - Security headers
- `jsonwebtoken` - JWT authentication
- `express-rate-limit` - API rate limiting

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

# Server configuration
PORT=8080
NODE_ENV=development

# Security
JWT_SECRET=CHANGE_THIS_TO_A_SECURE_RANDOM_STRING
REQUIRE_AUTHENTICATION=true

# CORS allowed origins
ALLOWED_ORIGINS=http://localhost:3000,capacitor://localhost
```

**Finding Your Broker Server:**
1. Open MT4/MT5 terminal
2. File → Open an Account
3. Find your broker in the list
4. Note the server name (e.g., "YourBroker-Live" or "YourBroker-Demo")

**⚠️ SECURITY WARNING:** Never commit `.env` files to version control! They contain sensitive credentials.

## 🚀 Usage

### Start the Server

**Production mode:**
```bash
npm start
```

**Development mode (with nodemon auto-restart):**
```bash
npm run dev
```

**Expected output:**
```
===============================================
QuantumTrader Pro - Bridge Server v2.1.0
===============================================
Environment: development
Port: 8080
Authentication: ENABLED
CORS: ENABLED
Rate Limiting: ENABLED
===============================================
✓ Server running on http://localhost:8080
✓ WebSocket server started
✓ Ready to accept connections
===============================================
```

## 🔌 API Endpoints

### Health Check

Check server status:

```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "2.1.0",
  "uptime": 3600,
  "timestamp": 1699875600000
}
```

### Connect to MT4/MT5

Establish connection with broker:

```http
POST /api/connect
Content-Type: application/json

{
  "login": YOUR_ACCOUNT_NUMBER,
  "password": "YOUR_PASSWORD",
  "server": "YOUR_BROKER_SERVER"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Connected to Your Broker Company",
  "account": YOUR_ACCOUNT_NUMBER,
  "balance": 10000.00,
  "equity": 10050.00,
  "leverage": 500
}
```

### Get Trading Signals

Retrieve ML-generated trading signals:

```http
GET /api/signals?account=YOUR_ACCOUNT_NUMBER
```

**Response:**
```json
{
  "signals": [
    {
      "symbol": "EURUSD",
      "action": "BUY",
      "confidence": 0.85,
      "entry_price": 1.0900,
      "stop_loss": 1.0850,
      "take_profit": 1.0950,
      "timestamp": 1699875600000
    }
  ]
}
```

### Get Open Positions

Retrieve all active trades:

```http
GET /api/positions?account=YOUR_ACCOUNT_NUMBER
```

**Response:**
```json
{
  "positions": [
    {
      "ticket": 123456,
      "symbol": "EURUSD",
      "type": "BUY",
      "volume": 0.01,
      "open_price": 1.0900,
      "current_price": 1.0920,
      "profit": 20.00,
      "stop_loss": 1.0850,
      "take_profit": 1.0950
    }
  ]
}
```

### Execute Trade

Open a new position:

```http
POST /api/trade
Content-Type: application/json

{
  "account": YOUR_ACCOUNT_NUMBER,
  "symbol": "EURUSD",
  "type": "BUY",
  "volume": 0.01,
  "stop_loss": 1.0850,
  "take_profit": 1.0950
}
```

**Response (Success):**
```json
{
  "success": true,
  "ticket": 123456,
  "message": "Trade executed successfully"
}
```

### Close Position

Close an existing trade:

```http
POST /api/close
Content-Type: application/json

{
  "account": YOUR_ACCOUNT_NUMBER,
  "ticket": 123456
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Position closed successfully",
  "close_price": 1.0920,
  "profit": 20.00
}
```

## 🔄 WebSocket Connection

Connect to WebSocket for real-time updates:

### JavaScript Example

```javascript
const ws = new WebSocket('ws://localhost:8080');

ws.onopen = () => {
  console.log('Connected to QuantumTrader Bridge');

  // Subscribe to price updates
  ws.send(JSON.stringify({
    type: 'subscribe',
    symbols: ['EURUSD', 'GBPUSD', 'USDJPY']
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);

  switch(data.type) {
    case 'price':
      console.log(`${data.symbol}: ${data.bid} / ${data.ask}`);
      break;
    case 'signal':
      console.log(`Signal: ${data.action} ${data.symbol} (${data.confidence})`);
      break;
  }
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
};

ws.onclose = () => {
  console.log('Disconnected from bridge');
};
```

### WebSocket Message Types

#### Subscribe to Symbols

```json
{
  "type": "subscribe",
  "symbols": ["EURUSD", "GBPUSD", "USDJPY"]
}
```

#### Price Update

```json
{
  "type": "price",
  "symbol": "EURUSD",
  "bid": 1.0900,
  "ask": 1.0902,
  "timestamp": 1699875600000
}
```

#### Signal Update

```json
{
  "type": "signal",
  "symbol": "EURUSD",
  "action": "BUY",
  "confidence": 0.85,
  "entry_price": 1.0900,
  "stop_loss": 1.0850,
  "take_profit": 1.0950,
  "timestamp": 1699875600000
}
```

#### Trade Execution Notification

```json
{
  "type": "trade_executed",
  "ticket": 123456,
  "symbol": "EURUSD",
  "type": "BUY",
  "volume": 0.01,
  "price": 1.0900
}
```

## 🔗 Integration with MT4/MT5

### 1. Install Expert Advisor

```bash
# Copy EA to MT4/MT5 directory
cp mql4/QuantumTraderPro.mq4 /path/to/MT4/MQL4/Experts/

# Or for MT5:
cp mql4/QuantumTraderPro.mq5 /path/to/MT5/MQL5/Experts/
```

**Compile in MetaEditor:**
1. Open MetaEditor (F4 in MT4/MT5)
2. Open `QuantumTraderPro.mq4` or `QuantumTraderPro.mq5`
3. Compile (F7)
4. Attach to chart

### 2. Configure Bridge URL in MT4/MT5

**Allow WebRequest URLs:**
1. Tools → Options → Expert Advisors
2. Check "Allow WebRequest for listed URLs"
3. Add: `http://localhost:8080`
4. Add: `http://YOUR_SERVER_IP:8080` (if bridge runs on different machine)
5. Click OK and restart MT4/MT5

### 3. Configure Expert Advisor

When attaching the EA to a chart, configure these input parameters:

- **Bridge URL:** `http://localhost:8080` (or your server IP)
- **Account Number:** Your MT4/MT5 account number
- **Server:** Your broker server name (e.g., "YourBroker-Live")
- **Magic Number:** Unique identifier (default: 20251112)
- **Risk Per Trade:** 0.01 - 0.05 (1% - 5%)

### 4. Install Indicators (Optional)

```bash
# Copy indicators to MT4/MT5 directory
cp mql4/QuantumTrendIndicator.mq4 /path/to/MT4/MQL4/Indicators/
cp mql4/MLSignalOverlay.mq4 /path/to/MT4/MQL4/Indicators/
```

Compile and attach to charts for visual signal overlays.

## 📱 Mobile App Integration

The mobile app connects automatically to the bridge server.

**Configure in app settings:**
1. Open QuantumTrader Pro mobile app
2. Navigate to: **Settings → API Endpoint**
3. Enter: `http://YOUR_SERVER_IP:8080`
4. Click "Test Connection"
5. Save settings

**Local Network Example:** `http://192.168.1.100:8080`
**Cloud Server Example:** `https://your-domain.com:8080` (use HTTPS in production)

## 🔐 Security Best Practices

### Production Deployment Checklist

- [ ] **Change JWT Secret** - Generate strong random string (min 32 characters)
- [ ] **Enable HTTPS** - Use SSL/TLS certificates (Let's Encrypt recommended)
- [ ] **Firewall Rules** - Restrict access to trusted IP addresses only
- [ ] **Strong Passwords** - Use complex broker passwords
- [ ] **Rate Limiting** - Configure appropriate limits in `.env`
- [ ] **Environment Variables** - Use system environment variables instead of `.env` file
- [ ] **Audit Logging** - Enable `ENABLE_AUDIT_LOGGING=true`
- [ ] **Regular Updates** - Keep dependencies updated (`npm audit fix`)

### Generate Secure JWT Secret

```bash
# Generate 32-byte random string (base64 encoded)
openssl rand -base64 32
```

Copy the output to `.env` as `JWT_SECRET=...`

### Enable HTTPS (Production)

In `.env`:
```bash
ENABLE_HTTPS=true
SSL_KEY_PATH=/path/to/private-key.pem
SSL_CERT_PATH=/path/to/certificate.pem
```

### Restrict CORS Origins

In `.env`, set allowed origins (comma-separated):
```bash
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

### Use Demo Accounts First

**Always test with demo accounts before going live:**
```bash
MT_SERVER=YourBroker-Demo
MT_LOGIN=DEMO_ACCOUNT_NUMBER
```

## 🔍 Troubleshooting

### Server Won't Start

**Error:** `Port 8080 already in use`

**Solution:**
```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or change port in .env
PORT=8081
```

### Connection to MT4/MT5 Failed

**Error:** `MT5 initialize() failed`

**Solution:**
1. Verify MT4/MT5 terminal is running
2. Check broker credentials in `.env`
3. Confirm server name is correct (check MT4/MT5 account details)
4. Ensure account is active and not locked
5. Try connecting manually in MT4/MT5 first

### WebRequest Not Allowed

**Error:** `WebRequest to 'http://localhost:8080' failed`

**Solution:**
1. Open MT4/MT5: Tools → Options → Expert Advisors
2. Check "Allow WebRequest for listed URLs"
3. Add `http://localhost:8080` to allowed URLs
4. Restart MT4/MT5

### No Price Updates via WebSocket

**Problem:** WebSocket connects but no price data

**Solution:**
1. Verify symbols are subscribed correctly
2. Check if MT4/MT5 terminal is receiving live quotes
3. Ensure markets are open (Forex: Mon-Fri 24h)
4. Check server logs for errors: `npm start`

### Authentication Errors

**Error:** `Invalid or missing JWT token`

**Solution:**
1. Check `REQUIRE_AUTHENTICATION=true` in `.env`
2. Obtain JWT token via `/api/auth/login` endpoint
3. Include token in headers: `Authorization: Bearer <token>`
4. For testing only: set `REQUIRE_AUTHENTICATION=false`

### Rate Limit Exceeded

**Error:** `Too many requests`

**Solution:**
1. Wait 15 minutes for rate limit reset
2. Adjust limits in `.env`:
   ```bash
   RATE_LIMIT_MAX=200  # Increase general API limit
   TRADE_RATE_LIMIT_MAX=50  # Increase trade execution limit
   ```

## 📊 Monitoring & Logging

### View Server Logs

```bash
# Real-time logs
npm start

# Logs with timestamps
npm start | tee bridge-server.log

# View specific log level
LOG_LEVEL=debug npm start
```

### Log Levels

Configure in `.env`:
- `LOG_LEVEL=error` - Errors only
- `LOG_LEVEL=warn` - Warnings and errors
- `LOG_LEVEL=info` - Info, warnings, and errors (default)
- `LOG_LEVEL=debug` - All messages including debug

### Health Monitoring

Check server health:
```bash
curl http://localhost:8080/api/health
```

## 🔄 Broker Compatibility

This bridge server is **100% broker-agnostic** and has been tested with:

- ✅ Any broker offering MT4 platform
- ✅ Any broker offering MT5 platform
- ✅ Demo and live accounts
- ✅ All account types (ECN, Standard, Pro)
- ✅ Multiple brokers simultaneously (run multiple bridge instances)

**No specific broker is recommended or endorsed.**

## 🛠️ Development

### Run with Auto-Restart

```bash
npm run dev
```

Nodemon will automatically restart the server when files change.

### Run Tests

```bash
# Run test suite (if implemented)
npm test

# Run specific test file
npm test -- tests/api.test.js
```

### Environment Variables Reference

See `.env.example` for complete list of configurable options.

## 📚 Next Steps

1. **Configure broker credentials** - Edit `.env` file
2. **Start bridge server** - `npm start`
3. **Install MT4/MT5 EA** - Copy and compile Expert Advisor
4. **Configure mobile app** - Set bridge URL in app settings
5. **Test connection** - Use health check and test trades
6. **Deploy to production** - Enable HTTPS and security features

## ⚠️ Disclaimer

**This software is for educational and research purposes only.**

- Never risk more than you can afford to lose
- Always test with demo accounts first
- No warranty or guarantee of profitability
- Consult a licensed financial advisor before trading

## 📄 License

MIT - QuantumTrader Pro

## 🆘 Support

For issues, questions, or feature requests:

- **GitHub Issues:** https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues
- **Documentation:** See `/docs` folder
- **Security Issues:** See `SECURITY.md`

## 🙏 Acknowledgments

This bridge server is broker-agnostic and works with any MT4/MT5 broker. No specific broker is recommended or endorsed.
