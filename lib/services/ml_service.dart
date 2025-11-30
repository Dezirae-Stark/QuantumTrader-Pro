import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'autotrading_engine.dart';

class MLService {
  final Logger _logger = Logger();
  bool _isInitialized = false;
  // Interpreter? _interpreter; // TFLite interpreter
  Map<String, dynamic>? _lastPrediction;

  Future<void> initialize() async {
    _logger.i('Initializing ML Service...');

    try {
      // Load TFLite model if available
      // await _loadModel();
      _isInitialized = true;
      _logger.i('ML Service initialized successfully');
    } catch (e) {
      _logger.e('Error initializing ML service: $e');
    }
  }

  // Future<void> _loadModel() async {
  //   try {
  //     _interpreter = await Interpreter.fromAsset('ml/sample_model.tflite');
  //     _logger.i('TFLite model loaded successfully');
  //   } catch (e) {
  //     _logger.w('TFLite model not available: $e');
  //   }
  // }

  Future<Map<String, dynamic>?> loadPredictionFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final data = json.decode(jsonString);
      _lastPrediction = data;
      _logger.i('Loaded prediction from asset: $assetPath');
      return data;
    } catch (e) {
      _logger.e('Error loading prediction asset: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadPredictionFromNetwork(
    String url,
  ) async {
    try {
      // For now, return mock data. In production, use http package
      _logger.i('Network prediction loading not implemented yet');
      return generateMockPrediction();
    } catch (e) {
      _logger.e('Error loading prediction from network: $e');
    }
    return null;
  }

  Map<String, dynamic> generateMockPrediction() {
    final random = Random();
    return {
      'symbol': 'EURUSD',
      'direction': random.nextBool() ? 'buy' : 'sell',
      'confidence': 0.75 + random.nextDouble() * 0.2,
      'predictedPrice': 1.0800 + random.nextDouble() * 0.01,
      'currentPrice': 1.0850,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<MLPredictionOld?> predict(List<double> features) async {
    if (!_isInitialized) {
      _logger.w('ML Service not initialized');
      return null;
    }

    try {
      // Simulated prediction logic
      // In production, use TFLite interpreter:
      // final input = [features];
      // final output = List.filled(1 * 3, 0).reshape([1, 3]);
      // _interpreter?.run(input, output);

      // Simulate prediction
      final trendProbabilities = [
        0.65, // bullish
        0.20, // bearish
        0.15, // neutral
      ];

      return MLPredictionOld(
        trendProbabilities: trendProbabilities,
        entryProbability: 0.72,
        exitProbability: 0.28,
        confidenceScore: 0.78,
        predictedWindow: 5, // candles ahead
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Error during prediction: $e');
      return null;
    }
  }

  Future<List<MLPrediction>> getPredictions(Map<String, dynamic> marketData) async {
    if (!_isInitialized) {
      _logger.w('ML Service not initialized');
      return [];
    }

    final predictions = <MLPrediction>[];
    final random = Random();

    try {
      for (final entry in marketData.entries) {
        final symbol = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final currentPrice = (data['price'] ?? 0.0).toDouble();

        if (currentPrice == 0) continue;

        // Simulate ML prediction with some randomness
        final trendFactor = random.nextDouble();
        final confidence = 0.65 + (random.nextDouble() * 0.3); // 0.65 - 0.95

        // Determine direction based on simulated analysis
        final direction = trendFactor > 0.5 ? TradeDirection.buy : TradeDirection.sell;

        // Calculate predicted price (1-3% movement)
        final priceChange = currentPrice * (0.01 + random.nextDouble() * 0.02);
        final predictedPrice = direction == TradeDirection.buy
            ? currentPrice + priceChange
            : currentPrice - priceChange;

        predictions.add(MLPrediction(
          symbol: symbol,
          direction: direction,
          currentPrice: currentPrice,
          predictedPrice: predictedPrice,
          confidence: confidence,
          candlesAhead: 3 + random.nextInt(5), // 3-7 candles
          timestamp: DateTime.now(),
        ));
      }

      _logger.i('Generated ${predictions.length} ML predictions');
      return predictions;
    } catch (e) {
      _logger.e('Error generating predictions: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> analyzeTrendContinuation(
    List<double> priceHistory,
  ) async {
    if (priceHistory.length < 10) {
      _logger.w('Insufficient price history for analysis');
      return null;
    }

    // Simulated trend analysis
    final avgChange =
        priceHistory.sublist(priceHistory.length - 5).reduce((a, b) => a + b) /
        5;
    final isUptrend = avgChange > 0;

    return {
      'trend': isUptrend ? 'bullish' : 'bearish',
      'continuation_probability': 0.68,
      'reversal_probability': 0.32,
      'confidence': 0.75,
      'recommendation': isUptrend ? 'HOLD/BUY' : 'HOLD/SELL',
    };
  }

  MLPredictionOld? getLastPrediction() {
    if (_lastPrediction == null) return null;

    try {
      return MLPredictionOld(
        trendProbabilities: List<double>.from(
          _lastPrediction!['trend_probabilities'] ?? [0.33, 0.33, 0.34],
        ),
        entryProbability: _lastPrediction!['entry_probability'] ?? 0.5,
        exitProbability: _lastPrediction!['exit_probability'] ?? 0.5,
        confidenceScore: _lastPrediction!['confidence_score'] ?? 0.5,
        predictedWindow: _lastPrediction!['predicted_window'] ?? 5,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Error parsing last prediction: $e');
      return null;
    }
  }

  void dispose() {
    // _interpreter?.close();
  }
}

class MLPredictionOld {
  final List<double> trendProbabilities; // [bullish, bearish, neutral]
  final double entryProbability;
  final double exitProbability;
  final double confidenceScore;
  final int predictedWindow; // Number of candles ahead
  final DateTime timestamp;

  MLPredictionOld({
    required this.trendProbabilities,
    required this.entryProbability,
    required this.exitProbability,
    required this.confidenceScore,
    required this.predictedWindow,
    required this.timestamp,
  });

  String getDominantTrend() {
    final maxIndex = trendProbabilities.indexOf(
      trendProbabilities.reduce((a, b) => a > b ? a : b),
    );
    return ['Bullish', 'Bearish', 'Neutral'][maxIndex];
  }

  bool shouldEnter() => entryProbability > 0.6 && confidenceScore > 0.7;
  bool shouldExit() => exitProbability > 0.6 && confidenceScore > 0.7;
}
