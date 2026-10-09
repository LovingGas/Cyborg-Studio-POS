import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../main.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/app_state.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _customers = context.read<AppState>().customers.listWithBalances();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(state.t('customers'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editCustomer(context, null),
        child: const Icon(Icons.add),
      ),
      body: _customers.isEmpty
          ? Center(child: Text(state.t('no_customers')))
          : ListView.separated(
              itemCount: _customers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = _customers[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text([
                    if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                    if (c.address != null && c.address!.isNotEmpty) c.address!,
                  ].join(' · ')),
                  trailing: c.balanceDue > 0
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(ks(c.balanceDue),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                            Text(state.t('balance_due'),
                                style: const TextStyle(fontSize: 11)),
                          ],
                        )
                      : null,
                  onTap: () => _editCustomer(context, c),
                );
              },
            ),
    );
  }

  Future<void> _editCustomer(BuildContext context, Customer? existing) async {
    final state = context.read<AppState>();
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null
            ? state.t('add_customer')
            : state.t('edit_customer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: existing == null,
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
              const SizedBox(height: 10),
              TextField(
                controller: address,
                decoration: InputDecoration(
                  labelText: state.t('address'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(state.t('balance_due')),
                    Text(ks(existing.balanceDue),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(state.t('cancel')),
          ),
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'charge'),
              child: Text(state.t('add_credit')),
            ),
          if (existing != null && existing.balanceDue > 0)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'repay'),
              child: Text(state.t('record_repayment')),
            ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              state.customers.save(Customer(
                id: existing?.id ?? newId(),
                name: name.text.trim(),
                phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                address:
                    address.text.trim().isEmpty ? null : address.text.trim(),
              ));
              Navigator.pop(dialogContext, 'save');
            },
            child: Text(state.t('save')),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'save') {
      setState(_reload);
    } else if (action == 'repay' && existing != null) {
      await _recordRepayment(context, existing);
    } else if (action == 'charge' && existing != null) {
      await _recordCharge(context, existing);
    }
  }

  /// Manual debt-book entry: the customer took goods on credit outside a
  /// POS sale, so the shop types the owed amount in directly.
  Future<void> _recordCharge(BuildContext context, Customer c) async {
    final state = context.read<AppState>();
    final amount = TextEditingController();
    final note = TextEditingController();
    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${state.t('add_credit')} — ${c.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: state.t('amount'),
                  helperText:
                      '${state.t('balance_due')}: ${ks(c.balanceDue)}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: InputDecoration(
                  labelText: state.t('note_optional'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
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
              final v = int.tryParse(amount.text.trim());
              if (v == null || v <= 0) return;
              state.customers.recordCharge(
                customerId: c.id,
                amount: v,
                note: note.text.trim().isEmpty ? null : note.text.trim(),
              );
              Navigator.pop(dialogContext, true);
            },
            child: Text(state.t('save')),
          ),
        ],
      ),
    );
    if (done == true && context.mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.t('charge_done'))),
      );
    }
  }

  Future<void> _recordRepayment(BuildContext context, Customer c) async {
    final state = context.read<AppState>();
    final amount = TextEditingController();
    final note = TextEditingController();
    var method = 'cash';
    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('${state.t('record_repayment')} — ${c.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: state.t('amount'),
                    helperText:
                        '${state.t('balance_due')}: ${ks(c.balanceDue)}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: InputDecoration(
                    labelText: state.t('method'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final m
                        in kPaymentMethods.where((m) => m.code != 'credit'))
                      DropdownMenuItem(value: m.code, child: Text(m.label)),
                  ],
                  onChanged: (v) => setState(() => method = v ?? method),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: InputDecoration(
                    labelText: state.t('note_optional'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
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
                final v = int.tryParse(amount.text.trim());
                if (v == null || v <= 0) return;
                state.customers.recordRepayment(
                  customerId: c.id,
                  amount: v,
                  method: method,
                  note: note.text.trim().isEmpty ? null : note.text.trim(),
                );
                Navigator.pop(dialogContext, true);
              },
              child: Text(state.t('save')),
            ),
          ],
        ),
      ),
    );
    if (done == true && context.mounted) {
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.t('repayment_done'))),
      );
    }
  }
}
