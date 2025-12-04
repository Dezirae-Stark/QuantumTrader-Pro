import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/broker_service.dart';

class BrokerConfigScreen extends StatefulWidget {
  const BrokerConfigScreen({super.key});

  @override
  State<BrokerConfigScreen> createState() => _BrokerConfigScreenState();
}

class _BrokerConfigScreenState extends State<BrokerConfigScreen> {
  BrokerProvider _selectedProvider = BrokerProvider.mt4;
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _accountController = TextEditingController();

  bool _isConnecting = false;
  bool? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings');
    setState(() {
      final providerStr =
          box.get('broker_provider', defaultValue: 'mt4') as String;
      _selectedProvider = BrokerProvider.fromString(providerStr);
      _apiUrlController.text =
          box.get('broker_api_url', defaultValue: 'http://localhost:8080')
              as String;
      _apiKeyController.text =
          box.get('broker_api_key', defaultValue: '') as String;
      _apiSecretController.text =
          box.get('broker_api_secret', defaultValue: '') as String;
      _accountController.text =
          box.get('broker_account', defaultValue: '') as String;
    });
  }

  Future<void> _saveSettings() async {
    final box = await Hive.openBox('settings');
    await box.put('broker_provider', _selectedProvider.id.toLowerCase());
    await box.put('broker_api_url', _apiUrlController.text);
    await box.put('broker_api_key', _apiKeyController.text);
    await box.put('broker_api_secret', _apiSecretController.text);
    await box.put('broker_account', _accountController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Broker settings saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isConnecting = true;
      _connectionStatus = null;
    });

    try {
      final brokerService = BrokerServiceFactory.create(
        provider: _selectedProvider,
        apiUrl: _apiUrlController.text,
        apiKey: _apiKeyController.text.isNotEmpty
            ? _apiKeyController.text
            : null,
        apiSecret: _apiSecretController.text.isNotEmpty
            ? _apiSecretController.text
            : null,
      );

      final connected = await brokerService.testConnection();

      setState(() {
        _connectionStatus = connected;
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connected ? '✓ Connection successful!' : '✗ Connection failed',
            ),
            backgroundColor: connected ? Colors.green : Colors.red,
          ),
        );
      }

      if (brokerService is GenericRESTBrokerService) {
        brokerService.dispose();
      }
    } catch (e) {
      setState(() {
        _connectionStatus = false;
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broker Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save settings',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Broker Provider Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Broker Provider',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select your broker platform. Each broker requires different configuration.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ...BrokerProvider.values.map((provider) {
                      final isSelected = _selectedProvider == provider;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedProvider = provider;
                              _connectionStatus = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? theme.colorScheme.primary.withOpacity(0.1)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Radio<BrokerProvider>(
                                  value: provider,
                                  groupValue: _selectedProvider,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedProvider = value;
                                        _connectionStatus = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        provider.displayName,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        _getProviderDescription(provider),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Connection Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.settings_ethernet,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Connection Settings',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // API URL
                    TextField(
                      controller: _apiUrlController,
                      decoration: InputDecoration(
                        labelText: 'API Endpoint URL',
                        hintText: _getProviderDefaultUrl(_selectedProvider),
                        prefixIcon: Icon(Icons.link),
                        border: const OutlineInputBorder(),
                        helperText: 'The base URL for your broker\'s API',
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) {
                        setState(() => _connectionStatus = null);
                      },
                    ),

                    const SizedBox(height: 16),

                    // API Key
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key (Optional)',
                        hintText: 'Enter your API key',
                        prefixIcon: Icon(Icons.vpn_key),
                        border: OutlineInputBorder(),
                        helperText: 'Required for authenticated brokers',
                      ),
                      obscureText: true,
                      onChanged: (_) {
                        setState(() => _connectionStatus = null);
                      },
                    ),

                    const SizedBox(height: 16),

                    // API Secret
                    TextField(
                      controller: _apiSecretController,
                      decoration: const InputDecoration(
                        labelText: 'API Secret (Optional)',
                        hintText: 'Enter your API secret',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                        helperText: 'Required for authenticated brokers',
                      ),
                      obscureText: true,
                      onChanged: (_) {
                        setState(() => _connectionStatus = null);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Account Number
                    TextField(
                      controller: _accountController,
                      decoration: const InputDecoration(
                        labelText: 'Account Number (Optional)',
                        hintText: 'Enter your trading account number',
                        prefixIcon: Icon(Icons.account_circle),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Connection Status
                    if (_connectionStatus != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _connectionStatus!
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _connectionStatus!
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _connectionStatus!
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _connectionStatus!
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _connectionStatus!
                                    ? 'Connected to ${_selectedProvider.displayName}'
                                    : 'Connection failed',
                                style: TextStyle(
                                  color: _connectionStatus!
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isConnecting ? null : _testConnection,
                            icon: _isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: Text(
                              _isConnecting ? 'Testing...' : 'Test Connection',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveSettings,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Settings'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Information Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broker Configuration Help',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getProviderHelp(_selectedProvider),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProviderDescription(BrokerProvider provider) {
    switch (provider) {
      case BrokerProvider.mt4:
        return 'MetaTrader 4 platform with bridge integration';
      case BrokerProvider.mt5:
        return 'MetaTrader 5 platform with advanced features';
      case BrokerProvider.oanda:
        return 'Oanda REST API for forex trading';
      case BrokerProvider.binance:
        return 'Binance exchange for cryptocurrency trading';
      case BrokerProvider.generic:
        return 'Generic REST API for any broker';
    }
  }

  String _getProviderDefaultUrl(BrokerProvider provider) {
    switch (provider) {
      case BrokerProvider.mt4:
      case BrokerProvider.mt5:
        return 'http://localhost:8080';
      case BrokerProvider.oanda:
        return 'https://api-fxpractice.oanda.com';
      case BrokerProvider.binance:
        return 'https://api.binance.com';
      case BrokerProvider.generic:
        return 'http://localhost:8080';
    }
  }

  String _getProviderHelp(BrokerProvider provider) {
    switch (provider) {
      case BrokerProvider.mt4:
        return 'For MT4, run the bridge server locally on port 8080. The API URL should point to your bridge server. No API key is needed for local connections.';
      case BrokerProvider.mt5:
        return 'For MT5, configure the bridge server and ensure it\'s running. Enter the bridge server URL in the API Endpoint field.';
      case BrokerProvider.oanda:
        return 'Get your Oanda API credentials from your account dashboard. Use the practice URL for demo accounts or the production URL for live trading.';
      case BrokerProvider.binance:
        return 'Generate API keys from your Binance account security settings. Never share your API secret. Use testnet for testing.';
      case BrokerProvider.generic:
        return 'For generic REST APIs, enter your broker\'s API endpoint URL. Provide API key and secret if required by your broker.';
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _accountController.dispose();
    super.dispose();
  }
}
