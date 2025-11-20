# QuantumTrader Pro - Quick Start Guide

**Version:** 2.1.0
**Time to Complete:** 5-10 minutes

Get QuantumTrader Pro up and running quickly with this streamlined guide.

---

## Prerequisites

Before starting, ensure you have:

- ✅ **Python** 3.11 or higher
- ✅ **Flutter** 3.0 or higher (for desktop app)
- ✅ **Git** installed
- ✅ **Broker account** (MT4, MT5, Oanda, or Binance)
- ✅ **10 GB** free disk space

---

## 5-Minute Setup

### Step 1: Clone and Install (2 minutes)

```bash
# Clone repository
git clone https://github.com/Dezirae-Stark/QuantumTrader-Pro.git
cd QuantumTrader-Pro

# Install Python dependencies
pip install -r requirements.txt

# Install Flutter dependencies (if using desktop app)
flutter pub get
```

### Step 2: Configure Environment (2 minutes)

```bash
# Copy environment template
cp .env.example .env

# Edit configuration (use your favorite editor)
nano .env
```

**Minimum required configuration:**

```bash
# .env
ENV=development
DEBUG=true

# Broker Configuration
BROKER_PROVIDER=mt4  # or mt5, oanda, binance
BROKER_API_URL=http://localhost:8080
BROKER_ACCOUNT=your_account_number
BROKER_API_KEY=your_api_key
BROKER_API_SECRET=your_api_secret

# ML Configuration
ML_CONFIDENCE_THRESHOLD=75.0
QUANTUM_CONFIDENCE_THRESHOLD=70.0
```

### Step 3: Start Trading (1 minute)

```bash
# Terminal 1: Start ML prediction engine
python ml/predictor_daemon_v2.py --symbols EURUSD,GBPUSD --interval 10

# Terminal 2 (optional): Start Flutter desktop app
flutter run -d linux  # or windows, macos
```

**That's it!** You're now running QuantumTrader Pro.

---

## What's Next?

### Verify Everything Works

```bash
# Check predictions are being generated
tail -f logs/quantumtrader.log

# Expected output:
# 2025-11-20 12:00:00 - INFO - Prediction: EURUSD BUY confidence=85.2%
# 2025-11-20 12:00:05 - INFO - Prediction: GBPUSD SELL confidence=78.9%
```

### Make Your First Trade

1. **Open the desktop app** (if not already running)
2. **Navigate to Dashboard** - View real-time predictions
3. **Review Signal** - Check confidence and entry price
4. **Place Order** - Click "Execute Trade" or enable auto-trading

### Enable Auto-Trading (Optional)

```bash
# Edit .env
FEATURE_AUTO_TRADING=true
MAX_RISK_PER_TRADE_PCT=1.0  # Start conservative!

# Restart prediction daemon
# Ctrl+C in Terminal 1, then:
python ml/predictor_daemon_v2.py --symbols EURUSD,GBPUSD --interval 10
```

⚠️ **Start with demo/paper trading first!**

---

## Common Configuration

### For MT4/MT5 Users

1. **Install MT4/MT5 terminal**
2. **Copy Expert Advisor** to `MT4/Experts/` directory
3. **Start bridge server**:
   ```bash
   cd bridge
   npm install
   node server.js
   ```
4. **Attach EA** to chart in MT4/MT5

### For Oanda Users

```bash
# .env
BROKER_PROVIDER=oanda
BROKER_API_URL=https://api-fxpractice.oanda.com  # or api-fxtrade for live
BROKER_API_KEY=your_oanda_api_key
BROKER_ACCOUNT=your_account_id
```

### For Binance Users

```bash
# .env
BROKER_PROVIDER=binance
BROKER_API_KEY=your_binance_api_key
BROKER_API_SECRET=your_binance_secret
```

---

## Common Gotchas

### Issue: "No GPG key configured"

**Solution**: GPG signing is optional for getting started
```bash
# Disable temporarily
git config --global commit.gpgsign false

# Or set up GPG (recommended)
./scripts/verify_gpg_setup.sh
```

### Issue: "Broker connection failed"

**Solutions**:
1. Check broker credentials in `.env`
2. Verify broker API URL is correct
3. Ensure broker API is accessible (try curl test)
4. Check firewall/network restrictions

```bash
# Test broker connection
curl -v $BROKER_API_URL/health
```

### Issue: "Module not found" errors

**Solution**: Install missing dependencies
```bash
# Python
pip install -r requirements.txt --upgrade

# Flutter
flutter pub get

# Node.js (for bridge)
cd bridge && npm install
```

### Issue: No predictions being generated

**Checklist**:
- ✅ Is ML engine running? Check Terminal 1
- ✅ Is broker connected? Check logs
- ✅ Are symbols correct? EURUSD not EUR/USD
- ✅ Is market open? No predictions when market closed

---

## Production Checklist

Before going to production:

### Security

