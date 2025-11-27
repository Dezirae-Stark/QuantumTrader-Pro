import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import '../models/app_state.dart';
import '../services/broker_adapter_service.dart';
import '../services/telegram_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _mt4EndpointController = TextEditingController();
  final _telegramBotTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    setState(() {
      _mt4EndpointController.text = box.get(
        'mt4_endpoint',
        defaultValue: 'http://localhost:8080',
      );
      _telegramBotTokenController.text = box.get(
        'telegram_bot_token',
        defaultValue: '',
      );
      _telegramChatIdController.text = box.get(
        'telegram_chat_id',
        defaultValue: '',
      );
    });
  }

  Future<void> _saveMT4Settings() async {
    final box = await Hive.openBox('settings');
    await box.put('mt4_endpoint', _mt4EndpointController.text);

    final brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    brokerService.setApiEndpoint(_mt4EndpointController.text);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('MT4 settings saved')));
    }
  }

  Future<void> _saveTelegramSettings() async {
    final telegramService = Provider.of<TelegramService>(
      context,
      listen: false,
    );
    telegramService.setCredentials(
      _telegramBotTokenController.text,
      _telegramChatIdController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Telegram settings saved')));
    }
  }

  Future<void> _testMT4Connection() async {
    final brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    final connected = await brokerService.testConnection();

    if (mounted) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setMT4Connection(connected);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            connected ? 'MT4 connection successful!' : 'MT4 connection failed',
          ),
          backgroundColor: connected ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0', style: theme.textTheme.bodySmall),
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
          Text('MT4 Connection', style: theme.textTheme.titleLarge),
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
          Text('Telegram Notifications', style: theme.textTheme.titleLarge),
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

          // Theme Settings
          Text('Appearance', style: theme.textTheme.titleLarge),
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

          // About
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text(
                    'Advanced MT4 trading with ML integration',
                  ),
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
