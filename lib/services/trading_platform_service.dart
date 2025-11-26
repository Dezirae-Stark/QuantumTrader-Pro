import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';
import 'websocket_service.dart';

// For backward compatibility, create an alias
typedef MT4Service = TradingPlatformService;

/// Unified trading platform service that supports both MT4 and MT5
/// Uses WebSocket for real-time data when available, falls back to HTTP polling
class TradingPlatformService {
  static final TradingPlatformService _instance = TradingPlatformService._internal();
  factory TradingPlatformService() => _instance;
  TradingPlatformService._internal();

  final Logger _logger = Logger();
  final WebSocketService _webSocketService = WebSocketService();
  
  Timer? _pollTimer;
  String _apiEndpoint = 'localhost:8080';
  String? _authToken;
  bool _isInitialized = false;
  bool _useWebSocket = true;
  
  // Callbacks for data updates
  Function(List<TradeSignal>)? onSignalsUpdate;
  Function(List<OpenTrade>)? onTradesUpdate;
  Function(MarketUpdate)? onPriceUpdate;
  
  // Connection state
  bool get isConnected => _useWebSocket ? _webSocketService.isConnected : _pollTimer?.isActive ?? false;
  Stream<WebSocketState> get connectionState => _webSocketService.stateStream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _logger.i('Initializing Trading Platform Service...');
    
    // Load saved configuration
    final prefs = await SharedPreferences.getInstance();
    _apiEndpoint = prefs.getString('bridge_endpoint') ?? _getDefaultEndpoint();
    _authToken = prefs.getString('auth_token');
    _useWebSocket = prefs.getBool('use_websocket') ?? true;
    
    // Initialize WebSocket service
    await _webSocketService.initialize();
    
    // Listen to WebSocket messages
    _webSocketService.messageStream.listen(_handleWebSocketMessage);
    
