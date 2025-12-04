import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/app_state.dart';

class MT4Service {
  final Logger _logger = Logger();
  Timer? _pollTimer;
  String _apiEndpoint = 'http://localhost:8080'; // Default endpoint

  Future<void> initialize() async {
    _logger.i('Initializing MT4 Service...');
    startPolling();
  }

  void setApiEndpoint(String endpoint) {
    _apiEndpoint = endpoint;
    _logger.i('MT4 API endpoint set to: $_apiEndpoint');
  }

  void startPolling({int intervalSeconds = 5}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      await fetchSignals();
      await fetchOpenTrades();
    });
    _logger.i('Started polling MT4 API every $intervalSeconds seconds');
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _logger.i('Stopped polling MT4 API');
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
      _logger.e('MT4 connection test failed: $e');
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
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('Connected to MT4: $server, Login: $login');
        return data['success'] == true;
      }
    } catch (e) {
      _logger.e('MT4 connection failed: $e');
    }
    return false;
  }

  void dispose() {
    stopPolling();
  }
}
