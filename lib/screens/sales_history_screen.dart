import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/receipt_text.dart';
import '../main.dart';
import '../models/models.dart';
import '../state/app_state.dart';

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
                    '${s.itemCount} ${state.t('items')}',
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
          Row(
            children: [
              Text(state.t('paper_width')),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: kPaper58Chars, label: Text('58mm')),
                  ButtonSegment(value: kPaper80Chars, label: Text('80mm')),
                ],
                selected: {_widthChars},
                onSelectionChanged: (s) {
                  setState(() => _widthChars = s.first);
                  state.setPaperWidthChars(s.first);
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                text,
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
}
