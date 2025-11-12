//+------------------------------------------------------------------+
//|                                                   QuickHedge.mq5 |
//|                        Counter-Hedge Recovery System            |
//|                                   https://github.com/Dezirae-Stark|
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property link      "https://github.com/Dezirae-Stark/QuantumTrader-Pro"
#property version   "2.10"
#property description "Automatic counter-hedge on stop loss with ML-guided leg-out"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters
input group "=== Hedge Settings ==="
input double HedgeMultiplier = 1.5;     // Hedge position multiplier
input bool   EnableMLLegOut = true;     // Use ML for leg-out timing
input int    MagicNumber = 20241113;    // Hedge Magic Number

input group "=== Bridge Server ==="
input string BridgeURL = "http://localhost:8080";  // Bridge Server URL

input group "=== Recovery Settings ==="
input double BreakevenThreshold = 0.0;  // Combined P&L breakeven threshold ($)
input bool   AutoLegOut = true;         // Automatic leg-out when profitable
input double MinProfitForLegOut = 0.5;  // Min % profit before leg-out

//--- Global Variables
CTrade trade;
CPositionInfo position;
datetime lastCheckTime = 0;
int checkIntervalSeconds = 5;

struct HedgePair
{
   ulong originalTicket;
   ulong hedgeTicket;
   double originalLots;
   double hedgeLots;
   string symbol;
   ENUM_POSITION_TYPE originalType;
   datetime openTime;
   bool leggedOut;
};

HedgePair hedgePairs[];
int totalPairs = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==========================================================");
   Print("QuickHedge v2.1.0 (MT5) - Counter-Hedge Recovery System");
   Print("==========================================================");
   Print("Hedge Multiplier: ", HedgeMultiplier);
   Print("ML Leg-Out: ", EnableMLLegOut ? "Enabled" : "Disabled");
   Print("Magic Number: ", MagicNumber);
   Print("==========================================================");

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   ArrayResize(hedgePairs, 100);  // Pre-allocate space

   Print("QuickHedge initialized successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("QuickHedge shutting down. Managed ", totalPairs, " hedge pairs.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check periodically
   if(TimeCurrent() - lastCheckTime < checkIntervalSeconds)
      return;

   lastCheckTime = TimeCurrent();

   //--- Monitor for positions hitting SL (position closed events)
   //--- In MT5, we need to track this through order history
   CheckForStopLossHits();

   //--- Manage existing hedge pairs
   ManageHedgePairs();
}

