//+------------------------------------------------------------------+
//|                                            QuantumTraderPro.mq5 |
//|                        QuantumTrader Pro - Quantum Trading System|
//|                                   https://github.com/Dezirae-Stark|
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property link      "https://github.com/Dezirae-Stark/QuantumTrader-Pro"
#property version   "2.10"
#property description "Quantum Trading System with ML and Chaos Theory"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input Parameters
input group "=== Bridge Server Settings ==="
input string BridgeURL = "http://localhost:8080";  // Bridge Server URL

input group "=== Account Settings ==="
input long   AccountLogin = 0;                      // Account Login (configure with your account number)
input string AccountPassword = "";                  // Account Password (encrypted)
input string AccountServer = "LHFXDemo-Server";     // Demo Server

input group "=== Risk Management ==="
input double RiskPercent = 2.0;                     // Risk % per trade
input double MaxDailyLoss = 5.0;                    // Max daily loss %
input int    MagicNumber = 20241112;                // EA Magic Number

input group "=== Trading Features ==="
input bool   EnableQuantumSignals = true;           // Enable Quantum Predictions
input bool   EnableMLSignals = true;                // Enable ML Signals
input bool   EnableCantileverHedge = true;          // Enable Cantilever Hedging
input bool   SendTelegramAlerts = true;             // Send Telegram Notifications
input int    PollingIntervalSeconds = 5;            // Bridge polling interval

//--- Global Variables
CTrade trade;
CPositionInfo position;
COrderInfo order;

datetime lastPollTime = 0;
double dayStartBalance = 0;
datetime dayStart = 0;
int webRequestHandle = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==========================================================");
   Print("QuantumTrader Pro v2.1.0 (MT5) Initializing...");
   Print("==========================================================");
   Print("Account: ", AccountLogin);
   Print("Server: ", AccountServer);
   Print("Bridge URL: ", BridgeURL);
   Print("Risk %: ", RiskPercent);
   Print("Magic Number: ", MagicNumber);
   Print("==========================================================");

   //--- Set EA magic number
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(false);

   //--- Store day start balance
   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
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

   //--- Update market data
   SendMarketData();

   //--- Get signals from bridge
   if(EnableQuantumSignals || EnableMLSignals)
   {
      ProcessTradingSignals();
   }

   //--- Manage open positions
   ManageOpenPositions();

   //--- Update bridge with position data
   SendPositionData();
}

//+------------------------------------------------------------------+
//| Test bridge connection                                           |
//+------------------------------------------------------------------+
bool TestBridgeConnection()
{
   string url = BridgeURL + "/api/health";
   string cookie = NULL, referer = NULL;
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";

   int timeout = 5000;
   int res = WebRequest("GET", url, cookie, referer, timeout, post, 0, result, headers);

   if(res == -1)
   {
      Print("Error: WebRequest failed. Error code: ", GetLastError());
      Print("Make sure to add '", BridgeURL, "' to allowed URLs in Tools->Options->Expert Advisors");
      return false;
   }

   if(res == 200)
   {
      Print("Bridge connection successful!");
      return true;
   }

   Print("Bridge returned status code: ", res);
   return false;
}

//+------------------------------------------------------------------+
//| Send account data to bridge                                      |
//+------------------------------------------------------------------+
void SendAccountData()
{
   string url = BridgeURL + "/api/account";
   string json = "{";
   json += "\"account\":" + IntegerToString(AccountLogin) + ",";
   json += "\"server\":\"" + AccountServer + "\",";
   json += "\"balance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
   json += "\"equity\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + ",";
   json += "\"margin\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + ",";
   json += "\"freeMargin\":" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + ",";
   json += "\"currency\":\"" + AccountInfoString(ACCOUNT_CURRENCY) + "\",";
   json += "\"leverage\":" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE));
   json += "}";

   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Send market data to bridge                                       |
