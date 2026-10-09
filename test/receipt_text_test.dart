import 'package:flutter_test/flutter_test.dart';
import 'package:cyborg_studio_pos/core/receipt_text.dart';

void main() {
  final items = [
    const ReceiptLineItem(
        name: 'Instant Noodles Family Pack (Spicy)', qty: 2, unitPrice: 1500),
    const ReceiptLineItem(name: 'Rice 1kg', qty: 1, unitPrice: 3200),
    const ReceiptLineItem(name: 'Cooking Oil 1L Bottle', qty: 0.5, unitPrice: 8000),
  ];

  String build(int width, {String? footer}) => buildReceiptText(
        widthChars: width,
        shopName: 'Shwe Grocery Store',
        address: '123 Pyay Road, Yangon',
        phone: '09 123 456 789',
        receiptNo: 'ABCD-20261009-0001',
        time: DateTime(2026, 10, 9, 14, 30),
        items: items,
        total: 10200,
        paymentLabel: 'Bank Transfer (KBZ Bank)',
        amountPaid: 0,
        footerText: footer,
      );

  test('58mm receipt: no line exceeds 32 chars', () {
    final lines = build(kPaper58Chars).split('\n');
    for (final line in lines) {
      expect(line.runes.length, lessThanOrEqualTo(kPaper58Chars),
          reason: 'line too wide: "$line"');
    }
  });

  test('40mm receipt: no line exceeds 24 chars', () {
    final lines = build(kPaper40Chars).split('\n');
    for (final line in lines) {
      expect(line.runes.length, lessThanOrEqualTo(kPaper40Chars),
          reason: 'line too wide: "$line"');
    }
  });

  test('48mm receipt: no line exceeds 28 chars', () {
    final lines = build(kPaper48Chars).split('\n');
    for (final line in lines) {
      expect(line.runes.length, lessThanOrEqualTo(kPaper48Chars),
          reason: 'line too wide: "$line"');
    }
  });

  test('80mm receipt: no line exceeds 48 chars', () {
    final lines = build(kPaper80Chars).split('\n');
    for (final line in lines) {
      expect(line.runes.length, lessThanOrEqualTo(kPaper80Chars),
          reason: 'line too wide: "$line"');
    }
  });

  test('narrower paper wraps into at least as many lines', () {
    final n58 = build(kPaper58Chars).split('\n').length;
    final n80 = build(kPaper80Chars).split('\n').length;
    expect(n58, greaterThan(n80));
  });

  test('total line is padded to the full width on both papers', () {
    for (final w in [kPaper58Chars, kPaper80Chars]) {
      final totalLine = build(w)
          .split('\n')
          .firstWhere((l) => l.startsWith('TOTAL'), orElse: () => '');
      expect(totalLine.runes.length, w, reason: 'width $w');
      expect(totalLine.trimRight(), endsWith('10,200 Ks'));
    }
  });

  test('header, payment label and default Burmese footer are present', () {
    final text = build(kPaper80Chars);
    expect(text, contains('Shwe Grocery Store'));
    expect(text, contains('09 123 456 789'));
    expect(text, contains('Payment: Bank Transfer (KBZ Bank)'));
    expect(text, contains(kDefaultReceiptFooter));
  });

  test('custom footer replaces the default', () {
    final text = build(kPaper58Chars, footer: 'Thank you, come again!');
    expect(text, contains('Thank you, come again!'));
    expect(text, isNot(contains(kDefaultReceiptFooter)));
  });

  test('long words are hard-split to fit the width', () {
    final lines = wrapText('Supercalifragilisticexpialidocious', 10);
    for (final line in lines) {
      expect(line.runes.length, lessThanOrEqualTo(10));
    }
    expect(lines.join(), 'Supercalifragilisticexpialidocious');
  });
}
