import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/cantilever_hedge_manager.dart';
import '../services/risk_manager.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_controls.dart';

class CyberpunkQuantumScreen extends StatefulWidget {
  const CyberpunkQuantumScreen({super.key});

  @override
  State<CyberpunkQuantumScreen> createState() => _CyberpunkQuantumScreenState();
}

class _CyberpunkQuantumScreenState extends State<CyberpunkQuantumScreen>
    with TickerProviderStateMixin {
  final hedgeManager = CantileverHedgeManager();
  final riskManager = RiskManager();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double _riskScale = 1.0;
  double _cantileverStepSize = 0.5;
  double _cantileverLockPercent = 0.6;
  bool _autoHedgeEnabled = true;
  double _hedgeMultiplier = 1.5;
  bool _isQuantumActive = false;

  // Quantum system modules
  final Map<String, ModuleStatus> _moduleStatus = {
    'Quantum Predictor': ModuleStatus(isActive: true, confidence: 0.94),
    'Chaos Analyzer': ModuleStatus(isActive: true, confidence: 0.87),
    'Adaptive ML': ModuleStatus(isActive: true, confidence: 0.91),
    'Cantilever Stops': ModuleStatus(isActive: false, confidence: 0.0),
    'Counter-Hedge': ModuleStatus(isActive: false, confidence: 0.0),
  };

  List<Map<String, dynamic>> _quantumPredictions = [];

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
    
    _loadQuantumData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadQuantumData() async {
    setState(() {
      _quantumPredictions = [
        {
          'candle': 1,
          'predicted_price': 1.0875,
          'upper_bound': 1.0890,
          'lower_bound': 1.0860,
          'bullish_probability': 0.72,
          'confidence': 0.85,
        },
        {
          'candle': 3,
          'predicted_price': 1.0895,
          'upper_bound': 1.0920,
          'lower_bound': 1.0870,
          'bullish_probability': 0.68,
          'confidence': 0.78,
        },
        {
          'candle': 5,
          'predicted_price': 1.0910,
          'upper_bound': 1.0945,
          'lower_bound': 1.0875,
          'bullish_probability': 0.65,
          'confidence': 0.70,
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: QuantumColors.backgroundSecondary,
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Icon(
                Icons.psychology,
                size: 28,
                color: _isQuantumActive
                    ? QuantumColors.neonCyan.withOpacity(_pulseAnimation.value)
                    : QuantumColors.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Quantum Trading System',
              style: theme.textTheme.headlineMedium!.copyWith(
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: QuantumColors.textTertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                QuantumToggle(
                  value: _isQuantumActive,
                  onChanged: (value) {
                    setState(() {
                      _isQuantumActive = value;
                      if (value) {
                        _showActivationMessage();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quantum System Module Status
          _buildModuleStatusCard(),
          const SizedBox(height: 20),

          // Risk Scale Control
          _buildRiskScaleCard(),
          const SizedBox(height: 20),

          // Cantilever Trailing Stop
          _buildCantileverCard(),
          const SizedBox(height: 20),

          // Counter-Hedge Recovery
          _buildHedgeCard(),
          const SizedBox(height: 20),

          // Quantum Predictions
          _buildPredictionsSection(),
          const SizedBox(height: 20),

          // System Performance
          _buildPerformanceCard(appState),
        ],
      ),
    );
  }

  Widget _buildModuleStatusCard() {
    return QuantumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: QuantumColors.neonCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.memory,
                  color: QuantumColors.neonCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Quantum System Modules',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isQuantumActive)
            Text(
              'Automated ML engine and quantum predictor are active',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: QuantumColors.neonGreen,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 16),
          ..._moduleStatus.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildModuleRow(entry.key, entry.value),
          )),
        ],
      ),
    );
  }

  Widget _buildModuleRow(String moduleName, ModuleStatus status) {
    final isActive = _isQuantumActive && status.isActive;
    
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? QuantumColors.neonGreen : QuantumColors.textTertiary,
            boxShadow: isActive
                ? [BoxShadow(
                    color: QuantumColors.neonGreen.withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )]
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            moduleName,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: isActive ? QuantumColors.textPrimary : QuantumColors.textTertiary,
            ),
          ),
        ),
        if (isActive && status.confidence > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: QuantumColors.neonCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: QuantumColors.neonCyan.withOpacity(0.3),
              ),
            ),
            child: Text(
              '${(status.confidence * 100).toInt()}%',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: QuantumColors.neonCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Icon(
          isActive ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: isActive ? QuantumColors.neonGreen : QuantumColors.textTertiary,
        ),
      ],
    );
  }

  Widget _buildRiskScaleCard() {
    return QuantumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: QuantumColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.speed,
                  color: QuantumColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Risk Scale',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          QuantumSlider(
            value: _riskScale,
            min: 0.1,
            max: 5.0,
            divisions: 49,
            label: 'Risk Multiplier',
            displayValue: (value) => '${value.toStringAsFixed(1)}x',
            activeColor: _getRiskColor(_riskScale),
            onChanged: (value) {
              setState(() {
                _riskScale = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getRiskColor(_riskScale).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getRiskColor(_riskScale).withOpacity(0.3),
              ),
            ),
            child: Text(
              _getRiskLabel(_riskScale),
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: _getRiskColor(_riskScale),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCantileverCard() {
    return QuantumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: QuantumColors.neonGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.stairs,
                  color: QuantumColors.neonGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cantilever Trailing Stop',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              QuantumToggle(
                value: _moduleStatus['Cantilever Stops']!.isActive,
                onChanged: (value) {
                  if (_isQuantumActive) {
                    setState(() {
                      _moduleStatus['Cantilever Stops']!.isActive = value;
                    });
                  }
                },
                scale: 0.8,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: QuantumSlider(
                  value: _cantileverStepSize,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: 'Step Size',
                  displayValue: (value) => '${(value * 100).toInt()}%',
                  onChanged: (value) {
                    if (_moduleStatus['Cantilever Stops']!.isActive) {
                      setState(() {
                        _cantileverStepSize = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: QuantumSlider(
                  value: _cantileverLockPercent,
                  min: 0.4,
                  max: 0.9,
                  divisions: 10,
                  label: 'Lock Percent',
                  displayValue: (value) => '${(value * 100).toInt()}%',
                  onChanged: (value) {
                    if (_moduleStatus['Cantilever Stops']!.isActive) {
                      setState(() {
                        _cantileverLockPercent = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: QuantumColors.neonGreen.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: QuantumColors.neonGreen.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: QuantumColors.neonGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Every ${(_cantileverStepSize * 100).toInt()}% profit → Lock ${(_cantileverLockPercent * 100).toInt()}% of it',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: QuantumColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHedgeCard() {
    return QuantumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: QuantumColors.neonMagenta.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.swap_horiz,
                  color: QuantumColors.neonMagenta,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Counter-Hedge Recovery',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              QuantumToggle(
                value: _autoHedgeEnabled,
                onChanged: (value) {
                  if (_isQuantumActive) {
                    setState(() {
                      _autoHedgeEnabled = value;
                      _moduleStatus['Counter-Hedge']!.isActive = value;
                    });
                  }
                },
                scale: 0.8,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: QuantumColors.neonCyan.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: QuantumColors.neonCyan.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-recovery system activates on stop loss',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: QuantumColors.neonCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHedgeStep('1', 'Stop loss triggers', Icons.warning),
                _buildHedgeStep('2', 'Opposite position opens (${_hedgeMultiplier}x)', Icons.swap_vert),
                _buildHedgeStep('3', 'ML manages both sides', Icons.psychology),
                _buildHedgeStep('4', 'Close at profit or breakeven', Icons.check_circle),
              ],
            ),
          ),
          const SizedBox(height: 16),
          QuantumSlider(
            value: _hedgeMultiplier,
            min: 1.0,
            max: 3.0,
            divisions: 8,
            label: 'Hedge Multiplier',
            displayValue: (value) => '${value.toStringAsFixed(1)}x',
            activeColor: QuantumColors.neonMagenta,
            onChanged: (value) {
              if (_autoHedgeEnabled) {
                setState(() {
                  _hedgeMultiplier = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHedgeStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: QuantumColors.neonMagenta.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: QuantumColors.neonMagenta,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 16, color: QuantumColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: QuantumColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quantum Predictions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_isQuantumActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: QuantumColors.neonGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: QuantumColors.neonGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: QuantumColors.neonGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: QuantumColors.neonGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ..._quantumPredictions.map((prediction) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPredictionCard(prediction),
        )),
      ],
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    final confidence = prediction['confidence'] as double;
    final bullishProb = prediction['bullish_probability'] as double;
    final isBullish = bullishProb > 0.5;
    
    return QuantumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: QuantumColors.neonMagenta.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: QuantumColors.neonMagenta.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Candle +${prediction['candle']}',
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: QuantumColors.neonMagenta,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    isBullish ? Icons.trending_up : Icons.trending_down,
                    color: isBullish ? QuantumColors.bullish : QuantumColors.bearish,
                    size: 24,
                  ),
                ],
              ),
              Text(
                prediction['predicted_price'].toStringAsFixed(5),
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Range',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: QuantumColors.textTertiary,
                      ),
                    ),
                    Text(
                      '${prediction['lower_bound'].toStringAsFixed(5)} - ${prediction['upper_bound'].toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Confidence',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: QuantumColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 120,
                    child: LinearProgressIndicator(
                      value: confidence,
                      backgroundColor: QuantumColors.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        confidence > 0.8
                            ? QuantumColors.neonGreen
                            : confidence > 0.6
                                ? QuantumColors.warning
                                : QuantumColors.error,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(confidence * 100).toInt()}%',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: confidence > 0.8
                          ? QuantumColors.neonGreen
                          : confidence > 0.6
                              ? QuantumColors.warning
                              : QuantumColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(AppState appState) {
    return QuantumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: QuantumColors.neonCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: QuantumColors.neonCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'System Performance',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildMetricTile('Win Rate Target', '94%', QuantumColors.neonGreen),
              _buildMetricTile('Current Win Rate', '89.3%', QuantumColors.neonCyan),
              _buildMetricTile('Trades Analyzed', '1,247', QuantumColors.neonMagenta),
              _buildMetricTile(
                'Learning Status',
                _isQuantumActive ? 'Active' : 'Idle',
                _isQuantumActive ? QuantumColors.neonGreen : QuantumColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isQuantumActive)
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: QuantumColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => LinearProgressIndicator(
                  value: _pulseAnimation.value,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(QuantumColors.neonCyan),
                  minHeight: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: QuantumColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(double risk) {
    if (risk <= 1.0) return QuantumColors.neonGreen;
    if (risk <= 2.5) return QuantumColors.neonCyan;
    if (risk <= 4.0) return QuantumColors.warning;
    return QuantumColors.error;
  }

  String _getRiskLabel(double risk) {
    if (risk <= 1.0) return 'Risk: ${risk.toStringAsFixed(1)}x (Low)';
    if (risk <= 2.5) return 'Risk: ${risk.toStringAsFixed(1)}x (Normal)';
    if (risk <= 4.0) return 'Risk: ${risk.toStringAsFixed(1)}x (High)';
    return 'Risk: ${risk.toStringAsFixed(1)}x (Extreme)';
  }

  void _showActivationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: QuantumColors.neonGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Automated ML engine and quantum predictor are active',
              style: TextStyle(color: QuantumColors.textPrimary),
            ),
          ],
        ),
        backgroundColor: QuantumColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: QuantumColors.neonGreen.withOpacity(0.5),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class ModuleStatus {
  bool isActive;
  final double confidence;

  ModuleStatus({
    required this.isActive,
    required this.confidence,
  });
}