//+------------------------------------------------------------------+
void SendMarketData()
{
   string url = BridgeURL + "/api/market";
   string json = "{";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"bid\":" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + ",";
   json += "\"ask\":" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + ",";
   json += "\"spread\":" + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + ",";
   json += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   json += "}";

   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Send position data to bridge                                     |
//+------------------------------------------------------------------+
void SendPositionData()
{
   string url = BridgeURL + "/api/positions";
   string json = "[";

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() != MagicNumber)
            continue;

         if(i > 0) json += ",";

         json += "{";
         json += "\"ticket\":" + IntegerToString(position.Ticket()) + ",";
         json += "\"symbol\":\"" + position.Symbol() + "\",";
         json += "\"type\":\"" + (position.Type() == POSITION_TYPE_BUY ? "BUY" : "SELL") + "\",";
         json += "\"volume\":" + DoubleToString(position.Volume(), 2) + ",";
         json += "\"openPrice\":" + DoubleToString(position.PriceOpen(), _Digits) + ",";
         json += "\"currentPrice\":" + DoubleToString(position.PriceCurrent(), _Digits) + ",";
         json += "\"profit\":" + DoubleToString(position.Profit(), 2) + ",";
         json += "\"swap\":" + DoubleToString(position.Swap(), 2) + ",";
         json += "\"commission\":" + DoubleToString(position.Commission(), 2) + ",";
         json += "\"sl\":" + DoubleToString(position.StopLoss(), _Digits) + ",";
         json += "\"tp\":" + DoubleToString(position.TakeProfit(), _Digits);
         json += "}";
      }
   }

   json += "]";
   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Extract JSON double value (simple parser)                        |
//+------------------------------------------------------------------+
double ExtractJSONDouble(string json, string field)
{
   string searchStr = "\"" + field + "\":";
   int pos = StringFind(json, searchStr);
   if(pos < 0) return 0.0;

   int startPos = pos + StringLen(searchStr);
   string remaining = StringSubstr(json, startPos);
   int endPos = StringFind(remaining, ",");
   if(endPos < 0) endPos = StringFind(remaining, "}");
   if(endPos < 0) return 0.0;

   return StringToDouble(StringSubstr(remaining, 0, endPos));
}

//+------------------------------------------------------------------+
//| Extract JSON string value                                        |
//+------------------------------------------------------------------+
string ExtractJSONString(string json, string field)
{
   string searchStr = "\"" + field + "\":\"";
   int pos = StringFind(json, searchStr);
   if(pos < 0) return "";

   int startPos = pos + StringLen(searchStr);
   int endPos = StringFind(json, "\"", startPos);
   if(endPos < 0) return "";

   return StringSubstr(json, startPos, endPos - startPos);
}

