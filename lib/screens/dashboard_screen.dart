import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../main.dart';
import '../models/models.dart';
import '../state/app_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Profit stays masked until the admin view is switched on (mirrors
  /// the prototype: cashiers never see profit figures).
  bool _adminView = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final today = state.sales.todaySummary();
    final profit = today.total - today.costTotal;
    final breakdown = state.sales.paymentBreakdown(
      fromMs: startOfDay,
      toMs: startOfDay + 86400000,
    );
    final days = state.sales.dailyTotals(days: 7);
    final maxDay = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);

    final soonLimit = now.add(const Duration(days: 30));
    final lowStock = state.productList
        .where((p) => p.isLowStock || p.isOutOfStock)
        .toList();
    final expiring = state.productList.where((p) {
      if (p.expiryDate == null) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(p.expiryDate!);
      return d.isBefore(soonLimit);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.payments_outlined,
                label: state.t('today_sales'),
                value: ks(today.total),
                sub: '${state.t('sales_count')}: ${today.count}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up,
                label: state.t('today_profit'),
                value: _adminView ? ks(profit) : '••••',
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(state.t('admin_view')),
          value: _adminView,
          onChanged: (v) => setState(() => _adminView = v),
        ),
        const Divider(height: 24),
        Text(state.t('last_7_days'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        d.total == 0 ? '' : _shortKs(d.total),
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: maxDay == 0
                            ? 2
                            : 4 + 96.0 * d.total / maxDay,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('E').format(d.day),
                        style: const TextStyle(fontSize: 10),
                      ),
                      Text(
                        DateFormat('dd/MM').format(d.day),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        Text(state.t('payment_breakdown'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (breakdown.isEmpty)
          Text(state.t('no_sales_today'))
        else
          for (final b in breakdown)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(paymentMethodLabel(b.method)),
              subtitle: Text(
                  '${state.t('sales_count')}: ${b.count} · ${_fmtQty(b.items)} ${state.t('items')}'),
              trailing: Text(ks(b.total),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        const Divider(height: 24),
        Text('${state.t('low_stock')} (${lowStock.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (lowStock.isEmpty)
          const Text('—')
        else
          for (final p in lowStock.take(10))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                p.isOutOfStock ? Icons.error_outline : Icons.warning_amber,
                color: p.isOutOfStock ? Colors.red : Colors.orange,
                size: 20,
              ),
              title: Text(p.displayName(state.lang)),
              trailing:
                  Text('${_fmtQty(p.stockQty)} ${unitLabel(p.unit, state.lang)}'),
            ),
        const Divider(height: 24),
        Text('${state.t('expiring_soon')} (${expiring.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (expiring.isEmpty)
          const Text('—')
        else
          for (final p in expiring.take(10))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: Colors.orange, size: 20),
              title: Text(p.displayName(state.lang)),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(
                  DateTime.fromMillisecondsSinceEpoch(p.expiryDate!))),
              trailing: Text(
                DateTime.fromMillisecondsSinceEpoch(p.expiryDate!)
                        .isBefore(now)
                    ? state.t('expired')
                    : state.t('expiring_soon'),
                style: TextStyle(
                  color: DateTime.fromMillisecondsSinceEpoch(p.expiryDate!)
                          .isBefore(now)
                      ? Colors.red
                      : Colors.orange,
                ),
              ),
            ),
      ],
    );
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  static String _shortKs(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return '$v';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
