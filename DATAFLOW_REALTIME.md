# QuantumTrader-Pro Real-Time Data Flow Architecture

## Overview

This document details the complete real-time data flow architecture of QuantumTrader-Pro, from market data acquisition through ML processing to trade execution and user notification.

## Data Flow Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│   Market    │────▶│    Bridge    │────▶│     ML      │────▶│   Trading    │
│   (MT4/5)   │     │   Server     │     │   Engine    │     │  Execution   │
└─────────────┘     └──────┬───────┘     └──────┬──────┘     └──────────────┘
                           │                     │
                           ▼                     ▼
                    ┌──────────────┐     ┌──────────────┐
                    │   Flutter    │     │   Signal     │
                    │     App      │◀────│   Storage    │
                    └──────────────┘     └──────────────┘
```

## Detailed Component Data Flows

### 1. Market Data Acquisition

**Source: MT4/MT5 Terminal**

```mql4
// Data Collection in EA (Every tick)
void OnTick() {
    MarketData data;
    data.symbol = _Symbol;
    data.bid = Bid;
    data.ask = Ask;
    data.time = TimeCurrent();
    data.volume = iVolume(_Symbol, 0, 0);
    
    // Send to bridge via HTTP POST
    SendMarketData(data);
}
```

**Data Format:**
```json
{
  "symbol": "EURUSD",
  "bid": 1.0855,
  "ask": 1.0856,
  "spread": 0.0001,
  "time": "2024-01-15T10:30:45Z",
  "volume": 125,
  "high": 1.0865,
  "low": 1.0845,
  "open": 1.0850
}
```

**Frequency:** Every tick (typically 2-10 updates/second per symbol)

### 2. Bridge Server Processing

**WebSocket Bridge Flow:**

```javascript
// Incoming market data
app.post('/api/market', authenticateToken, (req, res) => {
    const marketData = req.body;
    
    // Validate data
    if (!validateMarketData(marketData)) {
        return res.status(400).json({ error: 'Invalid data' });
    }
    
    // Store for ML processing
    storeMarketData(marketData);
    
    // Broadcast to connected clients
    broadcastToWebSocket('price_update', marketData);
    
    // Return acknowledgment
    res.json({ status: 'received', timestamp: Date.now() });
});

// WebSocket broadcast
function broadcastToWebSocket(type, data) {
    const message = {
        type: type,
        data: data,
        timestamp: new Date().toISOString()
    };
    
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(message));
        }
    });
}
```

**Data Storage:**
```javascript
// File-based storage for ML consumption
function storeMarketData(data) {
    const filename = `bridge/data/${data.symbol}_market.json`;
    const historicalData = loadExistingData(filename);
    
    // Append new data
    historicalData.push(data);
    
    // Keep only last 1000 ticks
    if (historicalData.length > 1000) {
        historicalData = historicalData.slice(-1000);
    }
    
    fs.writeFileSync(filename, JSON.stringify(historicalData, null, 2));
}
```

### 3. ML Engine Processing Pipeline

**Data Ingestion:**

```python
class MarketDataProcessor:
    def __init__(self, config):
        self.symbols = config['symbols']
        self.update_interval = config['update_interval']  # 10 seconds
        self.data_path = 'bridge/data/'
        
    def load_market_data(self, symbol):
        """Load latest market data from bridge storage"""
        filename = f"{self.data_path}{symbol}_market.json"
        
        try:
            with open(filename, 'r') as f:
                data = json.load(f)
                
            # Convert to pandas DataFrame
            df = pd.DataFrame(data)
            df['time'] = pd.to_datetime(df['time'])
            df.set_index('time', inplace=True)
            
            return df
        except Exception as e:
            logger.error(f"Error loading data for {symbol}: {e}")
            return pd.DataFrame()
