import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/dashboard_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/quantum_screen.dart';
import 'screens/settings_screen.dart';
import 'services/mt4_service.dart';
import 'services/telegram_service.dart';
import 'services/ml_service.dart';
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
        Provider(create: (_) => MT4Service()),
        Provider(create: (_) => TelegramService()),
        Provider(create: (_) => MLService()),
      ],
      child: MaterialApp(
        title: 'QuantumTrader Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            primary: Color(0xFF1E88E5),
            secondary: Color(0xFF00ACC1),
            surface: Colors.white,
            background: Color(0xFFF5F5F5),
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            backgroundColor: Color(0xFF1E88E5),
            foregroundColor: Colors.white,
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF42A5F5),
            secondary: Color(0xFF26C6DA),
            surface: Color(0xFF1E1E1E),
            background: Color(0xFF121212),
          ),
        ),
        themeMode: ThemeMode.light,
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
    const DashboardScreen(),
    const PortfolioScreen(),
    const QuantumScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final mt4Service = Provider.of<MT4Service>(context, listen: false);
    final telegramService = Provider.of<TelegramService>(context, listen: false);
    final mlService = Provider.of<MLService>(context, listen: false);

    await mt4Service.initialize();
    await telegramService.initialize();
    await mlService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
