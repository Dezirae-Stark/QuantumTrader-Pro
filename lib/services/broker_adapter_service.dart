import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_state.dart';

enum BrokerType { mt4, mt5 }

class BrokerAdapterService {
  final Logger _logger = Logger();
  Timer? _pollTimer;
  String _apiEndpoint = '';
  BrokerType _brokerType = BrokerType.mt4;
  bool _isConnected = false;
  
  // Cached credentials
  int? _login;
  String? _password;
  String? _server;
  
  // Settings box
  late Box _settingsBox;

  BrokerAdapterService() {
    _initializeSettingsBox();
  }

  Future<void> _initializeSettingsBox() async {
    _settingsBox = await Hive.openBox('broker_settings');
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    _login = _settingsBox.get('broker_login');
    _password = _settingsBox.get('broker_password');
    _server = _settingsBox.get('broker_server');
    _apiEndpoint = _settingsBox.get('broker_api_endpoint', defaultValue: 'http://localhost:8080');
    final savedType = _settingsBox.get('broker_type', defaultValue: 'mt4');
    _brokerType = savedType == 'mt5' ? BrokerType.mt5 : BrokerType.mt4;
  }

  Future<void> saveBrokerSettings({
    required int login,
    required String password,
    required String server,
    required String apiEndpoint,
    required BrokerType brokerType,
  }) async {
    await _settingsBox.put('broker_login', login);
    await _settingsBox.put('broker_password', password);
    await _settingsBox.put('broker_server', server);
    await _settingsBox.put('broker_api_endpoint', apiEndpoint);
    await _settingsBox.put('broker_type', brokerType == BrokerType.mt5 ? 'mt5' : 'mt4');
    
    _login = login;
    _password = password;
    _server = server;
    _apiEndpoint = apiEndpoint;
    _brokerType = brokerType;
    
    _logger.i('Broker settings saved: ${brokerType.name} - Login: $login, Server: $server');
  }

  BrokerType get brokerType => _brokerType;
  bool get isConnected => _isConnected;
  String get apiEndpoint => _apiEndpoint;
  int? get savedLogin => _login;
  String? get savedServer => _server;

  Future<void> initialize() async {
    _logger.i('Initializing Broker Adapter Service...');
    if (_login != null && _password != null && _server != null) {
      await connect(
        login: _login!,
        password: _password!,
        server: _server!,
      );
    }
  }

  void setApiEndpoint(String endpoint) {
    _apiEndpoint = endpoint;
    _settingsBox.put('broker_api_endpoint', endpoint);
    _logger.i('Broker API endpoint set to: $_apiEndpoint');
  }

  void setBrokerType(BrokerType type) {
    _brokerType = type;
    _settingsBox.put('broker_type', type == BrokerType.mt5 ? 'mt5' : 'mt4');
    _logger.i('Broker type set to: ${type.name}');
  }

  void startPolling({int intervalSeconds = 5}) {
    if (!_isConnected) {
      _logger.w('Cannot start polling - not connected to broker');
      return;
    }
    
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      fetchMarketData();
      fetchOpenTrades();
      fetchAccountInfo();
    });
    _logger.i('Started polling broker API every $intervalSeconds seconds');
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _logger.i('Stopped polling broker API');
  }

  Future<Map<String, dynamic>> fetchMarketData() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiEndpoint/api/market_data'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      _logger.e('Error fetching market data: $e');
    }
    return {};
  }

  Future<List<TradeSignal>> fetchSignals() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiEndpoint/api/signals'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => TradeSignal.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('signals')) {
          return (data['signals'] as List)
              .map((item) => TradeSignal.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      _logger.e('Error fetching signals: $e');
    }
    return [];
  }

  Future<List<OpenTrade>> fetchOpenTrades() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiEndpoint/api/trades'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((item) => OpenTrade.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('trades')) {
          return (data['trades'] as List)
              .map((item) => OpenTrade.fromJson(item))
              .toList();
        }
      }
    } catch (e) {
      _logger.e('Error fetching open trades: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchAccountInfo() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiEndpoint/api/account'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      _logger.e('Error fetching account info: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchPredictions() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_apiEndpoint/api/predictions'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      _logger.e('Error fetching predictions: $e');
    }
    return null;
  }

  Future<bool> sendTradeOrder({
    required String symbol,
    required String orderType,
    required double volume,
    double? stopLoss,
    double? takeProfit,
  }) async {
    if (!_isConnected) {
      _logger.w('Cannot send order - not connected to broker');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint/api/order'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'symbol': symbol,
              'type': orderType,
              'volume': volume,
              'stop_loss': stopLoss,
              'take_profit': takeProfit,
              'broker_type': _brokerType.name,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('Trade order sent successfully');
        return true;
      }
    } catch (e) {
      _logger.e('Error sending trade order: $e');
    }
    return false;
  }

  Future<bool> closePosition(String positionId) async {
    if (!_isConnected) {
      _logger.w('Cannot close position - not connected to broker');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint/api/close/$positionId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _logger.i('Position closed successfully');
        return true;
      }
    } catch (e) {
      _logger.e('Error closing position: $e');
    }
    return false;
  }

  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiEndpoint/api/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('Broker connection test failed: $e');
      return false;
    }
  }

  Future<bool> connect({
    required int login,
    required String password,
    required String server,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiEndpoint/api/connect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'login': login,
              'password': password,
              'server': server,
              'broker_type': _brokerType.name,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isConnected = data['success'] == true;
        
        if (_isConnected) {
          _logger.i('Connected to ${_brokerType.name.toUpperCase()}: $server, Login: $login');
          // Save successful connection details
          await saveBrokerSettings(
            login: login,
            password: password,
            server: server,
            apiEndpoint: _apiEndpoint,
            brokerType: _brokerType,
          );
          startPolling();
        }
        
        return _isConnected;
      }
    } catch (e) {
      _logger.e('${_brokerType.name.toUpperCase()} connection failed: $e');
    }
    _isConnected = false;
    return false;
  }

  Future<void> disconnect() async {
    stopPolling();
    _isConnected = false;
    
    try {
      await http.post(
        Uri.parse('$_apiEndpoint/api/disconnect'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      _logger.e('Error disconnecting: $e');
    }
    
    _logger.i('Disconnected from broker');
  }

  void dispose() {
    stopPolling();
    disconnect();
  }
}