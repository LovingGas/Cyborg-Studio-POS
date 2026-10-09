import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'screens/dashboard_screen.dart';
import 'screens/more_screen.dart';
import 'screens/products_screen.dart';
import 'screens/sell_screen.dart';
import 'screens/stock_screen.dart';
import 'state/app_state.dart';

final ksFormat = NumberFormat('#,###');
String ks(int v) => '${ksFormat.format(v)} Ks';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Loads the bundled libsqlite3 on old Android versions (plugin helper).
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  } catch (_) {
    // Non-fatal: newer Android links the system/bundled library directly.
  }
  final state = AppState();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const PosApp()),
  );
  state.bootstrap();
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyborg Studio POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) {
      return Scaffold(
        body: Center(
          child: state.error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Database error: ${state.error}'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final screens = [
      const SellScreen(),
      const DashboardScreen(),
      const ProductsScreen(),
      const StockScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.displayShopName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(state.t('app_title'), style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'mm', label: Text('မြန်မာ')),
              ],
              selected: {state.lang},
              onSelectionChanged: (s) => state.setLang(s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.point_of_sale), label: state.t('sell')),
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              label: state.t('dashboard')),
          NavigationDestination(
              icon: const Icon(Icons.inventory_2), label: state.t('products')),
          NavigationDestination(
              icon: const Icon(Icons.warehouse), label: state.t('stock')),
          NavigationDestination(
              icon: const Icon(Icons.more_horiz), label: state.t('more')),
        ],
      ),
    );
  }
}
