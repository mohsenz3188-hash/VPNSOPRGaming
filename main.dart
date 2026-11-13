import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/configs_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'services/vpn_engine_service.dart';
import 'theme/dragon_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final engine = VpnEngineService();
  await engine.initialize();
  runApp(
    ChangeNotifierProvider.value(
      value: engine,
      child: const VpnSoprGamingApp(),
    ),
  );
}

class VpnSoprGamingApp extends StatelessWidget {
  const VpnSoprGamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VPN SOPR Gaming',
      theme: buildDragonTheme(),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    ConfigsScreen(),
    LogsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<VpnEngineService>();
    final scaleColor = engine.connectionState == VpnConnectionState.connected
        ? DragonColors.electricBlue
        : DragonColors.crimsonRed;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DragonScalePainter(accentColor: scaleColor),
            ),
          ),
          IndexedStack(index: _index, children: _pages),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: DragonColors.charcoal,
        indicatorColor: DragonColors.electricBlue.withValues(alpha: 0.18),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: DragonColors.electricBlue),
            label: 'Core',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns, color: DragonColors.electricBlue),
            label: 'Configs',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal, color: DragonColors.electricBlue),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: DragonColors.electricBlue),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
