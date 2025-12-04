# MT5 Integration Guide

This guide explains how to connect QuantumTrader Pro to your MetaTrader 5 (MT5) broker for real-time data and trading.

## Prerequisites

1. **MetaTrader 5 Terminal** - Download and install from your broker
2. **Python 3.8+** - Required for the bridge server
3. **MT5 Account** - Demo or live account from your broker

## Installation

1. Install Python dependencies:
```bash
cd bridge
pip install -r requirements.txt
```

2. Configure MT5 Terminal:
   - Open MT5 and login to your account
   - Go to Tools → Options → Expert Advisors
   - Enable "Allow automated trading"
   - Enable "Allow DLL imports"

## Running the Bridge

1. Start the MT5 bridge server:
```bash
python mt_unified_bridge.py
```

2. The bridge will run on `http://localhost:8080`

## Connecting from QuantumTrader Pro

1. Open QuantumTrader Pro (mobile or desktop)
2. Go to Settings → Broker Configuration
3. Select "MetaTrader 5" as broker type
4. Enter your MT5 credentials:
   - **Login**: Your MT5 account number
   - **Password**: Your MT5 password
   - **Server**: Your broker's server name (e.g., "ICMarkets-Demo")
   - **API URL**: `http://localhost:8080` (or your bridge server URL)

## Available Endpoints

- `GET /api/health` - Check bridge status
- `POST /api/connect` - Connect to MT5
- `POST /api/disconnect` - Disconnect from MT5
- `GET /api/market_data` - Get real-time quotes
- `GET /api/account` - Get account information
- `GET /api/trades` - Get open positions
- `POST /api/order` - Place new order
- `POST /api/close/{position_id}` - Close position

## Security Notes

1. **Never expose the bridge server to the internet** - Use it locally or through a secure VPN
2. **Use demo accounts for testing** - Test thoroughly before using live accounts
3. **Implement proper authentication** - Add API keys for production use

## Supported Brokers

The MT5 integration works with any broker that supports MetaTrader 5:
- IC Markets
- Pepperstone  
- XM
- FXCM
- Oanda (via MT5)
- And many others...

## Troubleshooting

1. **Connection Failed**
   - Ensure MT5 terminal is running
   - Check firewall settings
   - Verify account credentials
   - Confirm server name is correct

2. **No Data Received**
   - Check if markets are open
   - Verify symbols are available on your account
   - Check bridge server logs

3. **Orders Not Executing**
   - Ensure "Allow automated trading" is enabled
   - Check account permissions
   - Verify sufficient margin

## MT4 Support

For MT4 integration, consider using:
- [MT4 Manager API](http://mtapi.tech/) - Commercial solution
- Custom Expert Advisors with DLL calls
- Third-party bridges like MetaAPI

The current bridge focuses on MT5 due to its superior Python integration.