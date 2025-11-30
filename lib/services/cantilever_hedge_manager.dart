import 'package:logger/logger.dart';
import '../models/app_state.dart';

/// Intelligent Cantilever Trailing Stop with Counter-Hedge Recovery
///
/// Features:
/// 1. Dynamic cantilever trailing stop (locks in profits)
/// 2. Automatic counter-hedge on stop loss hit
/// 3. ML-managed leg-out for profitable both sides
/// 4. Quantum probability-based exit optimization
class CantileverHedgeManager {
  final Logger _logger = Logger();

  // Track active cantilever stops
  final Map<String, CantileverStop> _activeCantilevers = {};

  void setupCantileverStop({
    required String symbol,
    required double entryPrice,
    required bool direction,
    required double stepPercent,
    required double lockPercent,
  }) {
    _activeCantilevers[symbol] = CantileverStop(
      symbol: symbol,
      entryPrice: entryPrice,
      currentStop: entryPrice * (direction ? 0.98 : 1.02),
      direction: direction,
      stepPercent: stepPercent,
      lockPercent: lockPercent,
      lastUpdatePrice: entryPrice,
      stopLossPrice: entryPrice * (direction ? 0.98 : 1.02),
      lockedProfitAmount: 0.0,
      profitSteps: 0,
      isActive: true,
      nextTriggerPrice: entryPrice * (direction ? 1.005 : 0.995),
    );
    _logger.i('Cantilever stop setup for $symbol at $entryPrice');
  }

  void updateCantileverStop({
    required String symbol,
    required double currentPrice,
  }) {
    final cantilever = _activeCantilevers[symbol];
    if (cantilever == null) return;

    final profitPercent = cantilever.direction
        ? (currentPrice - cantilever.entryPrice) / cantilever.entryPrice
        : (cantilever.entryPrice - currentPrice) / cantilever.entryPrice;

    if (profitPercent > cantilever.stepPercent) {
      final steps = (profitPercent / cantilever.stepPercent).floor();
      final lockedProfit = profitPercent * cantilever.lockPercent * steps;

      final newStop = cantilever.direction
          ? cantilever.entryPrice * (1 + lockedProfit)
          : cantilever.entryPrice * (1 - lockedProfit);

      if ((cantilever.direction && newStop > cantilever.currentStop) ||
          (!cantilever.direction && newStop < cantilever.currentStop)) {
        cantilever.currentStop = newStop;
        cantilever.lastUpdatePrice = currentPrice;
        _logger.i('Cantilever stop updated for $symbol to $newStop');
      }
    }
  }

  // User-configurable settings
  double userRiskScale = 1.0; // 1.0 = normal, 2.0 = double risk, 0.5 = half
  double cantileverStepSize = 0.5; // Move stop every 0.5% profit
  double cantileverLockPercent = 0.6; // Lock 60% of profit
  bool autoHedgeEnabled = true;
  double hedgeMultiplier = 1.5; // Hedge with 1.5x original position

  /// Calculate cantilever trailing stop that locks in profits progressively
  CantileverStop calculateCantileverStop({
    required OpenTrade trade,
    required double currentPrice,
    required double atr,
  }) {
    double entryPrice = trade.entryPrice;
    bool isBuy = trade.type.toLowerCase() == 'buy';

    // Calculate current profit in pips/points
    double profitPips = isBuy
        ? (currentPrice - entryPrice)
        : (entryPrice - currentPrice);

    double profitPercent = (profitPips / entryPrice).abs();

    // Initial stop loss (ATR-based)
    double initialStop = atr * 2.0;
    double stopLossPrice = isBuy
        ? entryPrice - initialStop
        : entryPrice + initialStop;

    // If trade is profitable, engage cantilever
    if (profitPercent > 0.001) {
      // How many "steps" of profit?
      int profitSteps = (profitPercent / cantileverStepSize).floor();

      if (profitSteps > 0) {
        // Lock in percentage of profit
        double lockedProfit = profitPips * cantileverLockPercent * profitSteps;

        // Move stop to lock profit
        stopLossPrice = isBuy
            ? entryPrice + lockedProfit
            : entryPrice - lockedProfit;

        _logger.i(
          'Cantilever activated! Locking ${(cantileverLockPercent * 100).toStringAsFixed(0)}% '
          'of profit. New stop: ${stopLossPrice.toStringAsFixed(5)}',
        );
      }
    }

    // Calculate profit if stopped out now
    double lockedProfitAmount = isBuy
        ? (stopLossPrice - entryPrice) *
              trade.volume *
              100000 // Simplified
        : (entryPrice - stopLossPrice) * trade.volume * 100000;

    return CantileverStop(
      stopLossPrice: stopLossPrice,
      lockedProfitAmount: lockedProfitAmount,
      profitSteps: profitPips > 0
          ? (profitPercent / cantileverStepSize).floor()
          : 0,
      isActive: profitPercent > cantileverStepSize,
      nextTriggerPrice: isBuy
          ? entryPrice +
                ((profitPercent / cantileverStepSize).ceil() + 1) *
                    cantileverStepSize *
                    entryPrice
          : entryPrice -
                ((profitPercent / cantileverStepSize).ceil() + 1) *
                    cantileverStepSize *
                    entryPrice,
    );
  }

