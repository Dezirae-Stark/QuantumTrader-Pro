//+------------------------------------------------------------------+
//|                                            QuantumTraderPro.mq4 |
//|                        QuantumTrader Pro - Quantum Trading System|
//|                                   https://github.com/Dezirae-Stark|
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property link      "https://github.com/Dezirae-Stark/QuantumTrader-Pro"
#property version   "2.10"
#property strict

#include "config.mqh"

//--- Input Parameters
input string BridgeURL = "http://localhost:8080";  // Bridge Server URL
input int    AccountLogin = 194302;                 // LHFX Account Login
input string AccountPassword = "";                  // Account Password (encrypted)
input string AccountServer = "LHFXDemo-Server";     // Demo Server
input double RiskPercent = 2.0;                     // Risk % per trade
input double MaxDailyLoss = 5.0;                    // Max daily loss %
input int    MagicNumber = 20241112;                // EA Magic Number
input bool   EnableQuantumSignals = true;           // Enable Quantum Predictions
input bool   EnableMLSignals = true;                // Enable ML Signals
input bool   EnableCantileverHedge = true;          // Enable Cantilever Hedging
input bool   SendTelegramAlerts = true;             // Send Telegram Notifications
input int    PollingIntervalSeconds = 5;            // Bridge polling interval

//--- Global Variables
datetime lastPollTime = 0;
double dayStartBalance = 0;
datetime dayStart = 0;
int requestHandle = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==========================================================");
   Print("QuantumTrader Pro v2.1.0 Initializing...");
   Print("==========================================================");
   Print("Account: ", AccountLogin);
   Print("Server: ", AccountServer);
   Print("Bridge URL: ", BridgeURL);
   Print("Risk %: ", RiskPercent);
   Print("Magic Number: ", MagicNumber);
   Print("==========================================================");

   //--- Store day start balance
   dayStartBalance = AccountBalance();
   dayStart = TimeCurrent();

   //--- Validate inputs
   if(RiskPercent <= 0 || RiskPercent > 10)
   {
      Print("ERROR: Risk percent must be between 0 and 10");
      return(INIT_PARAMETERS_INCORRECT);
   }

   //--- Test bridge connection
   if(!TestBridgeConnection())
   {
      Print("WARNING: Bridge server not responding. EA will continue to retry...");
   }

   //--- Send initialization data to bridge
   SendAccountData();
   SendMarketData();

   Print("QuantumTrader Pro initialized successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("QuantumTrader Pro shutting down. Reason: ", reason);

   //--- Send final statistics to bridge
   SendFinalStats();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if it's time to poll the bridge
   if(TimeCurrent() - lastPollTime < PollingIntervalSeconds)
      return;

   lastPollTime = TimeCurrent();

   //--- Check daily loss limit
   if(!CheckDailyLossLimit())
   {
      Print("Daily loss limit reached. Trading stopped for today.");
      return;
   }

   //--- Fetch signals from bridge
   FetchAndProcessSignals();

   //--- Update open positions to bridge
   SendOpenPositions();

   //--- Send market data
   SendMarketData();
}

//+------------------------------------------------------------------+
//| Test bridge server connection                                    |
//+------------------------------------------------------------------+
bool TestBridgeConnection()
{
   string url = BridgeURL + "/api/health";
   string headers = "Content-Type: application/json\r\n";
   char data[];
   char result[];
   string resultHeaders;

   int res = WebRequest("GET", url, headers, 5000, data, result, resultHeaders);

   if(res == 200)
   {
      Print("Bridge connection successful!");
      return true;
   }

   Print("Bridge connection failed. Code: ", res);
   return false;
}

//+------------------------------------------------------------------+
//| Send account data to bridge                                      |
//+------------------------------------------------------------------+
void SendAccountData()
{
   string url = BridgeURL + "/api/account";
   string headers = "Content-Type: application/json\r\n";

   string json = StringFormat(
      "{\"login\":%d,\"server\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"margin\":%.2f,\"freeMargin\":%.2f,\"leverage\":%d}",
      AccountLogin,
      AccountServer,
      AccountBalance(),
      AccountEquity(),
      AccountMargin(),
      AccountFreeMargin(),
      AccountLeverage()
   );

   char data[];
   StringToCharArray(json, data, 0, StringLen(json));

   char result[];
   string resultHeaders;

   WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
}

//+------------------------------------------------------------------+
//| Send market data to bridge                                       |
//+------------------------------------------------------------------+
void SendMarketData()
{
   string symbols[] = {Symbol(), "EURUSD", "GBPUSD", "USDJPY", "AUDUSD"};

   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string sym = symbols[i];

      string url = BridgeURL + "/api/market";
      string headers = "Content-Type: application/json\r\n";

      string json = StringFormat(
         "{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"spread\":%.1f,\"timestamp\":%d}",
         sym,
         MarketInfo(sym, MODE_BID),
         MarketInfo(sym, MODE_ASK),
         MarketInfo(sym, MODE_SPREAD),
         TimeCurrent()
      );

      char data[];
      StringToCharArray(json, data, 0, StringLen(json));

      char result[];
      string resultHeaders;

      WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
   }
}

