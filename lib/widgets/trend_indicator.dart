import 'package:flutter/material.dart';
import 'dart:math';

class TrendIndicatorCard extends StatelessWidget {
  final String symbol;

  const TrendIndicatorCard({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Simulate trend data (in production, fetch from MT4)
    final random = Random();
    final price = 1.0800 + (random.nextDouble() * 0.02);
    final change = -0.5 + (random.nextDouble() * 1.0);
    final isPositive = change >= 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price.toStringAsFixed(5),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isPositive ? Colors.green : Colors.red).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
