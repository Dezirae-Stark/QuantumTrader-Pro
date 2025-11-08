import 'dart:math';
import 'package:logger/logger.dart';
import '../models/app_state.dart';

/// Advanced risk management with Kelly Criterion and dynamic position sizing
class RiskManager {
  final Logger _logger = Logger();

  // Configuration
  double maxRiskPerTrade = 0.02; // 2% of account
  double maxPortfolioRisk = 0.06; // 6% total exposure
  double kellyFraction = 0.5; // Use 50% of Kelly (conservative)

  /// Calculate optimal position size using Kelly Criterion
  ///
  /// Kelly Formula: f* = (p*b - q) / b
  /// where:
  ///   p = win probability
  ///   q = loss probability (1-p)
  ///   b = ratio of average win to average loss
  double calculateKellyPositionSize({
    required double accountBalance,
    required double winRate,
    required double avgWin,
    required double avgLoss,
  }) {
    if (avgLoss == 0) {
      _logger.w('Average loss is 0, cannot calculate Kelly');
      return accountBalance * maxRiskPerTrade;
    }

    double p = winRate;
    double q = 1 - winRate;
    double b = avgWin / avgLoss;

    // Kelly percentage
    double kelly = (p * b - q) / b;

    // Apply safety margin (use fraction of Kelly)
    double safeFraction = kelly * kellyFraction;

    // Ensure within limits
    safeFraction = safeFraction.clamp(0.0, maxRiskPerTrade);

    double positionSize = accountBalance * safeFraction;

    _logger.i('Kelly position size: \$${positionSize.toStringAsFixed(2)} '
        '(${(safeFraction * 100).toStringAsFixed(1)}% of account)');

    return positionSize;
  }

  /// Get position size recommendation with multi-factor adjustment
  PositionSizeRecommendation getPositionRecommendation({
    required double accountBalance,
    required double confidence,
    required double volatility,
    required TrendDirection trend,
    required TradingMode mode,
    double winRate = 0.65,
    double avgWin = 150,
    double avgLoss = 100,
  }) {
    // Base size from Kelly
    double baseSize = calculateKellyPositionSize(
      accountBalance: accountBalance,
      winRate: winRate,
      avgWin: avgWin,
      avgLoss: avgLoss,
    );

    double adjustedSize = baseSize;
    List<String> adjustments = [];

    // 1. Confidence adjustment
    if (confidence > 0.8) {
      adjustedSize *= 1.2;
      adjustments.add('High confidence: +20%');
    } else if (confidence < 0.6) {
      adjustedSize *= 0.5;
      adjustments.add('Low confidence: -50%');
    }

    // 2. Volatility adjustment
    if (volatility > 0.015) {
      adjustedSize *= 0.7;
      adjustments.add('High volatility: -30%');
    } else if (volatility < 0.005) {
      adjustedSize *= 1.1;
      adjustments.add('Low volatility: +10%');
    }

    // 3. Trend strength adjustment
    if (trend == TrendDirection.bullish || trend == TrendDirection.bearish) {
      adjustedSize *= 1.05;
      adjustments.add('Strong trend: +5%');
    }

    // 4. Trading mode adjustment
    if (mode == TradingMode.conservative) {
      adjustedSize *= 0.8;
      adjustments.add('Conservative mode: -20%');
    } else {
      adjustedSize *= 1.1;
      adjustments.add('Aggressive mode: +10%');
    }

    // Final safety check
    double maxAllowedSize = accountBalance * maxRiskPerTrade;
    if (adjustedSize > maxAllowedSize) {
      adjustedSize = maxAllowedSize;
      adjustments.add('Capped at max risk per trade');
    }

    return PositionSizeRecommendation(
      lotSize: _convertToLotSize(adjustedSize),
      riskAmount: adjustedSize,
      riskPercent: (adjustedSize / accountBalance) * 100,
      confidence: confidence,
      adjustments: adjustments,
    );
  }

  /// Calculate adaptive stop loss and take profit based on ATR
  StopLossConfig calculateAdaptiveStops({
    required double entryPrice,
    required double atr,
    required TradingMode mode,
    required double volatility,
    required bool isBuy,
  }) {
    // Base multipliers
    double slMultiplier = mode == TradingMode.conservative ? 2.5 : 1.5;
    double tpMultiplier = mode == TradingMode.conservative ? 2.0 : 3.0;

    // Adjust for volatility regime
    if (volatility > 0.015) {
      // High volatility - wider stops
      slMultiplier *= 1.3;
      tpMultiplier *= 1.2;
    } else if (volatility < 0.005) {
      // Low volatility - tighter stops
      slMultiplier *= 0.9;
      tpMultiplier *= 0.9;
    }

    double stopLoss = atr * slMultiplier;
    double takeProfit = atr * tpMultiplier;

    // Ensure minimum risk/reward ratio of 1:1.5
    double minRR = 1.5;
    if (takeProfit / stopLoss < minRR) {
      takeProfit = stopLoss * minRR;
    }

    // Calculate actual price levels
    double stopLossPrice;
    double takeProfitPrice;

    if (isBuy) {
      stopLossPrice = entryPrice - stopLoss;
      takeProfitPrice = entryPrice + takeProfit;
    } else {
      stopLossPrice = entryPrice + stopLoss;
      takeProfitPrice = entryPrice - takeProfit;
    }

    return StopLossConfig(
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice,
      riskRewardRatio: takeProfit / stopLoss,
      trailingStop: atr * 1.2,
      atrMultiplier: slMultiplier,
    );
  }

