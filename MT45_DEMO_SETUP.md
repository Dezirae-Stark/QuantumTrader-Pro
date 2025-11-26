# MT4/MT5 Demo Account Setup Guide

## Overview

This guide will help you set up a demo account with a MetaTrader broker and configure QuantumTrader-Pro to connect to it.

## Popular MT4/MT5 Demo Brokers

### Recommended Brokers for Testing

1. **MetaQuotes Demo Server**
   - Server: MetaQuotes-Demo
   - Built into MT4/MT5
   - Instant demo account creation
   - Good for initial testing

2. **IC Markets**
   - Website: https://www.icmarkets.com
   - Server: ICMarketsSC-Demo02
   - High-quality data feeds
   - MT4 & MT5 support

3. **Pepperstone**
   - Website: https://www.pepperstone.com
   - Server: Pepperstone-Demo01
   - Reliable connectivity
   - Both platforms supported

4. **XM Trading**
   - Website: https://www.xm.com
   - Server: XMGlobal-Demo 3
   - Easy registration
   - Good for beginners

5. **FXCM**
   - Website: https://www.fxcm.com
   - Server: FXCM-Demo01
   - Professional features
   - Good API support

## Step-by-Step Demo Account Setup

### Option 1: Using MetaQuotes Built-in Demo

1. **Download MT4 or MT5**
   - MT4: https://www.metatrader4.com/en/download
   - MT5: https://www.metatrader5.com/en/download

2. **Open the Platform**
   - Launch MetaTrader
   - Go to File → Open Demo Account

3. **Create Demo Account**
   - Select "MetaQuotes-Demo" server
   - Fill in your details:
     - Name: Your Name
     - Email: your.email@example.com
     - Phone: +1234567890
   - Choose account type (Standard)
   - Select deposit (10,000 USD recommended)
   - Set leverage (1:100 recommended)
   - Click "Next"

4. **Save Credentials**
   ```
   Server: MetaQuotes-Demo
   Login: [Your assigned number]
   Password: [Your password]
   Investor: [Read-only password]
   ```

### Option 2: Broker-Specific Demo Account

1. **Visit Broker Website**
   - Go to your chosen broker's website
   - Look for "Demo Account" or "Try Demo"

2. **Register for Demo**
   - Fill registration form
   - Verify email
   - Download platform or get web terminal access

3. **Get Server Details**
   - Check welcome email for:
     - Demo server address
     - Account number
     - Password

## Configuring QuantumTrader-Pro

### 1. Update Bridge Configuration

Edit `bridge/.env`:

```env
# MT4/MT5 Configuration
MT_PLATFORM=MT5                           # or MT4
MT_SERVER=MetaQuotes-Demo:443            # Your demo server
MT_ACCOUNT=12345678                      # Your demo account number
MT_PASSWORD=YourDemoPassword123          # Your demo password
```

### 2. Configure Expert Advisor

1. **Copy EA to MetaTrader**
   ```bash
   # For MT4
   cp mql4/QuantumTraderPro.mq4 "C:/Program Files/MetaTrader 4/MQL4/Experts/"
   
   # For MT5
   cp mql5/QuantumTraderPro.mq5 "C:/Program Files/MetaTrader 5/MQL5/Experts/"
   ```

2. **Compile the EA**
   - Open MetaEditor (F4 in MT4/MT5)
   - Open the QuantumTraderPro EA
   - Compile (F7)
   - Check for no errors

3. **Configure EA Settings**
   - Drag EA to a chart (preferably EURUSD H1)
   - In EA settings:
     ```
     BridgeURL: http://localhost:8080
     AuthToken: your-jwt-token
     MagicNumber: 20240115
     EnableAutoTrading: true
     MaxSpread: 3.0
     ```

4. **Enable Auto Trading**
   - Tools → Options → Expert Advisors
   - ✓ Allow automated trading
   - ✓ Allow WebRequests for listed URL
   - Add URL: http://localhost:8080

