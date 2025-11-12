//+------------------------------------------------------------------+
//|                                            MLSignalOverlay.mq5 |
//|                        ML Prediction Overlay on Charts           |
//|                                   https://github.com/Dezirae-Stark|
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property link      "https://github.com/Dezirae-Stark/QuantumTrader-Pro"
#property version   "2.10"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot properties
#property indicator_label1  "ML Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  3

#property indicator_label2  "ML Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3

#property indicator_label3  "ML Prediction High"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property indicator_label4  "ML Prediction Low"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Input Parameters
input int    PredictionHorizon = 8;            // Prediction candles ahead
input double MinConfidence = 0.7;              // Minimum confidence threshold
input bool   ShowPredictionBands = true;       // Show prediction bands
input bool   EnableAlerts = true;              // Enable audio alerts
input string BridgeURL = "http://localhost:8080";  // Bridge Server URL
input int    UpdateIntervalSeconds = 10;       // Bridge polling interval

//--- Indicator buffers
double BuySignalBuffer[];
double SellSignalBuffer[];
double PredictionHighBuffer[];
double PredictionLowBuffer[];

//--- Global variables
datetime lastUpdateTime = 0;
datetime lastAlertTime = 0;
int alertCooldownSeconds = 300;  // 5 minutes

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, PredictionHighBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, PredictionLowBuffer, INDICATOR_DATA);

   //--- Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Up arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Down arrow

   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   //--- Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "ML Signals (" + IntegerToString(PredictionHorizon) + " candles)");

   //--- Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   Print("MLSignalOverlay v2.1.0 initialized successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Check if it's time to update
   if(TimeCurrent() - lastUpdateTime < UpdateIntervalSeconds)
      return(prev_calculated);

   lastUpdateTime = TimeCurrent();

   //--- Get ML predictions from bridge
   string predictions = GetMLPredictions();

   if(predictions == "")
      return(prev_calculated);

   //--- Parse and plot predictions
   PlotMLPredictions(predictions, rates_total, time, close);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get ML predictions from bridge                                   |
//+------------------------------------------------------------------+
string GetMLPredictions()
{
   string url = BridgeURL + "/api/predictions?symbol=" + _Symbol;
   url += "&horizon=" + IntegerToString(PredictionHorizon);
   url += "&minConfidence=" + DoubleToString(MinConfidence, 2);

   return SendHTTPRequest(url, "GET", "");
}

//+------------------------------------------------------------------+
//| Plot ML predictions on chart                                     |
//+------------------------------------------------------------------+
void PlotMLPredictions(string jsonData, int total, const datetime &time[], const double &close[])
{
   //--- Clear previous signals
   ArrayInitialize(BuySignalBuffer, 0.0);
   ArrayInitialize(SellSignalBuffer, 0.0);
   ArrayInitialize(PredictionHighBuffer, 0.0);
   ArrayInitialize(PredictionLowBuffer, 0.0);

   //--- Parse JSON (simplified parsing)
   //--- In production, use proper JSON parsing library

   //--- Look for BUY signal
   if(StringFind(jsonData, "\"action\":\"BUY\"") >= 0)
   {
      double confidence = ExtractValue(jsonData, "\"confidence\":");
      if(confidence >= MinConfidence)
      {
         int index = total - 1;
         BuySignalBuffer[index] = close[index] - (close[index] * 0.001);  // Slightly below price

         //--- Extract prediction bands
         if(ShowPredictionBands)
         {
            double predHigh = ExtractValue(jsonData, "\"predictedHigh\":");
            double predLow = ExtractValue(jsonData, "\"predictedLow\":");

            if(predHigh > 0 && predLow > 0)
            {
               PredictionHighBuffer[index] = predHigh;
               PredictionLowBuffer[index] = predLow;
            }
         }

         //--- Trigger alert
         if(EnableAlerts && TimeCurrent() - lastAlertTime > alertCooldownSeconds)
         {
            TriggerAlert("BUY", confidence);
            lastAlertTime = TimeCurrent();
         }

         Print("📈 ML BUY Signal: ", _Symbol, " | Confidence: ", DoubleToString(confidence * 100, 1), "%");
      }
   }

   //--- Look for SELL signal
   if(StringFind(jsonData, "\"action\":\"SELL\"") >= 0)
   {
      double confidence = ExtractValue(jsonData, "\"confidence\":");
      if(confidence >= MinConfidence)
      {
         int index = total - 1;
         SellSignalBuffer[index] = close[index] + (close[index] * 0.001);  // Slightly above price

         //--- Extract prediction bands
         if(ShowPredictionBands)
         {
            double predHigh = ExtractValue(jsonData, "\"predictedHigh\":");
            double predLow = ExtractValue(jsonData, "\"predictedLow\":");

            if(predHigh > 0 && predLow > 0)
            {
               PredictionHighBuffer[index] = predHigh;
               PredictionLowBuffer[index] = predLow;
            }
         }

         //--- Trigger alert
         if(EnableAlerts && TimeCurrent() - lastAlertTime > alertCooldownSeconds)
         {
            TriggerAlert("SELL", confidence);
            lastAlertTime = TimeCurrent();
         }

         Print("📉 ML SELL Signal: ", _Symbol, " | Confidence: ", DoubleToString(confidence * 100, 1), "%");
      }
   }

   //--- Plot prediction horizon
   PlotPredictionHorizon(jsonData, total, time, close);
}

