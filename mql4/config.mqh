//+------------------------------------------------------------------+
//|                                                       config.mqh |
//|                          QuantumTrader Pro Configuration Header  |
//|                           Broker-Agnostic Configuration          |
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property strict

//+------------------------------------------------------------------+
//| IMPORTANT: Broker Configuration                                  |
//+------------------------------------------------------------------+
// This EA is broker-agnostic. Configure your broker details via:
// 1. EA Input Parameters (when adding to chart)
// 2. Or modify the defaults below for your preferred broker
//
// DO NOT hardcode specific broker names or credentials
//+------------------------------------------------------------------+

//--- Broker Configuration (Set via EA Input Parameters)
// These are just placeholders - actual values come from EA inputs
// Example: "YourBroker-Live", "YourBroker-Demo"
#define DEFAULT_BROKER_SERVER    "YOUR_BROKER_SERVER"
#define DEFAULT_BRIDGE_URL       "http://localhost:8080"

//--- Trading Parameters
#define MAX_SPREAD_PIPS          3.0      // Maximum allowed spread (pips)
#define MIN_STOP_LOSS_PIPS       20.0     // Minimum stop loss distance (pips)
#define MAX_STOP_LOSS_PIPS       200.0    // Maximum stop loss distance (pips)
#define DEFAULT_SLIPPAGE         3        // Maximum allowed slippage (pips)

//--- Risk Management
#define MAX_RISK_PER_TRADE       2.0      // Maximum 2% risk per trade
#define MAX_DAILY_RISK           5.0      // Maximum 5% daily risk
#define MAX_OPEN_TRADES          5        // Maximum simultaneous trades

//--- Quantum System Parameters
#define QUANTUM_CONFIDENCE_THRESHOLD  70  // Minimum confidence for trade execution (%)
#define ML_CONFIDENCE_THRESHOLD       75  // ML signal threshold (%)

//--- Timing Parameters
#define BRIDGE_POLL_INTERVAL    5         // Seconds between bridge polls
#define CONNECTION_TIMEOUT      10000     // Milliseconds for API calls
#define RETRY_ATTEMPTS          3         // Number of retries for failed requests
#define RECONNECT_DELAY         5000      // Milliseconds delay before reconnect

//--- UI Color Definitions
#define COLOR_BUY       clrGreen      // Color for BUY signals/trades
#define COLOR_SELL      clrRed        // Color for SELL signals/trades
#define COLOR_CLOSE     clrYellow     // Color for CLOSE signals
#define COLOR_INFO      clrWhite      // Color for informational text
#define COLOR_WARNING   clrOrange     // Color for warnings
#define COLOR_ERROR     clrRed        // Color for errors

//--- Logging Levels
#define LOG_LEVEL_NONE      0         // No logging
#define LOG_LEVEL_ERROR     1         // Errors only
#define LOG_LEVEL_WARNING   2         // Warnings and errors
#define LOG_LEVEL_INFO      3         // Info, warnings, and errors
#define LOG_LEVEL_DEBUG     4         // All messages including debug

//--- Default Log Level
#define DEFAULT_LOG_LEVEL   LOG_LEVEL_INFO

//--- Magic Number for Trade Identification
// This should be unique per EA instance
#define DEFAULT_MAGIC_NUMBER    20251112

//--- Version Information
#define EA_VERSION          "2.1.0"
#define EA_BUILD_DATE       __DATE__

//+------------------------------------------------------------------+
//| Configuration Notes                                               |
//+------------------------------------------------------------------+
// 1. Server Configuration:
//    - Set via EA Input Parameters when adding to chart
//    - Or connect to bridge which handles MT4/MT5 connection
//
// 2. Risk Management:
//    - Adjust MAX_RISK_PER_TRADE based on your risk tolerance
//    - Never exceed MAX_DAILY_RISK to protect capital
//    - MAX_OPEN_TRADES limits concurrent positions
//
// 3. Bridge Connection:
//    - DEFAULT_BRIDGE_URL should match your bridge server
//    - Can be overridden via EA Input Parameters
//    - Ensure bridge server is running before EA starts
//
// 4. Quantum/ML Thresholds:
//    - Higher QUANTUM_CONFIDENCE_THRESHOLD = more conservative
//    - Lower threshold = more aggressive trading
//    - Adjust based on backtest results
//
// 5. Spread Filtering:
//    - Trades rejected if spread > MAX_SPREAD_PIPS
//    - Protects against trading during high volatility/low liquidity
//
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+

// Convert pips to points for current symbol
double PipsToPoints(double pips)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    if(digits == 3 || digits == 5)
        return pips * 10 * point;  // 5-digit broker
    else
        return pips * point;        // 4-digit broker
}

// Get current spread in pips
double GetSpreadPips()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    double spread_points = (ask - bid) / point;

    if(digits == 3 || digits == 5)
        return spread_points / 10.0;  // Convert to pips for 5-digit
    else
        return spread_points;         // Already in pips for 4-digit
}

// Check if spread is acceptable for trading
bool IsSpreadAcceptable()
{
    double current_spread = GetSpreadPips();

    if(current_spread > MAX_SPREAD_PIPS)
    {
        Print("Spread too high: ", DoubleToString(current_spread, 1), " pips (max: ",
              DoubleToString(MAX_SPREAD_PIPS, 1), " pips)");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Configuration Validation                                          |
//+------------------------------------------------------------------+

// Validate EA configuration on initialization
bool ValidateConfiguration()
{
    bool valid = true;

    // Check risk parameters
    if(MAX_RISK_PER_TRADE <= 0 || MAX_RISK_PER_TRADE > 10)
    {
        Print("ERROR: MAX_RISK_PER_TRADE must be between 0 and 10 (current: ",
              DoubleToString(MAX_RISK_PER_TRADE, 2), ")");
        valid = false;
    }

    if(MAX_DAILY_RISK <= 0 || MAX_DAILY_RISK > 20)
    {
        Print("ERROR: MAX_DAILY_RISK must be between 0 and 20 (current: ",
              DoubleToString(MAX_DAILY_RISK, 2), ")");
        valid = false;
    }

    // Check stop loss parameters
    if(MIN_STOP_LOSS_PIPS >= MAX_STOP_LOSS_PIPS)
    {
        Print("ERROR: MIN_STOP_LOSS_PIPS must be less than MAX_STOP_LOSS_PIPS");
        valid = false;
    }

    // Check confidence thresholds
    if(QUANTUM_CONFIDENCE_THRESHOLD < 0 || QUANTUM_CONFIDENCE_THRESHOLD > 100)
    {
        Print("ERROR: QUANTUM_CONFIDENCE_THRESHOLD must be between 0 and 100");
        valid = false;
    }

    if(valid)
        Print("✓ Configuration validation passed");
    else
        Print("✗ Configuration validation FAILED - check parameters");

    return valid;
}

//+------------------------------------------------------------------+
