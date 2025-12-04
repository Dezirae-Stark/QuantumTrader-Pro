import 'dart:async';
import 'package:logger/logger.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'broker_adapter_service.dart';
import 'ml_service.dart';
import 'risk_manager.dart';
import 'cantilever_hedge_manager.dart';
import 'quantum_settings_service.dart';
import '../models/app_state.dart';
import '../models/risk_assessment.dart';
import '../models/trading_enums.dart';

// TradingStatus moved to trading_enums.dart

class AutoTradingEngine {
  final Logger _logger = Logger();
  final BrokerAdapterService _brokerService;
  final MLService _mlService;
  final RiskManager _riskManager;
  final CantileverHedgeManager _hedgeManager;
  final QuantumSettingsService _quantumSettings;

  Timer? _tradingTimer;
  Timer? _monitoringTimer;
  TradingStatus _status = TradingStatus.idle;
  bool _isEnabled = false;

  // Trading parameters
  final Map<String, TradingSession> _activeSessions = {};
  late Box _tradingHistoryBox;

  // Performance metrics
  int _totalTrades = 0;
  int _winningTrades = 0;
  int _losingTrades = 0;
  double _totalProfit = 0.0;
  double _totalLoss = 0.0;

  AutoTradingEngine({
    required BrokerAdapterService brokerService,
    required MLService mlService,
    required RiskManager riskManager,
    required CantileverHedgeManager hedgeManager,
    required QuantumSettingsService quantumSettings,
  })  : _brokerService = brokerService,
        _mlService = mlService,
        _riskManager = riskManager,
        _hedgeManager = hedgeManager,
        _quantumSettings = quantumSettings;

  TradingStatus get status => _status;
  bool get isEnabled => _isEnabled;
  Map<String, TradingSession> get activeSessions => _activeSessions;

  double get winRate => _totalTrades > 0 ? (_winningTrades / _totalTrades) * 100 : 0.0;
  double get profitFactor => _totalLoss != 0 ? _totalProfit / _totalLoss.abs() : 0.0;
  double get netProfit => _totalProfit - _totalLoss.abs();

  Future<void> initialize() async {
    _logger.i('Initializing AutoTrading Engine...');
    _tradingHistoryBox = await Hive.openBox('trading_history');
    await _loadPerformanceMetrics();
  }

  Future<void> _loadPerformanceMetrics() async {
    _totalTrades = _tradingHistoryBox.get('total_trades', defaultValue: 0);
    _winningTrades = _tradingHistoryBox.get('winning_trades', defaultValue: 0);
    _losingTrades = _tradingHistoryBox.get('losing_trades', defaultValue: 0);
    _totalProfit = _tradingHistoryBox.get('total_profit', defaultValue: 0.0);
    _totalLoss = _tradingHistoryBox.get('total_loss', defaultValue: 0.0);
  }

  Future<void> _savePerformanceMetrics() async {
    await _tradingHistoryBox.put('total_trades', _totalTrades);
    await _tradingHistoryBox.put('winning_trades', _winningTrades);
    await _tradingHistoryBox.put('losing_trades', _losingTrades);
    await _tradingHistoryBox.put('total_profit', _totalProfit);
    await _tradingHistoryBox.put('total_loss', _totalLoss);
  }