```

**Feature Engineering:**

```python
def extract_features(self, df):
    """Extract ML features from raw market data"""
    features = pd.DataFrame(index=df.index)
    
    # Price features
    features['returns'] = df['bid'].pct_change()
    features['log_returns'] = np.log(df['bid'] / df['bid'].shift(1))
    
    # Volatility features
    features['volatility_5'] = features['returns'].rolling(5).std()
    features['volatility_20'] = features['returns'].rolling(20).std()
    
    # Technical indicators
    features['rsi'] = self.calculate_rsi(df['bid'], 14)
    features['macd'], features['signal'] = self.calculate_macd(df['bid'])
    
    # Market microstructure
    features['spread'] = df['ask'] - df['bid']
    features['spread_pct'] = features['spread'] / df['bid']
    features['volume_rate'] = df['volume'].rolling(5).mean()
    
    # Quantum features
    features['wave_function'] = self.quantum_predictor.calculate_wave_function(df)
    features['chaos_index'] = self.chaos_analyzer.calculate_lyapunov(df)
    
    return features
```

**Prediction Generation:**

```python
def generate_predictions(self, symbol, features):
    """Generate trading predictions using ensemble models"""
    
    # Prepare input data
    X = features.dropna().values[-1:, :]  # Latest features
    
    # Run predictions through ensemble
    predictions = {
        'quantum': self.quantum_model.predict(X),
        'chaos': self.chaos_model.predict(X),
        'ml_ensemble': self.ml_ensemble.predict(X),
        'technical': self.technical_analyzer.predict(X)
    }
    
    # Weighted combination
    weights = {'quantum': 0.3, 'chaos': 0.2, 'ml_ensemble': 0.4, 'technical': 0.1}
    final_prediction = sum(pred * weights[name] 
                          for name, pred in predictions.items())
    
    # Generate signal
    signal = {
        'symbol': symbol,
        'timestamp': datetime.now().isoformat(),
        'prediction': 'BUY' if final_prediction > 0.7 else 'SELL' if final_prediction < 0.3 else 'HOLD',
        'confidence': abs(final_prediction),
        'components': predictions,
        'features': features.iloc[-1].to_dict()
    }
    
    return signal
```

### 4. Signal Distribution

**Signal Storage:**

```python
def save_signal(self, signal):
    """Save signal for distribution"""
    # Save to JSON for immediate consumption
    filename = 'predictions/signal_output.json'
    
    # Load existing signals
    try:
        with open(filename, 'r') as f:
            signals = json.load(f)
    except:
        signals = []
    
    # Append new signal
    signals.append(signal)
    
    # Keep only last 100 signals
    signals = signals[-100:]
    
    # Save back
    with open(filename, 'w') as f:
        json.dump(signals, f, indent=2)
    
    # Also save to time-series database if configured
    if self.timeseries_db:
        self.timeseries_db.insert(signal)
```

**Bridge Server Signal API:**

```javascript
// Serve latest signals
app.get('/api/signals', authenticateToken, (req, res) => {
    try {
        const signals = JSON.parse(
            fs.readFileSync('predictions/signal_output.json', 'utf8')
        );
        
        // Filter by confidence if requested
        const minConfidence = req.query.min_confidence || 0.7;
        const filtered = signals.filter(s => s.confidence >= minConfidence);
        
        res.json({
            signals: filtered,
            count: filtered.length,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: 'Failed to load signals' });
    }
});
```

### 5. Mobile App Real-Time Updates

**WebSocket Connection:**

```dart
class WebSocketService {
  WebSocketChannel? _channel;
  final _streamController = StreamController<MarketUpdate>.broadcast();
  
  void connect(String endpoint) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://$endpoint/ws'),
    );
    
    _channel!.stream.listen((message) {
      final data = json.decode(message);
      
      switch (data['type']) {
        case 'price_update':
          _handlePriceUpdate(data['data']);
          break;
        case 'signal':
          _handleSignalUpdate(data['data']);
          break;
        case 'position_update':
          _handlePositionUpdate(data['data']);
          break;
      }
    });
  }
  
  void _handlePriceUpdate(Map<String, dynamic> data) {
    final update = MarketUpdate(
      symbol: data['symbol'],
      bid: data['bid'],
      ask: data['ask'],
      timestamp: DateTime.parse(data['timestamp']),
    );
    
    _streamController.add(update);
  }
}
```

**State Management:**

```dart
class MarketDataProvider extends ChangeNotifier {
  final Map<String, MarketData> _marketData = {};
  final List<TradeSignal> _signals = [];
  
  void updateMarketData(MarketUpdate update) {
    _marketData[update.symbol] = MarketData(
      symbol: update.symbol,
      currentBid: update.bid,
      currentAsk: update.ask,
      lastUpdate: update.timestamp,
    );
    
    notifyListeners();
  }
  
