import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'customers_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';
import 'stock_in_screen.dart';

/// Hub for the secondary screens that do not fit the bottom nav.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = <(IconData, String, Widget)>[
      (Icons.receipt_long, state.t('history'), const SalesHistoryScreen()),
      (Icons.people_outline, state.t('customers'), const CustomersScreen()),
      (Icons.local_shipping_outlined, state.t('stock_in'), const StockInScreen()),
      (Icons.settings, state.t('settings'), const SettingsScreen()),
    ];
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final (icon, label, screen) = entries[i];
        return ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => screen),
          ),
        );
      },
    );
  }
}
