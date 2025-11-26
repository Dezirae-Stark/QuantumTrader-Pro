import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/indicator_settings.dart';
import '../services/ml_service.dart';

class IndicatorSettingsWidget extends StatefulWidget {
  const IndicatorSettingsWidget({super.key});

  @override
  State<IndicatorSettingsWidget> createState() => _IndicatorSettingsWidgetState();
}

class _IndicatorSettingsWidgetState extends State<IndicatorSettingsWidget> {
  bool _isSyncing = false;

  Future<void> _syncWithBackend() async {
    setState(() => _isSyncing = true);
    
    try {
      final mlService = Provider.of<MLService>(context, listen: false);
      final settings = Provider.of<IndicatorSettings>(context, listen: false);
      
      // Send indicator states to backend
      for (var indicator in settings.allIndicators.entries) {
        await mlService.toggleIndicator(indicator.key, indicator.value);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indicators synchronized with ML engine'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Widget _buildCategorySection(String category, List<String> indicators) {
    final settings = Provider.of<IndicatorSettings>(context);
    final theme = Theme.of(context);
    
    // Category icons
    final categoryIcons = {
      'Trend': Icons.trending_up,
      'Momentum': Icons.speed,
      'Pattern': Icons.pattern,
      'Volume': Icons.bar_chart,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                categoryIcons[category] ?? Icons.analytics,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...indicators.map((indicator) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            title: Text(indicator),
            subtitle: Text(
              IndicatorSettings.descriptions[indicator] ?? '',
              style: theme.textTheme.bodySmall,
            ),
            value: settings.isEnabled(indicator),
            onChanged: (value) async {
              await settings.toggleIndicator(indicator, value);
            },
          ),
        )),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Provider.of<IndicatorSettings>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technical Indicators',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${settings.enabledCount} of ${settings.allIndicators.length} active',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await settings.resetToDefaults();
                    },
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncWithBackend,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Sync'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Group indicators by category
        ...settings.uniqueCategories.map((category) {
          final categoryIndicators = settings.getIndicatorsByCategory(category);
          return _buildCategorySection(category, categoryIndicators);
        }),
        
        // Information card
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signal Engine',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Indicators work together to generate probability-based trading signals. '
                          'Disable indicators that don\'t match your trading style.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}