//+------------------------------------------------------------------+
//| Fetch and process trading signals from bridge                    |
//+------------------------------------------------------------------+
void FetchAndProcessSignals()
{
   string url = BridgeURL + "/api/signals?account=" + IntegerToString(AccountLogin);
   string headers = "Content-Type: application/json\r\n";

   char data[];
   char result[];
   string resultHeaders;

   int res = WebRequest("GET", url, headers, 10000, data, result, resultHeaders);

   if(res != 200)
   {
      Print("Failed to fetch signals. Code: ", res);
      return;
   }

   string response = CharArrayToString(result);

   //--- Parse JSON response (simplified - in production use proper JSON parser)
   ProcessSignalsJSON(response);
}

//+------------------------------------------------------------------+
//| Extract JSON field value (simple parser)                         |
//+------------------------------------------------------------------+
double ExtractJSONDouble(string json, string field)
{
   string searchStr = "\"" + field + "\":";
   int pos = StringFind(json, searchStr);

   if(pos < 0)
      return 0.0;

   int startPos = pos + StringLen(searchStr);
   string remaining = StringSubstr(json, startPos);

   // Find the end (comma or closing brace)
   int endPos = StringFind(remaining, ",");
   if(endPos < 0)
      endPos = StringFind(remaining, "}");

   if(endPos < 0)
      return 0.0;

   string valueStr = StringSubstr(remaining, 0, endPos);
   return StringToDouble(valueStr);
}

//+------------------------------------------------------------------+
//| Extract JSON string field value                                  |
//+------------------------------------------------------------------+
string ExtractJSONString(string json, string field)
{
   string searchStr = "\"" + field + "\":\"";
   int pos = StringFind(json, searchStr);

   if(pos < 0)
      return "";

   int startPos = pos + StringLen(searchStr);
   int endPos = StringFind(json, "\"", startPos);

   if(endPos < 0)
      return "";

   return StringSubstr(json, startPos, endPos - startPos);
}

//+------------------------------------------------------------------+
//| Process signals from JSON response                               |
//+------------------------------------------------------------------+
void ProcessSignalsJSON(string json)
{
   //--- Parse JSON response
   //--- Expected format: {"signals": [{"symbol":"EURUSD", "type":"BUY", "confidence":85.5, ...}]}

   // Check if this is a signals array response
   if(StringFind(json, "\"signals\"") < 0)
      return;

   // Extract current symbol from signals array
   string currentSymbol = Symbol();
   int symbolPos = StringFind(json, "\"symbol\":\"" + currentSymbol + "\"");

   if(symbolPos < 0)
   {
      Print("No signals for current symbol: ", currentSymbol);
      return;
   }

   // Find the signal object for this symbol
   // Search backwards to find the opening brace of this signal
   int signalStart = symbolPos;
   while(signalStart > 0 && StringGetChar(json, signalStart) != '{')
      signalStart--;

   // Search forwards to find the closing brace
   int signalEnd = symbolPos;
   int braceCount = 1;
   signalEnd = signalStart + 1;

   while(signalEnd < StringLen(json) && braceCount > 0)
   {
      int ch = StringGetChar(json, signalEnd);
      if(ch == '{') braceCount++;
      if(ch == '}') braceCount--;
      signalEnd++;
   }

   // Extract the signal object
   string signal = StringSubstr(json, signalStart, signalEnd - signalStart);

   // Extract signal fields
   string signalType = ExtractJSONString(signal, "type");
   double confidence = ExtractJSONDouble(signal, "confidence");
   string action = ExtractJSONString(signal, "action");

   Print("Signal parsed: Type=", signalType, " Action=", action, " Confidence=", confidence, "%");

   //--- Process BUY signals
   if(signalType == "BUY" && action == "BUY" && confidence >= 70)
   {
      Print("✅ BUY signal confirmed! Confidence: ", confidence, "%");

      // Extract prediction data
      double nextPrice = ExtractJSONDouble(signal, "next_price");
      double upperBound = ExtractJSONDouble(signal, "upper_bound");
      double lowerBound = ExtractJSONDouble(signal, "lower_bound");

      // Calculate SL and TP
      double currentPrice = MarketInfo(currentSymbol, MODE_ASK);
      double sl = lowerBound > 0 ? lowerBound : currentPrice - 50 * Point;
      double tp = upperBound > 0 ? upperBound : currentPrice + 100 * Point;

      // Check if we already have an open position
      bool hasPosition = false;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == currentSymbol && OrderType() == OP_BUY)
            {
               hasPosition = true;
               break;
            }
         }
      }

      if(!hasPosition)
      {
         ExecuteBuyOrder(currentSymbol, CalculateLotSize(), sl, tp);
      }
      else
      {
         Print("Already have open BUY position for ", currentSymbol);
      }
   }
   //--- Process SELL signals
   else if(signalType == "SELL" && action == "SELL" && confidence >= 70)
   {
      Print("✅ SELL signal confirmed! Confidence: ", confidence, "%");

      // Extract prediction data
      double nextPrice = ExtractJSONDouble(signal, "next_price");
      double upperBound = ExtractJSONDouble(signal, "upper_bound");
      double lowerBound = ExtractJSONDouble(signal, "lower_bound");

      // Calculate SL and TP
      double currentPrice = MarketInfo(currentSymbol, MODE_BID);
      double sl = upperBound > 0 ? upperBound : currentPrice + 50 * Point;
      double tp = lowerBound > 0 ? lowerBound : currentPrice - 100 * Point;

      // Check if we already have an open position
      bool hasPosition = false;
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == currentSymbol && OrderType() == OP_SELL)
            {
               hasPosition = true;
               break;
            }
         }
      }

      if(!hasPosition)
      {
         ExecuteSellOrder(currentSymbol, CalculateLotSize(), sl, tp);
      }
      else
      {
         Print("Already have open SELL position for ", currentSymbol);
      }
   }
   else if(confidence < 70)
   {
      Print("Signal confidence too low: ", confidence, "% (minimum: 70%)");
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                            |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double riskAmount = AccountBalance() * RiskPercent / 100.0;
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double stopLoss = 50; // Default 50 pips

   double lotSize = riskAmount / (stopLoss * tickValue);

   //--- Round to valid lot size
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   return lotSize;
}

