import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/models.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Device/shop identity for the standard columns (§1.1). Generated once on
/// first run and persisted in settings_kv / devices.
class Identity {
  final String shopId;
  final String deviceId;
  const Identity(this.shopId, this.deviceId);
}

class SettingsRepository {
  final AppDatabase _holder;
  SettingsRepository(this._holder);
  Database get _db => _holder.db;

  String? get(String shopId, String key) {
    final rows = _db.select(
      'SELECT value FROM settings_kv WHERE shop_id = ? AND key = ?',
      [shopId, key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void set(String shopId, String key, String value) {
    _db.execute(
      'INSERT INTO settings_kv (shop_id, key, value) VALUES (?, ?, ?) '
      'ON CONFLICT (shop_id, key) DO UPDATE SET value = excluded.value',
      [shopId, key, value],
    );
  }

  Future<Identity> ensureIdentity() async {
    var shopId = get('local', 'shop_id');
    var deviceId = get('local', 'device_id');
    if (shopId == null) {
      shopId = newId();
      set('local', 'shop_id', shopId);
    }
    if (deviceId == null) {
      deviceId = newId();
      set('local', 'device_id', deviceId);
      final t = nowMs();
      _db.execute(
        'INSERT OR IGNORE INTO devices (device_id, platform, activated_at) VALUES (?, ?, ?)',
        [deviceId, 'android', t],
      );
    }
    // Seed the shops profile row from settings_kv values if missing.
    final existing = _db.select('SELECT id FROM shops WHERE id = ?', [shopId]);
    if (existing.isEmpty) {
      final t = nowMs();
      _db.execute(
        'INSERT INTO shops (id, name, name_mm, phone, address, shop_id, device_id, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          shopId,
          get(shopId, 'shop_name') ?? 'My Shop',
          get(shopId, 'shop_name_mm'),
          get(shopId, 'shop_phone'),
          get(shopId, 'shop_address'),
          shopId,
          deviceId,
          t,
          t,
        ],
      );
    }
    return Identity(shopId, deviceId);
  }
}

class ProductRepository {
  final AppDatabase _holder;
  final Identity identity;
  ProductRepository(this._holder, this.identity);
  Database get _db => _holder.db;

  List<Product> list({String? categoryCode, String query = '', bool includeInactive = true}) {
    final where = <String>['deleted_at IS NULL'];
    final args = <Object?>[];
    if (!includeInactive) where.add('is_active = 1');
    if (categoryCode != null) {
      where.add('category_code = ?');
      args.add(categoryCode);
    }
    if (query.trim().isNotEmpty) {
      where.add('(name_en LIKE ? OR name_mm LIKE ? OR sku LIKE ? OR barcode LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q, q]);
    }
    final rows = _db.select(
      'SELECT * FROM products WHERE ${where.join(' AND ')} '
      'ORDER BY is_favorite DESC, name_en COLLATE NOCASE',
      args,
    );
    return rows.map(Product.fromRow).toList();
  }

  Product save(Product p) {
    final t = nowMs();
    final existing = _db.select('SELECT id FROM products WHERE id = ?', [p.id]);
    if (existing.isEmpty) {
      _db.execute(
        'INSERT INTO products (id, category_code, name_en, name_mm, sku, barcode, unit, '
        'cost_price, sell_price, stock_qty, low_stock_threshold, expiry_date, is_favorite, '
        'is_active, shop_id, device_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          p.id, p.categoryCode, p.nameEn, p.nameMm, p.sku, p.barcode, p.unit,
          p.costPrice, p.sellPrice, p.stockQty, p.lowStockThreshold, p.expiryDate,
          p.isFavorite ? 1 : 0, p.isActive ? 1 : 0, identity.shopId, identity.deviceId, t, t,
        ],
      );
    } else {
      _db.execute(
        'UPDATE products SET category_code = ?, name_en = ?, name_mm = ?, sku = ?, '
        'barcode = ?, unit = ?, cost_price = ?, sell_price = ?, stock_qty = ?, '
        'low_stock_threshold = ?, expiry_date = ?, is_favorite = ?, is_active = ?, '
        'updated_at = ?, sync_status = \'pending\' WHERE id = ?',
        [
          p.categoryCode, p.nameEn, p.nameMm, p.sku, p.barcode, p.unit, p.costPrice,
          p.sellPrice, p.stockQty, p.lowStockThreshold, p.expiryDate,
          p.isFavorite ? 1 : 0, p.isActive ? 1 : 0, t, p.id,
        ],
      );
    }
    return p;
  }

  /// Adjusts stock and records the movement in stock_adjustments (ledger —
  /// Foundation §6.3: stock truth comes from records, never bare edits).
  void adjustStock(Product p, double delta, String reason) {
    final t = nowMs();
    _db.execute('BEGIN');
    try {
      _db.execute(
        'UPDATE products SET stock_qty = stock_qty + ?, updated_at = ?, '
        'sync_status = \'pending\' WHERE id = ?',
        [delta, t, p.id],
      );
      _db.execute(
        'INSERT INTO stock_adjustments (id, product_id, qty_delta, reason, shop_id, '
        'device_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [newId(), p.id, delta, reason, identity.shopId, identity.deviceId, t, t],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

class SaleRepository {
  final AppDatabase _holder;
  final Identity identity;
  SaleRepository(this._holder, this.identity);
  Database get _db => _holder.db;

  List<Customer> customers() {
    final rows = _db.select(
      'SELECT * FROM customers WHERE deleted_at IS NULL ORDER BY name COLLATE NOCASE',
    );
    return rows.map(Customer.fromRow).toList();
  }

  String _nextReceiptNo(int t) {
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final day =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final deviceShort =
        identity.deviceId.replaceAll('-', '').substring(0, 4).toUpperCase();
    final startOfDay = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final rows = _db.select(
      'SELECT COUNT(*) AS c FROM sales WHERE created_at >= ?',
      [startOfDay],
    );
    final seq = ((rows.first['c'] as num?)?.toInt() ?? 0) + 1;
    return '$deviceShort-$day-${seq.toString().padLeft(4, '0')}';
  }

  /// Writes the sale + items, decrements stock, and (for Credit) raises the
  /// customer's balance — all in one transaction.
  CompletedSale completeSale({
    required List<CartItem> items,
    required String paymentMethod,
    String? paymentBank,
    String? customerId,
    int amountPaid = 0,
  }) {
    final t = nowMs();
    final subtotal = items.fold<int>(0, (s, i) => s + i.lineTotal);
    final costTotal = items.fold<int>(
        0, (s, i) => s + (i.product.costPrice * i.qty).round());
    final total = subtotal;
    // A recorded sale is settled: non-Cash always counts as paid in full,
    // and Cash with no amount entered (0) means "exact" — never store 0.
    final paid = paymentMethod == 'cash' && amountPaid > 0 ? amountPaid : total;
    final change = paymentMethod == 'cash' && paid > total ? paid - total : 0;
    final saleId = newId();
    final receiptNo = _nextReceiptNo(t);
    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO sales (id, receipt_no, customer_id, subtotal, discount, tax, total, '
        'cost_total, payment_method, payment_bank, amount_paid, change_due, status, source, '
        'shop_id, device_id, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, \'completed\', \'pos\', ?, ?, ?, ?)',
        [
          saleId, receiptNo, customerId, subtotal, total, costTotal, paymentMethod,
          paymentBank, paid, change, identity.shopId, identity.deviceId, t, t,
        ],
      );
      for (final item in items) {
        _db.execute(
          'INSERT INTO sale_items (id, sale_id, product_id, product_name_snapshot, qty, '
          'unit_price, cost_price_snapshot, shop_id, device_id, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            newId(), saleId, item.product.id, item.product.nameEn, item.qty,
            item.product.sellPrice, item.product.costPrice, identity.shopId,
            identity.deviceId, t, t,
          ],
        );
        _db.execute(
          'UPDATE products SET stock_qty = stock_qty - ?, updated_at = ?, '
          'sync_status = \'pending\' WHERE id = ?',
          [item.qty, t, item.product.id],
        );
      }
      if (paymentMethod == 'credit' && customerId != null) {
        _db.execute(
          'UPDATE customers SET balance_due = balance_due + ?, updated_at = ? WHERE id = ?',
          [total, t, customerId],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return CompletedSale(id: saleId, receiptNo: receiptNo, total: total, changeDue: change);
  }

  // ---- Sales history / receipt / void ----

  /// Newest first, voided sales included (shown struck-through in the UI).
  List<SaleRecord> listSales({int limit = 200}) {
    final rows = _db.select(
      'SELECT s.*, (SELECT COALESCE(SUM(si.qty), 0) FROM sale_items si WHERE si.sale_id = s.id) '
      'AS item_count FROM sales s WHERE s.deleted_at IS NULL '
      'ORDER BY s.created_at DESC LIMIT ?',
      [limit],
    );
    return rows.map(SaleRecord.fromRow).toList();
  }

  SaleRecord? saleById(String saleId) {
    final rows = _db.select(
      'SELECT s.*, (SELECT COALESCE(SUM(si.qty), 0) FROM sale_items si WHERE si.sale_id = s.id) '
      'AS item_count FROM sales s WHERE s.id = ?',
      [saleId],
    );
    return rows.isEmpty ? null : SaleRecord.fromRow(rows.first);
  }

  List<SaleItemRecord> saleItems(String saleId) {
    final rows = _db.select(
      'SELECT * FROM sale_items WHERE sale_id = ? AND deleted_at IS NULL '
      'ORDER BY created_at, product_name_snapshot',
      [saleId],
    );
    return rows.map(SaleItemRecord.fromRow).toList();
  }

  /// Voids a sale: status → 'void', every item's stock is restored and the
  /// restoration is written to the stock_adjustments ledger (reason
  /// 'void_sale', note carries the receipt no. + the cashier's reason), and
  /// a Credit sale's amount comes back off the customer's stored balance.
  /// No-op when the sale is already void.
  void voidSale(String saleId, String reason) {
    final sale = saleById(saleId);
    if (sale == null || sale.isVoid) return;
    final items = saleItems(saleId);
    final t = nowMs();
    _db.execute('BEGIN');
    try {
      _db.execute(
        "UPDATE sales SET status = 'void', updated_at = ?, sync_status = 'pending' "
        'WHERE id = ?',
        [t, saleId],
      );
      for (final item in items) {
        if (item.productId == null) continue;
        _db.execute(
          'UPDATE products SET stock_qty = stock_qty + ?, updated_at = ?, '
          "sync_status = 'pending' WHERE id = ?",
          [item.qty, t, item.productId],
        );
        _db.execute(
          'INSERT INTO stock_adjustments (id, product_id, qty_delta, reason, note, '
          'shop_id, device_id, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            newId(), item.productId, item.qty, 'void_sale',
            'Void ${sale.receiptNo ?? saleId}: $reason',
            identity.shopId, identity.deviceId, t, t,
          ],
        );
      }
      if (sale.paymentMethod == 'credit' && sale.customerId != null) {
        _db.execute(
          'UPDATE customers SET balance_due = balance_due - ?, updated_at = ? '
          'WHERE id = ?',
          [sale.total, t, sale.customerId],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ---- Dashboard aggregates (completed sales only) ----

  static int _startOfDayMs(DateTime d) =>
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  ({int count, int total, int costTotal}) salesSummary({
    required int fromMs,
    required int toMs,
  }) {
    final rows = _db.select(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS t, '
      'COALESCE(SUM(cost_total), 0) AS ct FROM sales '
      "WHERE status = 'completed' AND deleted_at IS NULL "
      'AND created_at >= ? AND created_at < ?',
      [fromMs, toMs],
    );
    final r = rows.first;
    return (
      count: (r['c'] as num).toInt(),
      total: (r['t'] as num).toInt(),
      costTotal: (r['ct'] as num).toInt(),
    );
  }

  ({int count, int total, int costTotal}) todaySummary() {
    final now = DateTime.now();
    final start = _startOfDayMs(now);
    return salesSummary(fromMs: start, toMs: start + 86400000);
  }

  /// (method code, sale count, total, item quantity) for completed sales
  /// in the window. Item quantities come from a separate grouped query so
  /// the join cannot inflate the money totals.
  List<({String method, int count, int total, double items})> paymentBreakdown({
    required int fromMs,
    required int toMs,
  }) {
    final rows = _db.select(
      'SELECT payment_method AS m, COUNT(*) AS c, COALESCE(SUM(total), 0) AS t '
      'FROM sales WHERE status = \'completed\' AND deleted_at IS NULL '
      'AND created_at >= ? AND created_at < ? '
      'GROUP BY payment_method ORDER BY t DESC',
      [fromMs, toMs],
    );
    final itemRows = _db.select(
      'SELECT s.payment_method AS m, COALESCE(SUM(si.qty), 0) AS iq '
      'FROM sales s JOIN sale_items si ON si.sale_id = s.id '
      'WHERE s.status = \'completed\' AND s.deleted_at IS NULL '
      'AND si.deleted_at IS NULL '
      'AND s.created_at >= ? AND s.created_at < ? '
      'GROUP BY s.payment_method',
      [fromMs, toMs],
    );
    final itemsByMethod = <String, double>{
      for (final r in itemRows)
        r['m'] as String: (r['iq'] as num).toDouble(),
    };
    return rows
        .map((r) => (
              method: r['m'] as String,
              count: (r['c'] as num).toInt(),
              total: (r['t'] as num).toInt(),
              items: itemsByMethod[r['m'] as String] ?? 0,
            ))
        .toList();
  }

  /// Total completed sales per day for the last [days] days, oldest first
  /// (today last). Days with no sales come back as 0.
  List<({DateTime day, int total})> dailyTotals({int days = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final out = <({DateTime day, int total})>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final s = salesSummary(
        fromMs: day.millisecondsSinceEpoch,
        toMs: day.millisecondsSinceEpoch + 86400000,
      );
      out.add((day: day, total: s.total));
    }
    return out;
  }
}

/// The single definition of an outstanding credit balance:
/// completed Credit-sale totals plus manual credit charges, minus
/// recorded repayments.
int creditBalance({
  required int creditSalesTotal,
  int chargesTotal = 0,
  required int repaymentsTotal,
}) =>
    creditSalesTotal + chargesTotal - repaymentsTotal;

class CustomerRepository {
  final AppDatabase _holder;
  final Identity identity;
  CustomerRepository(this._holder, this.identity);
  Database get _db => _holder.db;

  /// Customers with their outstanding balance computed from the records
  /// (Credit sales − credit_repayments), not the stored column.
  List<Customer> listWithBalances() {
    final rows = _db.select(
      'SELECT c.*, '
      '(SELECT COALESCE(SUM(s.total), 0) FROM sales s WHERE s.customer_id = c.id '
      "AND s.payment_method = 'credit' AND s.status = 'completed' "
      'AND s.deleted_at IS NULL) + '
      '(SELECT COALESCE(SUM(ch.amount), 0) FROM credit_charges ch '
      'WHERE ch.customer_id = c.id AND ch.deleted_at IS NULL) - '
      '(SELECT COALESCE(SUM(r.amount), 0) FROM credit_repayments r '
      'WHERE r.customer_id = c.id AND r.deleted_at IS NULL) AS computed_balance '
      'FROM customers c WHERE c.deleted_at IS NULL ORDER BY c.name COLLATE NOCASE',
    );
    return rows.map(Customer.fromRow).toList();
  }

  Customer save(Customer c) {
    final t = nowMs();
    final existing = _db.select('SELECT id FROM customers WHERE id = ?', [c.id]);
    if (existing.isEmpty) {
      _db.execute(
        'INSERT INTO customers (id, name, phone, address, shop_id, device_id, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [c.id, c.name, c.phone, c.address, identity.shopId, identity.deviceId, t, t],
      );
    } else {
      _db.execute(
        'UPDATE customers SET name = ?, phone = ?, address = ?, updated_at = ?, '
        "sync_status = 'pending' WHERE id = ?",
        [c.name, c.phone, c.address, t, c.id],
      );
    }
    return c;
  }

  /// Records a repayment against the customer's Credit balance and keeps
  /// the stored `balance_due` column in step with the computed balance.
  void recordRepayment({
    required String customerId,
    required int amount,
    String? method,
    String? note,
  }) {
    final t = nowMs();
    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO credit_repayments (id, customer_id, amount, method, note, '
        'shop_id, device_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [newId(), customerId, amount, method, note, identity.shopId, identity.deviceId, t, t],
      );
      _db.execute(
        'UPDATE customers SET balance_due = balance_due - ?, updated_at = ? WHERE id = ?',
        [amount, t, customerId],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Records a manual credit charge (debt-book entry: goods taken now,
  /// pay later, typed in without a POS sale) and raises the stored
  /// `balance_due` column in step with the computed balance.
  void recordCharge({
    required String customerId,
    required int amount,
    String? note,
  }) {
    final t = nowMs();
    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO credit_charges (id, customer_id, amount, note, '
        'shop_id, device_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [newId(), customerId, amount, note, identity.shopId, identity.deviceId, t, t],
      );
      _db.execute(
        'UPDATE customers SET balance_due = balance_due + ?, updated_at = ? WHERE id = ?',
        [amount, t, customerId],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

class PurchaseRepository {
  final AppDatabase _holder;
  final Identity identity;
  PurchaseRepository(this._holder, this.identity);
  Database get _db => _holder.db;

  List<Supplier> suppliers() {
    final rows = _db.select(
      'SELECT * FROM suppliers WHERE deleted_at IS NULL ORDER BY name COLLATE NOCASE',
    );
    return rows.map(Supplier.fromRow).toList();
  }

  Supplier addSupplier({required String name, String? phone, String? address}) {
    final t = nowMs();
    final s = Supplier(id: newId(), name: name, phone: phone, address: address);
    _db.execute(
      'INSERT INTO suppliers (id, name, phone, address, shop_id, device_id, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [s.id, s.name, s.phone, s.address, identity.shopId, identity.deviceId, t, t],
    );
    return s;
  }

  List<PurchaseRecord> listPurchases({int limit = 200}) {
    final rows = _db.select(
      'SELECT p.*, sup.name AS supplier_name, '
      '(SELECT COUNT(*) FROM purchase_items pi WHERE pi.purchase_id = p.id) AS item_count '
      'FROM purchases p LEFT JOIN suppliers sup ON sup.id = p.supplier_id '
      'WHERE p.deleted_at IS NULL ORDER BY p.created_at DESC LIMIT ?',
      [limit],
    );
    return rows.map(PurchaseRecord.fromRow).toList();
  }

  /// Records a stock-in: purchase + lines, stock incremented, and each
  /// product's cost price updated to the purchase unit cost — one
  /// transaction, mirroring [SaleRepository.completeSale].
  PurchaseRecord recordPurchase({
    String? supplierId,
    required List<PurchaseLine> lines,
  }) {
    final t = nowMs();
    final total = lines.fold<int>(0, (s, l) => s + l.lineTotal);
    final purchaseId = newId();
    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO purchases (id, supplier_id, total, payment_status, shop_id, '
        'device_id, created_at, updated_at) '
        "VALUES (?, ?, ?, 'paid', ?, ?, ?, ?)",
        [purchaseId, supplierId, total, identity.shopId, identity.deviceId, t, t],
      );
      for (final line in lines) {
        _db.execute(
          'INSERT INTO purchase_items (id, purchase_id, product_id, qty, unit_cost, '
          'shop_id, device_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            newId(), purchaseId, line.productId, line.qty, line.unitCost,
            identity.shopId, identity.deviceId, t, t,
          ],
        );
        _db.execute(
          'UPDATE products SET stock_qty = stock_qty + ?, cost_price = ?, '
          "updated_at = ?, sync_status = 'pending' WHERE id = ?",
          [line.qty, line.unitCost, t, line.productId],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
    return PurchaseRecord(
      id: purchaseId,
      supplierId: supplierId,
      total: total,
      createdAt: t,
      itemCount: lines.length,
    );
  }
}
