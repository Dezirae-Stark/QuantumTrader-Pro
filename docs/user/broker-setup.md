# Broker Setup Guide

This guide explains how to select and connect to your MT4/MT5 broker in QuantumTrader Pro.

## 🎯 Overview

QuantumTrader Pro uses a **dynamic broker catalog** that:

- ✅ Updates automatically with new brokers
- ✅ Works offline with embedded fallback list
- ✅ Cryptographically verified for security
- ✅ Requires no credentials to be stored in the app

## 📱 Selecting a Broker

### First-Time Setup

1. **Open QuantumTrader Pro**
2. **Navigate to Broker Selection**
   - From the main screen, tap "Select Broker"
   - Or go to Settings → Broker Connection

3. **Browse Available Brokers**
   - Use the search bar to find your broker
   - Filter by platform (MT4 / MT5)
   - Filter for demo accounts if needed

4. **Select Your Broker**
   - Tap on your broker from the list
   - Review the broker details
   - Confirm your selection

5. **Connect via WebTerminal**
   - Tap "Open WebTerminal"
   - You'll be directed to the MetaQuotes WebTerminal
   - Log in with your broker credentials

### Example: Connecting to LHFX

1. Open broker selection
2. Search for "LHFX"
3. Choose "LHFX" for live trading or "LHFX Demo" for practice
4. Tap "Open WebTerminal"
5. Log in at the MetaQuotes page with your LHFX account credentials

## 🔄 Updating the Broker List

The broker list updates automatically, but you can manually refresh:

### Automatic Updates

- **On Startup**: Checks for updates if catalog is > 1 hour old
- **Weekly Sync**: Background update every 7 days
- **Smart Scheduling**: Only when connected to WiFi and battery is healthy

### Manual Update

1. Go to Settings → Broker Catalog
2. Tap "Update Broker List Now"
3. Wait for the update to complete
4. A notification will confirm success or show the cached list if update fails

## 🔒 Security & Privacy

### What We Store

- ✅ Your selected broker name (encrypted locally)
- ✅ Cached broker list (validated and signed)

### What We DON'T Store

- ❌ Your broker username or password
- ❌ Your account number
- ❌ Any trading credentials

**All authentication happens directly with MetaQuotes' WebTerminal**, not in our app.

### Signature Verification

Every broker list update is:

1. **Fetched over HTTPS** from GitHub Pages
2. **Signature verified** with Ed25519 cryptography
3. **Schema validated** to ensure data integrity
4. **Rejected if invalid** - your app falls back to the cached or embedded list

You'll see a security indicator in Settings showing:
- ✅ "Signed catalog" - Verification passed
- ⚠️ "Using cached catalog" - Couldn't reach update server
- ℹ️ "Using embedded catalog" - First run or cache cleared

## 🌐 Offline Usage

**QuantumTrader Pro works offline!**

- The app includes an **embedded fallback** broker list
- Cached catalogs remain available when offline
- You can still select and connect to brokers without internet

The embedded list includes popular brokers like:
- LHFX (Live & Demo)
- OANDA (Live & Demo)
- ICMarkets (Live & Demo)
- Pepperstone
- XM Global

## 🛠️ Troubleshooting

### Broker Not Appearing?

1. Try updating the broker list manually
2. Check your internet connection
3. Clear the search filter
4. Check if you've filtered to MT4/MT5 only

### Update Failing?

- Check your network connection
- The app will continue using the cached list
- Background sync will retry automatically

### Can't Connect to WebTerminal?

- Ensure your device has internet access
- Verify your broker credentials are correct
- Check that you've selected the correct server (live vs demo)
- Some brokers may have region restrictions

### Selected Broker Disappeared?

If a broker is removed from the catalog:
- Your selection will remain until you choose a different broker
- Consider switching to an alternative broker
- Check the main repository for announcements

## 📞 Need Help?

- **Broker Login Issues**: Contact your broker's support
- **App Issues**: Open an issue at [github.com/Dezirae-Stark/QuantumTrader-Pro](https://github.com/Dezirae-Stark/QuantumTrader-Pro/issues)
- **Catalog Updates**: Check [QuantumTrader-Pro-data](https://github.com/Dezirae-Stark/QuantumTrader-Pro-data) for status

## 🆕 Requesting a New Broker

To add your broker to the catalog:

1. Go to [QuantumTrader-Pro-data](https://github.com/Dezirae-Stark/QuantumTrader-Pro-data)
2. Submit a Pull Request with broker details
3. Include: name, server ID, platform (MT4/MT5), and MetaQuotes WebTerminal URL
4. After review, your broker will be added to the next catalog update

---

**Last Updated**: 2025-11-12
**App Version**: 2.1.0+
