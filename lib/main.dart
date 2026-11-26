import 'package:flutter/material.dart';

import 'screens/agreement_screen.dart';
import 'screens/compare_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/inspection_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(AppScope(state: state, child: const DepositGuardApp()));
}

const brand = Color(0xFF0F766E);

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorSchemeSeed: brand,
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1513) : const Color(0xFFF6F8F7),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF161F1D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: dark ? const Color(0xFF26312E) : const Color(0xFFE3E8E6)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}

class DepositGuardApp extends StatelessWidget {
  const DepositGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return MaterialApp(
      title: 'DepositGuard',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: s.themeMode,
      home: s.tenancy == null ? const OnboardingScreen() : const HomeShell(),
    );
  }
}

/// One code base, three layouts:
///  * phone (< 700 px)      → bottom navigation bar
///  * tablet / small window → compact navigation rail
///  * desktop / large web   → extended rail with labels
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const _destinations = [
    (Icons.shield_outlined, Icons.shield, 'Overview'),
    (Icons.fact_check_outlined, Icons.fact_check, 'Inspection'),
    (Icons.compare_outlined, Icons.compare, 'Move-out'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Rent'),
    (Icons.verified_outlined, Icons.verified, 'Seal'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  void _go(int i) => setState(() => index = i);

  Widget _page() => switch (index) {
        0 => DashboardScreen(onNavigate: _go),
        1 => const InspectionScreen(),
        2 => const CompareScreen(),
        3 => const LedgerScreen(),
        4 => const AgreementScreen(),
        _ => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(index), child: _page()),
    );

    if (width < 700) {
      return Scaffold(
        appBar: AppBar(
          title: const Logo(),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: () => _go(5),
              icon: Icon(index == 5 ? Icons.settings : Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(child: page),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index.clamp(0, 4),
          onDestinationSelected: _go,
          destinations: [
            for (final d in _destinations.take(5))
              NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
          ],
        ),
      );
    }

    final extended = width >= 1100;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: index,
            onDestinationSelected: _go,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Logo(compact: !extended),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.compact = false});

  /// In the narrow navigation rail only the shield badge fits.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shield, color: Colors.white, size: 20),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          const Text('DepositGuard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ],
    );
  }
}
