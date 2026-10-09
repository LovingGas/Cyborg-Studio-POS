/// Static reference data from the Foundation design:
/// §3 category codes (21), §1.2 units, §4 payment methods.
library;

class CategoryInfo {
  final String code;
  final String nameEn;
  final String nameMm;
  final String group;
  const CategoryInfo(this.code, this.nameEn, this.nameMm, this.group);
}

/// All 21 categories (Foundation §3). The pilot build only *unlocks*
/// [pilotCategoryCode]; the rest exist in schema/UI as locked so the
/// entitlement model is visible from day one.
const String pilotCategoryCode = 'grocery';

const List<CategoryInfo> kCategories = [
  CategoryInfo('grocery', 'Grocery', 'ကုန်စုံ', 'Food & Drink'),
  CategoryInfo('beverage', 'Beverage', 'အဖျော်ယမကာ', 'Food & Drink'),
  CategoryInfo('food_restaurant', 'Food & Restaurant', 'စားသောက်ဆိုင်', 'Food & Drink'),
  CategoryInfo('tea_snacks', 'Tea & Traditional Snacks', 'လက်ဖက်ရည်နှင့် မုန့်မျိုးစုံ', 'Food & Drink'),
  CategoryInfo('pharmacy', 'Pharmacy', 'ဆေးဆိုင်', 'Retail Shops'),
  CategoryInfo('electronics', 'Electronics', 'အီလက်ထရောနစ်', 'Retail Shops'),
  CategoryInfo('clothing', 'Clothing', 'အဝတ်အထည်', 'Retail Shops'),
  CategoryInfo('household', 'Household', 'အိမ်သုံးပစ္စည်း', 'Retail Shops'),
  CategoryInfo('stationery', 'Stationery', 'စာရေးကိရိယာ', 'Retail Shops'),
  CategoryInfo('beauty', 'Beauty', 'အလှကုန်', 'Retail Shops'),
  CategoryInfo('hardware', 'Hardware', 'သံထည်/ဆောက်လုပ်ရေး အသေး', 'Retail Shops'),
  CategoryInfo('toy_shop', 'Toy Shop', 'ကလေးကစားစရာ', 'Retail Shops'),
  CategoryInfo('consumer_goods', 'Consumer Goods', 'လူသုံးကုန်', 'Retail Shops'),
  CategoryInfo('gold_jewelry', 'Gold & Jewelry', 'ရွှေနှင့် ကျောက်မျက်', 'Retail Shops'),
  CategoryInfo('online_shop', 'Online Shop', 'အွန်လိုင်းဆိုင်', 'Retail Shops'),
  CategoryInfo('mobile', 'Mobile Sales & Service & Accessories', 'မိုဘိုင်း အရောင်းနှင့် ဝန်ဆောင်မှု', 'Services'),
  CategoryInfo('construction', 'Construction Materials', 'ဆောက်လုပ်ရေးပစ္စည်း', 'Services'),
  CategoryInfo('travel_tours', 'Travel & Tours', 'ခရီးသွား ဝန်ဆောင်မှု', 'Services'),
  CategoryInfo('general', 'General', 'အထွေထွေ', 'Services'),
  CategoryInfo('ktv_bar', 'KTV Bar', 'KTV ဘား', 'Hospitality & Entertainment'),
  CategoryInfo('hotel_restaurant', 'Hotel & Restaurant', 'ဟိုတယ်နှင့် စားသောက်ဆိုင်', 'Hospitality & Entertainment'),
];

CategoryInfo categoryByCode(String code) =>
    kCategories.firstWhere((c) => c.code == code, orElse: () => kCategories.last);

/// Units seen in the prototype + Foundation §1.2.
const List<String> kUnits = [
  'pcs', 'kg', 'pack', 'bag', 'bottle', 'box', 'can',
  'night', 'sheet', 'gallon', 'length', 'tical', 'gram',
  'person', 'trip', 'ticket', 'day', 'service',
];

class PaymentMethod {
  final String code;
  final String label;
  final bool primary;
  const PaymentMethod(this.code, this.label, {this.primary = false});
}

/// The 10 user-app payment methods (Foundation §4). Cash is the default;
/// Cash + the 3 big wallets are primary buttons, the rest sit under "More".
const List<PaymentMethod> kPaymentMethods = [
  PaymentMethod('cash', 'Cash', primary: true),
  PaymentMethod('kbz_pay', 'KBZ Pay', primary: true),
  PaymentMethod('aya_pay', 'AYA Pay', primary: true),
  PaymentMethod('wave_pay', 'Wave Pay', primary: true),
  PaymentMethod('cb_pay', 'CB Pay'),
  PaymentMethod('uab_pay', 'UAB Pay'),
  PaymentMethod('mmqr_pay', 'MMQR Pay'),
  PaymentMethod('bank_transfer', 'Bank Transfer'),
  PaymentMethod('card', 'Card'),
  PaymentMethod('credit', 'Credit'),
];

PaymentMethod paymentByCode(String code) => kPaymentMethods.firstWhere(
      (p) => p.code == code,
      orElse: () => kPaymentMethods.first,
    );

/// Receiving banks recorded on Bank Transfer sales (Foundation §4).
const List<String> kBanks = [
  'KBZ Bank', 'AYA Bank', 'CB Bank', 'Yoma Bank', 'UAB Bank', 'Other',
];

/// Quick cash-tendered amounts (Ks).
const List<int> kQuickCash = [1000, 5000, 10000, 50000, 100000];
