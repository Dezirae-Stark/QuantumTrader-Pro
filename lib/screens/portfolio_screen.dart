import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_state.dart';
import '../services/broker_adapter_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  Future<void> _loadTrades() async {
    final brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    final trades = await brokerService.fetchOpenTrades();
    if (mounted) {
      Provider.of<AppState>(context, listen: false).updateOpenTrades(trades);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(onPressed: _loadTrades, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrades,
        child: CustomScrollView(
          slivers: [
            // Total P&L Summary
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: appState.totalPnL >= 0
                        ? [Color(0xFF4CAF50), Color(0xFF66BB6A)]
                        : [Color(0xFFF44336), Color(0xFFEF5350)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (appState.totalPnL >= 0
                                  ? Color(0xFF4CAF50)
                                  : Color(0xFFF44336))
                              .withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Total P&L',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(appState.totalPnL),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          appState.totalPnL >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${appState.openTrades.length} Active Positions',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Open Trades Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Open Positions',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),

            // Open Trades List
            appState.openTrades.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: theme.colorScheme.secondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No open positions',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your active trades will appear here',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final trade = appState.openTrades[index];
                        return TradeCard(trade: trade);
                      }, childCount: appState.openTrades.length),
                    ),
                  ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
          ],
        ),
      ),
    );
  }
}

class TradeCard extends StatelessWidget {
  final OpenTrade trade;

  const TradeCard({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProfitable = trade.profitLoss >= 0;
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: trade.type.toLowerCase() == 'buy'
                            ? Color(0xFF4CAF50).withOpacity(0.1)
                            : Color(0xFFF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trade.type.toUpperCase(),
                        style: TextStyle(
                          color: trade.type.toLowerCase() == 'buy'
                              ? Color(0xFF4CAF50)
                              : Color(0xFFF44336),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      trade.symbol,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyFormat.format(trade.profitLoss),
                  style: TextStyle(
                    color: isProfitable ? Color(0xFF4CAF50) : Color(0xFFF44336),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Entry',
                    trade.entryPrice.toStringAsFixed(5),
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Current',
                    trade.currentPrice.toStringAsFixed(5),
                    theme,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Volume',
                    trade.volume.toStringAsFixed(2),
                    theme,
                  ),
                ),
              ],
            ),
            if (trade.predictedWindow != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ML Prediction: ${trade.predictedWindow} candles ahead',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
