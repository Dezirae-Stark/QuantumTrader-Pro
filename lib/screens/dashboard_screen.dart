import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/broker_adapter_service.dart';
import '../widgets/signal_card.dart';
import '../widgets/trend_indicator.dart';
import '../widgets/connection_status.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<String> _watchedSymbols = ['EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD'];

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  Future<void> _loadSignals() async {
    final brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    final signals = await brokerService.fetchSignals();
    if (mounted) {
      Provider.of<AppState>(context, listen: false).updateSignals(signals);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icons/app_icon.png',
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(Icons.show_chart),
            ),
            const SizedBox(width: 12),
            const Text('QuantumTrader Pro'),
          ],
        ),
        actions: [ConnectionStatusWidget(), const SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSignals,
        child: CustomScrollView(
          slivers: [
            // Trading Mode Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trading Mode',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<TradingMode>(
                          segments: const [
                            ButtonSegment(
                              value: TradingMode.conservative,
                              label: Text('Conservative'),
                              icon: Icon(Icons.shield_outlined),
                            ),
                            ButtonSegment(
                              value: TradingMode.aggressive,
                              label: Text('Aggressive'),
                              icon: Icon(Icons.flash_on),
                            ),
                          ],
                          selected: {appState.tradingMode},
                          onSelectionChanged: (Set<TradingMode> selected) {
                            appState.setTradingMode(selected.first);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Watched Symbols
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Market Overview',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final symbol = _watchedSymbols[index];
                  final marketData = appState.marketData[symbol];
                  return TrendIndicatorCard(
                    symbol: symbol,
                    price: marketData?['price']?.toDouble() ?? 0.0,
                    changePercent: marketData?['changePercent']?.toDouble() ?? 0.0,
                    isConnected: appState.isBrokerConnected,
                  );
                }, childCount: _watchedSymbols.length),
              ),
            ),

            // Recent Signals
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Signals', style: theme.textTheme.titleLarge),
                    TextButton.icon(
                      onPressed: _loadSignals,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ),

            // Signals List
            appState.signals.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pending_actions,
                            size: 64,
                            color: theme.colorScheme.secondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No signals available',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull to refresh or check MT4 connection',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final signal = appState.signals[index];
                        return SignalCard(signal: signal);
                      }, childCount: appState.signals.length),
                    ),
                  ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
          ],
        ),
      ),
    );
  }
}