  Future<void> start() async {
    if (!_brokerService.isConnected || !_quantumSettings.isQuantumActive) {
      _logger.w('Cannot start autotrading: Broker not connected or Quantum system inactive');
      return;
    }

    _isEnabled = true;
    _status = TradingStatus.analyzing;

    // Start trading cycle
    _tradingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _tradingCycle();
    });

    // Start position monitoring
    _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _monitorPositions();
    });

    _logger.i('AutoTrading Engine started');
  }

  Future<void> stop() async {
    _isEnabled = false;
    _status = TradingStatus.idle;

    _tradingTimer?.cancel();
    _monitoringTimer?.cancel();

    // Close all active sessions safely
    for (final session in _activeSessions.values) {
      await _closeTradingSession(session);
    }

    _logger.i('AutoTrading Engine stopped');
  }

  Future<void> _tradingCycle() async {
    if (!_isEnabled || _status != TradingStatus.analyzing) return;

    try {
      // Get market data
      final marketData = await _brokerService.fetchMarketData();
      if (marketData.isEmpty) return;

      // Get ML predictions for watched symbols
      final predictions = await _mlService.getPredictions(marketData);

      // Analyze each prediction
      for (final prediction in predictions) {
        await _analyzePrediction(prediction, marketData);
      }

    } catch (e) {
      _logger.e('Trading cycle error: $e');
    }
  }

  Future<void> _analyzePrediction(
    MLPrediction prediction,
    Map<String, dynamic> marketData,
  ) async {
    final symbol = prediction.symbol;

    // Check if we already have an active session for this symbol
    if (_activeSessions.containsKey(symbol)) {
      return;
    }

    // Apply risk filters
    final riskAssessment = await _riskManager.assessTrade(
      symbol: symbol,
      direction: prediction.direction,
      currentPrice: prediction.currentPrice,
      predictedPrice: prediction.predictedPrice,
    );

    if (!riskAssessment.isApproved) {
      _logger.w('Trade rejected by risk manager: ${riskAssessment.reason}');
      return;
    }

    // Check confidence threshold
    final requiredConfidence = _quantumSettings.riskScale > 2.0 ? 0.85 : 0.75;
    if (prediction.confidence < requiredConfidence) {
      _logger.w('Trade rejected: Low confidence ${prediction.confidence}');
      return;
    }

    // Execute trade
    await _executeTrade(prediction, riskAssessment);
  }

  Future<void> _executeTrade(
    MLPrediction prediction,
    RiskAssessment riskAssessment,
  ) async {
    _status = TradingStatus.executing;

    try {
      // Calculate position size based on risk
      final positionSize = _calculatePositionSize(
        riskAssessment.recommendedLotSize,
        _quantumSettings.riskScale,
      );

      // Send trade order
      final success = await _brokerService.sendTradeOrder(
        symbol: prediction.symbol,
        orderType: prediction.direction == TradeDirection.buy ? 'buy' : 'sell',
        volume: positionSize,
        stopLoss: riskAssessment.stopLoss,
        takeProfit: riskAssessment.takeProfit,
      );

      if (success) {
        // Create trading session
        final session = TradingSession(
          symbol: prediction.symbol,
          direction: prediction.direction,
          entryPrice: prediction.currentPrice,
          targetPrice: prediction.predictedPrice,
          stopLoss: riskAssessment.stopLoss!,
          takeProfit: riskAssessment.takeProfit!,
          lotSize: positionSize,
          confidence: prediction.confidence,
          startTime: DateTime.now(),
        );

        _activeSessions[prediction.symbol] = session;
        _logger.i('Trade executed: ${prediction.symbol} ${prediction.direction}');

        // Enable cantilever stops if configured
        if (_quantumSettings.getModuleStatus('Cantilever Stops')) {
          _hedgeManager.setupCantileverStop(
            symbol: prediction.symbol,
            entryPrice: prediction.currentPrice,
            direction: prediction.direction == TradeDirection.buy,
            stepPercent: _quantumSettings.cantileverStepSize,
            lockPercent: _quantumSettings.cantileverLockPercent,
          );
        }
      }

    } catch (e) {
      _logger.e('Trade execution error: $e');
    } finally {
      _status = TradingStatus.analyzing;
    }
  }

  Future<void> _monitorPositions() async {
    if (!_isEnabled || _activeSessions.isEmpty) return;

    _status = TradingStatus.monitoring;

    try {
      final openTrades = await _brokerService.fetchOpenTrades();

      for (final trade in openTrades) {
        final session = _activeSessions[trade.symbol];
        if (session == null) continue;

        // Update session with current data
        session.currentPrice = trade.currentPrice;
        session.currentProfit = trade.profitLoss;

        // Check cantilever adjustments
        if (_quantumSettings.getModuleStatus('Cantilever Stops')) {
          _hedgeManager.updateCantileverStop(
            symbol: trade.symbol,
            currentPrice: trade.currentPrice,
          );
        }

        // Check for exit conditions
        if (_shouldExitTrade(session, trade)) {
          await _closeTradingSession(session);
        }

        // Check for hedge activation
        if (_shouldActivateHedge(session, trade)) {
          await _activateCounterHedge(session);
        }
      }

    } catch (e) {
      _logger.e('Position monitoring error: $e');
    } finally {
      _status = TradingStatus.analyzing;
    }
  }

  bool _shouldExitTrade(TradingSession session, OpenTrade trade) {
    // Check if target reached
    if (session.direction == TradeDirection.buy) {
      if (trade.currentPrice >= session.takeProfit) {
        _logger.i('Take profit reached for ${session.symbol}');
        return true;
      }
    } else {
      if (trade.currentPrice <= session.takeProfit) {
        _logger.i('Take profit reached for ${session.symbol}');
        return true;
      }
    }

    // Check time-based exit (if trade is older than prediction window)
    final tradeDuration = DateTime.now().difference(session.startTime);
    if (tradeDuration.inHours > 8) {
      _logger.i('Time-based exit for ${session.symbol}');
      return true;
    }

    // Check drawdown limit
    final drawdownPercent = (trade.profitLoss / session.entryPrice).abs() * 100;
    if (drawdownPercent > 5.0) {
      _logger.w('Drawdown limit reached for ${session.symbol}');
      return true;
    }

    return false;
  }

  bool _shouldActivateHedge(TradingSession session, OpenTrade trade) {
    if (!_quantumSettings.autoHedgeEnabled || session.hasHedge) {
      return false;
    }

    // Check if stop loss is close
    final priceToStopLoss = (trade.currentPrice - session.stopLoss).abs();
    final stopLossDistance = (session.entryPrice - session.stopLoss).abs();

    if (priceToStopLoss < stopLossDistance * 0.2) {
      _logger.w('Stop loss proximity detected for ${session.symbol}');
      return true;
    }

    return false;
  }

  Future<void> _activateCounterHedge(TradingSession session) async {
    if (!_quantumSettings.getModuleStatus('Counter-Hedge')) return;

    try {
      // Open opposite position with multiplier
      final hedgeSize = session.lotSize * _quantumSettings.hedgeMultiplier;
      final hedgeDirection = session.direction == TradeDirection.buy ? 'sell' : 'buy';

      final success = await _brokerService.sendTradeOrder(
        symbol: session.symbol,
        orderType: hedgeDirection,
        volume: hedgeSize,
      );

      if (success) {
        session.hasHedge = true;
        session.hedgeActivatedAt = DateTime.now();
        _logger.i('Counter-hedge activated for ${session.symbol}');
      }

    } catch (e) {
      _logger.e('Hedge activation error: $e');
    }
  }

  Future<void> _closeTradingSession(TradingSession session) async {
    try {
      // Close the position
      // Note: In real implementation, we'd need the position ID
      await _brokerService.closePosition(session.symbol);

      // Update performance metrics
      _totalTrades++;
      if (session.currentProfit > 0) {
        _winningTrades++;
        _totalProfit += session.currentProfit;
      } else {
        _losingTrades++;
        _totalLoss += session.currentProfit;
      }

      await _savePerformanceMetrics();

      // Remove from active sessions
      _activeSessions.remove(session.symbol);

      // Record in history
      await _recordTradeHistory(session);

      _logger.i('Trading session closed for ${session.symbol}: \$${session.currentProfit.toStringAsFixed(2)}');

    } catch (e) {
      _logger.e('Error closing trading session: $e');
    }
  }

  Future<void> _recordTradeHistory(TradingSession session) async {
    final history = {
      'symbol': session.symbol,
      'direction': session.direction.toString(),
      'entryPrice': session.entryPrice,
      'exitPrice': session.currentPrice,
      'profit': session.currentProfit,
      'duration': DateTime.now().difference(session.startTime).inMinutes,
      'confidence': session.confidence,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final trades = _tradingHistoryBox.get('trades', defaultValue: []);
    trades.add(history);
    await _tradingHistoryBox.put('trades', trades);
  }

  double _calculatePositionSize(double baseLotSize, double riskScale) {
    // Apply risk scaling
    final adjustedSize = baseLotSize * riskScale;

    // Apply maximum position size limit
    const maxSize = 5.0;
    return adjustedSize > maxSize ? maxSize : adjustedSize;
  }

  Map<String, dynamic> getPerformanceStats() {
    return {
      'totalTrades': _totalTrades,
      'winningTrades': _winningTrades,
      'losingTrades': _losingTrades,
      'winRate': winRate,
      'profitFactor': profitFactor,
      'netProfit': netProfit,
      'activeSessions': _activeSessions.length,
      'status': _status.toString().split('.').last,
    };
  }

  void dispose() {
    stop();
  }
}

class TradingSession {
  final String symbol;
  final TradeDirection direction;
  final double entryPrice;
  final double targetPrice;
  final double stopLoss;
  final double takeProfit;
  final double lotSize;
  final double confidence;
  final DateTime startTime;

  double currentPrice;
  double currentProfit;
  bool hasHedge;
  DateTime? hedgeActivatedAt;

  TradingSession({
    required this.symbol,
    required this.direction,
    required this.entryPrice,
    required this.targetPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.lotSize,
    required this.confidence,
    required this.startTime,
    this.currentPrice = 0.0,
    this.currentProfit = 0.0,
    this.hasHedge = false,
    this.hedgeActivatedAt,
  });
}

class MLPrediction {
  final String symbol;
  final TradeDirection direction;
  final double currentPrice;
  final double predictedPrice;
  final double confidence;
  final int candlesAhead;
  final DateTime timestamp;

  MLPrediction({
    required this.symbol,
    required this.direction,
    required this.currentPrice,
    required this.predictedPrice,
    required this.confidence,
    required this.candlesAhead,
    required this.timestamp,
  });
}

// TradeDirection moved to trading_enums.dart