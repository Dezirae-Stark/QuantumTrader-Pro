//+------------------------------------------------------------------+
//|                                      QuantumTrendIndicator.mq5 |
//|                        Quantum Market State Visualization        |
//|                                   https://github.com/Dezirae-Stark|
//+------------------------------------------------------------------+
#property copyright "QuantumTrader Pro"
#property link      "https://github.com/Dezirae-Stark/QuantumTrader-Pro"
#property version   "2.10"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   4

//--- Plot properties
#property indicator_label1  "Quantum Bullish"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Quantum Bearish"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "Quantum Neutral"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  1

#property indicator_label4  "Trend Strength"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrDodgerBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

//--- Input Parameters
input int    QuantumPeriod = 20;        // Quantum calculation period
input double ThresholdBullish = 0.6;    // Bullish threshold
input double ThresholdBearish = -0.6;   // Bearish threshold
input bool   EnableAlerts = true;       // Enable audio alerts
input string BridgeURL = "http://localhost:8080";  // Bridge Server URL

//--- Indicator buffers
double BullishBuffer[];
double BearishBuffer[];
double NeutralBuffer[];
double StrengthBuffer[];

//--- Global variables
datetime lastAlertTime = 0;
int alertCooldownSeconds = 300;  // 5 minutes between alerts

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, BullishBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, NeutralBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, StrengthBuffer, INDICATOR_DATA);

   //--- Set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   //--- Set indicator window name
   IndicatorSetString(INDICATOR_SHORTNAME, "QuantumTrend(" + IntegerToString(QuantumPeriod) + ")");

   //--- Initialize buffers with empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   Print("QuantumTrendIndicator v2.1.0 initialized successfully!");
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
   //--- Check for minimum bars
   if(rates_total < QuantumPeriod)
      return(0);

   //--- Determine start position
   int start;
   if(prev_calculated == 0)
      start = QuantumPeriod;
   else
      start = prev_calculated - 1;

   //--- Calculate quantum states for each bar
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate quantum superposition
      double quantumState = CalculateQuantumState(i, close, high, low);

      //--- Calculate trend strength
      double trendStrength = CalculateTrendStrength(i, close);

      //--- Assign to appropriate buffer
      if(quantumState >= ThresholdBullish)
      {
         BullishBuffer[i] = quantumState;
         BearishBuffer[i] = 0.0;
         NeutralBuffer[i] = 0.0;

         //--- Trigger bullish alert
         if(EnableAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > alertCooldownSeconds)
         {
            TriggerAlert("BULLISH", quantumState);
            lastAlertTime = TimeCurrent();
         }
      }
      else if(quantumState <= ThresholdBearish)
      {
         BullishBuffer[i] = 0.0;
         BearishBuffer[i] = quantumState;
         NeutralBuffer[i] = 0.0;

         //--- Trigger bearish alert
         if(EnableAlerts && i == rates_total - 1 && TimeCurrent() - lastAlertTime > alertCooldownSeconds)
         {
            TriggerAlert("BEARISH", quantumState);
            lastAlertTime = TimeCurrent();
         }
      }
      else
      {
         BullishBuffer[i] = 0.0;
         BearishBuffer[i] = 0.0;
         NeutralBuffer[i] = quantumState;
      }

      StrengthBuffer[i] = trendStrength;
   }

   //--- Send data to bridge (latest bar only)
   if(rates_total > 0)
   {
      SendQuantumDataToBridge(rates_total - 1, BullishBuffer, BearishBuffer, NeutralBuffer, StrengthBuffer);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate quantum state using wave function                      |
//+------------------------------------------------------------------+
double CalculateQuantumState(int index, const double &close[], const double &high[], const double &low[])
{
   if(index < QuantumPeriod)
      return 0.0;

   //--- Calculate price wave function components
   double priceSum = 0.0;
   double volatilitySum = 0.0;

   for(int i = 0; i < QuantumPeriod; i++)
   {
      int pos = index - i;
      if(pos < 0)
         break;

      double priceChange = (close[pos] - close[pos - 1]) / close[pos - 1];
      double volatility = (high[pos] - low[pos]) / close[pos];

      priceSum += priceChange;
      volatilitySum += volatility;
   }

   //--- Normalize
   double avgPriceChange = priceSum / QuantumPeriod;
   double avgVolatility = volatilitySum / QuantumPeriod;

   //--- Apply quantum superposition principle
   //--- ψ = α|Bullish⟩ + β|Bearish⟩ + γ|Neutral⟩
   double quantumState = avgPriceChange * (1.0 - avgVolatility);

   //--- Apply Heisenberg uncertainty correction
   double uncertaintyFactor = 1.0 + (avgVolatility * 0.5);
   quantumState /= uncertaintyFactor;

   //--- Normalize to [-1, 1]
   quantumState = MathMax(-1.0, MathMin(1.0, quantumState * 10));

   return quantumState;
}

//+------------------------------------------------------------------+
//| Calculate trend strength                                         |
//+------------------------------------------------------------------+
double CalculateTrendStrength(int index, const double &close[])
{
   if(index < QuantumPeriod)
      return 0.0;

   //--- Calculate momentum
   double momentum = 0.0;
   int upMoves = 0;
   int downMoves = 0;

   for(int i = 1; i < QuantumPeriod; i++)
   {
      int pos = index - i;
      if(pos <= 0)
         break;

      if(close[pos] > close[pos - 1])
         upMoves++;
      else if(close[pos] < close[pos - 1])
         downMoves++;
   }

   //--- Calculate strength as ratio
   int totalMoves = upMoves + downMoves;
   if(totalMoves > 0)
   {
      momentum = (double)(upMoves - downMoves) / totalMoves;
   }

   return momentum;
}

//+------------------------------------------------------------------+
//| Trigger alert                                                     |
//+------------------------------------------------------------------+
void TriggerAlert(string direction, double state)
{
   string message = "Quantum " + direction + " Signal: " + _Symbol + " | State: " + DoubleToString(state, 2);

   //--- Audio alert
   Alert(message);

   //--- Send to bridge
   SendAlertToBridge(direction, state);
}

//+------------------------------------------------------------------+
//| Send quantum data to bridge                                      |
//+------------------------------------------------------------------+
void SendQuantumDataToBridge(int index, const double &bullish[], const double &bearish[], const double &neutral[], const double &strength[])
{
   if(TimeCurrent() % 60 != 0)  // Only send once per minute
      return;

   string url = BridgeURL + "/api/quantum/state";
   string json = "{";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",";
   json += "\"bullish\":" + DoubleToString(bullish[index], 4) + ",";
   json += "\"bearish\":" + DoubleToString(bearish[index], 4) + ",";
   json += "\"neutral\":" + DoubleToString(neutral[index], 4) + ",";
   json += "\"strength\":" + DoubleToString(strength[index], 4);
   json += "}";

   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Send alert to bridge                                             |
//+------------------------------------------------------------------+
void SendAlertToBridge(string direction, double state)
{
   string url = BridgeURL + "/api/quantum/alert";
   string json = "{";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"direction\":\"" + direction + "\",";
   json += "\"state\":" + DoubleToString(state, 4) + ",";
   json += "\"time\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"";
   json += "}";

   SendHTTPRequest(url, "POST", json);
}

//+------------------------------------------------------------------+
//| Send HTTP request to bridge                                      |
//+------------------------------------------------------------------+
void SendHTTPRequest(string url, string method, string data)
{
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string cookie = NULL, referer = NULL;
   int timeout = 2000;

   if(method == "POST")
   {
      StringToCharArray(data, post, 0, StringLen(data));
   }

   //--- Send request (ignore errors for indicators)
   WebRequest(method, url, cookie, referer, timeout, post, ArraySize(post), result, headers);
}
//+------------------------------------------------------------------+
