import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum TradingMode { conservative, aggressive }

enum TrendDirection { bullish, bearish, neutral }

class AppState extends ChangeNotifier {
  TradingMode _tradingMode = TradingMode.conservative;
  bool _isDarkMode = false;
  bool _isConnectedToMT4 = false;
  bool _isTelegramConnected = false;
  List<TradeSignal> _signals = [];
  List<OpenTrade> _openTrades = [];
  double _totalPnL = 0.0;

  TradingMode get tradingMode => _tradingMode;
  bool get isDarkMode => _isDarkMode;
  bool get isConnectedToMT4 => _isConnectedToMT4;
  bool get isTelegramConnected => _isTelegramConnected;
  List<TradeSignal> get signals => _signals;
  List<OpenTrade> get openTrades => _openTrades;
  double get totalPnL => _totalPnL;

  void setTradingMode(TradingMode mode) {
    _tradingMode = mode;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setMT4Connection(bool connected) {
    _isConnectedToMT4 = connected;
    notifyListeners();
  }

  void setTelegramConnection(bool connected) {
    _isTelegramConnected = connected;
    notifyListeners();
  }

  void updateSignals(List<TradeSignal> signals) {
    _signals = signals;
    notifyListeners();
  }

  void updateOpenTrades(List<OpenTrade> trades) {
    _openTrades = trades;
    _calculateTotalPnL();
    notifyListeners();
  }

  void _calculateTotalPnL() {
    _totalPnL = _openTrades.fold(0.0, (sum, trade) => sum + trade.profitLoss);
  }

  void addSignal(TradeSignal signal) {
    _signals.insert(0, signal);
    notifyListeners();
  }
}

class TradeSignal {
  final String symbol;
  final TrendDirection trend;
  final double probability;
  final String action; // entry, exit
  final DateTime timestamp;
  final Map<String, dynamic>? mlPrediction;

  TradeSignal({
    required this.symbol,
    required this.trend,
    required this.probability,
    required this.action,
    required this.timestamp,
    this.mlPrediction,
  });

  factory TradeSignal.fromJson(Map<String, dynamic> json) {
    return TradeSignal(
      symbol: json['symbol'] ?? '',
      trend: _parseTrend(json['trend']),
      probability: (json['probability'] ?? 0.0).toDouble(),
      action: json['action'] ?? 'entry',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      mlPrediction: json['ml_prediction'],
    );
  }

  static TrendDirection _parseTrend(dynamic trend) {
    if (trend == null) return TrendDirection.neutral;
    final trendStr = trend.toString().toLowerCase();
    if (trendStr.contains('bull')) return TrendDirection.bullish;
    if (trendStr.contains('bear')) return TrendDirection.bearish;
    return TrendDirection.neutral;
  }

  Color getTrendColor() {
    switch (trend) {
      case TrendDirection.bullish:
        return const Color(0xFF4CAF50);
      case TrendDirection.bearish:
        return const Color(0xFFF44336);
      case TrendDirection.neutral:
        return const Color(0xFFFF9800);
    }
  }
}

class OpenTrade {
  final String symbol;
  final String type; // buy, sell
  final double entryPrice;
  final double currentPrice;
  final double volume;
  final double profitLoss;
  final DateTime openTime;
  final int? predictedWindow; // 3-8 candles ahead

  OpenTrade({
    required this.symbol,
    required this.type,
    required this.entryPrice,
    required this.currentPrice,
    required this.volume,
    required this.profitLoss,
    required this.openTime,
    this.predictedWindow,
  });

  factory OpenTrade.fromJson(Map<String, dynamic> json) {
    return OpenTrade(
      symbol: json['symbol'] ?? '',
      type: json['type'] ?? 'buy',
      entryPrice: (json['entry_price'] ?? 0.0).toDouble(),
      currentPrice: (json['current_price'] ?? 0.0).toDouble(),
      volume: (json['volume'] ?? 0.0).toDouble(),
      profitLoss: (json['profit_loss'] ?? 0.0).toDouble(),
      openTime: DateTime.parse(
        json['open_time'] ?? DateTime.now().toIso8601String(),
      ),
      predictedWindow: json['predicted_window'],
    );
  }
}
