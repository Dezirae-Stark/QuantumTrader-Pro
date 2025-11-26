import 'dart:async';
import 'package:logger/logger.dart';
import '../models/app_state.dart';
import 'trading_platform_service.dart';
import 'websocket_service.dart';

/// Unified Data Service - Single source of truth for all market data
/// Manages data flow between WebSocket, HTTP polling, and UI components
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final Logger _logger = Logger();
  final TradingPlatformService _platformService = TradingPlatformService();
  
  // Data streams
  final _signalsController = StreamController<List<TradeSignal>>.broadcast();
  final _tradesController = StreamController<List<OpenTrade>>.broadcast();
  final _pricesController = StreamController<Map<String, MarketData>>.broadcast();
  final _accountController = StreamController<AccountInfo>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  
  // Cached data
  final Map<String, MarketData> _marketData = {};
  final List<TradeSignal> _signals = [];
  final List<OpenTrade> _openTrades = [];
  AccountInfo? _accountInfo;
  
  // Configuration
  bool _isInitialized = false;
  final Set<String> _subscribedSymbols = {};
  
  // Public streams
  Stream<List<TradeSignal>> get signalsStream => _signalsController.stream;
  Stream<List<OpenTrade>> get tradesStream => _tradesController.stream;
  Stream<Map<String, MarketData>> get pricesStream => _pricesController.stream;
  Stream<AccountInfo> get accountStream => _accountController.stream;
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  
  // Current data getters
  List<TradeSignal> get currentSignals => List.unmodifiable(_signals);
  List<OpenTrade> get openTrades => List.unmodifiable(_openTrades);
  Map<String, MarketData> get marketData => Map.unmodifiable(_marketData);
  AccountInfo? get accountInfo => _accountInfo;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _logger.i('Initializing Data Service...');
    
    // Initialize platform service
    await _platformService.initialize();
    
    // Set up callbacks
    _platformService.onSignalsUpdate = _handleSignalsUpdate;
    _platformService.onTradesUpdate = _handleTradesUpdate;
    _platformService.onPriceUpdate = _handlePriceUpdate;
    
    // Listen to connection state
    _platformService.connectionState.listen((state) {
      _connectionController.add(ConnectionStatus(
        isConnected: state == WebSocketState.connected,
        connectionType: state == WebSocketState.connected ? 'WebSocket' : 'HTTP',
        lastUpdate: DateTime.now(),
      ));
    });
    
    _isInitialized = true;
    _logger.i('Data Service initialized');
  }
  
  Future<void> connect({
    required String endpoint,
    String? authToken,
    bool useWebSocket = true,
  }) async {
    if (!_isInitialized) await initialize();
    
    _logger.i('Connecting to: $endpoint (WebSocket: $useWebSocket)');
    
    await _platformService.connect(
      endpoint: endpoint,
      authToken: authToken,
      useWebSocket: useWebSocket,
    );
    
    // Subscribe to default symbols
    subscribeToSymbols(['EURUSD', 'GBPUSD', 'XAUUSD', 'BTCUSD', 'USDJPY']);
    
    // Fetch initial data
    await refreshAllData();
  }
  
  Future<void> connectToBroker({
    required String platform,
    required String server,
    required int login,
    required String password,
  }) async {
    final success = await _platformService.connectToBroker(
      platform: platform,
      server: server,
      login: login,
      password: password,
    );
    
    if (success) {
      await refreshAllData();
    }
    
    return success ? Future.value() : Future.error('Broker connection failed');
  }
  
  void subscribeToSymbols(List<String> symbols) {
    for (final symbol in symbols) {
      subscribeToSymbol(symbol);
    }
  }
  
  void subscribeToSymbol(String symbol) {
    if (_subscribedSymbols.add(symbol)) {
      _logger.d('Subscribed to $symbol');
    }
  }
  
  void unsubscribeFromSymbol(String symbol) {
    if (_subscribedSymbols.remove(symbol)) {
      _logger.d('Unsubscribed from $symbol');
      _marketData.remove(symbol);
      _notifyPriceUpdate();
    }
  }
  
  Future<void> refreshAllData() async {
    await Future.wait([
      fetchSignals(),
      fetchOpenTrades(),
      fetchAccountInfo(),
    ]);
  }
  
  Future<void> fetchSignals() async {
    final signals = await _platformService.fetchSignals();
    _handleSignalsUpdate(signals);
  }
  
  Future<void> fetchOpenTrades() async {
    final trades = await _platformService.fetchOpenTrades();
    _handleTradesUpdate(trades);
  }
  
  Future<void> fetchAccountInfo() async {
    final info = await _platformService.getAccountInfo();
    if (info != null) {
      _accountInfo = AccountInfo.fromJson(info);
      _accountController.add(_accountInfo!);
    }
  }
  
  void _handleSignalsUpdate(List<TradeSignal> signals) {
    // Filter signals for subscribed symbols
    final filteredSignals = signals.where(
      (s) => _subscribedSymbols.contains(s.symbol)
    ).toList();
    
    // Merge with existing signals (keep last 50)
    _signals.clear();
    _signals.addAll(filteredSignals);
    
    // Sort by timestamp (newest first)
    _signals.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Keep only last 50 signals
    if (_signals.length > 50) {
      _signals.removeRange(50, _signals.length);
    }
    
    _signalsController.add(_signals);
    _logger.d('Updated signals: ${_signals.length}');
  }
  
  void _handleTradesUpdate(List<OpenTrade> trades) {
    _openTrades.clear();
    _openTrades.addAll(trades);
    _tradesController.add(_openTrades);
    _logger.d('Updated trades: ${_openTrades.length}');
  }
  
  void _handlePriceUpdate(MarketUpdate update) {
    // Update market data
    _marketData[update.symbol] = MarketData(
      symbol: update.symbol,
      currentBid: update.bid,
      currentAsk: update.ask,
      spread: update.spread,
      lastUpdate: update.timestamp,
      dailyChange: _calculateDailyChange(update.symbol, update.bid),
      dailyVolume: update.volume,
    );
    
    _notifyPriceUpdate();
  }
  
  void _notifyPriceUpdate() {
    // Only emit subscribed symbols
    final subscribedData = Map.fromEntries(
      _marketData.entries.where((e) => _subscribedSymbols.contains(e.key))
    );
    _pricesController.add(subscribedData);
  }
  
  double _calculateDailyChange(String symbol, double currentPrice) {
    // TODO: Implement daily change calculation based on 24h history
    // For now, return a placeholder
    return 0.0;
  }
  
  // Trading operations
  Future<bool> executeTrade(TradeRequest request) async {
    final success = await _platformService.executeTrade(
      symbol: request.symbol,
      type: request.type,
      lots: request.lots,
      stopLoss: request.stopLoss,
      takeProfit: request.takeProfit,
      comment: request.comment,
    );
    
    if (success) {
      // Refresh trades after execution
      await fetchOpenTrades();
    }
    
    return success;
  }
  
  Future<bool> closePosition(int ticket) async {
    final success = await _platformService.closePosition(ticket);
    
    if (success) {
      // Refresh trades after closing
      await fetchOpenTrades();
    }
    
    return success;
  }
  
  Future<bool> modifyPosition({
    required int ticket,
    double? stopLoss,
    double? takeProfit,
  }) async {
    final success = await _platformService.modifyPosition(
      ticket: ticket,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
    );
    
    if (success) {
      // Refresh trades after modification
      await fetchOpenTrades();
    }
    
    return success;
  }
  
  // Utility methods
  MarketData? getMarketData(String symbol) => _marketData[symbol];
  
  List<TradeSignal> getSignalsForSymbol(String symbol) {
    return _signals.where((s) => s.symbol == symbol).toList();
  }
  
  List<OpenTrade> getTradesForSymbol(String symbol) {
    return _openTrades.where((t) => t.symbol == symbol).toList();
  }
  
  double getTotalProfit() {
    return _openTrades.fold(0.0, (sum, trade) => sum + trade.profit);
  }
  
  int getOpenTradeCount() => _openTrades.length;
  
  void dispose() {
    _signalsController.close();
    _tradesController.close();
    _pricesController.close();
    _accountController.close();
    _connectionController.close();
    _platformService.dispose();
  }
}

