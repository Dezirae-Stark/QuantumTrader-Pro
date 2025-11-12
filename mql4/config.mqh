//+------------------------------------------------------------------+
//|                                                       config.mqh |
//|                          QuantumTrader Pro Configuration Header  |
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property strict

//--- LHFX Demo Account Configuration
#define LHFX_LOGIN           194302
#define LHFX_SERVER          "LHFXDemo-Server"
#define DEFAULT_BRIDGE_URL   "http://localhost:8080"

//--- Trading Parameters
#define MAX_SPREAD_PIPS      3.0
#define MIN_STOP_LOSS_PIPS   20.0
#define MAX_STOP_LOSS_PIPS   200.0
#define DEFAULT_SLIPPAGE     3

//--- Risk Management
#define MAX_RISK_PER_TRADE   2.0    // Maximum 2% risk per trade
#define MAX_DAILY_RISK       5.0    // Maximum 5% daily risk
#define MAX_OPEN_TRADES      5      // Maximum simultaneous trades

//--- Quantum System Parameters
#define QUANTUM_CONFIDENCE_THRESHOLD  70  // Minimum confidence for trade execution
#define ML_CONFIDENCE_THRESHOLD       75  // ML signal threshold

//--- Timing Parameters
#define BRIDGE_POLL_INTERVAL    5     // Seconds between bridge polls
#define CONNECTION_TIMEOUT      10000  // Milliseconds for API calls
#define RETRY_ATTEMPTS          3      // Number of retries for failed requests

//--- Color Definitions
#define COLOR_BUY    clrGreen
#define COLOR_SELL   clrRed
#define COLOR_CLOSE  clrYellow
#define COLOR_INFO   clrWhite

//+------------------------------------------------------------------+
