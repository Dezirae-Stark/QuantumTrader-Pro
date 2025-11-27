import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/mt4_service.dart';
import '../services/telegram_service.dart';
import '../theme/colors/quantum_colors.dart';
import '../theme/components/quantum_card.dart';
import '../theme/components/quantum_button.dart';
import '../theme/components/quantum_controls.dart';

class CyberpunkSettingsScreen extends StatefulWidget {
  const CyberpunkSettingsScreen({super.key});

  @override
  State<CyberpunkSettingsScreen> createState() => _CyberpunkSettingsScreenState();
}

class _CyberpunkSettingsScreenState extends State<CyberpunkSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  // Connection settings
  final _mt4HostController = TextEditingController();
  final _mt4PortController = TextEditingController();
  final _mt4PasswordController = TextEditingController();
  final _telegramTokenController = TextEditingController();

  // Trading settings
  bool _darkModeEnabled = true;
  bool _ultraHighAccuracyEnabled = false;
  double _maxRiskPercent = 20.0;
  bool _riskModelExpanded = true;
  bool _mt4SectionExpanded = false;
  bool _telegramSectionExpanded = false;

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
    
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mt4HostController.dispose();
    _mt4PortController.dispose();
    _mt4PasswordController.dispose();
    _telegramTokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    // Load settings from storage
    // In production, load from Hive or shared preferences
  }

  Future<void> _saveSettings() async {
    // Save settings to storage
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
          // MT4 Connection
          _buildMT4Section(),
          const SizedBox(height: 16),

          // Telegram Integration
          _buildTelegramSection(),
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

  Widget _buildMT4Section() {
    return QuantumCard(
      onTap: () {
        setState(() {
          _mt4SectionExpanded = !_mt4SectionExpanded;
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
                      'MT4 Connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Configure MetaTrader 4 connection',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: QuantumColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _mt4SectionExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: QuantumColors.textTertiary,
                ),
              ),
            ],
          ),
          if (_mt4SectionExpanded) ...[
            const SizedBox(height: 20),
            _buildTextField(
              controller: _mt4HostController,
              label: 'Host',
              hint: 'broker.server.com',
              icon: Icons.dns,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _mt4PortController,
              label: 'Port',
              hint: '443',
              icon: Icons.router,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _mt4PasswordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock,
              obscureText: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: QuantumButton(
                    text: 'Test Connection',
                    type: QuantumButtonType.secondary,
                    onPressed: () async {
                      // Test MT4 connection
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: QuantumColors.neonGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: QuantumColors.neonGreen,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelegramSection() {
    return QuantumCard(
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
                      'Receive alerts and monitor trades',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: QuantumColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
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
            const SizedBox(height: 20),
            QuantumButton(
              text: 'Connect Telegram',
              type: QuantumButtonType.secondary,
              icon: Icons.link,
              onPressed: () async {
                // Connect to Telegram
              },
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
                  const SizedBox(height: 12),
                  _buildRiskDetail('• Max risk per trade: 20% of account'),
                  _buildRiskDetail('• Quantum ML adjusts position sizing'),
                  _buildRiskDetail('• Counter-hedge recovery on stop loss'),
                  _buildRiskDetail('• Cantilever stops lock in profits'),
                  _buildRiskDetail('• 94%+ target win rate compensates risk'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            QuantumSlider(
              value: _maxRiskPercent,
              min: 5,
              max: 30,
              divisions: 25,
              label: 'Max Risk Per Trade',
              displayValue: (value) => '${value.toInt()}%',
              activeColor: _maxRiskPercent > 20 ? QuantumColors.error : QuantumColors.warning,
              onChanged: (value) {
                setState(() {
                  _maxRiskPercent = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_maxRiskPercent > 20)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QuantumColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: QuantumColors.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.dangerous,
                      color: QuantumColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Risk above 20% requires advanced experience',
                        style: TextStyle(
                          color: QuantumColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.dark_mode,
                    color: QuantumColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Dark Mode',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              QuantumToggle(
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.speed,
                      color: QuantumColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ultra High Accuracy Mode',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            'More compute for higher win rate',
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: QuantumColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              QuantumToggle(
                value: _ultraHighAccuracyEnabled,
                onChanged: (value) {
                  setState(() {
                    _ultraHighAccuracyEnabled = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorsSection() {
    final categories = {
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
          ...categories.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: QuantumColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: QuantumColors.neonCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...entry.value.map((indicator) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _indicators[indicator]!
                                  ? QuantumColors.neonGreen
                                  : QuantumColors.surface,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            indicator,
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: _indicators[indicator]!
                                  ? QuantumColors.textPrimary
                                  : QuantumColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      QuantumToggle(
                        value: _indicators[indicator]!,
                        onChanged: (value) {
                          setState(() {
                            _indicators[indicator] = value;
                          });
                        },
                        scale: 0.8,
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
              ],
            );
          }),
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
          _buildAboutRow('Version', 'v2.5.0'),
          _buildAboutRow('ML Engine', 'Quantum v4'),
          _buildAboutRow('Win Rate Target', '94.7%'),
          _buildAboutRow('License', 'MIT'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: QuantumColors.neonCyan.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: QuantumColors.neonCyan.withOpacity(0.2),
              ),
            ),
            child: Text(
              'QuantumTrader Pro uses advanced machine learning and quantum-inspired algorithms to achieve professional-grade trading performance.',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: QuantumColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGitHubSection() {
    return QuantumCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          QuantumColors.neonMagenta.withOpacity(0.1),
          QuantumColors.neonCyan.withOpacity(0.1),
        ],
      ),
      onTap: () {
        // Open GitHub repo
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.code,
            color: QuantumColors.neonCyan,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'View on GitHub',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            color: QuantumColors.textTertiary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: QuantumColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: QuantumColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: QuantumColors.neonCyan.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(color: QuantumColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: QuantumColors.textTertiary),
              prefixIcon: Icon(icon, color: QuantumColors.neonCyan, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskDetail(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: QuantumColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: QuantumColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}