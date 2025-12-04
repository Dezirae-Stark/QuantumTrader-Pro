import 'package:flutter/material.dart';

class TrendIndicatorCard extends StatelessWidget {
  final String symbol;
  final double price;
  final double changePercent;
  final bool isConnected;

  const TrendIndicatorCard({
    super.key,
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = changePercent >= 0;

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
              isConnected && price > 0 
                ? price.toStringAsFixed(5)
                : '---.-----',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: !isConnected || price == 0 ? Colors.grey : null,
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
                isConnected && price > 0
                  ? '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%'
                  : '-.--%',
                style: TextStyle(
                  color: !isConnected || price == 0 
                    ? Colors.grey
                    : (isPositive ? Colors.green : Colors.red),
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
