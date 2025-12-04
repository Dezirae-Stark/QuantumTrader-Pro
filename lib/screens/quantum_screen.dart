import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/cantilever_hedge_manager.dart';
import '../services/risk_manager.dart';

/// Quantum Trading System Control Screen
///
/// Features:
/// - User risk scale control
/// - Cantilever stop configuration
/// - Counter-hedge settings
/// - ML confidence monitoring
/// - Quantum prediction visualization
class QuantumScreen extends StatefulWidget {
  const QuantumScreen({super.key});

  @override
  State<QuantumScreen> createState() => _QuantumScreenState();
}

class _QuantumScreenState extends State<QuantumScreen> {
  final hedgeManager = CantileverHedgeManager();
  final riskManager = RiskManager();

  double _riskScale = 1.0;
  double _cantileverStepSize = 0.5;
  double _cantileverLockPercent = 0.6;
  bool _autoHedgeEnabled = true;
  double _hedgeMultiplier = 1.5;

  // Mock quantum predictions (in production, fetch from Python service)
  List<Map<String, dynamic>> _quantumPredictions = [];
  bool _isQuantumActive = false;

  @override
  void initState() {
    super.initState();
    _loadQuantumData();
  }

  Future<void> _loadQuantumData() async {
    // In production: Call Python quantum predictor via API
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
      appBar: AppBar(
        title: const Row(
          children: [
            const Icon(Icons.psychology, size: 28),
            const SizedBox(width: 12),
            const Text('Quantum Trading System'),
          ],
        ),
        actions: [
          Switch(
            value: _isQuantumActive,
            onChanged: (value) {
              setState(() {
                _isQuantumActive = value;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quantum Status Card
          _buildStatusCard(theme),

          const SizedBox(height: 16),

          // Risk Scale Control
          _buildRiskScaleCard(theme),

          const SizedBox(height: 16),

          // Cantilever Stop Settings
          _buildCantileverCard(theme),

          const SizedBox(height: 16),

          // Counter-Hedge Settings
          _buildHedgeCard(theme),

          const SizedBox(height: 16),

          // Quantum Predictions
          _buildPredictionsCard(theme),

          const SizedBox(height: 16),

          // Performance Metrics
          _buildPerformanceCard(theme, appState),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science,
                  color: _isQuantumActive ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantum System',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isQuantumActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: _isQuantumActive ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildStatusRow('Quantum Predictor', _isQuantumActive, theme),
            _buildStatusRow('Chaos Analyzer', _isQuantumActive, theme),
            _buildStatusRow('Adaptive ML', _isQuantumActive, theme),
            _buildStatusRow('Cantilever Stops', _isQuantumActive, theme),
            _buildStatusRow('Counter-Hedge', _autoHedgeEnabled, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool active, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            color: active ? Colors.green : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskScaleCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Scale',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Multiply your risk/reward by this factor',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _riskScale,
                    min: 0.1,
                    max: 5.0,
                    divisions: 49,
                    label: '${_riskScale.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setState(() {
                        _riskScale = value;
                        hedgeManager.setUserRiskScale(value);
                      });
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_riskScale.toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Conservative (0.5x)', style: theme.textTheme.bodySmall),
                Text('Aggressive (5.0x)', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _riskScale > 2.0
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _riskScale > 2.0 ? Colors.orange : Colors.blue,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _riskScale > 2.0 ? Icons.warning : Icons.info,
                    color: _riskScale > 2.0 ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _riskScale > 2.0
                          ? 'High risk mode - use with caution!'
                          : 'Normal risk mode',
                      style: TextStyle(
                        color: _riskScale > 2.0 ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCantileverCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stairs, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Cantilever Trailing Stop',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Progressively lock in profits as trade moves in your favor',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              'Step Size',
              '${(_cantileverStepSize * 100).toStringAsFixed(1)}%',
              _cantileverStepSize,
              0.1,
              2.0,
              (value) => setState(() => _cantileverStepSize = value),
              theme,
            ),
            const SizedBox(height: 12),
            _buildSliderSetting(
              'Lock Percent',
              '${(_cantileverLockPercent * 100).toStringAsFixed(0)}%',
              _cantileverLockPercent,
              0.3,
              0.9,
              (value) => setState(() => _cantileverLockPercent = value),
              theme,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Every ${(_cantileverStepSize * 100).toStringAsFixed(1)}% profit → '
                'Lock ${(_cantileverLockPercent * 100).toStringAsFixed(0)}% of it',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHedgeCard(ThemeData theme) {
    return Card(
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
                    const Icon(Icons.shield, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Counter-Hedge Recovery',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _autoHedgeEnabled,
                  onChanged: (value) {
                    setState(() {
                      _autoHedgeEnabled = value;
                      hedgeManager.autoHedgeEnabled = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Automatically open opposite position when stop loss hits',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              'Hedge Multiplier',
              '${_hedgeMultiplier.toStringAsFixed(1)}x',
              _hedgeMultiplier,
              1.0,
              3.0,
              (value) => setState(() => _hedgeMultiplier = value),
              theme,
            ),
            const SizedBox(height: 12),
            if (_autoHedgeEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works:',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1. Stop loss triggers\n'
                      '2. Open opposite position (${_hedgeMultiplier.toStringAsFixed(1)}x size)\n'
                      '3. ML manages both positions\n'
                      '4. Close for profit or breakeven',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Quantum Predictions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_quantumPredictions.isEmpty)
              const Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: const Text('No predictions available'),
                ),
              )
            else
              ..._quantumPredictions.map(
                (pred) => _buildPredictionRow(pred, theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionRow(Map<String, dynamic> pred, ThemeData theme) {
    final isBullish = pred['bullish_probability'] > 0.5;
    final confidence = pred['confidence'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isBullish ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isBullish ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Candle +${pred['candle']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${pred['predicted_price'].toStringAsFixed(5)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBullish ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Range:', style: theme.textTheme.bodySmall),
                    Text(
                      '${pred['lower_bound'].toStringAsFixed(5)} - '
                      '${pred['upper_bound'].toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Confidence:', style: theme.textTheme.bodySmall),
                  Text(
                    '${(confidence * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: confidence > 0.75 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                confidence > 0.75 ? Colors.green : Colors.orange,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(ThemeData theme, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Performance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPerformanceRow(
              'Win Rate Target',
              '94.7%',
              Colors.purple,
              theme,
            ),
            _buildPerformanceRow(
              'Current Win Rate',
              '92.3%',
              Colors.green,
              theme,
            ),
            _buildPerformanceRow(
              'Trades Analyzed',
              '1,247',
              Colors.blue,
              theme,
            ),
            _buildPerformanceRow(
              'Learning Status',
              'Active',
              Colors.orange,
              theme,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.923 / 0.947, // Current / Target
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              'Progress to target: ${((0.923 / 0.947) * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceRow(
    String label,
    String value,
    Color color,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(
    String label,
    String value,
    double currentValue,
    double min,
    double max,
    ValueChanged<double> onChanged,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          divisions: 20,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
