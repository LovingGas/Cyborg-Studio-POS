/// Fixed-width receipt rendering (Foundation §4A). One layout engine,
/// parameterised by characters-per-line: 58 mm paper ≈ 32 chars,
/// 80 mm paper ≈ 48 chars. Text mode only — the logo is omitted here;
/// the raster path (for printers with no Myanmar code page) comes with
/// the printer phase.
library;

import 'package:intl/intl.dart';

/// Default thank-you/footer line when the shop has not set
/// `receipt_footer_text` (receipt-customization addendum).
const String kDefaultReceiptFooter = 'ကျေးဇူးတင်ပါသည် — နောက်ထပ် အားပေးပါဦး';

const int kPaper58Chars = 32;
const int kPaper80Chars = 48;

class ReceiptLineItem {
  final String name;
  final double qty;
  final int unitPrice;
  const ReceiptLineItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
  });
  int get amount => (qty * unitPrice).round();
}

final _money = NumberFormat('#,###');
String _ks(int v) => _money.format(v);

String _qty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

int _len(String s) => s.runes.length;

/// Word-wraps [text] to lines of at most [width] runes. Words longer
/// than the width are hard-split. Existing newlines are honoured.
List<String> wrapText(String text, int width) {
  final out = <String>[];
  for (final rawLine in text.split('\n')) {
    final words = rawLine.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var current = '';
    void flush() {
      if (current.isNotEmpty) {
        out.add(current);
        current = '';
      }
    }

    for (final word in words) {
      var w = word;
      while (_len(w) > width) {
        flush();
        final runes = w.runes.toList();
        out.add(String.fromCharCodes(runes.take(width)));
        w = String.fromCharCodes(runes.skip(width));
      }
      if (current.isEmpty) {
        current = w;
      } else if (_len(current) + 1 + _len(w) <= width) {
        current = '$current $w';
      } else {
        flush();
        current = w;
      }
    }
    flush();
    if (rawLine.trim().isEmpty) out.add('');
  }
  return out;
}

String _center(String line, int width) {
  final pad = (width - _len(line)) ~/ 2;
  return pad > 0 ? '${' ' * pad}$line' : line;
}

/// Left text + right text on one line of exactly [width] runes; if they
/// do not fit side by side, the right text goes on its own right-aligned
/// line.
List<String> _leftRight(String left, String right, int width) {
  final gap = width - _len(left) - _len(right);
  if (gap >= 1) return ['$left${' ' * gap}$right'];
  return [left, '${' ' * (width - _len(right))}$right'];
}

/// Builds the receipt as fixed-width plain text where every line is at
/// most [widthChars] runes — the same text that the §4A raster fallback
/// will later draw for Myanmar-unaware printers.
String buildReceiptText({
  required int widthChars,
  required String shopName,
  String? address,
  String? phone,
  required String receiptNo,
  required DateTime time,
  required List<ReceiptLineItem> items,
  required int total,
  required String paymentLabel,
  int amountPaid = 0,
  int changeDue = 0,
  String? footerText,
}) {
  final w = widthChars;
  final lines = <String>[];
  final divider = '-' * w;

  // Header: shop name / address / phone, centred (§4A + addendum rule 2:
  // empty fields are omitted entirely).
  for (final l in wrapText(shopName, w)) {
    lines.add(_center(l, w));
  }
  if (address != null && address.trim().isNotEmpty) {
    for (final l in wrapText(address.trim(), w)) {
      lines.add(_center(l, w));
    }
  }
  if (phone != null && phone.trim().isNotEmpty) {
    lines.add(_center(phone.trim(), w));
  }
  lines.add(divider);
  lines.addAll(_leftRight(
    'No: $receiptNo',
    DateFormat('yyyy-MM-dd HH:mm').format(time),
    w,
  ));
  lines.add(divider);

  // Items: name (wrapped), then "  qty x price" with the amount right.
  for (final item in items) {
    lines.addAll(wrapText(item.name, w));
    lines.addAll(_leftRight(
      '  ${_qty(item.qty)} x ${_ks(item.unitPrice)}',
      _ks(item.amount),
      w,
    ));
  }
  lines.add(divider);

  // Totals.
  lines.addAll(_leftRight('TOTAL', '${_ks(total)} Ks', w));
  if (amountPaid > 0) {
    lines.addAll(_leftRight('Paid', '${_ks(amountPaid)} Ks', w));
  }
  if (changeDue > 0) {
    lines.addAll(_leftRight('Change', '${_ks(changeDue)} Ks', w));
  }
  lines.addAll(wrapText('Payment: $paymentLabel', w));
  lines.add(divider);

  // Footer: the shop's thank-you text, or the Burmese default.
  final footer = (footerText != null && footerText.trim().isNotEmpty)
      ? footerText.trim()
      : kDefaultReceiptFooter;
  for (final l in wrapText(footer, w)) {
    lines.add(_center(l, w));
  }
  return lines.join('\n');
}