//+------------------------------------------------------------------+
//| Process trading signals from bridge                              |
//+------------------------------------------------------------------+
void ProcessTradingSignals()
{
   //--- Build request URL
   string url = BridgeURL + "/api/signals?symbol=" + _Symbol;

   //--- Send HTTP GET request
   string response = SendHTTPRequest(url, "GET", "");

   //--- Validate response is not empty
   if(response == "")
   {
      Print("No response from bridge server");
      return;
   }

   //--- Check if this is a valid signals array response
   int checkSignals = StringFind(response, "\"signals\"");
   if(checkSignals < 0)
   {
      Print("Invalid response format - no signals array found");
      return;
   }

   //--- Build search string for current symbol
   string symbolSearch = "\"symbol\":\"";
   symbolSearch += _Symbol;
   symbolSearch += "\"";

   //--- Find signal for current symbol
   int symbolPos = StringFind(response, symbolSearch);

   if(symbolPos < 0)
   {
      Print("No signals for current symbol: ", _Symbol);
      return;
   }

   //--- Extract the complete signal JSON object
   //--- Declare character variable once for reuse
   int ch = 0;

   //--- Step 1: Find the opening brace before symbolPos
   int signalStart = symbolPos;
   while(signalStart > 0)
   {
      ch = StringGetCharacter(response, signalStart);
      if(ch == '{')
         break;
      signalStart--;
   }

   //--- Step 2: Find the matching closing brace
   int signalEnd = signalStart + 1;
   int braceCount = 1;
   int responseLen = StringLen(response);

   while(signalEnd < responseLen && braceCount > 0)
   {
      ch = StringGetCharacter(response, signalEnd);
      if(ch == '{')
         braceCount++;
      if(ch == '}')
         braceCount--;
      signalEnd++;
   }

   //--- Extract signal substring
   int signalLength = signalEnd - signalStart;
   string signal = StringSubstr(response, signalStart, signalLength);

   //--- Parse signal fields using helper functions
   string signalType = ExtractJSONString(signal, "type");
   string action = ExtractJSONString(signal, "action");
   double confidence = ExtractJSONDouble(signal, "confidence");

   //--- Log parsed signal
   Print("Signal parsed: Type=", signalType, " Action=", action, " Confidence=", confidence, "%");

   //--- Extract prediction bounds for SL/TP calculation
   double nextPrice = ExtractJSONDouble(signal, "next_price");
   double upperBound = ExtractJSONDouble(signal, "upper_bound");
   double lowerBound = ExtractJSONDouble(signal, "lower_bound");

   //--- Process BUY signals
   if(signalType == "BUY" && action == "BUY" && confidence >= 70)
   {
      if(!HasOpenPosition(POSITION_TYPE_BUY))
      {
         Print("✅ BUY signal confirmed! Confidence: ", confidence, "%");

         //--- Calculate order parameters
         double lots = CalculateLotSize();
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = 0.0;
         double tp = 0.0;

         //--- Use predicted bounds or calculate dynamically
         if(lowerBound > 0)
            sl = lowerBound;
         else
            sl = CalculateStopLoss(true);

         if(upperBound > 0)
            tp = upperBound;
         else
            tp = CalculateTakeProfit(true);

         //--- Execute BUY order
         bool orderResult = trade.Buy(lots, _Symbol, 0, sl, tp, "Quantum Signal");
         if(orderResult)
         {
            Print("BUY order opened: Ticket #", trade.ResultOrder());

            //--- Send Telegram notification if enabled
            if(SendTelegramAlerts)
            {
               string msg = "📈 BUY Signal Executed on ";
               msg += _Symbol;
               msg += " (Confidence: ";
               msg += DoubleToString(confidence, 1);
               msg += "%)";
               SendTelegramNotification(msg);
            }
         }
         else
         {
            Print("Failed to open BUY order. Error: ", GetLastError());
         }
      }
      else
      {
         Print("Already have open BUY position for ", _Symbol);
      }
   }
   //--- Process SELL signals
   else if(signalType == "SELL" && action == "SELL" && confidence >= 70)
   {
      if(!HasOpenPosition(POSITION_TYPE_SELL))
      {
         Print("✅ SELL signal confirmed! Confidence: ", confidence, "%");

         //--- Calculate order parameters
         double lots = CalculateLotSize();
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = 0.0;
         double tp = 0.0;

         //--- Use predicted bounds or calculate dynamically
         if(upperBound > 0)
            sl = upperBound;
         else
            sl = CalculateStopLoss(false);

         if(lowerBound > 0)
            tp = lowerBound;
         else
            tp = CalculateTakeProfit(false);

         //--- Execute SELL order
         bool orderResult = trade.Sell(lots, _Symbol, 0, sl, tp, "Quantum Signal");
         if(orderResult)
         {
            Print("SELL order opened: Ticket #", trade.ResultOrder());

            //--- Send Telegram notification if enabled
            if(SendTelegramAlerts)
            {
               string msg = "📉 SELL Signal Executed on ";
               msg += _Symbol;
               msg += " (Confidence: ";
               msg += DoubleToString(confidence, 1);
               msg += "%)";
               SendTelegramNotification(msg);
            }
         }
         else
         {
            Print("Failed to open SELL order. Error: ", GetLastError());
         }
      }
      else
      {
         Print("Already have open SELL position for ", _Symbol);
      }
   }
   else
   {
      if(confidence < 70)
      {
         Print("Signal confidence too low: ", confidence, "% (minimum: 70%)");
      }
      else
      {
         Print("Signal type or action not recognized: Type=", signalType, " Action=", action);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions (trailing stop, cantilever hedge)         |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() != MagicNumber)
            continue;

         //--- Apply cantilever trailing stop
         if(EnableCantileverHedge)
         {
            ApplyCantileverTrailingStop();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply cantilever trailing stop                                   |
//+------------------------------------------------------------------+
void ApplyCantileverTrailingStop()
{
   double profitPercent = (position.Profit() / dayStartBalance) * 100;

   if(profitPercent >= 0.5)  // Every 0.5% profit
   {
      double lockProfit = profitPercent * 0.6;  // Lock 60%
      double newSL = 0;

      if(position.Type() == POSITION_TYPE_BUY)
      {
         newSL = position.PriceOpen() + (position.PriceOpen() * lockProfit / 100);
         if(newSL > position.StopLoss())
         {
            trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
            Print("Cantilever trailing stop updated: ", newSL);
         }
      }
      else if(position.Type() == POSITION_TYPE_SELL)
      {
         newSL = position.PriceOpen() - (position.PriceOpen() * lockProfit / 100);
         if(newSL < position.StopLoss() || position.StopLoss() == 0)
         {
            trade.PositionModify(position.Ticket(), newSL, position.TakeProfit());
            Print("Cantilever trailing stop updated: ", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                           |
//+------------------------------------------------------------------+
bool CheckDailyLossLimit()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLoss = ((dayStartBalance - currentBalance) / dayStartBalance) * 100;

   if(dailyLoss >= MaxDailyLoss)
   {
      //--- Close all positions
      CloseAllPositions();
      return false;
   }

   //--- Reset counter at midnight
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour == 0 && dt.min == 0)
   {
      dayStartBalance = currentBalance;
      dayStart = TimeCurrent();
      Print("Daily loss counter reset. New baseline: ", dayStartBalance);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() == MagicNumber)
         {
            trade.PositionClose(position.Ticket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_POSITION_TYPE type)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Magic() == MagicNumber && position.Type() == type)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopLossPips = 50;  // Default 50 pips

   double lots = riskAmount / (stopLossPips * tickValue);

   //--- Normalize to allowed lot steps
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(lots, maxLot));

   return lots;
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy)
{
   double stopPips = 50;  // 50 pips default
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(isBuy)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID) - stopPips * point * 10;
   else
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK) + stopPips * point * 10;
}

//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isBuy)
{
   double tpPips = 100;  // 100 pips default (2:1 R:R)
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(isBuy)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID) + tpPips * point * 10;
   else
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - tpPips * point * 10;
}

//+------------------------------------------------------------------+
//| Send HTTP request to bridge                                      |
//+------------------------------------------------------------------+
string SendHTTPRequest(string url, string method, string data)
{
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string cookie = NULL, referer = NULL;
   int timeout = 5000;

   if(method == "POST" || method == "PUT")
   {
      StringToCharArray(data, post, 0, StringLen(data));
   }

   int res = WebRequest(method, url, cookie, referer, timeout, post, ArraySize(post), result, headers);

   if(res == -1)
   {
      int err = GetLastError();
      if(err == 4060)  // URL not allowed
      {
         Print("ERROR: Add '", BridgeURL, "' to allowed URLs in Tools->Options->Expert Advisors");
      }
      else
      {
         Print("WebRequest error: ", err);
      }
      return "";
   }

   return CharArrayToString(result);
}

//+------------------------------------------------------------------+
//| Send Telegram notification                                       |
//+------------------------------------------------------------------+
void SendTelegramNotification(string message)
{
   string url = BridgeURL + "/api/telegram/send";
   string json = "{";
   json += "\"message\":\"" + message + "\",";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"account\":" + IntegerToString(AccountLogin);
   json += "}";

   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Send final statistics on EA shutdown                             |
//+------------------------------------------------------------------+
void SendFinalStats()
{
   string url = BridgeURL + "/api/stats/final";
   string json = "{";
   json += "\"account\":" + IntegerToString(AccountLogin) + ",";
   json += "\"finalBalance\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + ",";
   json += "\"finalEquity\":" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + ",";
   json += "\"startBalance\":" + DoubleToString(dayStartBalance, 2) + ",";
   json += "\"profit\":" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) - dayStartBalance, 2) + ",";
   json += "\"shutdownTime\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   json += "}";

   SendHTTPRequest(url, "POST", json);
}
//+------------------------------------------------------------------+