//+------------------------------------------------------------------+
//| Execute buy order                                                |
//+------------------------------------------------------------------+
bool ExecuteBuyOrder(string symbol, double lots, double sl, double tp)
{
   double price = MarketInfo(symbol, MODE_ASK);

   int ticket = OrderSend(
      symbol,
      OP_BUY,
      lots,
      price,
      3,
      sl,
      tp,
      "QuantumTrader Pro",
      MagicNumber,
      0,
      clrGreen
   );

   if(ticket > 0)
   {
      Print("BUY order opened: Ticket=", ticket, " Lots=", lots, " Price=", price);
      return true;
   }

   Print("BUY order failed: ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Execute sell order                                               |
//+------------------------------------------------------------------+
bool ExecuteSellOrder(string symbol, double lots, double sl, double tp)
{
   double price = MarketInfo(symbol, MODE_BID);

   int ticket = OrderSend(
      symbol,
      OP_SELL,
      lots,
      price,
      3,
      sl,
      tp,
      "QuantumTrader Pro",
      MagicNumber,
      0,
      clrRed
   );

   if(ticket > 0)
   {
      Print("SELL order opened: Ticket=", ticket, " Lots=", lots, " Price=", price);
      return true;
   }

   Print("SELL order failed: ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber)
         {
            bool closed = false;

            if(OrderType() == OP_BUY)
            {
               closed = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 3, clrYellow);
            }
            else if(OrderType() == OP_SELL)
            {
               closed = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 3, clrYellow);
            }

            if(closed)
               Print("Closed position: Ticket=", OrderTicket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Send open positions to bridge                                    |
//+------------------------------------------------------------------+
void SendOpenPositions()
{
   string url = BridgeURL + "/api/positions";
   string headers = "Content-Type: application/json\r\n";

   string json = "{\"positions\":[";

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber)
         {
            if(i > 0) json += ",";

            json += StringFormat(
               "{\"ticket\":%d,\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":%.2f,\"openPrice\":%.5f,\"currentPrice\":%.5f,\"profit\":%.2f,\"sl\":%.5f,\"tp\":%.5f}",
               OrderTicket(),
               OrderSymbol(),
               (OrderType() == OP_BUY) ? "BUY" : "SELL",
               OrderLots(),
               OrderOpenPrice(),
               (OrderType() == OP_BUY) ? MarketInfo(OrderSymbol(), MODE_BID) : MarketInfo(OrderSymbol(), MODE_ASK),
               OrderProfit(),
               OrderStopLoss(),
               OrderTakeProfit()
            );
         }
      }
   }

   json += "]}";

   char data[];
   StringToCharArray(json, data, 0, StringLen(json));

   char result[];
   string resultHeaders;

   WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                           |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
   //--- Reset at start of new day
   datetime currentDay = TimeCurrent() - (TimeCurrent() % 86400);
   if(currentDay != dayStart)
   {
      dayStartBalance = AccountBalance();
      dayStart = currentDay;
      return true;
   }

   //--- Check if loss exceeds limit
   double currentLoss = (dayStartBalance - AccountEquity()) / dayStartBalance * 100.0;

   if(currentLoss > MaxDailyLoss)
   {
      Print("ALERT: Daily loss limit exceeded: ", DoubleToString(currentLoss, 2), "%");
      CloseAllPositions();
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Send final statistics on shutdown                                |
//+------------------------------------------------------------------+
void SendFinalStats()
{
   string url = BridgeURL + "/api/stats";
   string headers = "Content-Type: application/json\r\n";

   string json = StringFormat(
      "{\"account\":%d,\"finalBalance\":%.2f,\"finalEquity\":%.2f,\"timestamp\":%d}",
      AccountLogin,
      AccountBalance(),
      AccountEquity(),
      TimeCurrent()
   );

   char data[];
   StringToCharArray(json, data, 0, StringLen(json));

   char result[];
   string resultHeaders;

   WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
}

//+------------------------------------------------------------------+
