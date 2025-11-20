import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

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

  Future<Map<String, dynamic>?> loadPredictionFromJson(String jsonPath) async {
    try {
      final file = File(jsonPath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final data = json.decode(jsonString);
        _lastPrediction = data;
        _logger.i('Loaded prediction from JSON: $jsonPath');
        return data;
      }
    } catch (e) {
      _logger.e('Error loading prediction JSON: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadPredictionFromAsset(
    String assetPath,
  ) async {
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

  Future<MLPrediction?> predict(List<double> features) async {
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

      return MLPrediction(
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

  MLPrediction? getLastPrediction() {
    if (_lastPrediction == null) return null;

    try {
      return MLPrediction(
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

class MLPrediction {
  final List<double> trendProbabilities; // [bullish, bearish, neutral]
  final double entryProbability;
  final double exitProbability;
  final double confidenceScore;
  final int predictedWindow; // Number of candles ahead
  final DateTime timestamp;

  MLPrediction({
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