  /// Trigger counter-hedge when stop loss is hit
  ///
  /// Instead of accepting loss, open opposite position to recover
  Future<CounterHedge?> triggerCounterHedge({
    required OpenTrade originalTrade,
    required double currentPrice,
    required double accountBalance,
    required double mlConfidence,
  }) async {
    if (!autoHedgeEnabled) {
      _logger.w('Auto-hedge disabled');
      return null;
    }

    // Calculate loss on original trade
    double loss = originalTrade.profitLoss;

    if (loss >= 0) {
      _logger.i('Trade is profitable, no hedge needed');
      return null;
    }

    _logger.w('Stop loss hit! Loss: \$${loss.toStringAsFixed(2)}');
    _logger.i('Activating counter-hedge recovery system...');

    // Determine hedge direction (opposite of original)
    String hedgeDirection = originalTrade.type.toLowerCase() == 'buy'
        ? 'sell'
        : 'buy';

    // Calculate hedge position size
    double hedgeVolume = originalTrade.volume * hedgeMultiplier * userRiskScale;

    // Use ML confidence to adjust hedge size
    if (mlConfidence > 0.75) {
      hedgeVolume *= 1.2; // Larger hedge if ML is confident
      _logger.i(
        'ML high confidence (${mlConfidence.toStringAsFixed(2)}), increasing hedge by 20%',
      );
    } else if (mlConfidence < 0.55) {
      hedgeVolume *= 0.8; // Smaller hedge if uncertain
      _logger.i(
        'ML low confidence (${mlConfidence.toStringAsFixed(2)}), reducing hedge by 20%',
      );
    }

    // Calculate break-even targets for both positions
    double hedgeEntryPrice = currentPrice;

    // Both positions need to net zero loss
    double requiredMovement = loss.abs() / (hedgeVolume * 100000);

    double hedgeTargetPrice = hedgeDirection == 'buy'
        ? hedgeEntryPrice + requiredMovement
        : hedgeEntryPrice - requiredMovement;

    CounterHedge hedge = CounterHedge(
      originalTrade: originalTrade,
      hedgeDirection: hedgeDirection,
      hedgeVolume: hedgeVolume,
      hedgeEntryPrice: hedgeEntryPrice,
      hedgeTargetPrice: hedgeTargetPrice,
      totalLossToRecover: loss.abs(),
      timestamp: DateTime.now(),
      mlConfidence: mlConfidence,
      status: HedgeStatus.active,
    );

    _logger.i('Counter-hedge plan:');
    _logger.i('  Direction: $hedgeDirection');
    _logger.i('  Volume: ${hedgeVolume.toStringAsFixed(2)} lots');
    _logger.i('  Entry: ${hedgeEntryPrice.toStringAsFixed(5)}');
    _logger.i('  Target: ${hedgeTargetPrice.toStringAsFixed(5)}');
    _logger.i('  Loss to recover: \$${loss.abs().toStringAsFixed(2)}');

    return hedge;
  }

