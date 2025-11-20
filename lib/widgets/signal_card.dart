import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';

class SignalCard extends StatelessWidget {
  final TradeSignal signal;

  const SignalCard({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm:ss');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: signal.getTrendColor(),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          signal.symbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              signal.trend == TrendDirection.bullish
                                  ? Icons.arrow_upward
                                  : signal.trend == TrendDirection.bearish
                                  ? Icons.arrow_downward
                                  : Icons.remove,
                              size: 16,
                              color: signal.getTrendColor(),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              signal.trend.name.toUpperCase(),
                              style: TextStyle(
                                color: signal.getTrendColor(),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: signal.action == 'entry'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        signal.action.toUpperCase(),
                        style: TextStyle(
                          color: signal.action == 'entry'
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(signal.timestamp),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: signal.getTrendColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Probability', style: theme.textTheme.bodySmall),
                      Text(
                        '${(signal.probability * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: signal.probability,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        signal.getTrendColor(),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            if (signal.mlPrediction != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.psychology,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ML Prediction Available',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
