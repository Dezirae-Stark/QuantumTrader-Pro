import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../widgets/signal_card.dart';
import '../widgets/connection_status.dart';
import 'broker_config_screen.dart';

class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({super.key});

  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  final List<String> _watchedSymbols = [
    'EURUSD',
    'GBPUSD',
    'USDJPY',
    'AUDUSD',
    'XAUUSD',
  ];

  final Map<String, List<double>> _priceHistory = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializePriceHistory();
    _startAutoRefresh();
    _loadSignals();
  }

  void _initializePriceHistory() {
    for (final symbol in _watchedSymbols) {
      _priceHistory[symbol] = List.generate(20, (i) => 1.0 + (i * 0.001));
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _updatePriceData();
      }
    });
  }

  void _updatePriceData() {
    // Simulate price updates (in real app, fetch from broker service)
    setState(() {
      for (final symbol in _watchedSymbols) {
        final history = _priceHistory[symbol]!;
        history.removeAt(0);
        final lastPrice = history.last;
        final change =
            (lastPrice * 0.001) *
            (DateTime.now().millisecond % 2 == 0 ? 1 : -1);
        history.add(lastPrice + change);
      }
    });
  }

  Future<void> _loadSignals() async {
    // TODO: Fetch from broker service
    // For now, keep existing logic
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('QuantumTrader Pro'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_input_antenna),
                tooltip: 'Broker Configuration',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BrokerConfigScreen(),
                    ),
                  );
                },
              ),
              ConnectionStatusWidget(),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              tabs: const [
                const Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 20)),
                const Tab(text: 'Markets', icon: Icon(Icons.trending_up, size: 20)),
                Tab(
                  text: 'Signals',
                  icon: const Icon(Icons.notifications_active, size: 20),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(appState, theme),
            _buildMarketsTab(theme),
            _buildSignalsTab(appState, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(AppState appState, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadSignals,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme: theme,
                    icon: Icons.account_balance_wallet,
                    label: 'Balance',
                    value: '\$10,000.00',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme: theme,
                    icon: Icons.trending_up,
                    label: 'Equity',
                    value: '\$10,250.00',
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme: theme,
                    icon: Icons.show_chart,
                    label: 'Profit',
                    value: '+\$250.00',
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme: theme,
                    icon: Icons.pie_chart,
                    label: 'Positions',
                    value: '3 open',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Trading Mode
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Trading Mode',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<TradingMode>(
                      segments: const [
                        ButtonSegment(
                          value: TradingMode.conservative,
                          label: const Text('Conservative'),
                          icon: const Icon(Icons.shield_outlined),
                        ),
                        ButtonSegment(
                          value: TradingMode.aggressive,
                          label: const Text('Aggressive'),
                          icon: const Icon(Icons.flash_on),
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

            const SizedBox(height: 24),

            // Performance Chart
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Account Performance',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                        Chip(
                          label: const Text('+2.5%'),
                          backgroundColor: Colors.green.shade100,
                          labelStyle: TextStyle(
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '\$${value.toInt()}',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}h',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                20,
                                (i) => FlSpot(
                                  i.toDouble(),
                                  10000 + (i * 50) + ((i % 3) * 30),
                                ),
                              ),
                              isCurved: true,
                              color: theme.colorScheme.primary,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: theme.colorScheme.primary.withOpacity(
                                  0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketsTab(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _watchedSymbols.length,
      itemBuilder: (context, index) {
        final symbol = _watchedSymbols[index];
        final priceHistory = _priceHistory[symbol]!;
        final currentPrice = priceHistory.last;
        final change =
            priceHistory.last - priceHistory[priceHistory.length - 5];
        final changePercent =
            (change / priceHistory[priceHistory.length - 5]) * 100;
        final isPositive = change >= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          symbol,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPrice.toStringAsFixed(5),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                            color: isPositive
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: isPositive
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 80,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: priceHistory
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: isPositive ? Colors.green : Colors.red,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: isPositive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignalsTab(AppState appState, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadSignals,
      child: appState.signals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.pending_actions,
                    size: 80,
                    color: theme.colorScheme.secondary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text('No Active Signals', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appState.signals.length,
              itemBuilder: (context, index) {
                final signal = appState.signals[index];
                return SignalCard(signal: signal);
              },
            ),
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
