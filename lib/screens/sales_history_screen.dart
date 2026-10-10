import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/receipt_text.dart';
import '../main.dart';
import '../models/models.dart';
import '../state/app_state.dart';

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<SaleRecord> _sales = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _sales = context.read<AppState>().sales.listSales();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final timeFmt = DateFormat('dd MMM HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(state.t('history'))),
      body: _sales.isEmpty
          ? Center(child: Text(state.t('no_sales')))
          : ListView.separated(
              itemCount: _sales.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = _sales[i];
                final when =
                    DateTime.fromMillisecondsSinceEpoch(s.createdAt);
                return ListTile(
                  title: Text(
                    s.receiptNo ?? s.id.substring(0, 8),
                    style: s.isVoid
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  subtitle: Text(
                    '${timeFmt.format(when)} · ${s.paymentLabel} · '
                    '${_fmtQty(s.itemCount)} ${state.t('items')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.isVoid)
                        Chip(
                          label: Text(state.t('voided')),
                          backgroundColor: Colors.red.shade100,
                          visualDensity: VisualDensity.compact,
                        ),
                      const SizedBox(width: 8),
                      Text(ks(s.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceiptScreen(saleId: s.id),
                      ),
                    );
                    if (mounted) setState(_reload);
                    state.reloadProducts();
                  },
                );
              },
            ),
    );
  }
}

/// Receipt view: the §4A fixed-width text receipt at 58 mm (32 chars) or
/// 80 mm (48 chars), with a width toggle and the void-sale action.
class ReceiptScreen extends StatefulWidget {
  final String saleId;
  const ReceiptScreen({super.key, required this.saleId});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late int _widthChars;

  @override
  void initState() {
    super.initState();
    _widthChars = context.read<AppState>().paperWidthChars;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sale = state.sales.saleById(widget.saleId);
    if (sale == null) {
      return Scaffold(
        appBar: AppBar(title: Text(state.t('receipt_no'))),
        body: Center(child: Text(state.t('no_sales'))),
      );
    }
    final items = state.sales.saleItems(widget.saleId);
    final text = buildReceiptText(
      widthChars: _widthChars,
      shopName: state.displayShopName,
      address: state.shopAddress,
      phone: state.shopPhone,
      receiptNo: sale.receiptNo ?? sale.id.substring(0, 8),
      time: DateTime.fromMillisecondsSinceEpoch(sale.createdAt),
      items: items
          .map((i) => ReceiptLineItem(
              name: i.name, qty: i.qty, unitPrice: i.unitPrice))
          .toList(),
      total: sale.total,
      paymentLabel: sale.paymentLabel,
      amountPaid: sale.amountPaid,
      changeDue: sale.changeDue,
      footerText: state.receiptFooter,
    );
    return Scaffold(
      appBar: AppBar(title: Text('${state.t('receipt_no')} ${sale.receiptNo ?? ''}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(state.t('paper_width')),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (chars, label) in const [
                (kPaper40Chars, '40mm'),
                (kPaper48Chars, '48mm'),
                (kPaper58Chars, '58mm'),
                (kPaper80Chars, '80mm'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _widthChars == chars,
                  onSelected: (_) {
                    setState(() => _widthChars = chars);
                    state.setPaperWidthChars(chars);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            // Scale the whole fixed-width receipt down to fit the card so
            // no line is ever clipped at either edge (a horizontal scroll
            // view hid the left/right ends at large system font sizes).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: Text(
                text,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _widthChars == kPaper58Chars ? 12.5 : 11.5,
                  height: 1.35,
                  decoration:
                      sale.isVoid ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
          if (sale.isVoid) ...[
            const SizedBox(height: 12),
            Chip(
              label: Text(state.t('voided')),
              backgroundColor: Colors.red.shade100,
            ),
          ] else ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: Text(state.t('correct_prices')),
              onPressed: () => _correctPrices(context, sale),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.block, color: Colors.red),
              label: Text(state.t('void_sale'),
                  style: const TextStyle(color: Colors.red)),
              onPressed: () => _voidSale(context, sale),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _voidSale(BuildContext context, SaleRecord sale) async {
    final state = context.read<AppState>();
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(state.t('void_sale')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: state.t('void_reason'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(state.t('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, ctrl.text.trim()),
            child: Text(state.t('void_sale')),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;
    state.sales.voidSale(sale.id, reason);
    state.reloadProducts();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.t('void_done'))),
    );
  }

  /// Fixes prices typed wrong on a sale that already went through:
  /// per-item sell/cost prices are edited, and totals, profit and any
  /// Credit balance are corrected to match. Quantities never change.
  Future<void> _correctPrices(BuildContext context, SaleRecord sale) async {
    final state = context.read<AppState>();
    final items = state.sales.saleItems(sale.id);
    final sellCtrls = [
      for (final i in items) TextEditingController(text: i.unitPrice.toString())
    ];
    final costCtrls = [
      for (final i in items) TextEditingController(text: i.costPrice.toString())
    ];
    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(state.t('correct_prices')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var idx = 0; idx < items.length; idx++) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${items[idx].name} × ${_fmtQty(items[idx].qty)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sellCtrls[idx],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: state.t('sell_price'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrls[idx],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: state.t('cost_price'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(state.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              state.sales.correctSalePrices(sale.id, [
                for (var idx = 0; idx < items.length; idx++)
                  (
                    itemId: items[idx].id,
                    unitPrice:
                        int.tryParse(sellCtrls[idx].text.trim()) ??
                            items[idx].unitPrice,
                    costPrice:
                        int.tryParse(costCtrls[idx].text.trim()) ??
                            items[idx].costPrice,
                  ),
              ]);
              Navigator.pop(dialogContext, true);
            },
            child: Text(state.t('save')),
          ),
        ],
      ),
    );
    if (done == true && context.mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.t('sale_corrected'))),
      );
    }
  }
}
