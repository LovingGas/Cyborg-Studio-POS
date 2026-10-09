import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite access + schema for the final app (Foundation design §1).
///
/// Conventions (Foundation §0/§1.1): UUID text primary keys, money is
/// integer Ks, timestamps are integer milliseconds, quantity is REAL
/// (weight-based selling), nothing is hard-deleted (`deleted_at`
/// tombstone), every syncable table carries shop_id / branch_id /
/// device_id / created_at / updated_at / deleted_at / sync_status.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int schemaVersion = 2;

  /// In-memory database with the full schema — used by unit tests so the
  /// repository layer can be exercised without platform channels.
  factory AppDatabase.inMemory() {
    final holder = AppDatabase._(sqlite3.openInMemory());
    holder.db.execute('PRAGMA foreign_keys = ON');
    holder._createSchema();
    return holder;
  }

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'all_in_one_pos.db'));
    final db = sqlite3.open(file.path);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA foreign_keys = ON');
    final holder = AppDatabase._(db);
    holder._createSchema();
    return holder;
  }

  /// Standard columns added to every syncable table (§1.1).
  static const String _std = '''
    shop_id TEXT,
    branch_id TEXT,
    device_id TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    sync_status TEXT NOT NULL DEFAULT 'pending'
  ''';

  void _createSchema() {
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version >= schemaVersion) return;
    db.execute('BEGIN');
    try {
      for (final ddl in _schema) {
        db.execute(ddl);
      }
      db.execute('PRAGMA user_version = $schemaVersion');
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static const List<String> _schema = [
    // ---- Core profile / local-only (§1.2, §1.4) ----
    '''CREATE TABLE IF NOT EXISTS shops (
      id TEXT PRIMARY KEY, name TEXT, name_mm TEXT, phone TEXT, address TEXT,
      theme TEXT NOT NULL DEFAULT 'teal', logo_blob_key TEXT, banner_blob_key TEXT,
      active_category_code TEXT NOT NULL DEFAULT 'grocery', $_std)''',
    '''CREATE TABLE IF NOT EXISTS devices (
      device_id TEXT PRIMARY KEY, device_code TEXT, model TEXT, platform TEXT,
      app_version TEXT, activated_at INTEGER, last_sync_at INTEGER)''',
    '''CREATE TABLE IF NOT EXISTS local_users (
      id TEXT PRIMARY KEY, name TEXT, role TEXT NOT NULL DEFAULT 'cashier',
      pin_hash TEXT, is_active INTEGER NOT NULL DEFAULT 1, $_std)''',
    '''CREATE TABLE IF NOT EXISTS license_state (
      id INTEGER PRIMARY KEY CHECK (id = 1), token TEXT, key_type TEXT,
      entitled_categories TEXT, expires_at INTEGER, grace_until INTEGER,
      bound_device_code TEXT, status TEXT, updated_at INTEGER)''',
    '''CREATE TABLE IF NOT EXISTS settings_kv (
      shop_id TEXT, key TEXT, value TEXT, PRIMARY KEY (shop_id, key))''',

    // ---- Core POS tables (§1.2) ----
    '''CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY, category_code TEXT NOT NULL, name_en TEXT NOT NULL,
      name_mm TEXT, sku TEXT, barcode TEXT, unit TEXT NOT NULL DEFAULT 'pcs',
      cost_price INTEGER NOT NULL DEFAULT 0, sell_price INTEGER NOT NULL DEFAULT 0,
      stock_qty REAL NOT NULL DEFAULT 0, low_stock_threshold REAL NOT NULL DEFAULT 0,
      expiry_date INTEGER, is_favorite INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1, photo_blob_key TEXT,
      variant_options TEXT, serial_tracked INTEGER NOT NULL DEFAULT 0,
      pricing_mode TEXT NOT NULL DEFAULT 'fixed', making_charge INTEGER, $_std)''',
    '''CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
      balance_due INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS suppliers (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
      balance_due INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS sales (
      id TEXT PRIMARY KEY, receipt_no TEXT, customer_id TEXT, cashier_id TEXT,
      subtotal INTEGER NOT NULL DEFAULT 0, discount INTEGER NOT NULL DEFAULT 0,
      tax INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL DEFAULT 0,
      cost_total INTEGER NOT NULL DEFAULT 0, payment_method TEXT NOT NULL DEFAULT 'cash',
      payment_bank TEXT, amount_paid INTEGER NOT NULL DEFAULT 0,
      change_due INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'completed',
      source TEXT NOT NULL DEFAULT 'pos', source_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS sale_items (
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL, product_id TEXT,
      product_name_snapshot TEXT, qty REAL NOT NULL DEFAULT 0,
      unit_price INTEGER NOT NULL DEFAULT 0, cost_price_snapshot INTEGER NOT NULL DEFAULT 0,
      variant TEXT, serial_imei TEXT, weight REAL, gold_rate_snapshot INTEGER, $_std)''',
    '''CREATE TABLE IF NOT EXISTS purchases (
      id TEXT PRIMARY KEY, supplier_id TEXT, total INTEGER NOT NULL DEFAULT 0,
      payment_status TEXT NOT NULL DEFAULT 'paid', $_std)''',
    '''CREATE TABLE IF NOT EXISTS purchase_items (
      id TEXT PRIMARY KEY, purchase_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, unit_cost INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS stock_adjustments (
      id TEXT PRIMARY KEY, product_id TEXT NOT NULL, qty_delta REAL NOT NULL DEFAULT 0,
      reason TEXT NOT NULL DEFAULT 'count_fix', note TEXT, adjusted_by TEXT, $_std)''',
    // Schema v2: repayments against a customer's Credit balance. The
    // outstanding balance is computed as Credit-sale totals − repayments.
    '''CREATE TABLE IF NOT EXISTS credit_repayments (
      id TEXT PRIMARY KEY, customer_id TEXT NOT NULL,
      amount INTEGER NOT NULL DEFAULT 0, method TEXT, note TEXT, $_std)''',

    // ---- Module tables (§1.3) — created now, used as categories unlock ----
    '''CREATE TABLE IF NOT EXISTS ktv_rooms (
      id TEXT PRIMARY KEY, name TEXT, capacity INTEGER, hourly_rate INTEGER, $_std)''',
    '''CREATE TABLE IF NOT EXISTS ktv_sessions (
      id TEXT PRIMARY KEY, room_id TEXT, customer_name TEXT, hourly_rate INTEGER,
      status TEXT NOT NULL DEFAULT 'open', started_at INTEGER, ended_at INTEGER,
      sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS ktv_session_items (
      id TEXT PRIMARY KEY, session_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, unit_price INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS tea_tables (
      id TEXT PRIMARY KEY, name TEXT, seats INTEGER, $_std)''',
    '''CREATE TABLE IF NOT EXISTS tea_sessions (
      id TEXT PRIMARY KEY, table_id TEXT, status TEXT NOT NULL DEFAULT 'open',
      started_at INTEGER, ended_at INTEGER, sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS tea_session_items (
      id TEXT PRIMARY KEY, session_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, unit_price INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS rest_tables (
      id TEXT PRIMARY KEY, name TEXT, seats INTEGER, $_std)''',
    '''CREATE TABLE IF NOT EXISTS rest_sessions (
      id TEXT PRIMARY KEY, table_id TEXT, status TEXT NOT NULL DEFAULT 'open',
      started_at INTEGER, ended_at INTEGER, sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS rest_session_items (
      id TEXT PRIMARY KEY, session_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, unit_price INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS hotel_rooms (
      id TEXT PRIMARY KEY, name TEXT, room_type TEXT, price_per_night INTEGER, $_std)''',
    '''CREATE TABLE IF NOT EXISTS hotel_stays (
      id TEXT PRIMARY KEY, room_id TEXT, guest_name TEXT, guest_phone TEXT,
      planned_nights INTEGER, checkin_at INTEGER, checkout_at INTEGER,
      status TEXT NOT NULL DEFAULT 'checked_in', sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS hotel_stay_items (
      id TEXT PRIMARY KEY, stay_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, unit_price INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS online_orders (
      id TEXT PRIMARY KEY, customer_name TEXT, phone TEXT, address TEXT,
      channel TEXT, status TEXT NOT NULL DEFAULT 'new',
      delivery_fee INTEGER NOT NULL DEFAULT 0, payment_method TEXT, sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS online_order_items (
      id TEXT PRIMARY KEY, order_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, unit_price INTEGER NOT NULL DEFAULT 0, $_std)''',
    '''CREATE TABLE IF NOT EXISTS travel_bookings (
      id TEXT PRIMARY KEY, customer_name TEXT, phone TEXT, product_id TEXT,
      travel_date INTEGER, passengers INTEGER, total_price INTEGER,
      deposit_amount INTEGER, deposit_method TEXT, balance_due INTEGER,
      status TEXT NOT NULL DEFAULT 'confirmed', sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS repair_jobs (
      id TEXT PRIMARY KEY, customer_id TEXT, customer_name TEXT, phone TEXT,
      device_model TEXT, issue TEXT, status TEXT NOT NULL DEFAULT 'received',
      charge INTEGER, sale_id TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS refunds (
      id TEXT PRIMARY KEY, sale_id TEXT, online_order_id TEXT, reason TEXT,
      amount INTEGER NOT NULL DEFAULT 0, method TEXT,
      restock INTEGER NOT NULL DEFAULT 0, refunded_by TEXT, $_std)''',
    '''CREATE TABLE IF NOT EXISTS refund_items (
      id TEXT PRIMARY KEY, refund_id TEXT NOT NULL, product_id TEXT,
      qty REAL NOT NULL DEFAULT 0, $_std)''',

    // ---- Indexes for the hot paths ----
    'CREATE INDEX IF NOT EXISTS idx_products_category ON products (category_code, is_active)',
    'CREATE INDEX IF NOT EXISTS idx_sales_created ON sales (created_at)',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items (sale_id)',
  ];
}