### 3. Update Mobile App Configuration

Edit `lib/services/mt4_service.dart`:

```dart
class MT4Service {
  // Update endpoint to your bridge server
  String _apiEndpoint = 'http://192.168.1.100:8080'; // Your machine's IP
  
  // For development
  String _apiEndpoint = Platform.isAndroid 
    ? 'http://10.0.2.2:8080'     // Android emulator
    : 'http://localhost:8080';   // iOS simulator
}
```

## Testing the Connection

### 1. Verify Bridge Connection

```bash
# Start the bridge server
cd bridge
npm start

# In another terminal, test the health endpoint
curl http://localhost:8080/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "bridge": "connected",
  "uptime": 120
}
```

### 2. Test MT4/MT5 Connection

In MetaTrader:
1. Check Expert Advisors tab for connection messages
2. Look for "Bridge connected successfully" in the logs
3. Verify no error messages

### 3. Test Data Flow

1. **Market Data Test**
   ```bash
   # Watch for incoming market data
   tail -f bridge/logs/bridge.log | grep "market_data"
   ```

2. **Signal Generation Test**
   ```bash
   # Check if ML is generating signals
   tail -f predictions/signal_output.json
   ```

3. **Mobile App Test**
   - Open the Flutter app
   - Go to Settings
   - Enter bridge URL
   - Test connection
   - Check Dashboard for live data

## Common Issues and Solutions

### Issue 1: "No connection to trade server"
**Solution:**
- Check internet connection
- Verify server address is correct
- Try different demo server
- Check if demo account expired (usually 30 days)

### Issue 2: "WebRequest failed"
**Solution:**
- Ensure URL is in allowed list
- Check firewall settings
- Verify bridge server is running
- Use http:// not https:// for localhost

### Issue 3: "Invalid account"
**Solution:**
- Demo accounts expire after 30 days
- Create new demo account
- Update credentials in .env
- Restart bridge server

### Issue 4: "No data received"
**Solution:**
- Check if market is open (Forex: Sunday 5PM - Friday 5PM EST)
- Verify EA is attached to active chart
- Check EA is enabled (smiley face)
- Review MT4/MT5 journal for errors

## Security Notes

### For Demo Testing
- Demo accounts are safe for testing
- No real money at risk
- Passwords can be less secure

### For Live Trading (Future)
- Use strong, unique passwords
- Enable 2FA if available
- Use read-only (Investor) password for monitoring
- Never share master password
- Use VPS for 24/7 operation

## Recommended Demo Testing Workflow

1. **Week 1: Basic Testing**
   - Test all connections
   - Verify data flow
   - Check signal generation
   - Test manual trades

2. **Week 2: Strategy Testing**
   - Run paper trading
   - Monitor performance
   - Adjust risk settings
   - Test different pairs

3. **Week 3: Stress Testing**
   - High-frequency data
   - Multiple pairs
   - News events
   - Connection interruptions

4. **Week 4: Optimization**
   - Fine-tune parameters
   - Optimize latency
   - Test fail-safes
   - Prepare for live

## Next Steps

1. **After Successful Demo Setup:**
   - Run system for 24 hours
   - Monitor all logs
   - Check for any errors
   - Validate signal accuracy

2. **Performance Metrics to Track:**
   - Connection uptime
   - Signal generation rate
   - Execution latency
   - Error frequency

3. **Before Going Live:**
   - Complete 30 days demo testing
   - Document all issues
   - Optimize all components
   - Create backup procedures

## Support Resources

- MetaTrader Forum: https://www.mql5.com/en/forum
- MQL4 Documentation: https://docs.mql4.com
- MQL5 Documentation: https://www.mql5.com/en/docs
- QuantumTrader-Pro Issues: [Create GitHub Issue]

Remember: **Always test thoroughly on demo before considering live trading!**