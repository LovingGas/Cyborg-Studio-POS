import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../main.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/app_state.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.products.list(query: _query);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: state.t('search_products'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(state.t('no_products')))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(p.nameEn.characters.first.toUpperCase()),
                        ),
                        title: Text(p.displayName(state.lang)),
                        subtitle: Text(
                          '${categoryByCode(p.categoryCode).nameEn} · '
                          '${ks(p.sellPrice)} · ${state.t('in_stock')}: '
                          '${_fmtQty(p.stockQty)} ${p.unit}'
                          '${p.isLowStock ? ' · ${state.t('low_stock')}' : ''}',
                        ),
                        trailing: p.isFavorite
                            ? const Icon(Icons.star, color: Colors.amber)
                            : null,
                        onTap: () => _edit(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: Text(state.t('add_product')),
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Future<void> _edit(BuildContext context, Product? product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );
    if (saved == true && context.mounted) {
      context.read<AppState>().reloadProducts();
    }
  }
}

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  late final TextEditingController _nameEn;
  late final TextEditingController _nameMm;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _sell;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;
  String _category = pilotCategoryCode;
  String _unit = 'pcs';
  DateTime? _expiry;
  bool _favorite = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameEn = TextEditingController(text: p?.nameEn ?? '');
    _nameMm = TextEditingController(text: p?.nameMm ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(text: p?.costPrice.toString() ?? '0');
    _sell = TextEditingController(text: p?.sellPrice.toString() ?? '0');
    _stock = TextEditingController(
        text: p == null ? '0' : _fmtQty(p.stockQty));
    _threshold = TextEditingController(
        text: p == null ? '5' : _fmtQty(p.lowStockThreshold));
    _category = p?.categoryCode ?? pilotCategoryCode;
    _unit = p?.unit ?? 'pcs';
    _expiry = p?.expiryDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(p!.expiryDate!);
    _favorite = p?.isFavorite ?? false;
    _active = p?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_nameEn, _nameMm, _sku, _barcode, _cost, _sell, _stock, _threshold]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    // Name is validated manually in _save (no Form ancestor needed).
    Widget field(TextEditingController c, String label, {TextInputType? kb}) =>
        TextFormField(
          controller: c,
          keyboardType: kb,
          decoration: InputDecoration(labelText: label, isDense: true),
        );

    return AlertDialog(
      title: Text(widget.product == null
          ? state.t('add_product')
          : state.t('edit_product')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                field(_nameEn, state.t('name_en')),
                field(_nameMm, state.t('name_mm')),
                Row(children: [
                  Expanded(child: field(_sku, state.t('sku'))),
                  const SizedBox(width: 12),
                  Expanded(child: field(_barcode, state.t('barcode'))),
                ]),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration:
                      InputDecoration(labelText: state.t('category'), isDense: true),
                  items: [
                    for (final c in kCategories)
                      DropdownMenuItem(
                        value: c.code,
                        child: Text(
                          lang == 'mm' ? c.nameMm : c.nameEn,
                          style: TextStyle(
                            color: c.code == pilotCategoryCode
                                ? null
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    if (v != pilotCategoryCode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.t('locked_pilot'))),
                      );
                      return;
                    }
                    setState(() => _category = v);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration:
                      InputDecoration(labelText: state.t('unit'), isDense: true),
                  items: [
                    for (final u in kUnits)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
                Row(children: [
                  Expanded(
                      child: field(_cost, state.t('cost_price'),
                          kb: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: field(_sell, state.t('sell_price'),
                          kb: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(
                      child: field(_stock, state.t('stock_qty'),
                          kb: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: field(_threshold, state.t('low_stock_at'),
                          kb: const TextInputType.numberWithOptions(decimal: true))),
                ]),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(state.t('expiry_date')),
                  subtitle: Text(_expiry == null
                      ? '—'
                      : '${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiry ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _expiry = picked);
                    },
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(state.t('favorite')),
                  value: _favorite,
                  onChanged: (v) => setState(() => _favorite = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(state.t('active')),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(state.t('cancel')),
        ),
        FilledButton(
          onPressed: () => _save(context),
          child: Text(state.t('save')),
        ),
      ],
    );
  }

  void _save(BuildContext context) {
    final state = context.read<AppState>();
    if (_nameEn.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.t('required_field'))),
      );
      return;
    }
    int parseInt(TextEditingController c) =>
        int.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;
    double parseQty(TextEditingController c) =>
        double.tryParse(c.text.trim()) ?? 0;
    final product = Product(
      id: widget.product?.id ?? newId(),
      categoryCode: _category,
      nameEn: _nameEn.text.trim(),
      nameMm: _nameMm.text.trim().isEmpty ? null : _nameMm.text.trim(),
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      unit: _unit,
      costPrice: parseInt(_cost),
      sellPrice: parseInt(_sell),
      stockQty: parseQty(_stock),
      lowStockThreshold: parseQty(_threshold),
      expiryDate: _expiry?.millisecondsSinceEpoch,
      isFavorite: _favorite,
      isActive: _active,
    );
    state.products.save(product);
    Navigator.pop(context, true);
  }
}
