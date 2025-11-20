/// Broker Service Abstraction for QuantumTrader Pro
/// Supports multiple broker providers: MT4, MT5, Oanda, Binance, Generic REST
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Broker provider types
enum BrokerProvider {
  mt4('MT4', 'MetaTrader 4'),
  mt5('MT5', 'MetaTrader 5'),
  oanda('Oanda', 'Oanda'),
  binance('Binance', 'Binance'),
  generic('Generic', 'Generic REST API');

  const BrokerProvider(this.id, this.displayName);
  final String id;
  final String displayName;

  static BrokerProvider fromString(String value) {
    return BrokerProvider.values.firstWhere(
      (e) => e.id.toLowerCase() == value.toLowerCase(),
      orElse: () => BrokerProvider.generic,
    );
  }
}

/// Order side (buy/sell)
enum OrderSide { buy, sell }

/// Order type
enum OrderType { market, limit, stop, stopLimit }

/// Order status
enum OrderStatus {
  pending,
  accepted,
  partiallyFilled,
  filled,
  cancelled,
  rejected,
  expired
}

/// Market data candle (OHLC)
class Candle {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  Candle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  double get typicalPrice => (high + low + close) / 3;

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      timestamp: DateTime.parse(json['timestamp'] as String),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }
}

/// Trading order
class Order {
  final String orderId;
  final String symbol;
  final OrderSide side;
  final double quantity;
  final OrderType orderType;
  final OrderStatus status;
  final double? price;
  final double? stopPrice;
  final double? stopLoss;
  final double? takeProfit;
  final DateTime timestamp;