// Additional models
class MarketData {
  final String symbol;
  final double currentBid;
  final double currentAsk;
  final double spread;
  final DateTime lastUpdate;
  final double dailyChange;
  final int dailyVolume;

  MarketData({
    required this.symbol,
    required this.currentBid,
    required this.currentAsk,
    required this.spread,
    required this.lastUpdate,
    required this.dailyChange,
    required this.dailyVolume,
  });

  double get midPrice => (currentBid + currentAsk) / 2;
  double get spreadPips => spread * (symbol.contains('JPY') ? 100 : 10000);
}

class AccountInfo {
  final int login;
  final String name;
  final String server;
  final String currency;
  final double balance;
  final double equity;
  final double margin;
  final double freeMargin;
  final double marginLevel;
  final double profit;

  AccountInfo({
    required this.login,
    required this.name,
    required this.server,
    required this.currency,
    required this.balance,
    required this.equity,
    required this.margin,
    required this.freeMargin,
    required this.marginLevel,
    required this.profit,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) {
    return AccountInfo(
      login: json['login'] ?? 0,
      name: json['name'] ?? '',
      server: json['server'] ?? '',
      currency: json['currency'] ?? 'USD',
      balance: (json['balance'] ?? 0).toDouble(),
      equity: (json['equity'] ?? 0).toDouble(),
      margin: (json['margin'] ?? 0).toDouble(),
      freeMargin: (json['free_margin'] ?? 0).toDouble(),
      marginLevel: (json['margin_level'] ?? 0).toDouble(),
      profit: (json['profit'] ?? 0).toDouble(),
    );
  }
}

class ConnectionStatus {
  final bool isConnected;
  final String connectionType;
  final DateTime lastUpdate;

  ConnectionStatus({
    required this.isConnected,
    required this.connectionType,
    required this.lastUpdate,
  });
}

class TradeRequest {
  final String symbol;
  final TradeType type;
  final double lots;
  final double? stopLoss;
  final double? takeProfit;
  final String? comment;

  TradeRequest({
    required this.symbol,
    required this.type,
    required this.lots,
    this.stopLoss,
    this.takeProfit,
    this.comment,
  });
}