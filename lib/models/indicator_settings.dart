import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Model for managing indicator toggle settings
class IndicatorSettings extends ChangeNotifier {
  // Default enabled state for indicators
  static const Map<String, bool> defaultSettings = {
    'Alligator': true,
    'Awesome Oscillator': true,
    'Accelerator Oscillator': true,
    'Fractals': true,
    'Elliott Wave': true,
    'Williams MFI': true,
  };

  // Indicator descriptions
  static const Map<String, String> descriptions = {
    'Alligator': 'Bill Williams trend-following indicator using 3 smoothed moving averages',
    'Awesome Oscillator': 'Momentum indicator showing market driving force',
    'Accelerator Oscillator': 'Early warning signal of momentum changes',
    'Fractals': 'Identifies market turning points and support/resistance',
    'Elliott Wave': 'Detects impulse and corrective wave patterns',
    'Williams MFI': 'Market Facilitation Index for volume and price efficiency',
  };

  // Indicator categories
  static const Map<String, String> categories = {
    'Alligator': 'Trend',
    'Awesome Oscillator': 'Momentum',
    'Accelerator Oscillator': 'Momentum',
    'Fractals': 'Pattern',
    'Elliott Wave': 'Pattern',
    'Williams MFI': 'Volume',
  };

  late Box _settingsBox;
  Map<String, bool> _indicatorStates = {};

  IndicatorSettings() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settingsBox = await Hive.openBox('indicator_settings');
    
    // Load saved settings or use defaults
    for (var indicator in defaultSettings.keys) {
      _indicatorStates[indicator] = _settingsBox.get(
        indicator,
        defaultValue: defaultSettings[indicator]!,
      );
    }
    notifyListeners();
  }

  bool isEnabled(String indicatorName) {
    return _indicatorStates[indicatorName] ?? true;
  }

  Future<void> toggleIndicator(String indicatorName, bool enabled) async {
    _indicatorStates[indicatorName] = enabled;
    await _settingsBox.put(indicatorName, enabled);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _indicatorStates = Map.from(defaultSettings);
    
    // Save to Hive
    for (var entry in defaultSettings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
    notifyListeners();
  }

  List<String> get enabledIndicators {
    return _indicatorStates.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  int get enabledCount {
    return _indicatorStates.values.where((enabled) => enabled).length;
  }

  Map<String, bool> get allIndicators => Map.from(_indicatorStates);

  // Get indicators by category
  List<String> getIndicatorsByCategory(String category) {
    return categories.entries
        .where((entry) => entry.value == category)
        .map((entry) => entry.key)
        .toList();
  }

  // Get all unique categories
  List<String> get uniqueCategories {
    return categories.values.toSet().toList();
  }
}