  /// ML-managed leg-out strategy
  ///
  /// Intelligently close positions to maximize profit on both sides
  Future<LegOutPlan> calculateLegOutStrategy({
    required OpenTrade originalTrade,
    required CounterHedge hedge,
    required double currentPrice,
    required double mlTrendProbability,
    required double volatility,
  }) async {
    List<LegOutStep> steps = [];

    // Current P&L of both positions
    bool originalIsBuy = originalTrade.type.toLowerCase() == 'buy';
    double originalPnL = originalIsBuy
        ? (currentPrice - originalTrade.entryPrice) *
              originalTrade.volume *
              100000
        : (originalTrade.entryPrice - currentPrice) *
              originalTrade.volume *
              100000;

    bool hedgeIsBuy = hedge.hedgeDirection == 'buy';
    double hedgePnL = hedgeIsBuy
        ? (currentPrice - hedge.hedgeEntryPrice) * hedge.hedgeVolume * 100000
        : (hedge.hedgeEntryPrice - currentPrice) * hedge.hedgeVolume * 100000;

    double totalPnL = originalPnL + hedgePnL;

    _logger.i('Leg-out analysis:');
    _logger.i('  Original trade P&L: \$${originalPnL.toStringAsFixed(2)}');
    _logger.i('  Hedge trade P&L: \$${hedgePnL.toStringAsFixed(2)}');
    _logger.i('  Combined P&L: \$${totalPnL.toStringAsFixed(2)}');

    // Strategy 1: If combined is profitable, close both
    if (totalPnL > hedge.totalLossToRecover * 0.5) {
      steps.add(
        LegOutStep(
          action: 'Close both positions',
          reason: 'Combined profit exceeds 50% of original loss',
          timing: 'Immediate',
          expectedProfit: totalPnL,
        ),
      );
      return LegOutPlan(steps: steps, strategy: 'Close both', confidence: 0.95);
    }

    // Strategy 2: Close profitable side first, ride the winner
    if (originalPnL > 0 && hedgePnL > originalPnL) {
      // Hedge is more profitable, close original first
      steps.add(
        LegOutStep(
          action: 'Close original position first',
          reason: 'Original is profitable but hedge is better',
          timing:
              'When original hits +${(originalPnL * 1.2).toStringAsFixed(2)}',
          expectedProfit: originalPnL,
        ),
      );
      steps.add(
        LegOutStep(
          action:
              'Ride hedge to target: ${hedge.hedgeTargetPrice.toStringAsFixed(5)}',
          reason:
              'ML trend probability: ${mlTrendProbability.toStringAsFixed(2)}',
          timing: 'Let run with trailing stop',
          expectedProfit: hedgePnL * 1.5,
        ),
      );
      return LegOutPlan(
        steps: steps,
        strategy: 'Close original, ride hedge',
        confidence: mlTrendProbability,
      );
    } else if (hedgePnL > 0 && originalPnL > hedgePnL) {
      // Original is more profitable, close hedge first
      steps.add(
        LegOutStep(
          action: 'Close hedge position first',
          reason: 'Hedge is profitable but original is better',
          timing: 'When hedge hits +${(hedgePnL * 1.2).toStringAsFixed(2)}',
          expectedProfit: hedgePnL,
        ),
      );
      steps.add(
        LegOutStep(
          action: 'Ride original to recovery target',
          reason: 'Original trend resuming',
          timing: 'Let run with cantilever stop',
          expectedProfit: originalPnL * 1.5,
        ),
      );
      return LegOutPlan(
        steps: steps,
        strategy: 'Close hedge, ride original',
        confidence: 1.0 - mlTrendProbability,
      );
    }

    // Strategy 3: Partial close, reduce risk
    if (totalPnL > 0 && totalPnL < hedge.totalLossToRecover * 0.5) {
      steps.add(
        LegOutStep(
          action: 'Partial close 50% of both positions',
          reason: 'Lock in partial profit, reduce risk',
          timing: 'Immediate',
          expectedProfit: totalPnL * 0.5,
        ),
      );
      steps.add(
        LegOutStep(
          action: 'Trail remaining 50%',
          reason: 'Let profitable portion run',
          timing:
              'Based on volatility: ${(volatility * 100).toStringAsFixed(2)}%',
          expectedProfit: totalPnL * 0.75,
        ),
      );
      return LegOutPlan(
        steps: steps,
        strategy: 'Partial close, trail remainder',
        confidence: 0.75,
      );
    }

    // Strategy 4: Both negative, wait for reversal
    if (totalPnL < 0) {
      double requiredMove =
          (hedge.totalLossToRecover - totalPnL) / (hedge.hedgeVolume * 100000);

      steps.add(
        LegOutStep(
          action: 'Hold both positions',
          reason: 'Waiting for market reversal',
          timing:
              'Until combined P&L > 0 or ${requiredMove.toStringAsFixed(5)} pip move',
          expectedProfit: 0,
        ),
      );
      steps.add(
        LegOutStep(
          action: 'Set combined stop loss',
          reason: 'Prevent catastrophic loss',
          timing:
              'If total loss exceeds ${(hedge.totalLossToRecover * 1.5).toStringAsFixed(2)}',
          expectedProfit: -hedge.totalLossToRecover * 1.5,
        ),
      );
      return LegOutPlan(
        steps: steps,
        strategy: 'Wait for reversal',
        confidence: 0.50,
      );
    }

    // Default: Close both at break-even
    steps.add(
      LegOutStep(
        action: 'Close both at break-even',
        reason: 'Neutral strategy',
        timing: 'When combined P&L ≥ 0',
        expectedProfit: 0,
      ),
    );

    return LegOutPlan(
      steps: steps,
      strategy: 'Break-even exit',
      confidence: 0.60,
    );
  }

