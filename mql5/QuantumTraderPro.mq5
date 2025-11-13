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
//| Process trading signals from bridge                              |
//+------------------------------------------------------------------+
void ProcessTradingSignals()
{
   string url = BridgeURL + "/api/signals?symbol=" + _Symbol;
   string response = SendHTTPRequest(url, "GET", "");

   if(response == "")
      return;

   //--- Parse JSON response (simplified)
   //--- In production, use proper JSON parsing library
   if(StringFind(response, "\"action\":\"BUY\"") >= 0)
   {
      if(!HasOpenPosition(POSITION_TYPE_BUY))
      {
         double lots = CalculateLotSize();
         double sl = CalculateStopLoss(true);
         double tp = CalculateTakeProfit(true);

         if(trade.Buy(lots, _Symbol, 0, sl, tp, "Quantum Signal"))
         {
            Print("BUY order opened: Ticket #", trade.ResultOrder());
            if(SendTelegramAlerts)
               SendTelegramNotification("📈 BUY Signal Executed on " + _Symbol);
         }
      }
   }
   else if(StringFind(response, "\"action\":\"SELL\"") >= 0)
   {
      if(!HasOpenPosition(POSITION_TYPE_SELL))
      {
         double lots = CalculateLotSize();
         double sl = CalculateStopLoss(false);
         double tp = CalculateTakeProfit(false);

         if(trade.Sell(lots, _Symbol, 0, sl, tp, "Quantum Signal"))
         {
            Print("SELL order opened: Ticket #", trade.ResultOrder());
            if(SendTelegramAlerts)
               SendTelegramNotification("📉 SELL Signal Executed on " + _Symbol);
         }
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
