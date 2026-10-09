import 'package:flutter/foundation.dart';

import '../core/receipt_text.dart';
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

  String get displayShopName =>
      (lang == 'mm' && shopNameMm != null && shopNameMm!.isNotEmpty)
          ? shopNameMm!
          : shopName;

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
  void reloadProducts() {
    productList = products.list();
    notifyListeners();
  }

  // ---- cart ----
  int get cartTotal => cart.fold(0, (s, i) => s + i.lineTotal);
  int get cartCount => cart.length;

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
