import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';

enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  StreamController<dynamic>? _messageController;
  StreamController<WebSocketState>? _stateController;
  
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  String? _wsUrl;
  String? _authToken;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final Duration _reconnectDelay = const Duration(seconds: 5);
  
  bool _isConnected = false;
  bool _shouldReconnect = true;
  
  // Streams
  Stream<dynamic> get messageStream => _messageController?.stream ?? const Stream.empty();
  Stream<WebSocketState> get stateStream => _stateController?.stream ?? const Stream.empty();
  
  // Current state
  WebSocketState _currentState = WebSocketState.disconnected;
  WebSocketState get currentState => _currentState;
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    _logger.i('Initializing WebSocket service...');
    
    _messageController = StreamController<dynamic>.broadcast();
    _stateController = StreamController<WebSocketState>.broadcast();
    
    // Load saved endpoint
    final prefs = await SharedPreferences.getInstance();
    final savedEndpoint = prefs.getString('bridge_endpoint') ?? 'localhost:8080';
    _wsUrl = 'ws://$savedEndpoint/ws';
    _authToken = prefs.getString('auth_token');
    
    _logger.i('WebSocket URL: $_wsUrl');
  }

  Future<void> connect({String? endpoint, String? token}) async {
    if (endpoint != null) {
      _wsUrl = endpoint.startsWith('ws://') || endpoint.startsWith('wss://') 
          ? endpoint 
          : 'ws://$endpoint/ws';
          
      // Save endpoint
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bridge_endpoint', endpoint.replaceAll('ws://', '').replaceAll('/ws', ''));
    }
    
    if (token != null) {
      _authToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
    
    _shouldReconnect = true;
    await _connect();
  }

  Future<void> _connect() async {
    if (_currentState == WebSocketState.connecting || 
        _currentState == WebSocketState.connected) {
      _logger.w('Already connected or connecting');
      return;
    }
    
    _updateState(WebSocketState.connecting);
    
    try {
      _logger.i('Connecting to WebSocket: $_wsUrl');
      
      // Add auth token to URL if available
      final connectUrl = _authToken != null 
          ? '$_wsUrl?token=$_authToken'
          : _wsUrl!;
      
      _channel = IOWebSocketChannel.connect(
        connectUrl,
        pingInterval: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 10),
      );
      
      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );
      
      // Send initial handshake
      _sendHandshake();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _updateState(WebSocketState.connected);
      
      _logger.i('WebSocket connected successfully');
      
    } catch (e) {
      _logger.e('WebSocket connection failed: $e');
      _handleError(e);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message);
      _logger.d('Received message: ${data['type']}');
      
      // Handle different message types
      switch (data['type']) {
        case 'pong':
          // Heartbeat response
          break;
          
        case 'handshake':
          _logger.i('Handshake successful');
          break;
          
        case 'price_update':
          _handlePriceUpdate(data['data']);
          break;
          
        case 'signal':
          _handleSignalUpdate(data['data']);
          break;
          
        case 'position_update':
          _handlePositionUpdate(data['data']);
          break;
          
        case 'error':
          _logger.e('Server error: ${data['message']}');
          break;
          
        default:
          _messageController?.add(data);
      }
      
    } catch (e) {
      _logger.e('Error parsing message: $e');
    }
  }

  void _handlePriceUpdate(Map<String, dynamic> data) {
    final update = MarketUpdate(
      symbol: data['symbol'],
      bid: data['bid'].toDouble(),
      ask: data['ask'].toDouble(),
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      spread: data['spread']?.toDouble() ?? (data['ask'] - data['bid']).toDouble(),
      volume: data['volume'] ?? 0,
    );
    
    _messageController?.add({
      'type': 'price_update',
      'data': update,
    });
  }

  void _handleSignalUpdate(Map<String, dynamic> data) {
    final signal = TradeSignal(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: data['symbol'] ?? 'UNKNOWN',
      trend: _parseTrendFromPrediction(data['prediction']),
      probability: (data['confidence'] ?? 0.0).toDouble(),
      action: 'entry',
      timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
      mlPrediction: data,
    );
    
    _messageController?.add({
      'type': 'signal',
      'data': signal,
    });
  }

  TrendDirection _parseTrendFromPrediction(dynamic prediction) {
    if (prediction == null) return TrendDirection.neutral;
    final predStr = prediction.toString().toLowerCase();
    if (predStr.contains('buy') || predStr.contains('bull')) return TrendDirection.bullish;
    if (predStr.contains('sell') || predStr.contains('bear')) return TrendDirection.bearish;
    return TrendDirection.neutral;
  }

  void _handlePositionUpdate(Map<String, dynamic> data) {
    final position = OpenTrade(
      ticket: data['ticket'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: data['symbol'] ?? 'UNKNOWN',
      type: data['type'] == 'BUY' ? 'buy' : 'sell',
      entryPrice: data['open_price']?.toDouble() ?? 0.0,
      currentPrice: data['current_price']?.toDouble() ?? 0.0,
      volume: data['lots']?.toDouble() ?? 0.0,
      profitLoss: data['profit']?.toDouble() ?? 0.0,
      openTime: DateTime.parse(data['open_time'] ?? DateTime.now().toIso8601String()),
    );
    
    _messageController?.add({
      'type': 'position_update',
      'data': position,
    });
  }

  void _handleError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _updateState(WebSocketState.error);
    
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDisconnect() {
    _logger.w('WebSocket disconnected');
    _isConnected = false;
    _updateState(WebSocketState.disconnected);
    
    _heartbeatTimer?.cancel();
    
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e('Max reconnection attempts reached');
      _updateState(WebSocketState.error);
      return;
    }
    
    _reconnectAttempts++;
    _updateState(WebSocketState.reconnecting);
    
    final delay = _reconnectDelay * _reconnectAttempts;
    _logger.i('Reconnecting in ${delay.inSeconds} seconds (attempt $_reconnectAttempts)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        _connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        sendMessage({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  void _sendHandshake() {
    sendMessage({
      'type': 'handshake',
      'version': '2.0',
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        final jsonMessage = json.encode(message);
        _channel!.sink.add(jsonMessage);
        _logger.d('Sent message: ${message['type']}');
      } catch (e) {
        _logger.e('Error sending message: $e');
      }
    } else {
      _logger.w('Cannot send message - not connected');
    }
  }

  void subscribeToSymbol(String symbol) {
    sendMessage({
      'type': 'subscribe',
      'symbol': symbol,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void unsubscribeFromSymbol(String symbol) {
    sendMessage({
      'type': 'unsubscribe',
      'symbol': symbol,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void requestSignals({double? minConfidence}) {
    sendMessage({
      'type': 'get_signals',
      'min_confidence': minConfidence ?? 0.7,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _updateState(WebSocketState newState) {
    _currentState = newState;
    _stateController?.add(newState);
  }

  Future<void> disconnect() async {
    _logger.i('Disconnecting WebSocket...');
    
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    await _channel?.sink.close();
    _channel = null;
    
    _isConnected = false;
    _updateState(WebSocketState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController?.close();
    _stateController?.close();
  }
}

// Data models
class MarketUpdate {
  final String symbol;
  final double bid;
  final double ask;
  final DateTime timestamp;
  final double spread;
  final int volume;

  MarketUpdate({
    required this.symbol,
    required this.bid,
    required this.ask,
    required this.timestamp,
    required this.spread,
    required this.volume,
  });
}