import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';
import '../services/broker_adapter_service.dart';

class AccountLoginScreen extends StatefulWidget {
  const AccountLoginScreen({Key? key}) : super(key: key);

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController(text: 'LHFXDemo-Server');

  bool _isLoading = false;
  bool _rememberCredentials = true;
  String _selectedBroker = 'LHFX';

  final List<Map<String, String>> _brokers = [
    {'name': 'LHFX', 'server': 'LHFXDemo-Server'},
    {'name': 'LHFX Live', 'server': 'LHFX-Server'},
    {'name': 'MetaQuotes', 'server': 'MetaQuotes-Demo'},
    {'name': 'Custom', 'server': ''},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final login = prefs.getString('mt4_login');
    final password = prefs.getString('mt4_password');
    final server = prefs.getString('mt4_server');

    if (login != null) {
      setState(() {
        _loginController.text = login;
        _passwordController.text = password ?? '';
        _serverController.text = server ?? 'LHFXDemo-Server';
      });
    }
  }

  Future<void> _saveCredentials() async {
    if (_rememberCredentials) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mt4_login', _loginController.text);
      await prefs.setString('mt4_password', _passwordController.text);
      await prefs.setString('mt4_server', _serverController.text);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final brokerService = BrokerAdapterService();
      final success = await brokerService.connect(
        login: _loginController.text,
        password: _passwordController.text,
        server: _serverController.text,
      );

      if (success && mounted) {
        await _saveCredentials();

        final appState = Provider.of<AppState>(context, listen: false);
        appState.setMT4Connection(true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to MT4!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );

        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect. Check your credentials.'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Connect MT4/MT5 Account'),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Broker Logo/Icon
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance,
                    size: 60,
                    color: Color(0xFF00D9FF),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Broker Selection
              DropdownButtonFormField<String>(
                value: _selectedBroker,
                decoration: InputDecoration(
                  labelText: 'Broker',
                  prefixIcon: const Icon(
                    Icons.business,
                    color: Color(0xFF00D9FF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF00D9FF)),
                ),
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                items: _brokers.map((broker) {
                  return DropdownMenuItem<String>(
                    value: broker['name'],
                    child: Text(broker['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBroker = value!;
                    final broker = _brokers.firstWhere(
                      (b) => b['name'] == value,
                    );
                    if (broker['server']!.isNotEmpty) {
                      _serverController.text = broker['server']!;
                    }
                  });
                },
              ),

              const SizedBox(height: 20),

              // Login Field
              TextFormField(
                controller: _loginController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Account Login',
                  hintText: '194302',
                  prefixIcon: const Icon(
                    Icons.person,
                    color: Color(0xFF00D9FF),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF00D9FF)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your account login';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Login must be a number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF00D9FF)),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF00D9FF)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Server Field
              TextFormField(
                controller: _serverController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Server',
                  hintText: 'LHFXDemo-Server',
                  prefixIcon: const Icon(Icons.dns, color: Color(0xFF00D9FF)),
                  filled: true,
                  fillColor: const Color(0xFF16213E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  labelStyle: const TextStyle(color: Color(0xFF00D9FF)),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter server address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Remember Credentials Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _rememberCredentials,
                    onChanged: (value) {
                      setState(() {
                        _rememberCredentials = value!;
                      });
                    },
                    fillColor: MaterialStateProperty.all(
                      const Color(0xFF00D9FF),
                    ),
                  ),
                  const Text(
                    'Remember credentials',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Connect Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Demo Account Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D9FF).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF00D9FF),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Demo Account Info',
                          style: TextStyle(
                            color: Color(0xFF00D9FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'LHFX Practice Account:\nLogin: 194302\nServer: LHFXDemo-Server',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }
}
