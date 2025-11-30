import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/autotrading_engine.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_button.dart';

class AutoTradingStatusWidget extends StatefulWidget {
  const AutoTradingStatusWidget({super.key});

  @override
  State<AutoTradingStatusWidget> createState() => _AutoTradingStatusWidgetState();
}

class _AutoTradingStatusWidgetState extends State<AutoTradingStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final autoTradingEngine = Provider.of<AutoTradingEngine>(context);
    final isActive = autoTradingEngine.isEnabled;
    final stats = autoTradingEngine.getPerformanceStats();

    return QuantumCard(
      hasGlow: isActive,
      glowColor: QuantumColors.neonGreen.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? QuantumColors.neonGreen.withOpacity(_pulseAnimation.value * 0.2)
                        : QuantumColors.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: isActive
                        ? QuantumColors.neonGreen
                        : QuantumColors.textTertiary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AutoTrading Engine',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      isActive
                          ? 'Status: ${stats['status']}'
                          : 'Status: Inactive',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: isActive
                            ? QuantumColors.neonGreen
                            : QuantumColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              QuantumButton(
                text: isActive ? 'Stop' : 'Start',
                size: QuantumButtonSize.small,
                type: isActive
                    ? QuantumButtonType.outline
                    : QuantumButtonType.primary,
                onPressed: () async {
                  if (isActive) {
                    await autoTradingEngine.stop();
                  } else {
                    await autoTradingEngine.start();
                  }
                  setState(() {});
                },
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Win Rate',
                  '${stats['winRate'].toStringAsFixed(1)}%',
                  Icons.trending_up,
                  QuantumColors.neonGreen,
                ),
                _buildStatCard(
                  'Active',
                  '${stats['activeSessions']}',
                  Icons.swap_horiz,
                  QuantumColors.neonCyan,
                ),
                _buildStatCard(
                  'P/L Factor',
                  stats['profitFactor'].toStringAsFixed(2),
                  Icons.auto_graph,
                  QuantumColors.neonMagenta,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: QuantumColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: QuantumColors.neonGreen.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Profit',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: QuantumColors.textSecondary,
                    ),
                  ),
                  Text(
                    '\$${stats['netProfit'].toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: stats['netProfit'] >= 0
                          ? QuantumColors.neonGreen
                          : QuantumColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: QuantumColors.textTertiary,
          ),
        ),
      ],
    );
  }
}