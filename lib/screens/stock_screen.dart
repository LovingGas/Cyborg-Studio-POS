import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../main.dart';
import '../models/models.dart';
import '../state/app_state.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.productList;
    final stockValue = items.fold<int>(
        0, (s, p) => s + (p.costPrice * p.stockQty).round());
    final now = DateTime.now();
    final soon = now.add(const Duration(days: 30));

    String? expiryNote(Product p) {
      if (p.expiryDate == null) return null;
      final d = DateTime.fromMillisecondsSinceEpoch(p.expiryDate!);
      if (d.isBefore(now)) return state.t('expired');
      if (d.isBefore(soon)) return state.t('expiring_soon');
      return null;
    }

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text(state.t('stock_value')),
          trailing: Text(ks(stockValue),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(state.t('no_products')))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final note = expiryNote(p);
                    // Status lives in the subtitle, not in a wide chip in
                    // the trailing row: a long Myanmar chip label squeezed
                    // the title into a one-character-wide vertical strip.
                    final status = p.isOutOfStock
                        ? state.t('out_of_stock')
                        : p.isLowStock
                            ? state.t('low_stock')
                            : null;
                    return ListTile(
                      tileColor: p.isOutOfStock
                          ? Colors.red.withValues(alpha: 0.06)
                          : p.isLowStock
                              ? Colors.orange.withValues(alpha: 0.08)
                              : null,
                      title: Text(
                        p.displayName(state.lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          ?status,
                          '${state.t('low_stock_at')}: ${_fmtQty(p.lowStockThreshold)}',
                          ?note,
                        ].join(' · '),
                        style: TextStyle(
                          color: p.isOutOfStock
                              ? Colors.red.shade700
                              : p.isLowStock
                                  ? Colors.orange.shade800
                                  : null,
                          fontWeight: status != null ? FontWeight.w600 : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_fmtQty(p.stockQty)} ${unitLabel(p.unit, state.lang)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.tune, size: 20),
                            tooltip: state.t('adjust'),
                            onPressed: () => _adjust(context, p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _adjust(BuildContext context, Product p) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController();
    var reason = 'count_fix';
    final delta = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('${state.t('adjust')} — ${p.displayName(state.lang)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(
                  labelText: '${state.t('qty')} (+ / −)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: InputDecoration(labelText: state.t('adjust_reason')),
                items: [
                  DropdownMenuItem(
                      value: 'count_fix',
                      child: Text(state.t('reason_count_fix'))),
                  DropdownMenuItem(
                      value: 'damaged', child: Text(state.t('reason_damaged'))),
                  DropdownMenuItem(
                      value: 'expired', child: Text(state.t('reason_expired'))),
                  DropdownMenuItem(
                      value: 'other', child: Text(state.t('reason_other'))),
                ],
                onChanged: (v) => setState(() => reason = v ?? reason),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(state.t('cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, double.tryParse(ctrl.text.trim())),
              child: Text(state.t('save')),
            ),
          ],
        ),
      ),
    );
    if (delta != null && delta != 0) {
      state.products.adjustStock(p, delta, reason);
      state.reloadProducts();
    }
  }
}