  Order({
    required this.orderId,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.orderType,
    required this.status,
    this.price,
    this.stopPrice,
    this.stopLoss,
    this.takeProfit,
    required this.timestamp,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      orderId: json['order_id'] as String,
      symbol: json['symbol'] as String,
      side: json['side'] == 'buy' ? OrderSide.buy : OrderSide.sell,
      quantity: (json['quantity'] as num).toDouble(),
      orderType: _parseOrderType(json['order_type'] as String),
      status: _parseOrderStatus(json['status'] as String),
      price: (json['price'] as num?)?.toDouble(),
      stopPrice: (json['stop_price'] as num?)?.toDouble(),
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      takeProfit: (json['take_profit'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  static OrderType _parseOrderType(String type) {
    switch (type.toLowerCase()) {
      case 'limit':
        return OrderType.limit;
      case 'stop':
        return OrderType.stop;
      case 'stop_limit':
        return OrderType.stopLimit;
      default:
        return OrderType.market;
    }
  }

  static OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'accepted':
        return OrderStatus.accepted;
      case 'partially_filled':
        return OrderStatus.partiallyFilled;
      case 'filled':
        return OrderStatus.filled;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'rejected':
        return OrderStatus.rejected;
      case 'expired':
        return OrderStatus.expired;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Account information
class AccountInfo {
  final String accountId;
  final double balance;
  final double equity;
  final double margin;
  final double freeMargin;
  final double marginLevel;
  final double floatingPl;
  final String currency;
  final int leverage;
  final int openPositions;

  AccountInfo({
    required this.accountId,
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.floatingPl,
    required this.currency,
    required this.leverage,
    required this.openPositions,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      accountId: json['account_id'] as String,
      balance: (json['balance'] as num).toDouble(),
      equity: (json['equity'] as num).toDouble(),
      margin: (json['margin'] as num?)?.toDouble() ?? 0.0,
      freeMargin: (json['free_margin'] as num?)?.toDouble() ?? 0.0,
      marginLevel: (json['margin_level'] as num?)?.toDouble() ?? 0.0,
      floatingPl: (json['floating_pl'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String,
      leverage: json['leverage'] as int? ?? 1,
      openPositions: json['open_positions'] as int? ?? 0,
    );
  }
}

/// Base broker service interface
abstract class BrokerService {
  BrokerProvider get provider;
  bool get isConnected;

  Future<bool> connect();
  Future<void> disconnect();
  Future<bool> testConnection();

  Future<List<Candle>> getCandles(
    String symbol,
    String timeframe, {
    int limit = 500,
  });

  Future<AccountInfo?> getAccountInfo();

  Future<Order> placeOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    OrderType orderType = OrderType.market,
    double? price,
    double? stopLoss,
    double? takeProfit,
  });

  Future<List<Order>> getOpenOrders();
  Future<bool> cancelOrder(String orderId);

  Stream<Map<String, dynamic>>? getPriceStream(List<String> symbols);
}

/// Generic REST API broker service
class GenericRESTBrokerService implements BrokerService {
  final String apiUrl;
  final String? apiKey;
  final String? apiSecret;
  final http.Client _httpClient = http.Client();

  bool _isConnected = false;

  GenericRESTBrokerService({
    required this.apiUrl,
    this.apiKey,
    this.apiSecret,
  });

  @override
  BrokerProvider get provider => BrokerProvider.generic;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> connect() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$apiUrl/health'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<bool> testConnection() async {
    return await connect();
  }

  @override
  Future<List<Candle>> getCandles(
    String symbol,
    String timeframe, {
    int limit = 500,
  }) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$apiUrl/api/ohlc').replace(queryParameters: {
          'symbol': symbol,
          'timeframe': timeframe,
          'limit': limit.toString(),
        }),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final candlesData = data['candles'] as List;
        return candlesData.map((c) => Candle.fromJson(c as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching candles: $e');
      return [];
    }
  }

  @override
  Future<AccountInfo?> getAccountInfo() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$apiUrl/api/account'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AccountInfo.fromJson(data as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Error fetching account info: $e');
      return null;
    }
  }

  @override
  Future<Order> placeOrder({
    required String symbol,
    required OrderSide side,
    required double quantity,
    OrderType orderType = OrderType.market,
    double? price,
    double? stopLoss,
    double? takeProfit,
  }) async {
    final orderData = {
      'symbol': symbol,
      'side': side == OrderSide.buy ? 'buy' : 'sell',
      'quantity': quantity,
      'order_type': orderType.name.toLowerCase(),
      if (price != null) 'price': price,
      if (stopLoss != null) 'stop_loss': stopLoss,
      if (takeProfit != null) 'take_profit': takeProfit,
    };

    final response = await _httpClient.post(
      Uri.parse('$apiUrl/api/orders'),
      headers: {..._getHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(orderData),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return Order.fromJson(data as Map<String, dynamic>);
    }

    throw Exception('Failed to place order: ${response.body}');
  }

  @override
  Future<List<Order>> getOpenOrders() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$apiUrl/api/orders'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ordersData = data['orders'] as List;
        return ordersData.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
      }

      return [];
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  @override
  Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$apiUrl/api/orders/$orderId'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error cancelling order: $e');
      return false;
    }
  }

  @override
  Stream<Map<String, dynamic>>? getPriceStream(List<String> symbols) {
    try {
      final wsUrl = apiUrl.replaceFirst('http', 'ws');
      final channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/prices?symbols=${symbols.join(',')}'),
      );

      return channel.stream.map((data) {
        return json.decode(data as String) as Map<String, dynamic>;
      });
    } catch (e) {
      print('Error creating price stream: $e');
      return null;
    }
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{};

    if (apiKey != null) {
      headers['X-API-Key'] = apiKey!;
    }

    if (apiSecret != null) {
      headers['X-API-Secret'] = apiSecret!;
    }

    return headers;
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Broker service factory
class BrokerServiceFactory {
  static BrokerService create({
    required BrokerProvider provider,
    required String apiUrl,
    String? apiKey,
    String? apiSecret,
  }) {
    switch (provider) {
      case BrokerProvider.mt4:
      case BrokerProvider.mt5:
      case BrokerProvider.oanda:
      case BrokerProvider.binance:
      case BrokerProvider.generic:
        return GenericRESTBrokerService(
          apiUrl: apiUrl,
          apiKey: apiKey,
          apiSecret: apiSecret,
        );
    }
  }
}
