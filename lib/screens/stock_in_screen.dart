import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/models.dart';
import '../state/app_state.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({super.key});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  List<PurchaseRecord> _purchases = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _purchases = context.read<AppState>().purchases.listPurchases();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(state.t('stock_in'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newPurchase(context),
        icon: const Icon(Icons.add),
        label: Text(state.t('new_purchase')),
      ),
      body: _purchases.isEmpty
          ? Center(child: Text(state.t('no_purchases')))
          : ListView.separated(
              itemCount: _purchases.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _purchases[i];
                return ListTile(
                  title: Text(p.supplierName ?? '—'),
                  subtitle: Text(
                    '${fmt.format(DateTime.fromMillisecondsSinceEpoch(p.createdAt))}'
                    ' · ${p.itemCount} ${state.t('items')}',
                  ),
                  trailing: Text(ks(p.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                );
              },
            ),
    );
  }

  Future<void> _newPurchase(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _PurchaseFormScreen()),
    );
    if (saved != true || !context.mounted) return;
    setState(_reload);
    context.read<AppState>().reloadProducts();
  }
}

class _LineDraft {
  Product product;
  final TextEditingController qty;
  final TextEditingController cost;
  _LineDraft(this.product)
      : qty = TextEditingController(text: '1'),
        cost = TextEditingController(text: product.costPrice.toString());
  void dispose() {
    qty.dispose();
    cost.dispose();
  }
}

class _PurchaseFormScreen extends StatefulWidget {
  const _PurchaseFormScreen();

  @override
  State<_PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<_PurchaseFormScreen> {
  String? _supplierId;
  List<Supplier> _suppliers = [];
  final List<_LineDraft> _lines = [];

  @override
  void initState() {
    super.initState();
    _suppliers = context.read<AppState>().purchases.suppliers();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int get _total => _lines.fold(0, (s, l) {
        final q = double.tryParse(l.qty.text.trim()) ?? 0;
        final c = int.tryParse(l.cost.text.trim()) ?? 0;
        return s + (q * c).round();
      });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(state.t('new_purchase'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: InputDecoration(
                    labelText: state.t('supplier'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final s in _suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person_add_alt),
                tooltip: state.t('add_supplier'),
                onPressed: () => _addSupplier(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _lines.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _lines[i].product.id,
                    decoration: InputDecoration(
                      labelText: state.t('select_product'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final p in state.productList)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(p.displayName(state.lang)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      final p = state.productList
                          .firstWhere((p) => p.id == v);
                      setState(() {
                        _lines[i].product = p;
                        _lines[i].cost.text = p.costPrice.toString();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lines[i].qty,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: state.t('qty'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lines[i].cost,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: state.t('cost_price'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                    _lines[i].dispose();
                    _lines.removeAt(i);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(state.t('add_item')),
            onPressed: state.productList.isEmpty
                ? null
                : () => setState(
                    () => _lines.add(_LineDraft(state.productList.first))),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(state.t('total'),
                  style: Theme.of(context).textTheme.titleMedium),
              Text(ks(_total),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: Text(state.t('save')),
            onPressed: _lines.isEmpty
                ? null
                : () {
                    final lines = <PurchaseLine>[];
                    for (final l in _lines) {
                      final q = double.tryParse(l.qty.text.trim()) ?? 0;
                      final c = int.tryParse(l.cost.text.trim()) ?? 0;
                      if (q > 0) {
                        lines.add(PurchaseLine(
                            productId: l.product.id, qty: q, unitCost: c));
                      }
                    }
                    if (lines.isEmpty) return;
                    state.purchases.recordPurchase(
                      supplierId: _supplierId,
                      lines: lines,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(state.t('purchase_done'))),
                    );
                    Navigator.pop(context, true);
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _addSupplier(BuildContext context) async {
    final state = context.read<AppState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final added = await showDialog<Supplier>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(state.t('add_supplier')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: state.t('name'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: state.t('phone'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(state.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                dialogContext,
                state.purchases.addSupplier(
                  name: name.text.trim(),
                  phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                ),
              );
            },
            child: Text(state.t('save')),
          ),
        ],
      ),
    );
    if (added != null && mounted) {
      setState(() {
        _suppliers = [..._suppliers, added];
        _supplierId = added.id;
      });
    }
  }
}
