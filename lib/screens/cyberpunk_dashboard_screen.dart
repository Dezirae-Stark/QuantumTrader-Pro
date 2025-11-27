import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_button.dart';
import '../theme/components/quantum_controls.dart';
import '../widgets/signal_card.dart';
import 'broker_config_screen.dart';

class CyberpunkDashboardScreen extends StatefulWidget {
  const CyberpunkDashboardScreen({super.key});

  @override
  State<CyberpunkDashboardScreen> createState() => _CyberpunkDashboardScreenState();
}

class _CyberpunkDashboardScreenState extends State<CyberpunkDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _isMT4Connected = false;
  bool _isTelegramConnected = false;

  final List<String> _watchedSymbols = [
    'EURUSD',
    'GBPUSD',
    'USDJPY',
    'XAUUSD',
  ];

  final Map<String, MarketData> _marketData = {
    'EURUSD': MarketData(
      symbol: 'EURUSD',
      price: 1.0856,
      change: 0.0012,
      changePercent: 0.11,
      spread: 0.8,
      volume: 125430,
      trend: TrendDirection.bullish,
    ),
    'GBPUSD': MarketData(
      symbol: 'GBPUSD',
      price: 1.2634,
      change: -0.0023,
      changePercent: -0.18,
      spread: 1.2,
      volume: 98765,
      trend: TrendDirection.bearish,
    ),
    'USDJPY': MarketData(
      symbol: 'USDJPY',
      price: 149.32,
      change: 0.45,
      changePercent: 0.30,
      spread: 0.5,
      volume: 234567,
      trend: TrendDirection.bullish,
    ),
    'XAUUSD': MarketData(
      symbol: 'XAUUSD',
      price: 2034.56,
      change: 12.34,
      changePercent: 0.61,
      spread: 3.0,
      volume: 45678,
      trend: TrendDirection.bullish,
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startAutoRefresh();
    _loadSignals();
    _checkConnections();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _updateMarketData();
      }
    });
  }

  void _updateMarketData() {
    setState(() {
      _marketData.forEach((symbol, data) {
        final random = (DateTime.now().millisecond / 1000);
        final changeMultiplier = random > 0.5 ? 1 : -1;
        data.price += data.price * 0.0001 * changeMultiplier;
        data.change = data.price * 0.001 * changeMultiplier;
        data.changePercent = (data.change / data.price) * 100;
      });
    });
  }

  void _checkConnections() {
    // TODO: Check actual connections
    setState(() {
      _isMT4Connected = false;
      _isTelegramConnected = false;
    });
  }

  Future<void> _loadSignals() async {
    // TODO: Load from service
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
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: QuantumColors.backgroundSecondary,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QuantumTrader Pro',
                    style: theme.textTheme.headlineMedium!.copyWith(
                      color: QuantumColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildConnectionPill(
                        'MT4',
                        _isMT4Connected,
                        onTap: () => _navigateToBrokerConfig(),
                      ),
                      const SizedBox(width: 8),
                      _buildConnectionPill(
                        'TG',
                        _isTelegramConnected,
                        onTap: () => _navigateToBrokerConfig(),
                      ),
                    ],
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      QuantumColors.backgroundSecondary,
                      QuantumColors.backgroundTertiary.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: QuantumColors.neonCyan,
              indicatorWeight: 3,
              labelColor: QuantumColors.neonCyan,
              unselectedLabelColor: QuantumColors.textTertiary,
              tabs: const [
                Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined)),
                Tab(text: 'Markets', icon: Icon(Icons.show_chart)),
                Tab(text: 'Signals', icon: Icon(Icons.notifications_outlined)),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(appState),
            _buildMarketsTab(),
            _buildSignalsTab(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPill(String label, bool isConnected, {VoidCallback? onTap}) {
    return QuantumPillButton(
      text: label,
      isActive: isConnected,
      onPressed: onTap,
      icon: _getConnectionIcon(isConnected),
    );
  }

  IconData _getConnectionIcon(bool isConnected) {
    if (isConnected) return Icons.check_circle;
    return Icons.error_outline;
  }

  void _navigateToBrokerConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BrokerConfigScreen()),
    );
  }

  Widget _buildOverviewTab(AppState appState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trading Mode Section
          QuantumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: QuantumColors.neonCyan, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Trading Mode',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                QuantumSegmentedControl<TradingMode>(
                  value: appState.tradingMode,
                  options: const {
                    TradingMode.conservative: 'Conservative',
                    TradingMode.aggressive: 'Aggressive',
                  },
                  onValueChanged: (mode) {
                    appState.setTradingMode(mode);
                    _showTradingModeSnackbar(mode);
                  },
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    appState.tradingMode == TradingMode.conservative
                        ? 'Lower risk, fewer trades'
                        : 'Higher risk, more trades',
                    key: ValueKey(appState.tradingMode),
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: QuantumColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Market Overview Grid
          Text(
            'Market Overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: _watchedSymbols.map((symbol) {
              final data = _marketData[symbol]!;
              return _buildMarketCard(data);
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Recent Signals Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Signals',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              QuantumButton(
                text: 'Refresh',
                icon: Icons.refresh,
                size: QuantumButtonSize.small,
                type: QuantumButtonType.outline,
                onPressed: _loadSignals,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEmptySignalsState(),
        ],
      ),
    );
  }

  Widget _buildMarketCard(MarketData data) {
    final isPositive = data.changePercent >= 0;
    final color = isPositive ? QuantumColors.bullish : QuantumColors.bearish;
    
    return QuantumCard(
      hasGlow: data.trend == TrendDirection.bullish,
      glowColor: color.withOpacity(0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data.symbol,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Icon(
                _getTrendIcon(data.trend),
                color: color,
                size: 20,
              ),
            ],
          ),
          Text(
            data.price.toStringAsFixed(data.symbol.contains('JPY') ? 2 : 5),
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: QuantumColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${data.changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Spread: ${data.spread}',
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

  IconData _getTrendIcon(TrendDirection trend) {
    switch (trend) {
      case TrendDirection.bullish:
        return Icons.trending_up;
      case TrendDirection.bearish:
        return Icons.trending_down;
      case TrendDirection.neutral:
        return Icons.trending_flat;
    }
  }

  Widget _buildEmptySignalsState() {
    return QuantumCard(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_cellular_no_sim,
              size: 48,
              color: QuantumColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No signals yet',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: QuantumColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Signals will appear when the quantum engine\nis active and connected',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: QuantumColors.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _marketData.length,
      itemBuilder: (context, index) {
        final symbol = _marketData.keys.elementAt(index);
        final data = _marketData[symbol]!;
        return _buildMarketListItem(data);
      },
    );
  }

  Widget _buildMarketListItem(MarketData data) {
    final isPositive = data.changePercent >= 0;
    final color = isPositive ? QuantumColors.bullish : QuantumColors.bearish;

    return QuantumCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.symbol,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Volume: ${data.volume.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: QuantumColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.price.toStringAsFixed(data.symbol.contains('JPY') ? 2 : 5),
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data.changePercent.abs().toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Container(
            height: 60,
            width: 80,
            child: CustomPaint(
              painter: SparklinePainter(
                data: List.generate(20, (i) => data.price + (i - 10) * 0.001),
                lineColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalsTab(AppState appState) {
    return Center(
      child: _buildEmptySignalsState(),
    );
  }

  void _showTradingModeSnackbar(TradingMode mode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Trading mode set to ${mode == TradingMode.conservative ? "Conservative" : "Aggressive"}',
          style: TextStyle(color: QuantumColors.textPrimary),
        ),
        backgroundColor: QuantumColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: QuantumColors.neonCyan.withOpacity(0.5),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class MarketData {
  final String symbol;
  double price;
  double change;
  double changePercent;
  final double spread;
  final int volume;
  final TrendDirection trend;

  MarketData({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
    required this.spread,
    required this.volume,
    required this.trend,
  });
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  SparklinePainter({
    required this.data,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final glowPath = Path();

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedValue = (data[i] - min) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        glowPath.lineTo(x, y);
      }
    }

    canvas.drawPath(glowPath, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}