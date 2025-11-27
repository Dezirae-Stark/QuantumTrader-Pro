import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../services/mt4_service.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_button.dart';

class CyberpunkPortfolioScreen extends StatefulWidget {
  const CyberpunkPortfolioScreen({super.key});

  @override
  State<CyberpunkPortfolioScreen> createState() => _CyberpunkPortfolioScreenState();
}

class _CyberpunkPortfolioScreenState extends State<CyberpunkPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
    _loadTrades();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTrades() async {
    setState(() => _isLoading = true);
    
    try {
      final mt4Service = Provider.of<MT4Service>(context, listen: false);
      final trades = await mt4Service.fetchOpenTrades();
      if (mounted) {
        Provider.of<AppState>(context, listen: false).updateOpenTrades(trades);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: QuantumColors.backgroundSecondary,
        title: Text(
          'Portfolio',
          style: theme.textTheme.headlineMedium!.copyWith(
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadTrades,
            icon: AnimatedRotation(
              turns: _isLoading ? 1 : 0,
              duration: const Duration(seconds: 1),
              child: Icon(
                Icons.refresh,
                color: _isLoading ? QuantumColors.neonCyan : QuantumColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrades,
        color: QuantumColors.neonCyan,
        backgroundColor: QuantumColors.surface,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              // Total P&L Card
              SliverToBoxAdapter(
                child: _buildTotalPnLCard(appState, currencyFormat),
              ),

              // Portfolio Metrics
              SliverToBoxAdapter(
                child: _buildPortfolioMetrics(appState),
              ),

              // Open Positions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Open Positions',
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (appState.openTrades.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: QuantumColors.neonCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: QuantumColors.neonCyan.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 16,
                                color: QuantumColors.neonCyan,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Sort',
                                style: theme.textTheme.labelSmall!.copyWith(
                                  color: QuantumColors.neonCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Open Positions List or Empty State
              appState.openTrades.isEmpty
                  ? SliverFillRemaining(
                      child: _buildEmptyState(theme),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildTradeCard(
                            appState.openTrades[index],
                            currencyFormat,
                          ),
                          childCount: appState.openTrades.length,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalPnLCard(AppState appState, NumberFormat currencyFormat) {
    final isProfit = appState.totalPnL >= 0;
    final pnlColor = isProfit ? QuantumColors.bullish : QuantumColors.bearish;
    
    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      child: QuantumCard(
        hasGlow: true,
        glowColor: pnlColor.withOpacity(0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pnlColor.withOpacity(0.2),
            pnlColor.withOpacity(0.05),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Total P&L',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: QuantumColors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Icon(
                  isProfit ? Icons.trending_up : Icons.trending_down,
                  color: pnlColor,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  currencyFormat.format(appState.totalPnL),
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: QuantumColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: QuantumColors.neonCyan.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${appState.openTrades.length} active ${appState.openTrades.length == 1 ? 'position' : 'positions'}',
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: QuantumColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioMetrics(AppState appState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              icon: Icons.account_balance,
              label: 'Realized P&L',
              value: '\$0.00',
              color: QuantumColors.neonGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              icon: Icons.trending_flat,
              label: 'Unrealized P&L',
              value: '\$${appState.totalPnL.toStringAsFixed(2)}',
              color: QuantumColors.neonMagenta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              icon: Icons.account_balance_wallet,
              label: 'Equity',
              value: '\$10,250.00',
              color: QuantumColors.neonCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return QuantumCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: QuantumColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: QuantumCard(
        width: 300,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: QuantumColors.neonCyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: QuantumColors.neonCyan,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No open positions',
              style: theme.textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your active trades will appear here',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: QuantumColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            QuantumButton(
              text: 'Open New Trade',
              icon: Icons.add_circle_outline,
              onPressed: () {
                // Navigate to trading screen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeCard(OpenTrade trade, NumberFormat currencyFormat) {
    final isProfit = trade.profitLoss >= 0;
    final profitColor = isProfit ? QuantumColors.bullish : QuantumColors.bearish;

    return QuantumCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _showTradeDetails(trade),
      child: Column(
        children: [
          Row(
            children: [
              // Trade direction icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: trade.type == 'buy'
                      ? QuantumColors.bullish.withOpacity(0.1)
                      : QuantumColors.bearish.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  trade.type == 'buy'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: trade.type == 'buy'
                      ? QuantumColors.bullish
                      : QuantumColors.bearish,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Trade info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trade.symbol,
                          style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: profitColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${isProfit ? '+' : ''}${currencyFormat.format(trade.profitLoss)}',
                            style: TextStyle(
                              color: profitColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTradeInfo(
                          'Volume',
                          trade.volume.toString(),
                          Icons.pie_chart_outline,
                        ),
                        const SizedBox(width: 16),
                        _buildTradeInfo(
                          'Entry',
                          trade.entryPrice.toStringAsFixed(5),
                          Icons.login,
                        ),
                        const SizedBox(width: 16),
                        _buildTradeInfo(
                          'Current',
                          trade.currentPrice.toStringAsFixed(5),
                          Icons.trending_flat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Risk indicators
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (trade.profitLoss.abs() / 100).clamp(0, 1),
                  backgroundColor: QuantumColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isProfit ? QuantumColors.bullish : QuantumColors.bearish,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${((trade.profitLoss.abs() / 100) * 100).toStringAsFixed(0)}% Risk',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: QuantumColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradeInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: QuantumColors.textTertiary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: QuantumColors.textTertiary,
                fontSize: 10,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showTradeDetails(OpenTrade trade) {
    // Show trade details in modal
    showModalBottomSheet(
      context: context,
      backgroundColor: QuantumColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trade Details - ${trade.symbol}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            // Add trade details here
            QuantumButton(
              text: 'Close Position',
              type: QuantumButtonType.secondary,
              onPressed: () {
                Navigator.pop(context);
                // Close position logic
              },
            ),
          ],
        ),
      ),
    );
  }
}