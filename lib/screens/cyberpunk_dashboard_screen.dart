import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/app_state.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_button.dart';
import '../theme/components/quantum_controls.dart';
import '../services/broker_adapter_service.dart';
import '../services/telegram_service.dart';
import '../widgets/market_pair_dialog.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'broker_config_screen.dart';

class CyberpunkDashboardScreen extends StatefulWidget {
  const CyberpunkDashboardScreen({super.key});

  @override
  State<CyberpunkDashboardScreen> createState() => _CyberpunkDashboardScreenState();
}

class _CyberpunkDashboardScreenState extends State<CyberpunkDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BrokerAdapterService _brokerService;
  late TelegramService _telegramService;
  late Box _marketSettingsBox;
  Timer? _refreshTimer;
  bool _isLoadingMarketData = true;

  List<String> _watchedSymbols = [
    'EURUSD',
    'GBPUSD',
    'USDJPY',
    'XAUUSD',
  ];

  final Map<String, MarketData> _marketData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    _telegramService = Provider.of<TelegramService>(context, listen: false);
    _initializeData();
    _startAutoRefresh();
  }

  Future<void> _initializeData() async {
    _marketSettingsBox = await Hive.openBox('market_settings');
    _loadWatchedPairs();
    await _checkConnections();
    await _loadMarketData();
    await _loadSignals();
  }

  void _loadWatchedPairs() {
    final savedPairs = _marketSettingsBox.get('watched_pairs');
    if (savedPairs != null && savedPairs is List) {
      setState(() {
        _watchedSymbols = List<String>.from(savedPairs);
      });
    }
  }

  void _updateWatchedPairs(List<String> newPairs) {
    setState(() {
      _watchedSymbols = newPairs;
      // Initialize market data for new pairs
      for (final symbol in _watchedSymbols) {
        if (!_marketData.containsKey(symbol)) {
          _marketData[symbol] = MarketData(
            symbol: symbol,
            price: 0.0,
            change: 0.0,
            changePercent: 0.0,
            spread: 0.0,
            volume: 0,
            trend: TrendDirection.neutral,
          );
        }
      }
    });
    _loadMarketData();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (mounted) {
        await _loadMarketData();
        await _checkConnections();
      }
    });
  }

  Future<void> _loadMarketData() async {
    if (!_brokerService.isConnected) {
      // Initialize empty data when not connected
      setState(() {
        for (final symbol in _watchedSymbols) {
          _marketData[symbol] = MarketData(
            symbol: symbol,
            price: 0.0,
            change: 0.0,
            changePercent: 0.0,
            spread: 0.0,
            volume: 0,
            trend: TrendDirection.neutral,
          );
        }
        _isLoadingMarketData = false;
      });
      return;
    }

    try {
      final marketData = await _brokerService.fetchMarketData();
      if (marketData.isNotEmpty && mounted) {
        setState(() {
          // Update market data from live feed
          for (final symbol in _watchedSymbols) {
            if (marketData.containsKey(symbol)) {
              final data = marketData[symbol] as Map<String, dynamic>;
              _marketData[symbol] = MarketData(
                symbol: symbol,
                price: (data['price'] ?? 0.0).toDouble(),
                change: (data['change'] ?? 0.0).toDouble(),
                changePercent: (data['changePercent'] ?? 0.0).toDouble(),
                spread: (data['spread'] ?? 0.0).toDouble(),
                volume: (data['volume'] ?? 0).toInt(),
                trend: _determineTrend(data['changePercent'] ?? 0.0),
              );
            }
          }
          _isLoadingMarketData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading market data: $e');
      setState(() {
        _isLoadingMarketData = false;
      });
    }
  }

  TrendDirection _determineTrend(double changePercent) {
    if (changePercent > 0.1) return TrendDirection.bullish;
    if (changePercent < -0.1) return TrendDirection.bearish;
    return TrendDirection.neutral;
  }

  Future<void> _checkConnections() async {
    final appState = Provider.of<AppState>(context, listen: false);

    // Check broker connection
    final isBrokerConnected = _brokerService.isConnected;
    appState.setMT4Connection(isBrokerConnected);

    // Check Telegram connection
    final isTelegramConnected = await _telegramService.isConnected();
    appState.setTelegramConnection(isTelegramConnected);
  }

  Future<void> _loadSignals() async {
    if (!_brokerService.isConnected) return;

    try {
      final signals = await _brokerService.fetchSignals();
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.updateSignals(signals);
      }
    } catch (e) {
      debugPrint('Error loading signals: $e');
    }
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
      body: Column(
        children: [
          // Custom app bar with connection status
          Container(
            decoration: BoxDecoration(
              color: QuantumColors.backgroundSecondary,
              border: Border(
                bottom: BorderSide(
                  color: QuantumColors.neonCyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QuantumTrader Pro',
                      style: theme.textTheme.headlineMedium!.copyWith(
                        color: QuantumColors.textPrimary,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildConnectionPill(
                          _brokerService.brokerType == BrokerType.mt5 ? 'MT5' : 'MT4',
                          appState.isConnectedToMT4,
                          onTap: () => _navigateToBrokerConfig(),
                        ),
                        const SizedBox(width: 8),
                        _buildConnectionPill(
                          'TG',
                          appState.isTelegramConnected,
                          onTap: () => _navigateToBrokerConfig(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab bar
          Container(
            color: QuantumColors.backgroundSecondary,
            child: TabBar(
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
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(appState),
                _buildMarketsTab(),
                _buildSignalsTab(appState),
              ],
            ),
          ),
        ],
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
    if (appState.signals.isEmpty) {
      return Center(
        child: _buildEmptySignalsState(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appState.signals.length,
      itemBuilder: (context, index) {
        final signal = appState.signals[index];
        return _buildSignalCard(signal);
      },
    );
  }

  Widget _buildSignalCard(TradeSignal signal) {
    final color = signal.getTrendColor();

    return QuantumCard(
      margin: const EdgeInsets.only(bottom: 12),
      hasGlow: signal.probability > 0.8,
      glowColor: color.withOpacity(0.3),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      signal.symbol,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${(signal.probability * 100).toInt()}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _getTrendIcon(signal.trend),
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      signal.trend.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      signal.action.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: QuantumColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(signal.timestamp),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: QuantumColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  void _showTradingModeSnackbar(TradingMode mode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Trading mode set to ${mode == TradingMode.conservative ? 'Conservative' : 'Aggressive'}',
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