  void addSignal(TradeSignal signal) {
    _signals.insert(0, signal);
    
    // Keep only last 50 signals
    if (_signals.length > 50) {
      _signals.removeLast();
    }
    
    notifyListeners();
    
    // Show notification
    _showSignalNotification(signal);
  }
}
```

### 6. Trade Execution Flow

**Signal to Trade:**

```dart
// Mobile app initiates trade
Future<bool> executeTrade(TradeSignal signal) async {
  final trade = TradeRequest(
    symbol: signal.symbol,
    type: signal.type,
    lots: calculatePositionSize(signal),
    stopLoss: calculateStopLoss(signal),
    takeProfit: calculateTakeProfit(signal),
    comment: 'QuantumTrader-${signal.id}',
  );
  
  final response = await http.post(
    Uri.parse('$apiEndpoint/api/trade'),
    headers: {'Authorization': 'Bearer $token'},
    body: json.encode(trade.toJson()),
  );
  
  return response.statusCode == 200;
}
```

**Bridge to MT4/MT5:**

```javascript
// Bridge server handles trade request
app.post('/api/trade', authenticateToken, validateTrade, async (req, res) => {
    const trade = req.body;
    
    // Forward to MT4/MT5
    const mt4Response = await forwardToMT4(trade);
    
    if (mt4Response.success) {
        // Update position tracking
        updatePositions(mt4Response.ticket, trade);
        
        // Broadcast position update
        broadcastToWebSocket('position_update', {
            ticket: mt4Response.ticket,
            symbol: trade.symbol,
            type: trade.type,
            status: 'opened'
        });
        
        res.json({
            success: true,
            ticket: mt4Response.ticket,
            message: 'Trade executed successfully'
        });
    } else {
        res.status(400).json({
            success: false,
            error: mt4Response.error
        });
    }
});
```

### 7. Real-Time Position Monitoring

**MT4/MT5 Position Updates:**

```mql4
// Monitor open positions
void CheckPositions() {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderMagicNumber() == MAGIC_NUMBER) {
                PositionData pos;
                pos.ticket = OrderTicket();
                pos.symbol = OrderSymbol();
                pos.profit = OrderProfit();
                pos.swap = OrderSwap();
                pos.commission = OrderCommission();
                
                // Send update if changed
                if (HasPositionChanged(pos)) {
                    SendPositionUpdate(pos);
                }
            }
        }
    }
}
```

## Data Flow Optimization

### 1. Latency Reduction

**Target Latencies:**
- Market data to bridge: <50ms
- Bridge to ML: <100ms
- ML prediction: <500ms
- Signal to mobile: <100ms
- Trade execution: <1000ms

**Optimization Strategies:**
```python
# Use multiprocessing for parallel symbol processing
from multiprocessing import Pool

def process_symbols_parallel(symbols):
    with Pool(processes=4) as pool:
        results = pool.map(process_single_symbol, symbols)
    return results

# Cache predictions to reduce computation
@lru_cache(maxsize=128)
def get_cached_prediction(symbol, features_hash):
    return generate_prediction(symbol, features_hash)
```

### 2. Data Compression

**WebSocket Compression:**
```javascript
const WebSocket = require('ws');

const wss = new WebSocket.Server({
    port: 8080,
    perMessageDeflate: {
        zlibDeflateOptions: {
            level: zlib.Z_BEST_COMPRESSION,
        },
        threshold: 1024 // Compress messages > 1KB
    }
});
```

**Batch Updates:**
```dart
// Mobile app batches UI updates
Timer.periodic(Duration(milliseconds: 100), (timer) {
  if (_pendingUpdates.isNotEmpty) {
    setState(() {
      _marketData.addAll(_pendingUpdates);
      _pendingUpdates.clear();
    });
  }
});
```

### 3. Failover & Redundancy

**Connection Recovery:**
```dart
class ResilientWebSocket {
  int _retryCount = 0;
  Timer? _reconnectTimer;
  
  void _handleDisconnect() {
    _reconnectTimer = Timer(
      Duration(seconds: min(pow(2, _retryCount).toInt(), 60)),
      () {
        _retryCount++;
        connect();
      }
    );
  }
  