    _isInitialized = true;
    _logger.i('Trading Platform Service initialized');
  }

  String _getDefaultEndpoint() {
    // Platform-specific default endpoints
    if (Platform.isAndroid) {
      return '10.0.2.2:8080'; // Android emulator
    } else if (Platform.isIOS) {
      return 'localhost:8080'; // iOS simulator
    } else {
      return 'localhost:8080'; // Desktop
    }
  }

  Future<void> connect({
    String? endpoint,
    String? authToken,
    bool? useWebSocket,
  }) async {
    if (!_isInitialized) await initialize();
    
    if (endpoint != null) {
      _apiEndpoint = endpoint;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bridge_endpoint', endpoint);
    }
    
    if (authToken != null) {
      _authToken = authToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', authToken);
    }
    
    if (useWebSocket != null) {
      _useWebSocket = useWebSocket;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_websocket', useWebSocket);
    }
    
    _logger.i('Connecting to: $_apiEndpoint (WebSocket: $_useWebSocket)');
    
    if (_useWebSocket) {
      // Stop polling if active
      stopPolling();
      
      // Connect WebSocket
      await _webSocketService.connect(
        endpoint: _apiEndpoint,
        token: _authToken,
      );
      
      // Subscribe to all symbols
      _subscribeToAllSymbols();
    } else {
      // Disconnect WebSocket if connected
      await _webSocketService.disconnect();
      
      // Start HTTP polling
      startPolling();
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      switch (message['type']) {
        case 'price_update':
          final update = message['data'] as MarketUpdate;
          onPriceUpdate?.call(update);
          break;
          
        case 'signal':
          final signal = message['data'] as TradeSignal;
          // Accumulate signals and call callback
          onSignalsUpdate?.call([signal]);
          break;
          
        case 'position_update':
          final position = message['data'] as OpenTrade;
          // Update positions list
          fetchOpenTrades(); // Refresh full list
          break;
      }
    }
  }

  void _subscribeToAllSymbols() {
    final symbols = ['EURUSD', 'GBPUSD', 'XAUUSD', 'BTCUSD', 'USDJPY'];
    for (final symbol in symbols) {
      _webSocketService.subscribeToSymbol(symbol);
    }
  }

  void startPolling({int intervalSeconds = 5}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      fetchSignals();
      fetchOpenTrades();
    });
    _logger.i('Started HTTP polling every $intervalSeconds seconds');
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _logger.i('Stopped HTTP polling');
  }

  String get _httpEndpoint => _apiEndpoint.startsWith('http') 
      ? _apiEndpoint 
      : 'http://$_apiEndpoint';

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  Future<List<TradeSignal>> fetchSignals() async {
    try {
      final response = await http.get(
        Uri.parse('$_httpEndpoint/api/signals'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<TradeSignal> signals;
        
        if (data is List) {
          signals = data.map((item) => TradeSignal.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('signals')) {
          signals = (data['signals'] as List)
              .map((item) => TradeSignal.fromJson(item))
              .toList();
        } else {
          signals = [];
        }
        
        onSignalsUpdate?.call(signals);
        return signals;
      }
    } catch (e) {
      _logger.e('Error fetching signals: $e');
    }
    return [];
  }

  Future<List<OpenTrade>> fetchOpenTrades() async {
    try {
      final response = await http.get(
        Uri.parse('$_httpEndpoint/api/positions'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<OpenTrade> trades;
        
        if (data is List) {
          trades = data.map((item) => OpenTrade.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('positions')) {
          trades = (data['positions'] as List)
              .map((item) => OpenTrade.fromJson(item))
              .toList();
        } else {
          trades = [];
        }
        
        onTradesUpdate?.call(trades);
        return trades;
      }
    } catch (e) {
      _logger.e('Error fetching open trades: $e');
    }
    return [];
  }

  Future<bool> executeTrade({
    required String symbol,
    required TradeType type,
    required double lots,
    double? stopLoss,
    double? takeProfit,
    String? comment,
  }) async {
    try {
      final body = {
        'symbol': symbol,
        'type': type == TradeType.buy ? 'BUY' : 'SELL',
        'lots': lots,
        'stop_loss': stopLoss,
        'take_profit': takeProfit,
        'comment': comment ?? 'QuantumTrader-${DateTime.now().millisecondsSinceEpoch}',
      };
      
      final response = await http.post(
        Uri.parse('$_httpEndpoint/api/trade'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        _logger.i('Trade executed successfully: ${data['ticket']}');
        
        // Refresh positions
        fetchOpenTrades();
        return true;
      } else {
        final error = json.decode(response.body);
        _logger.e('Trade execution failed: ${error['error']}');
      }
    } catch (e) {
      _logger.e('Error executing trade: $e');
    }
    return false;
  }

  Future<bool> closePosition(int ticket) async {
    try {
      final response = await http.post(
        Uri.parse('$_httpEndpoint/api/trade/close/$ticket'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _logger.i('Position $ticket closed successfully');
        
        // Refresh positions
        fetchOpenTrades();
        return true;
      }
    } catch (e) {
      _logger.e('Error closing position: $e');
    }
    return false;
  }

  Future<bool> modifyPosition({
    required int ticket,
    double? stopLoss,
    double? takeProfit,
  }) async {
    try {
      final body = {
        'ticket': ticket,
        'stop_loss': stopLoss,
        'take_profit': takeProfit,
      };
      
      final response = await http.put(
        Uri.parse('$_httpEndpoint/api/trade/modify'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _logger.i('Position $ticket modified successfully');
        
        // Refresh positions
        fetchOpenTrades();
        return true;
      }
    } catch (e) {
      _logger.e('Error modifying position: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>?> getAccountInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_httpEndpoint/api/account'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      _logger.e('Error fetching account info: $e');
    }
    return null;
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_httpEndpoint/api/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
    } catch (e) {
      _logger.e('Connection test failed: $e');
    }
    return false;
  }

  Future<bool> connectToBroker({
    required String platform, // MT4 or MT5
    required String server,
    required int login,
    required String password,
  }) async {
    try {
      final body = {
        'platform': platform,
        'server': server,
        'login': login,
        'password': password,
      };
      
      final response = await http.post(
        Uri.parse('$_httpEndpoint/api/broker/connect'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('Connected to $platform broker: $server');
        
        // Save connection info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('broker_platform', platform);
        await prefs.setString('broker_server', server);
        await prefs.setInt('broker_login', login);
        
        return data['success'] == true;
      }
    } catch (e) {
      _logger.e('Broker connection failed: $e');
    }
    return false;
  }

  void switchMode(bool useWebSocket) {
    if (_useWebSocket != useWebSocket) {
      connect(useWebSocket: useWebSocket);
    }
  }

  void dispose() {
    stopPolling();
    _webSocketService.dispose();
  }
}