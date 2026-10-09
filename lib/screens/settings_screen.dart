import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/receipt_text.dart';
import '../core/themes.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _nameMm = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _footer = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _nameMm, _phone, _address, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!_loaded) {
      _name.text = state.shopName;
      _nameMm.text = state.shopNameMm ?? '';
      _phone.text = state.shopPhone ?? '';
      _address.text = state.shopAddress ?? '';
      _footer.text = state.receiptFooter;
      _loaded = true;
    }
    return Scaffold(
      appBar: AppBar(title: Text(state.t('settings'))),
      body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(state.t('shop_profile'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          decoration: InputDecoration(
              labelText: state.t('shop_name'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameMm,
          decoration: InputDecoration(
              labelText: state.t('shop_name_mm'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
              labelText: state.t('phone'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _address,
          decoration: InputDecoration(
              labelText: state.t('address'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            state.saveShopProfile(
              name: _name.text.trim().isEmpty ? 'My Shop' : _name.text.trim(),
              nameMm: _nameMm.text.trim().isEmpty ? null : _nameMm.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              address:
                  _address.text.trim().isEmpty ? null : _address.text.trim(),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.t('save'))),
            );
          },
          icon: const Icon(Icons.save),
          label: Text(state.t('save')),
        ),
        const Divider(height: 32),
        Text(state.t('receipt_no'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _footer,
          decoration: InputDecoration(
              labelText: state.t('receipt_footer'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(state.t('paper_width')),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: kPaper58Chars, label: Text('58mm')),
                ButtonSegment(value: kPaper80Chars, label: Text('80mm')),
              ],
              selected: {state.paperWidthChars},
              onSelectionChanged: (s) => state.setPaperWidthChars(s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            state.saveReceiptFooter(_footer.text);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.t('save'))),
            );
          },
          icon: const Icon(Icons.save),
          label: Text(state.t('save')),
        ),
        const Divider(height: 32),
        Text(state.t('language'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'mm', label: Text('မြန်မာ')),
          ],
          selected: {state.lang},
          onSelectionChanged: (s) => state.setLang(s.first),
        ),
        const Divider(height: 32),
        Text(state.t('theme_colour'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // Exactly 3 themes per row, however large the system font is.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
          ),
          itemCount: kAppThemes.length,
          itemBuilder: (context, i) {
            final option = kAppThemes[i];
            final selected = state.themeKey == option.key;
            return InkWell(
              onTap: () => state.setTheme(option.key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: selected ? 2 : 1,
                  ),
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.5)
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(backgroundColor: option.seed, radius: 13),
                    const SizedBox(height: 6),
                    Text(
                      option.label(state.lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const Divider(height: 32),
        Text(state.t('license'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text(state.t('license_pilot')),
            subtitle: Text('Device: ${state.identity.deviceId.substring(0, 8)}…'),
          ),
        ),
      ],
      ),
    );
  }
}