  void _handleConnect() {
    _retryCount = 0;
    _reconnectTimer?.cancel();
  }
}
```

## Monitoring & Metrics

### 1. Data Flow Metrics

```python
class DataFlowMonitor:
    def __init__(self):
        self.metrics = {
            'market_data_rate': deque(maxlen=1000),
            'prediction_latency': deque(maxlen=1000),
            'signal_generation_time': deque(maxlen=1000),
            'trade_execution_time': deque(maxlen=1000)
        }
    
    def record_market_data(self, symbol, timestamp):
        self.metrics['market_data_rate'].append({
            'symbol': symbol,
            'timestamp': timestamp,
            'delay': (datetime.now() - timestamp).total_seconds()
        })
    
    def get_statistics(self):
        return {
            metric: {
                'avg': np.mean([m['delay'] for m in data]),
                'p95': np.percentile([m['delay'] for m in data], 95),
                'p99': np.percentile([m['delay'] for m in data], 99)
            }
            for metric, data in self.metrics.items()
        }
```

### 2. Health Checks

```javascript
// Bridge server health endpoint
app.get('/api/health', (req, res) => {
    const health = {
        status: 'healthy',
        uptime: process.uptime(),
        connections: {
            mt4: checkMT4Connection(),
            ml: checkMLConnection(),
            websocket_clients: wss.clients.size
        },
        data_flow: {
            last_market_update: lastMarketUpdate,
            last_signal: lastSignalTime,
            pending_trades: pendingTrades.size
        },
        memory: process.memoryUsage(),
        timestamp: new Date().toISOString()
    };
    
    res.json(health);
});
```

## Security Considerations

### 1. Data Encryption

```python
# Encrypt sensitive signals
from cryptography.fernet import Fernet

class SecureSignalStorage:
    def __init__(self, key):
        self.cipher = Fernet(key)
    
    def save_signal(self, signal):
        # Encrypt sensitive fields
        signal['encrypted_data'] = self.cipher.encrypt(
            json.dumps({
                'prediction': signal['prediction'],
                'confidence': signal['confidence']
            }).encode()
        )
        
        # Remove plain text sensitive data
        del signal['prediction']
        del signal['confidence']
        
        return signal
```

### 2. Rate Limiting

```javascript
// Prevent data flooding
const dataRateLimit = rateLimit({
    windowMs: 1000, // 1 second
    max: 10, // 10 updates per second per symbol
    keyGenerator: (req) => req.body.symbol
});

app.post('/api/market', dataRateLimit, processMarketData);
```

## Troubleshooting Data Flow

### Common Issues

1. **Missing Market Data**
   - Check MT4/MT5 WebRequest permissions
   - Verify bridge server is running
   - Check file permissions in bridge/data/

2. **Delayed Predictions**
   - Monitor ML processing time
   - Check CPU/memory usage
   - Verify feature extraction performance

3. **WebSocket Disconnections**
   - Check network stability
   - Monitor connection limits
   - Verify authentication tokens

4. **Signal Delivery Failures**
   - Check signal confidence thresholds
   - Verify mobile app connectivity
   - Monitor push notification service

## Performance Benchmarks

| Data Flow Stage | Target Latency | Current | Status |
|----------------|----------------|---------|---------|
| Market Data Collection | <50ms | 45ms | ✅ |
| Bridge Processing | <20ms | 18ms | ✅ |
| ML Feature Extraction | <200ms | 180ms | ✅ |
| Prediction Generation | <300ms | 450ms | ⚠️ |
| Signal Distribution | <50ms | 40ms | ✅ |
| Mobile App Update | <100ms | 95ms | ✅ |
| Trade Execution | <1000ms | 850ms | ✅ |

## Future Enhancements

1. **Streaming ML Inference**
   - Implement online learning
   - Real-time model updates
   - Continuous feature extraction

2. **Edge Computing**
   - On-device ML inference
   - Reduced latency
   - Offline capability

3. **Multi-Region Deployment**
   - Geographic distribution
   - Reduced latency globally
   - Failover capability

4. **Advanced Protocols**
   - gRPC for lower latency
   - Protocol buffers for efficiency
   - HTTP/3 support