- [ ] Generate strong secrets: `openssl rand -hex 32`
- [ ] Set `DEBUG=false`
- [ ] Set `USE_SYNTHETIC_DATA=false`
- [ ] Enable authentication: `REQUIRE_AUTHENTICATION=true`
- [ ] Set up GPG signing: [docs/GPG_SETUP.md](docs/GPG_SETUP.md)
- [ ] Review [docs/SECURITY.md](docs/SECURITY.md)

### Configuration

- [ ] Configure all environment variables
- [ ] Set up notification services (Telegram, Discord, Email)
- [ ] Configure risk management parameters
- [ ] Set appropriate confidence thresholds
- [ ] Enable monitoring and metrics

### Testing

- [ ] Test with demo/paper trading first
- [ ] Run backtests: `python backtest/run_backtest.py`
- [ ] Verify predictions are accurate
- [ ] Test order execution
- [ ] Verify risk management works

### Deployment

- [ ] Set up CI/CD: [CICD_SETUP.md](CICD_SETUP.md)
- [ ] Configure production environment: [docs/ENVIRONMENT_SETUP.md](docs/ENVIRONMENT_SETUP.md)
- [ ] Set up monitoring and alerts
- [ ] Create backup procedures
- [ ] Document deployment process

---

## Configuration Reference

### Essential Environment Variables

| Variable | Required | Example | Description |
|----------|----------|---------|-------------|
| `ENV` | Yes | `development` | Environment mode |
| `BROKER_PROVIDER` | Yes | `mt4` | Broker type |
| `BROKER_API_URL` | Yes | `http://localhost:8080` | Broker API endpoint |
| `BROKER_ACCOUNT` | Yes | `194302` | Trading account |
| `BROKER_API_KEY` | Yes | `your_key` | API authentication |
| `ML_CONFIDENCE_THRESHOLD` | No | `75.0` | Min ML confidence |
| `QUANTUM_CONFIDENCE_THRESHOLD` | No | `70.0` | Min quantum confidence |

### Risk Management Defaults

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MAX_RISK_PER_TRADE_PCT` | 2.0% | Max risk per trade |
| `MAX_DAILY_RISK_PCT` | 5.0% | Max daily drawdown |
| `MAX_OPEN_POSITIONS` | 10 | Max concurrent positions |
| `MAX_SPREAD_PIPS` | 3.0 | Max acceptable spread |
| `MIN_STOP_LOSS_PIPS` | 20.0 | Minimum stop loss |

---

## Next Steps

### Learn More

1. **[README.md](README.md)** - Full project documentation
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture
3. **[QUANTUM_SYSTEM_GUIDE.md](QUANTUM_SYSTEM_GUIDE.md)** - Trading system details
4. **[docs/BACKTESTING.md](docs/BACKTESTING.md)** - Backtesting guide

### Advanced Topics

- **[docs/ENVIRONMENT_SETUP.md](docs/ENVIRONMENT_SETUP.md)** - Advanced configuration
- **[docs/SECRETS_MANAGEMENT.md](docs/SECRETS_MANAGEMENT.md)** - Secrets management
- **[CICD_SETUP.md](CICD_SETUP.md)** - CI/CD setup
- **[PRODUCTION_READINESS.md](PRODUCTION_READINESS.md)** - Production deployment

### Join the Community

- **GitHub**: https://github.com/Dezirae-Stark/QuantumTrader-Pro
- **Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas

---

## Troubleshooting

### Get Help

1. **Check logs**: `tail -f logs/quantumtrader.log`
2. **Run diagnostics**: `python scripts/diagnose.py` (if available)
3. **Search issues**: [GitHub Issues](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues)
4. **Ask community**: [GitHub Discussions](https://github.com/Dezirae-Stark/QuantumTrader-Pro/discussions)

### Debug Mode

Enable verbose logging:

```bash
# .env
DEBUG=true
LOG_LEVEL=DEBUG
DEV_VERBOSE_LOGGING=true
```

Restart services and check logs for detailed output.

---

## Quick Command Reference

```bash
# Start prediction engine
python ml/predictor_daemon_v2.py --symbols EURUSD,GBPUSD --interval 10

# Start Flutter app
flutter run -d linux  # or windows, macos, android

# Start bridge server (MT4/MT5)
cd bridge && node server.js

# Run tests
pytest tests/ -v
flutter test

# Run backtest
python backtest/run_backtest.py --symbols EURUSD --days 90

# Check configuration
python backend/config_validator.py --env development

# Verify GPG setup
./scripts/verify_gpg_setup.sh

# Export GPG key
./scripts/export_gpg_key.sh
```

---

## Success!

You're now ready to trade with QuantumTrader Pro! 🎉

**Remember**:
- ✅ Start with demo/paper trading
- ✅ Test thoroughly before risking real money
- ✅ Set conservative risk parameters initially
- ✅ Monitor performance closely
- ✅ Keep learning and improving

**Happy Trading!**

---

**QuantumTrader Pro** v2.1.0
Built by Dezirae Stark
📧 clockwork.halo@tutanota.de
🔗 [GitHub](https://github.com/Dezirae-Stark/QuantumTrader-Pro)

---

**Last Updated**: 2025-11-20
