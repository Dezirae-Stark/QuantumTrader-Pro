import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

class QuantumSettingsService {
  final Logger _logger = Logger();
  late Box _settingsBox;

  // Default values
  static const double _defaultRiskScale = 1.0;
  static const double _defaultCantileverStepSize = 0.5;
  static const double _defaultCantileverLockPercent = 0.6;
  static const double _defaultHedgeMultiplier = 1.5;
  static const bool _defaultAutoHedgeEnabled = true;
  static const bool _defaultQuantumActive = false;

  // Module defaults
  static const Map<String, bool> _defaultModuleStatus = {
    'Quantum Predictor': true,
    'Chaos Analyzer': true,
    'Adaptive ML': true,
    'Cantilever Stops': false,
    'Counter-Hedge': false,
  };

  Future<void> initialize() async {
    _logger.i('Initializing Quantum Settings Service...');
    _settingsBox = await Hive.openBox('quantum_settings');
  }

  // Quantum System Active State
  bool get isQuantumActive =>
      _settingsBox.get('quantum_active', defaultValue: _defaultQuantumActive);

  Future<void> setQuantumActive(bool value) async {
    await _settingsBox.put('quantum_active', value);
    _logger.i('Quantum system active: $value');
  }

  // Risk Scale
  double get riskScale =>
      _settingsBox.get('risk_scale', defaultValue: _defaultRiskScale);

  Future<void> setRiskScale(double value) async {
    await _settingsBox.put('risk_scale', value);
    _logger.i('Risk scale set to: $value');
  }

  // Cantilever Settings
  double get cantileverStepSize =>
      _settingsBox.get('cantilever_step_size', defaultValue: _defaultCantileverStepSize);

  Future<void> setCantileverStepSize(double value) async {
    await _settingsBox.put('cantilever_step_size', value);
    _logger.i('Cantilever step size set to: $value');
  }

  double get cantileverLockPercent =>
      _settingsBox.get('cantilever_lock_percent', defaultValue: _defaultCantileverLockPercent);

  Future<void> setCantileverLockPercent(double value) async {
    await _settingsBox.put('cantilever_lock_percent', value);
    _logger.i('Cantilever lock percent set to: $value');
  }

  // Hedge Settings
  bool get autoHedgeEnabled =>
      _settingsBox.get('auto_hedge_enabled', defaultValue: _defaultAutoHedgeEnabled);

  Future<void> setAutoHedgeEnabled(bool value) async {
    await _settingsBox.put('auto_hedge_enabled', value);
    _logger.i('Auto hedge enabled: $value');
  }

  double get hedgeMultiplier =>
      _settingsBox.get('hedge_multiplier', defaultValue: _defaultHedgeMultiplier);

  Future<void> setHedgeMultiplier(double value) async {
    await _settingsBox.put('hedge_multiplier', value);
    _logger.i('Hedge multiplier set to: $value');
  }

  // Module Status
  bool getModuleStatus(String moduleName) {
    return _settingsBox.get(
      'module_${moduleName.replaceAll(' ', '_')}',
      defaultValue: _defaultModuleStatus[moduleName] ?? false,
    );
  }

  Future<void> setModuleStatus(String moduleName, bool isActive) async {
    await _settingsBox.put('module_${moduleName.replaceAll(' ', '_')}', isActive);
    _logger.i('Module $moduleName active: $isActive');
  }

  Map<String, bool> getAllModuleStatus() {
    final Map<String, bool> status = {};
    for (final module in _defaultModuleStatus.keys) {
      status[module] = getModuleStatus(module);
    }
    return status;
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    await _settingsBox.clear();
    _logger.i('Quantum settings reset to defaults');
  }

  // Get all settings as a map
  Map<String, dynamic> getAllSettings() {
    return {
      'quantum_active': isQuantumActive,
      'risk_scale': riskScale,
      'cantilever_step_size': cantileverStepSize,
      'cantilever_lock_percent': cantileverLockPercent,
      'auto_hedge_enabled': autoHedgeEnabled,
      'hedge_multiplier': hedgeMultiplier,
      'modules': getAllModuleStatus(),
    };
  }
}