import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../models/app_state.dart';
import '../models/indicator_settings.dart';
import '../services/mt4_service.dart';
import '../services/telegram_service.dart';
import '../services/ml_service.dart';
import '../widgets/indicator_settings_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _mt4EndpointController = TextEditingController();
  final _telegramBotTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();
  final _accountBalanceController = TextEditingController();
  
  bool _unifiedAggressiveEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    setState(() {
      _mt4EndpointController.text =
          box.get('mt4_endpoint', defaultValue: 'http://localhost:8080');
      _telegramBotTokenController.text =
          box.get('telegram_bot_token', defaultValue: '');
      _telegramChatIdController.text =
          box.get('telegram_chat_id', defaultValue: '');
      _accountBalanceController.text =
          box.get('account_balance', defaultValue: '50000');
      _unifiedAggressiveEnabled =
          box.get('unified_aggressive_enabled', defaultValue: false);
    });
  }

  Future<void> _saveMT4Settings() async {
    final box = await Hive.openBox('settings');
    await box.put('mt4_endpoint', _mt4EndpointController.text);

    final mt4Service = Provider.of<MT4Service>(context, listen: false);
    mt4Service.setApiEndpoint(_mt4EndpointController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MT4 settings saved')),
      );
    }
  }

  Future<void> _saveTelegramSettings() async {
    final telegramService =
        Provider.of<TelegramService>(context, listen: false);
    telegramService.setCredentials(
      _telegramBotTokenController.text,
      _telegramChatIdController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram settings saved')),
      );
    }
  }

  Future<void> _testMT4Connection() async {
    final mt4Service = Provider.of<MT4Service>(context, listen: false);
    final connected = await mt4Service.testConnection();

    if (mounted) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setMT4Connection(connected);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(connected
              ? 'MT4 connection successful!'
              : 'MT4 connection failed'),
          backgroundColor: connected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleUnifiedAggressiveTrading() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final mlService = Provider.of<MLService>(context, listen: false);
      final accountBalance = double.tryParse(_accountBalanceController.text);
      
      final success = await mlService.enableUnifiedAggressiveTrading(
        !_unifiedAggressiveEnabled,
        accountBalance: accountBalance,
      );

      if (success) {
        setState(() {
          _unifiedAggressiveEnabled = !_unifiedAggressiveEnabled;
        });

        // Save to local storage
        final box = await Hive.openBox('settings');
        await box.put('unified_aggressive_enabled', _unifiedAggressiveEnabled);
        await box.put('account_balance', _accountBalanceController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _unifiedAggressiveEnabled 
                  ? '20% Risk Model ENABLED for all GBP/USD trades!'
                  : 'Unified Aggressive Trading disabled'
              ),
              backgroundColor: _unifiedAggressiveEnabled ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update trading settings'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFeatureRow(String text, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isActive ? Colors.green.shade700 : Colors.grey,
          fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.show_chart,
                    size: 48,
                    color: Color(0xFF1E88E5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'QuantumTrader Pro',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Built by Dezirae Stark',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // MT4 Connection Settings
          Text(
            'MT4 Connection',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _mt4EndpointController,
                    decoration: const InputDecoration(
                      labelText: 'API Endpoint',
                      hintText: 'http://localhost:8080',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveMT4Settings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testMT4Connection,
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('Test'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Telegram Settings
          Text(
            'Telegram Notifications',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _telegramBotTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Bot Token',
                      hintText: 'Enter your Telegram bot token',
                      prefixIcon: Icon(Icons.key),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _telegramChatIdController,
                    decoration: const InputDecoration(
                      labelText: 'Chat ID',
                      hintText: 'Enter your chat ID',
                      prefixIcon: Icon(Icons.chat),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveTelegramSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Telegram Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Unified Aggressive Trading Settings
          Text(
            'Aggressive Trading (20% Risk Model)',
            style: theme.textTheme.titleLarge?.copyWith(
              color: _unifiedAggressiveEnabled ? Colors.green : null,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: _unifiedAggressiveEnabled ? 4 : 2,
            color: _unifiedAggressiveEnabled 
              ? theme.colorScheme.primaryContainer.withOpacity(0.1)
              : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: _unifiedAggressiveEnabled ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your 20% Risk Model',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _unifiedAggressiveEnabled ? Colors.green : null,
                              ),
                            ),
                            Text(
                              _unifiedAggressiveEnabled
                                ? 'ACTIVE: 20% risk on ALL GBP/USD trades'
                                : 'Apply 20% risk to all GBP/USD strategies',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _unifiedAggressiveEnabled 
                                  ? Colors.green 
                                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.scale(
                        scale: 1.2,
                        child: Switch(
                          value: _unifiedAggressiveEnabled,
                          onChanged: _isLoading ? null : (value) => _toggleUnifiedAggressiveTrading(),
                          activeColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _accountBalanceController,
                    decoration: const InputDecoration(
                      labelText: 'Account Balance (\$)',
                      hintText: '50000',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(),
                      helperText: 'Used for position sizing calculations',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _unifiedAggressiveEnabled 
                        ? Colors.green.withOpacity(0.1)
                        : theme.colorScheme.surface,
                      border: Border.all(
                        color: _unifiedAggressiveEnabled ? Colors.green : Colors.grey.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Key Features:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _unifiedAggressiveEnabled ? Colors.green : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFeatureRow('• 100:1+ leverage optimization', _unifiedAggressiveEnabled),
                        _buildFeatureRow('• 20% risk on ALL GBP/USD strategies', _unifiedAggressiveEnabled),
                        _buildFeatureRow('• Multiple profit targets (25%/35%/25%/15%)', _unifiedAggressiveEnabled),
                        _buildFeatureRow('• 10%+ daily return targeting', _unifiedAggressiveEnabled),
                        _buildFeatureRow('• Works with all strategies (News, Ultra, Volatility)', _unifiedAggressiveEnabled),
                      ],
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Theme Settings
          Text(
            'Appearance',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between light and dark theme'),
              value: appState.isDarkMode,
              onChanged: (value) {
                appState.toggleDarkMode();
              },
              secondary: Icon(
                appState.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Ultra High Accuracy Mode
          Text(
            'Trading Mode',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Ultra High Accuracy Mode'),
                  subtitle: const Text('94.7%+ win rate with strict filters'),
                  value: appState.ultraHighAccuracyMode ?? false,
                  onChanged: (value) async {
                    final mlService = Provider.of<MLService>(context, listen: false);
                    final success = await mlService.enableUltraHighAccuracy(value);
                    if (success) {
                      appState.setUltraHighAccuracyMode(value);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value 
                              ? 'Ultra High Accuracy Mode Enabled (94.7%+ win rate)' 
                              : 'Standard Mode Enabled'
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  secondary: Icon(
                    appState.ultraHighAccuracyMode ?? false 
                      ? Icons.verified_user 
                      : Icons.trending_up,
                    color: appState.ultraHighAccuracyMode ?? false 
                      ? Colors.green 
                      : null,
                  ),
                ),
                if (appState.ultraHighAccuracyMode ?? false)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Divider(),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('Multiple timeframe confirmation'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('Advanced entry filters'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('Market regime filtering'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('Volatility-based sizing'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                            const SizedBox(width: 8),
                            const Text('ML ensemble voting'),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Technical Indicators Settings
          const IndicatorSettingsWidget(),

          const SizedBox(height: 24),

          // About
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('Advanced MT4 trading with ML integration'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'QuantumTrader Pro',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.show_chart, size: 48),
                      children: [
                        const Text(
                          'First Sterling QuantumTrader Pro - A full-featured mobile trading companion for MT4 with machine learning integration.',
                        ),
                        const SizedBox(height: 16),
                        const Text('Built by: Dezirae Stark'),
                        const Text('Email: clockwork.halo@tutanota.de'),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('GitHub Repository'),
                  subtitle: const Text('View source code'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    // Open GitHub repo
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mt4EndpointController.dispose();
    _telegramBotTokenController.dispose();
    _telegramChatIdController.dispose();
    super.dispose();
  }
}