  /// Check if new trade would violate correlation limits
  bool checkCorrelationRisk({
    required String newSymbol,
    required List<OpenTrade> currentTrades,
  }) {
    // Correlation matrix (simplified - in production use real correlation data)
    final correlationMatrix = {
      'EURUSD': {'GBPUSD': 0.85, 'USDCHF': -0.92, 'USDJPY': -0.45},
      'GBPUSD': {'EURUSD': 0.85, 'USDJPY': -0.40, 'USDCHF': -0.78},
      'USDJPY': {'EURUSD': -0.45, 'GBPUSD': -0.40, 'AUDUSD': 0.60},
      'AUDUSD': {'NZDUSD': 0.88, 'USDJPY': 0.60, 'USDCAD': -0.65},
      'NZDUSD': {'AUDUSD': 0.88, 'USDJPY': 0.55},
      'USDCHF': {'EURUSD': -0.92, 'GBPUSD': -0.78},
    };

    for (final trade in currentTrades) {
      double correlation =
          correlationMatrix[newSymbol]?[trade.symbol]?.abs() ?? 0.0;

      if (correlation > 0.7) {
        _logger.w(
            'High correlation detected: $newSymbol vs ${trade.symbol} ($correlation)');
        return false; // Reject trade due to high correlation
      }
    }

    return true; // Safe to trade
  }

  /// Calculate total portfolio risk exposure
  PortfolioRisk calculatePortfolioRisk(List<OpenTrade> trades) {
    double totalExposure = 0.0;
    double totalPotentialLoss = 0.0;

    for (final trade in trades) {
      totalExposure += trade.volume * trade.currentPrice;
      // Estimate potential loss at stop loss
      double potentialLoss = trade.volume * 100; // Simplified
      totalPotentialLoss += potentialLoss;
    }

    return PortfolioRisk(
      totalExposure: totalExposure,
      totalPotentialLoss: totalPotentialLoss,
      numberOfPositions: trades.length,
      isOverExposed: totalPotentialLoss > 0, // Add real logic
    );
  }

  /// Convert dollar risk to lot size
  double _convertToLotSize(double riskAmount) {
    // Simplified conversion - in production use real pip values
    // Assuming $10 per pip per lot for major pairs
    double pipValue = 10.0;
    double stopLossInPips = 50; // Typical stop loss

    return (riskAmount / (pipValue * stopLossInPips)).clamp(0.01, 100.0);
  }

  /// Calculate expected value of a trade
  double calculateExpectedValue({
    required double winRate,
    required double avgWin,
    required double avgLoss,
  }) {
    double lossRate = 1 - winRate;
    return (winRate * avgWin) - (lossRate * avgLoss);
  }

  /// Determine if trade should be taken based on risk metrics
  TradeApproval approveTrade({
    required double confidence,
    required double riskRewardRatio,
    required double portfolioRiskPercent,
    required bool passesCorrelation,
  }) {
    List<String> reasons = [];
    bool approved = true;

    // Check 1: Minimum confidence
    if (confidence < 0.6) {
      approved = false;
      reasons.add('Confidence too low (<60%)');
    }

    // Check 2: Minimum risk/reward
    if (riskRewardRatio < 1.5) {
      approved = false;
      reasons.add('Risk/reward too low (<1.5)');
    }

    // Check 3: Portfolio risk limit
    if (portfolioRiskPercent > maxPortfolioRisk) {
      approved = false;
      reasons.add('Portfolio risk limit exceeded');
    }

    // Check 4: Correlation
    if (!passesCorrelation) {
      approved = false;
      reasons.add('High correlation with existing positions');
    }

    if (approved) {
      reasons.add('All risk checks passed');
    }

    return TradeApproval(
      approved: approved,
      confidence: confidence,
      reasons: reasons,
    );
  }
}

/// Position size recommendation with reasoning
class PositionSizeRecommendation {
  final double lotSize;
  final double riskAmount;
  final double riskPercent;
  final double confidence;
  final List<String> adjustments;

  PositionSizeRecommendation({
    required this.lotSize,
    required this.riskAmount,
    required this.riskPercent,
    required this.confidence,
    required this.adjustments,
  });

  @override
  String toString() {
    return 'Position: ${lotSize.toStringAsFixed(2)} lots '
        '(\$${riskAmount.toStringAsFixed(2)}, ${riskPercent.toStringAsFixed(1)}%)';
  }
}

/// Stop loss configuration
class StopLossConfig {
  final double stopLoss;
  final double takeProfit;
  final double stopLossPrice;
  final double takeProfitPrice;
  final double riskRewardRatio;
  final double trailingStop;
  final double atrMultiplier;

  StopLossConfig({
    required this.stopLoss,
    required this.takeProfit,
    required this.stopLossPrice,
    required this.takeProfitPrice,
    required this.riskRewardRatio,
    required this.trailingStop,
    required this.atrMultiplier,
  });

  @override
  String toString() {
    return 'SL: ${stopLossPrice.toStringAsFixed(5)} | '
        'TP: ${takeProfitPrice.toStringAsFixed(5)} | '
        'R:R = 1:${riskRewardRatio.toStringAsFixed(1)}';
  }
}

/// Portfolio risk metrics
class PortfolioRisk {
  final double totalExposure;
  final double totalPotentialLoss;
  final int numberOfPositions;
  final bool isOverExposed;

  PortfolioRisk({
    required this.totalExposure,
    required this.totalPotentialLoss,
    required this.numberOfPositions,
    required this.isOverExposed,
  });
}

/// Trade approval decision
class TradeApproval {
  final bool approved;
  final double confidence;
  final List<String> reasons;

  TradeApproval({
    required this.approved,
    required this.confidence,
    required this.reasons,
  });
}