  /// Scale risk based on user settings
  double applyUserRiskScale(double baseRiskAmount) {
    return baseRiskAmount * userRiskScale;
  }

  /// Update user risk scale (1.0 = normal, 2.0 = aggressive, 0.5 = conservative)
  void setUserRiskScale(double scale) {
    if (scale < 0.1 || scale > 5.0) {
      _logger.w('Risk scale out of bounds (0.1-5.0), capping');
      userRiskScale = scale.clamp(0.1, 5.0);
    } else {
      userRiskScale = scale;
      _logger.i('User risk scale set to: ${scale}x');
    }
  }
}

/// Cantilever trailing stop configuration
class CantileverStop {
  final String symbol;
  final double entryPrice;
  double currentStop;
  final bool direction; // true = buy, false = sell
  final double stepPercent;
  final double lockPercent;
  double lastUpdatePrice;

  // Original fields for compatibility
  final double stopLossPrice;
  final double lockedProfitAmount;
  final int profitSteps;
  final bool isActive;
  final double nextTriggerPrice;

  CantileverStop({
    this.symbol = '',
    this.entryPrice = 0.0,
    double? currentStop,
    this.direction = true,
    this.stepPercent = 0.0,
    this.lockPercent = 0.0,
    double? lastUpdatePrice,
    required this.stopLossPrice,
    required this.lockedProfitAmount,
    required this.profitSteps,
    required this.isActive,
    required this.nextTriggerPrice,
  }) : currentStop = currentStop ?? stopLossPrice,
       lastUpdatePrice = lastUpdatePrice ?? entryPrice;

  @override
  String toString() {
    return 'Cantilever Stop @ ${stopLossPrice.toStringAsFixed(5)} '
        '(Locked: \$${lockedProfitAmount.toStringAsFixed(2)}, '
        'Steps: $profitSteps)';
  }
}

/// Counter-hedge position
class CounterHedge {
  final OpenTrade originalTrade;
  final String hedgeDirection;
  final double hedgeVolume;
  final double hedgeEntryPrice;
  final double hedgeTargetPrice;
  final double totalLossToRecover;
  final DateTime timestamp;
  final double mlConfidence;
  HedgeStatus status;

  CounterHedge({
    required this.originalTrade,
    required this.hedgeDirection,
    required this.hedgeVolume,
    required this.hedgeEntryPrice,
    required this.hedgeTargetPrice,
    required this.totalLossToRecover,
    required this.timestamp,
    required this.mlConfidence,
    required this.status,
  });

  double calculateCurrentPnL(double currentPrice) {
    bool isBuy = hedgeDirection == 'buy';
    return isBuy
        ? (currentPrice - hedgeEntryPrice) * hedgeVolume * 100000
        : (hedgeEntryPrice - currentPrice) * hedgeVolume * 100000;
  }
}

enum HedgeStatus { active, partial_closed, fully_closed, stopped }

/// Leg-out execution plan
class LegOutPlan {
  final List<LegOutStep> steps;
  final String strategy;
  final double confidence;

  LegOutPlan({
    required this.steps,
    required this.strategy,
    required this.confidence,
  });

  @override
  String toString() {
    String output =
        'Leg-Out Strategy: $strategy (Confidence: ${(confidence * 100).toStringAsFixed(0)}%)\n';
    for (int i = 0; i < steps.length; i++) {
      output += 'Step ${i + 1}: ${steps[i]}\n';
    }
    return output;
  }
}

/// Individual step in leg-out process
class LegOutStep {
  final String action;
  final String reason;
  final String timing;
  final double expectedProfit;

  LegOutStep({
    required this.action,
    required this.reason,
    required this.timing,
    required this.expectedProfit,
  });

  @override
  String toString() {
    return '$action\n  Reason: $reason\n  Timing: $timing\n  Expected: \$${expectedProfit.toStringAsFixed(2)}';
  }
}