//+------------------------------------------------------------------+
//| Check order history for stop loss hits                          |
//+------------------------------------------------------------------+
void CheckForStopLossHits()
{
   //--- Get history from last 24 hours
   datetime fromTime = TimeCurrent() - 86400;
   HistorySelect(fromTime, TimeCurrent());

   int totalDeals = HistoryDealsTotal();

   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         //--- Check if it's a stop loss exit
         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         long dealReason = HistoryDealGetInteger(dealTicket, DEAL_REASON);

         if(dealEntry == DEAL_ENTRY_OUT && dealReason == DEAL_REASON_SL)
         {
            //--- Position was closed by stop loss
            ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);

            //--- Check if we already hedged this position
            if(!IsPositionHedged(positionId))
            {
               //--- Create counter hedge
               ENUM_POSITION_TYPE originalType = (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
               CreateCounterHedge(positionId, symbol, originalType, volume);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if position already has a hedge                           |
//+------------------------------------------------------------------+
bool IsPositionHedged(ulong positionId)
{
   for(int i = 0; i < totalPairs; i++)
   {
      if(hedgePairs[i].originalTicket == positionId && !hedgePairs[i].leggedOut)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Create counter hedge position                                    |
//+------------------------------------------------------------------+
void CreateCounterHedge(ulong originalTicket, string symbol, ENUM_POSITION_TYPE originalType, double originalVolume)
{
   Print("STOP LOSS HIT! Creating counter-hedge for position #", originalTicket);

   //--- Calculate hedge volume
   double hedgeVolume = originalVolume * HedgeMultiplier;

   //--- Normalize volume
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   hedgeVolume = MathFloor(hedgeVolume / lotStep) * lotStep;
   hedgeVolume = MathMax(minLot, MathMin(hedgeVolume, maxLot));

   //--- Open opposite position
   bool success = false;
   ulong hedgeTicket = 0;

   if(originalType == POSITION_TYPE_BUY)
   {
      // Original was BUY, hedge with SELL
      if(trade.Sell(hedgeVolume, symbol, 0, 0, 0, "Counter-Hedge"))
      {
         success = true;
         hedgeTicket = trade.ResultOrder();
      }
   }
   else
   {
      // Original was SELL, hedge with BUY
      if(trade.Buy(hedgeVolume, symbol, 0, 0, 0, "Counter-Hedge"))
      {
         success = true;
         hedgeTicket = trade.ResultOrder();
      }
   }

   if(success)
   {
      Print("✅ Counter-hedge created successfully! Ticket #", hedgeTicket);
      Print("   Original: ", originalVolume, " lots | Hedge: ", hedgeVolume, " lots (", HedgeMultiplier, "x)");

      //--- Record hedge pair
      hedgePairs[totalPairs].originalTicket = originalTicket;
      hedgePairs[totalPairs].hedgeTicket = hedgeTicket;
      hedgePairs[totalPairs].originalLots = originalVolume;
      hedgePairs[totalPairs].hedgeLots = hedgeVolume;
      hedgePairs[totalPairs].symbol = symbol;
      hedgePairs[totalPairs].originalType = originalType;
      hedgePairs[totalPairs].openTime = TimeCurrent();
      hedgePairs[totalPairs].leggedOut = false;
      totalPairs++;

      //--- Send notification to bridge
      SendHedgeNotification(originalTicket, hedgeTicket, symbol, originalVolume, hedgeVolume);
   }
   else
   {
      Print("❌ Failed to create counter-hedge. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Manage existing hedge pairs                                      |
//+------------------------------------------------------------------+
void ManageHedgePairs()
{
   for(int i = 0; i < totalPairs; i++)
   {
      if(hedgePairs[i].leggedOut)
         continue;

      //--- Check if hedge position still exists
      if(!PositionSelectByTicket(hedgePairs[i].hedgeTicket))
      {
         //--- Hedge was manually closed
         hedgePairs[i].leggedOut = true;
         Print("Hedge pair #", i, " - Position manually closed");
         continue;
      }

      //--- Get combined P&L
      if(position.SelectByTicket(hedgePairs[i].hedgeTicket))
      {
         double hedgeProfit = position.Profit() + position.Swap() + position.Commission();
         double originalLoss = CalculateOriginalLoss(i);
         double combinedPL = hedgeProfit + originalLoss;

         //--- Check for leg-out conditions
         if(AutoLegOut && ShouldLegOut(i, combinedPL))
         {
            ExecuteLegOut(i);
         }

         //--- Display status
         if(TimeCurrent() % 60 == 0)  // Every minute
         {
            Print("Hedge Pair #", i, " - Combined P&L: $", combinedPL, " | Hedge Profit: $", hedgeProfit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate original position loss                                |
//+------------------------------------------------------------------+
double CalculateOriginalLoss(int pairIndex)
{
   //--- Get deal from history
   ulong dealTicket = hedgePairs[pairIndex].originalTicket;
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         ulong posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         if(posId == dealTicket)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            return profit + swap + commission;
         }
      }
   }

   return 0;  // Default if not found
}

//+------------------------------------------------------------------+
//| Determine if should leg out                                      |
//+------------------------------------------------------------------+
bool ShouldLegOut(int pairIndex, double combinedPL)
{
   //--- Breakeven or profit
   if(combinedPL >= BreakevenThreshold)
   {
      Print("✅ Leg-out condition met: Combined P&L = $", combinedPL);
      return true;
   }

   //--- Check ML recommendation if enabled
   if(EnableMLLegOut)
   {
      if(GetMLLegOutRecommendation(pairIndex))
      {
         Print("✅ ML recommends leg-out for pair #", pairIndex);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get ML leg-out recommendation from bridge                        |
//+------------------------------------------------------------------+
bool GetMLLegOutRecommendation(int pairIndex)
{
   string url = BridgeURL + "/api/hedge/legout-recommendation";
   string json = "{";
   json += "\"hedgeTicket\":" + IntegerToString(hedgePairs[pairIndex].hedgeTicket) + ",";
   json += "\"symbol\":\"" + hedgePairs[pairIndex].symbol + "\",";
   json += "\"openTime\":\"" + TimeToString(hedgePairs[pairIndex].openTime, TIME_DATE|TIME_SECONDS) + "\"";
   json += "}";

   string response = SendHTTPRequest(url, "POST", json);

   //--- Parse response (simplified)
   if(StringFind(response, "\"legOut\":true") >= 0)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Execute leg-out strategy                                         |
//+------------------------------------------------------------------+
void ExecuteLegOut(int pairIndex)
{
   Print("🎯 Executing leg-out for hedge pair #", pairIndex);

   //--- Close hedge position
   if(trade.PositionClose(hedgePairs[pairIndex].hedgeTicket))
   {
      hedgePairs[pairIndex].leggedOut = true;
      Print("✅ Hedge position closed successfully!");

      //--- Send notification
      SendLegOutNotification(pairIndex);
   }
   else
   {
      Print("❌ Failed to close hedge position. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Send hedge creation notification                                 |
//+------------------------------------------------------------------+
void SendHedgeNotification(ulong originalTicket, ulong hedgeTicket, string symbol, double originalLots, double hedgeLots)
{
   string url = BridgeURL + "/api/telegram/send";
   string message = "🛡️ COUNTER-HEDGE ACTIVATED\n";
   message += "Symbol: " + symbol + "\n";
   message += "Original Position: #" + IntegerToString(originalTicket) + " (" + DoubleToString(originalLots, 2) + " lots)\n";
   message += "Hedge Position: #" + IntegerToString(hedgeTicket) + " (" + DoubleToString(hedgeLots, 2) + " lots)\n";
   message += "Multiplier: " + DoubleToString(HedgeMultiplier, 1) + "x";

   string json = "{";
   json += "\"message\":\"" + message + "\",";
   json += "\"type\":\"hedge_created\"";
   json += "}";

   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Send leg-out notification                                        |
//+------------------------------------------------------------------+
void SendLegOutNotification(int pairIndex)
{
   string url = BridgeURL + "/api/telegram/send";
   string message = "🎯 HEDGE LEG-OUT EXECUTED\n";
   message += "Symbol: " + hedgePairs[pairIndex].symbol + "\n";
   message += "Hedge Ticket: #" + IntegerToString(hedgePairs[pairIndex].hedgeTicket) + "\n";
   message += "Recovery successful!";

   string json = "{";
   json += "\"message\":\"" + message + "\",";
   json += "\"type\":\"hedge_legout\"";
   json += "}";

   SendHTTPRequest(url, "POST", json);
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
      return "";
   }

   return CharArrayToString(result);
}
//+------------------------------------------------------------------+
