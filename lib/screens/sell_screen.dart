import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../main.dart';
import '../state/app_state.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.products
        .list(categoryCode: pilotCategoryCode, query: _query, includeInactive: false)
        .where((p) => !p.isOutOfStock)
        .toList();

    return Column(
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
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 0.95,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => state.addToCart(p),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(p.nameEn.characters.first.toUpperCase()),
                                  ),
                                  const Spacer(),
                                  if (p.isFavorite)
                                    const Icon(Icons.star, color: Colors.amber, size: 18),
                                  if (p.isLowStock)
                                    const Icon(Icons.warning_amber,
                                        color: Colors.orange, size: 18),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.displayName(state.lang),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(ks(p.sellPrice),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                '${state.t('in_stock')}: ${_fmtQty(p.stockQty)} ${p.unit}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _CartBar(onCheckout: () => _openCheckout(context)),
      ],
    );
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Future<void> _openCheckout(BuildContext context) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => const CheckoutDialog(),
    );
    if (done == true && context.mounted) {
      context.read<AppState>().reloadProducts();
    }
  }
}

class _CartBar extends StatelessWidget {
  final VoidCallback onCheckout;
  const _CartBar({required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Material(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.cart.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(state.t('cart_empty')),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in state.cart)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.product.displayName(state.lang)} × ${_fmtQty(item.qty)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () =>
                                state.setCartQty(item, item.qty - 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () =>
                                state.setCartQty(item, item.qty + 1),
                          ),
                          SizedBox(
                            width: 86,
                            child: Text(ks(item.lineTotal),
                                textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Text('${state.t('total')}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(ks(state.cartTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: state.cart.isEmpty ? null : state.clearCart,
                  child: Text(state.t('clear')),
                ),
                FilledButton.icon(
                  onPressed: state.cart.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.payments),
                  label: Text(
                      '${state.t('checkout')} (${state.cartCount} ${state.t('items')})'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _method = 'cash';
  String _bank = kBanks.first;
  String? _customerId;
  String _customerName = '';
  bool _showMore = false;
  final _paidCtrl = TextEditingController();

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final customers = state.sales.customers();
    final paid = int.tryParse(_paidCtrl.text.replaceAll(',', '')) ?? 0;
    final change = _method == 'cash' && paid > state.cartTotal
        ? paid - state.cartTotal
        : 0;
    final canComplete = state.cart.isNotEmpty &&
        (_method != 'cash' || paid >= state.cartTotal || paid == 0) &&
        (_method != 'credit' || _customerId != null || _customerName.trim().isNotEmpty);

    Widget methodButton(PaymentMethod m) => ChoiceChip(
          label: Text(m.label),
          selected: _method == m.code,
          onSelected: (_) => setState(() => _method = m.code),
        );

    return AlertDialog(
      title: Text(state.t('payment_method')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in kPaymentMethods.where((p) => p.primary))
                  methodButton(m),
              ],
            ),
            TextButton.icon(
              onPressed: () => setState(() => _showMore = !_showMore),
              icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
              label: Text(state.t('more')),
            ),
            if (_showMore)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in kPaymentMethods.where((p) => !p.primary))
                    methodButton(m),
                ],
              ),
            if (_method == 'bank_transfer') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _bank,
                decoration: InputDecoration(labelText: state.t('bank')),
                items: [
                  for (final b in kBanks)
                    DropdownMenuItem(value: b, child: Text(b)),
                ],
                onChanged: (v) => setState(() => _bank = v ?? _bank),
              ),
            ],
            if (_method == 'credit') ...[
              const SizedBox(height: 8),
              if (customers.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  decoration:
                      InputDecoration(labelText: state.t('customer_name')),
                  items: [
                    for (final c in customers)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                )
              else
                TextField(
                  decoration:
                      InputDecoration(labelText: state.t('customer_name')),
                  onChanged: (v) => setState(() => _customerName = v),
                ),
            ],
            if (_method == 'cash') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _paidCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: state.t('amount_paid'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: Text(state.t('exact')),
                    onPressed: () => setState(
                        () => _paidCtrl.text = state.cartTotal.toString()),
                  ),
                  for (final amt in kQuickCash)
                    ActionChip(
                      label: Text(ksFormat.format(amt)),
                      onPressed: () =>
                          setState(() => _paidCtrl.text = amt.toString()),
                    ),
                ],
              ),
              if (change > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${state.t('change')}: ${ks(change)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(state.t('total'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(ks(state.cartTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
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
          onPressed: canComplete ? () => _complete(context) : null,
          child: Text(state.t('complete_sale')),
        ),
      ],
    );
  }

  void _complete(BuildContext context) {
    final state = context.read<AppState>();
    // Pilot: Credit links a saved customer when one is picked. A typed name
    // (only shown when no customers exist yet) completes the sale without a
    // customer link — the People screen is a later step.
    final customerId = _customerId;
    final sale = state.sales.completeSale(
      items: List.of(state.cart),
      paymentMethod: _method,
      paymentBank: _method == 'bank_transfer' ? _bank : null,
      customerId: customerId,
      amountPaid: int.tryParse(_paidCtrl.text.replaceAll(',', '')) ?? 0,
    );
    state.clearCart();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${state.t('sale_done')} · ${state.t('receipt_no')} ${sale.receiptNo}'
          '${sale.changeDue > 0 ? ' · ${state.t('change')}: ${ks(sale.changeDue)}' : ''}',
        ),
      ),
    );
  }
}
