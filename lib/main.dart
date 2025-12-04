import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/quantum_theme.dart';
import 'theme/utils/quantum_wallpaper.dart';
import 'screens/cyberpunk_dashboard_screen.dart';
import 'screens/cyberpunk_portfolio_screen.dart';
import 'screens/cyberpunk_quantum_screen.dart';
import 'screens/enhanced_settings_screen.dart';
import 'services/broker_adapter_service.dart';
import 'services/telegram_service.dart';
import 'services/ml_service.dart';
import 'services/quantum_settings_service.dart';
import 'services/autotrading_engine.dart';
import 'services/risk_manager.dart';
import 'services/cantilever_hedge_manager.dart';
import 'models/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('trades');

  runApp(const QuantumTraderApp());
}

class QuantumTraderApp extends StatelessWidget {
  const QuantumTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider(create: (_) => BrokerAdapterService()),
        Provider(create: (_) => TelegramService()),
        Provider(create: (_) => MLService()),
        Provider(create: (_) => QuantumSettingsService()),
        Provider(create: (_) => RiskManager()),
        Provider(create: (_) => CantileverHedgeManager()),
        ProxyProvider<BrokerAdapterService, AutoTradingEngine>(
          update: (context, brokerService, _) {
            final mlService = Provider.of<MLService>(
              context,
              listen: false,
            );
            final quantumSettings = Provider.of<QuantumSettingsService>(
              context,
              listen: false,
            );
            final riskManager = Provider.of<RiskManager>(
              context,
              listen: false,
            );
            final hedgeManager = Provider.of<CantileverHedgeManager>(
              context,
              listen: false,
            );

            return AutoTradingEngine(
              brokerService: brokerService,
              mlService: mlService,
              riskManager: riskManager,
              hedgeManager: hedgeManager,
              quantumSettings: quantumSettings,
            );
          },
        ),
      ],
      child: MaterialApp(
        title: 'QuantumTrader Pro',
        debugShowCheckedModeBanner: false,
        theme: QuantumTheme.darkTheme(),
        darkTheme: QuantumTheme.darkTheme(),
        themeMode: ThemeMode.dark,
        home: const MainNavigator(),
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CyberpunkDashboardScreen(),
    const CyberpunkPortfolioScreen(),
    const CyberpunkQuantumScreen(),
    const EnhancedSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final brokerService = Provider.of<BrokerAdapterService>(context, listen: false);
    final telegramService = Provider.of<TelegramService>(
      context,
      listen: false,
    );
    final mlService = Provider.of<MLService>(context, listen: false);

    await brokerService.initialize();
    await telegramService.initialize();
    await mlService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return QuantumWallpaper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _screens[_selectedIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Portfolio',
              ),
              NavigationDestination(
                icon: Icon(Icons.psychology_outlined),
                selectedIcon: Icon(Icons.psychology),
                label: 'Quantum',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
