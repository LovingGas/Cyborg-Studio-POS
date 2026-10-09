// Lightweight sanity tests that need no platform channels (the full app
// needs SQLite + path_provider, covered by on-device smoke testing).
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/constants.dart';
import 'package:pos_app/l10n/strings.dart';

void main() {
  test('21 categories with Grocery as pilot', () {
    expect(kCategories.length, 21);
    expect(pilotCategoryCode, 'grocery');
    expect(categoryByCode('grocery').nameEn, 'Grocery');
  });

  test('10 payment methods, 4 primary, Cash first', () {
    expect(kPaymentMethods.length, 10);
    expect(kPaymentMethods.where((p) => p.primary).length, 4);
    expect(kPaymentMethods.first.code, 'cash');
    expect(paymentByCode('bank_transfer').label, 'Bank Transfer');
    expect(kBanks, contains('KBZ Bank'));
  });

  test('every EN string has an MM translation', () {
    for (final key in kStrings['en']!.keys) {
      expect(kStrings['mm']![key], isNotNull, reason: 'missing mm: $key');
    }
  });
}
