import 'package:flutter/foundation.dart';

import '../core/receipt_text.dart';
import '../core/samples.dart';
import '../core/themes.dart';
import '../db/app_database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

/// Single app-wide state for the pilot: language, shop profile (from
/// settings_kv), the cart, and the loaded product list.
class AppState extends ChangeNotifier {
  late final AppDatabase _holder;
  late final Identity identity;
  late final SettingsRepository settings;
  late final ProductRepository products;
  late final SaleRepository sales;
  late final CustomerRepository customers;
  late final PurchaseRepository purchases;

  bool ready = false;
  String? error;

  String lang = 'en';

  /// Selected colour theme key (settings_kv `app_theme`, see kAppThemes).
  String themeKey = kDefaultThemeKey;
  String shopName = 'My Shop';
  String? shopNameMm;
  String? shopPhone;
  String? shopAddress;

  /// Receipt thank-you/footer text (settings_kv `receipt_footer_text`,
  /// addendum default when unset) and paper width in chars (§4A:
  /// 58 mm → 32, 80 mm → 48).
  String receiptFooter = kDefaultReceiptFooter;
  int paperWidthChars = kPaper80Chars;

  List<Product> productList = [];
  final List<CartItem> cart = [];

  Future<void> bootstrap() async {
    try {
      _holder = await AppDatabase.open();
      settings = SettingsRepository(_holder);
      identity = await settings.ensureIdentity();
      products = ProductRepository(_holder, identity);
      sales = SaleRepository(_holder, identity);
      customers = CustomerRepository(_holder, identity);
      purchases = PurchaseRepository(_holder, identity);
      lang = settings.get(identity.shopId, 'ui_lang') ?? 'en';
      themeKey = settings.get(identity.shopId, 'app_theme') ?? kDefaultThemeKey;
      shopName = settings.get(identity.shopId, 'shop_name') ?? 'My Shop';
      shopNameMm = settings.get(identity.shopId, 'shop_name_mm');
      shopPhone = settings.get(identity.shopId, 'shop_phone');
      shopAddress = settings.get(identity.shopId, 'shop_address');
      receiptFooter =
          settings.get(identity.shopId, 'receipt_footer_text') ??
              kDefaultReceiptFooter;
      paperWidthChars =
          settings.get(identity.shopId, 'printer_paper_width') == '58'
              ? kPaper58Chars
              : kPaper80Chars;
      reloadProducts();
      ready = true;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  String t(String key) => kStrings[lang]?[key] ?? kStrings['en']?[key] ?? key;

  /// The Myanmar shop name wins whenever one is set — it is the shop's
  /// signboard name, so the header and receipts show it in both UI
  /// languages. Shops that only set an English name are unaffected.
  String get displayShopName =>
      (shopNameMm != null && shopNameMm!.isNotEmpty) ? shopNameMm! : shopName;

  void saveReceiptFooter(String text) {
    receiptFooter = text.trim().isEmpty ? kDefaultReceiptFooter : text.trim();
    settings.set(identity.shopId, 'receipt_footer_text', receiptFooter);
    notifyListeners();
  }

  void setPaperWidthChars(int chars) {
    paperWidthChars = chars;
    settings.set(
        identity.shopId, 'printer_paper_width', chars == kPaper58Chars ? '58' : '80');
    notifyListeners();
  }

  void setTheme(String key) {
    themeKey = key;
    settings.set(identity.shopId, 'app_theme', key);
    _holder.db.execute(
      'UPDATE shops SET theme = ?, updated_at = ? WHERE id = ?',
      [key, nowMs(), identity.shopId],
    );
    notifyListeners();
  }

  void setLang(String value) {
    lang = value;
    settings.set(identity.shopId, 'ui_lang', value);
    notifyListeners();
  }

  void saveShopProfile({
    required String name,
    String? nameMm,
    String? phone,
    String? address,
  }) {
    shopName = name;
    shopNameMm = nameMm;
    shopPhone = phone;
    shopAddress = address;
    settings.set(identity.shopId, 'shop_name', name);
    settings.set(identity.shopId, 'shop_name_mm', nameMm ?? '');
    settings.set(identity.shopId, 'shop_phone', phone ?? '');
    settings.set(identity.shopId, 'shop_address', address ?? '');
    final t = nowMs();
    _holder.db.execute(
      'UPDATE shops SET name = ?, name_mm = ?, phone = ?, address = ?, updated_at = ? WHERE id = ?',
      [name, nameMm, phone, address, t, identity.shopId],
    );
    notifyListeners();
  }

  // ---- products ----
  /// Loads the Grocery sample catalog into an empty catalog. Returns how
  /// many products were inserted (0 when the catalog is not empty).
  int loadSampleProducts() {
    if (products.list().isNotEmpty) return 0;
    final samples = grocerySampleProducts();
    for (final sample in samples) {
      products.save(sample);
    }
    reloadProducts();
    return samples.length;
  }

  void reloadProducts() {
    productList = products.list();
    notifyListeners();
  }

  // ---- cart ----
  int get cartTotal => cart.fold(0, (s, i) => s + i.lineTotal);

  /// Total quantity in the cart (sum of line quantities) — the checkout
  /// button's "N items" means pieces, not distinct product lines.
  double get cartQtyTotal => cart.fold(0.0, (s, i) => s + i.qty);

  void addToCart(Product p) {
    final existing = cart.where((i) => i.product.id == p.id);
    if (existing.isNotEmpty) {
      existing.first.qty += 1;
    } else {
      cart.add(CartItem(p, 1));
    }
    notifyListeners();
  }

  void setCartQty(CartItem item, double qty) {
    if (qty <= 0) {
      cart.remove(item);
    } else {
      item.qty = qty;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }
}