//+------------------------------------------------------------------+
//| Plot prediction horizon lines                                    |
//+------------------------------------------------------------------+
void PlotPredictionHorizon(string jsonData, int total, const datetime &time[], const double &close[])
{
   if(!ShowPredictionBands)
      return;

   //--- Look for prediction array
   int predStart = StringFind(jsonData, "\"predictions\":[");
   if(predStart < 0)
      return;

   //--- Parse prediction values (simplified)
   //--- Each prediction has: candle, price, confidence
   //--- Format: {"candle":1,"price":1.2345,"confidence":0.85}

   for(int i = 1; i <= PredictionHorizon && i < 50; i++)
   {
      string searchKey = "\"candle\":" + IntegerToString(i);
      int pos = StringFind(jsonData, searchKey, predStart);

      if(pos > 0)
      {
         double predictedPrice = ExtractValue(jsonData, "\"price\":", pos);
         double conf = ExtractValue(jsonData, "\"confidence\":", pos);

         if(predictedPrice > 0 && conf >= MinConfidence)
         {
            int futureIndex = total - 1 + i;
            if(futureIndex < total + PredictionHorizon)
            {
               //--- Calculate prediction band width based on confidence
               double bandWidth = predictedPrice * (1.0 - conf) * 0.02;

               PredictionHighBuffer[futureIndex] = predictedPrice + bandWidth;
               PredictionLowBuffer[futureIndex] = predictedPrice - bandWidth;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Extract numeric value from JSON string                           |
//+------------------------------------------------------------------+
double ExtractValue(string json, string key, int startPos = 0)
{
   int keyPos = StringFind(json, key, startPos);
   if(keyPos < 0)
      return 0.0;

   int valueStart = keyPos + StringLen(key);
   string substr = StringSubstr(json, valueStart, 50);

   //--- Find end of number (comma, brace, or bracket)
   int endPos = 0;
   for(int i = 0; i < StringLen(substr); i++)
   {
      ushort ch = StringGetCharacter(substr, i);
      if(ch == ',' || ch == '}' || ch == ']' || ch == ' ')
      {
         endPos = i;
         break;
      }
   }

   if(endPos == 0)
      endPos = StringLen(substr);

   string valueStr = StringSubstr(substr, 0, endPos);
   return StringToDouble(valueStr);
}

//+------------------------------------------------------------------+
//| Trigger alert                                                     |
//+------------------------------------------------------------------+
void TriggerAlert(string direction, double confidence)
{
   string message = "ML " + direction + " Signal: " + _Symbol +
                    " | Confidence: " + DoubleToString(confidence * 100, 1) + "%";

   //--- Audio alert
   Alert(message);

   //--- Send to bridge/telegram
   SendAlertToBridge(direction, confidence);
}

//+------------------------------------------------------------------+
//| Send alert to bridge                                             |
//+------------------------------------------------------------------+
void SendAlertToBridge(string direction, double confidence)
{
   string url = BridgeURL + "/api/ml/alert";
   string json = "{";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"direction\":\"" + direction + "\",";
   json += "\"confidence\":" + DoubleToString(confidence, 4) + ",";
   json += "\"horizon\":" + IntegerToString(PredictionHorizon) + ",";
   json += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
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

   if(method == "POST")
   {
      StringToCharArray(data, post, 0, StringLen(data));
   }

   int res = WebRequest(method, url, cookie, referer, timeout, post, ArraySize(post), result, headers);

   if(res == -1)
   {
      int err = GetLastError();
      if(err == 4060 && TimeCurrent() % 300 == 0)  // Log once per 5 minutes
      {
         Print("ERROR: Add '", BridgeURL, "' to allowed URLs in Tools->Options->Expert Advisors");
      }
      return "";
   }

   if(res != 200)
      return "";

   return CharArrayToString(result);
}

//+------------------------------------------------------------------+
//| Custom indicator de-initialization                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clear chart objects if any
   Print("MLSignalOverlay shutting down. Reason: ", reason);
}
//+------------------------------------------------------------------+
