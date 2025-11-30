import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_button.dart';
import '../theme/components/quantum_controls.dart';
import '../services/broker_adapter_service.dart';
import '../services/telegram_service.dart';
import '../models/app_state.dart';

class EnhancedSettingsScreen extends StatefulWidget {
  const EnhancedSettingsScreen({super.key});

  @override
  State<EnhancedSettingsScreen> createState() => _EnhancedSettingsScreenState();
}

class _EnhancedSettingsScreenState extends State<EnhancedSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;
  late BrokerAdapterService _brokerService;
  late TelegramService _telegramService;
  late Box _settingsBox;

  // Broker connection settings
  BrokerType _selectedBrokerType = BrokerType.mt4;
  final _brokerLoginController = TextEditingController();
  final _brokerPasswordController = TextEditingController();
  final _brokerServerController = TextEditingController();
  final _apiEndpointController = TextEditingController();

  // Telegram settings
  final _telegramTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();

  // Trading settings
  bool _darkModeEnabled = true;
  bool _ultraHighAccuracyEnabled = false;
  double _maxRiskPercent = 20.0;
  bool _riskModelExpanded = true;
  bool _brokerSectionExpanded = false;
  bool _telegramSectionExpanded = false;

  // Connection status
  bool _isBrokerConnecting = false;
  bool _isTelegramConnecting = false;

  // Technical indicators
  final Map<String, bool> _indicators = {
    // Trend
    'Moving Averages': true,
    'MACD': true,
    'Parabolic SAR': false,
    'ADX': false,
    // Momentum
    'RSI': true,
    'Stochastic': false,
    'CCI': false,
    'Williams %R': false,
    // Volume
    'Volume': true,
    'OBV': false,
    'Money Flow': false,
    // Volatility
    'Bollinger Bands': true,
    'ATR': false,
    'Standard Deviation': false,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    _telegramService = Provider.of<TelegramService>(context, listen: false);
    _settingsBox = await Hive.openBox('app_settings');

    await _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _brokerLoginController.dispose();
    _brokerPasswordController.dispose();
    _brokerServerController.dispose();
    _apiEndpointController.dispose();
    _telegramTokenController.dispose();
    _telegramChatIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      // Load broker settings
      _selectedBrokerType = _brokerService.brokerType;
      _apiEndpointController.text = _brokerService.apiEndpoint;
      if (_brokerService.savedLogin != null) {
        _brokerLoginController.text = _brokerService.savedLogin.toString();
      }
      if (_brokerService.savedServer != null) {
        _brokerServerController.text = _brokerService.savedServer!;
      }

      // Load other settings
      _darkModeEnabled = _settingsBox.get('dark_mode_enabled', defaultValue: true);
      _ultraHighAccuracyEnabled = _settingsBox.get('ultra_high_accuracy', defaultValue: false);
      _maxRiskPercent = _settingsBox.get('max_risk_percent', defaultValue: 20.0);

      // Load indicators
      _indicators.forEach((key, defaultValue) {
        _indicators[key] = _settingsBox.get('indicator_$key', defaultValue: defaultValue);
      });
    });
  }

  Future<void> _saveSettings() async {
    await _settingsBox.put('dark_mode_enabled', _darkModeEnabled);
    await _settingsBox.put('ultra_high_accuracy', _ultraHighAccuracyEnabled);
    await _settingsBox.put('max_risk_percent', _maxRiskPercent);

    // Save indicators
    _indicators.forEach((key, value) async {
      await _settingsBox.put('indicator_$key', value);
    });

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
              'Settings saved successfully',
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: QuantumColors.backgroundSecondary,
        title: Text(
          'Settings',
          style: theme.textTheme.headlineMedium!.copyWith(
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) => IconButton(
                onPressed: _saveSettings,
                icon: Icon(
                  Icons.save,
                  color: QuantumColors.neonGreen.withOpacity(_glowAnimation.value),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Broker Connection (MT4/MT5)
          _buildBrokerSection(appState),
          const SizedBox(height: 16),

          // Telegram Integration
          _buildTelegramSection(appState),
          const SizedBox(height: 16),

          // 20% Risk Model (Collapsible)
          _buildRiskModelSection(),
          const SizedBox(height: 16),

          // Theme Settings
          _buildThemeSection(),
          const SizedBox(height: 16),

          // Technical Indicators
          _buildIndicatorsSection(),
          const SizedBox(height: 16),

          // About Section
          _buildAboutSection(),
          const SizedBox(height: 24),

          // GitHub Link
          _buildGitHubSection(),
        ],
      ),
    );
  }

  Widget _buildBrokerSection(AppState appState) {
    return QuantumCard(
      hasGlow: appState.isConnectedToMT4,
      glowColor: QuantumColors.neonCyan.withOpacity(0.3),
      onTap: () {
        setState(() {
          _brokerSectionExpanded = !_brokerSectionExpanded;
        });
      },
      child: Column(
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
                  Icons.cable,
                  color: QuantumColors.neonCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Broker Connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      appState.isConnectedToMT4
                          ? 'Connected to ${_selectedBrokerType.name.toUpperCase()}'
                          : 'Configure MetaTrader connection',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: appState.isConnectedToMT4
                            ? QuantumColors.neonGreen
                            : QuantumColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (appState.isConnectedToMT4)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: QuantumColors.neonGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: QuantumColors.neonGreen,
                    size: 16,
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _brokerSectionExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: QuantumColors.textTertiary,
                ),
              ),
            ],
          ),
          if (_brokerSectionExpanded) ...[
            const SizedBox(height: 20),
            // Broker Type Selector
            QuantumSegmentedControl<BrokerType>(
              value: _selectedBrokerType,
              options: const {
                BrokerType.mt4: 'MT4',
                BrokerType.mt5: 'MT5',
              },
              onValueChanged: (type) {
                setState(() {
                  _selectedBrokerType = type;
                });
                _brokerService.setBrokerType(type);
              },
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _brokerLoginController,
              label: 'Login',
              hint: '12345678',
              icon: Icons.person,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _brokerPasswordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _brokerServerController,
              label: 'Server',
              hint: 'broker.server.com:443',
              icon: Icons.dns,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _apiEndpointController,
              label: 'API Endpoint',
              hint: 'http://localhost:8080',
              icon: Icons.api,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: QuantumButton(
                    text: appState.isConnectedToMT4 ? 'Disconnect' : 'Connect',
                    type: appState.isConnectedToMT4
                        ? QuantumButtonType.outline
                        : QuantumButtonType.primary,
                    isLoading: _isBrokerConnecting,
                    onPressed: _handleBrokerConnection,
                  ),
                ),
                if (!appState.isConnectedToMT4) ...[
                  const SizedBox(width: 12),
                  QuantumButton(
                    text: 'Test',
                    type: QuantumButtonType.secondary,
                    icon: Icons.wifi_tethering,
                    size: QuantumButtonSize.small,
                    onPressed: _testBrokerConnection,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelegramSection(AppState appState) {
    return QuantumCard(
      hasGlow: appState.isTelegramConnected,
      glowColor: QuantumColors.neonMagenta.withOpacity(0.3),
      onTap: () {
        setState(() {
          _telegramSectionExpanded = !_telegramSectionExpanded;
        });
      },
      child: Column(
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
                  Icons.telegram,
                  color: QuantumColors.neonMagenta,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Telegram Integration',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      appState.isTelegramConnected
                          ? 'Connected and receiving alerts'
                          : 'Receive alerts and monitor trades',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: appState.isTelegramConnected
                            ? QuantumColors.neonGreen
                            : QuantumColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (appState.isTelegramConnected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: QuantumColors.neonGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: QuantumColors.neonGreen,
                    size: 16,
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _telegramSectionExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: QuantumColors.textTertiary,
                ),
              ),
            ],
          ),
          if (_telegramSectionExpanded) ...[
            const SizedBox(height: 20),
            _buildTextField(
              controller: _telegramTokenController,
              label: 'Bot Token',
              hint: '1234567890:ABCdefGHIjklMNOpqrsTUVwxyz',
              icon: Icons.key,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _telegramChatIdController,
              label: 'Chat ID',
              hint: '-1001234567890',
              icon: Icons.chat,
            ),
            const SizedBox(height: 20),
            QuantumButton(
              text: appState.isTelegramConnected ? 'Disconnect' : 'Connect Telegram',
              type: appState.isTelegramConnected
                  ? QuantumButtonType.outline
                  : QuantumButtonType.secondary,
              icon: Icons.link,
              isLoading: _isTelegramConnecting,
              onPressed: _handleTelegramConnection,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskModelSection() {
    return QuantumCard(
      hasGlow: _riskModelExpanded,
      glowColor: QuantumColors.warning.withOpacity(0.3),
      onTap: () {
        setState(() {
          _riskModelExpanded = !_riskModelExpanded;
        });
      },
      child: Column(
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
                  Icons.warning,
                  color: QuantumColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '20% Risk Model',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Professional trading configuration',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: QuantumColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _riskModelExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: QuantumColors.textTertiary,
                ),
              ),
            ],
          ),
          if (_riskModelExpanded) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: QuantumColors.warning.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: QuantumColors.warning.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: QuantumColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Professional risk management strategy',
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: QuantumColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRiskItem('Max risk per trade: 20%'),
                  _buildRiskItem('Leverage: 1:100 recommended'),
                  _buildRiskItem('Stop loss: Always enabled'),
                  _buildRiskItem('Risk/Reward ratio: 1:2 minimum'),
                  const SizedBox(height: 16),
                  QuantumSlider(
                    value: _maxRiskPercent,
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: 'Max Risk Per Trade',
                    displayValue: (value) => '${value.toInt()}%',
                    activeColor: QuantumColors.warning,
                    onChanged: (value) {
                      setState(() {
                        _maxRiskPercent = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
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
                  Icons.palette,
                  color: QuantumColors.neonCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Theme & Display',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSwitchRow(
            'Dark Mode',
            'Cyberpunk theme optimized for trading',
            _darkModeEnabled,
            (value) {
              setState(() {
                _darkModeEnabled = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildSwitchRow(
            'Ultra High Accuracy',
            'ML predictions with higher confidence threshold',
            _ultraHighAccuracyEnabled,
            (value) {
              setState(() {
                _ultraHighAccuracyEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorsSection() {
    final indicatorCategories = {
      'Trend': ['Moving Averages', 'MACD', 'Parabolic SAR', 'ADX'],
      'Momentum': ['RSI', 'Stochastic', 'CCI', 'Williams %R'],
      'Volume': ['Volume', 'OBV', 'Money Flow'],
      'Volatility': ['Bollinger Bands', 'ATR', 'Standard Deviation'],
    };

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
                  Icons.show_chart,
                  color: QuantumColors.neonGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Technical Indicators',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...indicatorCategories.entries.map((category) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.key,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: QuantumColors.neonCyan,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              ...category.value.map((indicator) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildIndicatorRow(indicator, _indicators[indicator]!),
              )),
              const SizedBox(height: 16),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
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
                  Icons.info,
                  color: QuantumColors.neonMagenta,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'About',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow('Version', '2.1.0'),
          const SizedBox(height: 8),
          _buildInfoRow('Build', '2024.11.27'),
          const SizedBox(height: 8),
          _buildInfoRow('Powered by', 'Quantum ML Engine v4'),
        ],
      ),
    );
  }

  Widget _buildGitHubSection() {
    return Center(
      child: QuantumButton(
        text: 'View on GitHub',
        icon: Icons.code,
        type: QuantumButtonType.outline,
        onPressed: () {
          // Open GitHub repository
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(color: QuantumColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: QuantumColors.neonCyan),
        filled: true,
        fillColor: QuantumColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: QuantumColors.neonCyan.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: QuantumColors.neonCyan,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(color: QuantumColors.textSecondary),
        hintStyle: TextStyle(color: QuantumColors.textTertiary),
      ),
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: QuantumColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        QuantumToggle(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildIndicatorRow(String name, bool enabled) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _indicators[name] = !_indicators[name]!;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? QuantumColors.neonGreen.withOpacity(0.1)
              : QuantumColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? QuantumColors.neonGreen.withOpacity(0.5)
                : QuantumColors.surface,
          ),
        ),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_box : Icons.check_box_outline_blank,
              color: enabled ? QuantumColors.neonGreen : QuantumColors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: enabled ? QuantumColors.textPrimary : QuantumColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: QuantumColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: QuantumColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: QuantumColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: QuantumColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _handleBrokerConnection() async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.isConnectedToMT4) {
      // Disconnect
      await _brokerService.disconnect();
      appState.setMT4Connection(false);
      return;
    }

    // Validate inputs
    if (_brokerLoginController.text.isEmpty ||
        _brokerPasswordController.text.isEmpty ||
        _brokerServerController.text.isEmpty) {
      _showErrorSnackbar('Please fill in all broker connection fields');
      return;
    }

    setState(() {
      _isBrokerConnecting = true;
    });

    try {
      // Set API endpoint
      _brokerService.setApiEndpoint(_apiEndpointController.text);

      // Connect to broker
      final success = await _brokerService.connect(
        login: int.parse(_brokerLoginController.text),
        password: _brokerPasswordController.text,
        server: _brokerServerController.text,
      );

      if (success) {
        appState.setMT4Connection(true);
        _showSuccessSnackbar('Connected to ${_selectedBrokerType.name.toUpperCase()} successfully');
      } else {
        _showErrorSnackbar('Failed to connect to broker');
      }
    } catch (e) {
      _showErrorSnackbar('Connection error: ${e.toString()}');
    } finally {
      setState(() {
        _isBrokerConnecting = false;
      });
    }
  }

  Future<void> _testBrokerConnection() async {
    if (_apiEndpointController.text.isEmpty) {
      _showErrorSnackbar('Please enter API endpoint');
      return;
    }

    _brokerService.setApiEndpoint(_apiEndpointController.text);
    final isConnected = await _brokerService.testConnection();

    if (isConnected) {
      _showSuccessSnackbar('API endpoint is reachable');
    } else {
      _showErrorSnackbar('Cannot reach API endpoint');
    }
  }

  Future<void> _handleTelegramConnection() async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (appState.isTelegramConnected) {
      // Disconnect - for now just update state
      appState.setTelegramConnection(false);
      return;
    }

    // Validate inputs
    if (_telegramTokenController.text.isEmpty ||
        _telegramChatIdController.text.isEmpty) {
      _showErrorSnackbar('Please fill in all Telegram fields');
      return;
    }

    setState(() {
      _isTelegramConnecting = true;
    });

    try {
      // Set credentials and connect
      _telegramService.setCredentials(
        _telegramTokenController.text,
        _telegramChatIdController.text,
      );

      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 1));

      appState.setTelegramConnection(true);
      _showSuccessSnackbar('Connected to Telegram successfully');
    } catch (e) {
      _showErrorSnackbar('Telegram connection error: ${e.toString()}');
    } finally {
      setState(() {
        _isTelegramConnecting = false;
      });
    }
  }

  void _showSuccessSnackbar(String message) {
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
            Text(message, style: TextStyle(color: QuantumColors.textPrimary)),
          ],
        ),
        backgroundColor: QuantumColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: QuantumColors.neonGreen.withOpacity(0.5)),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error,
              color: QuantumColors.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(color: QuantumColors.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: QuantumColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: QuantumColors.error.withOpacity(0.5)),
        ),
      ),
    );
  }
}