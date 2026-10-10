import 'package:sqlite3/sqlite3.dart';

import '../core/constants.dart';

class Product {
  final String id;
  final String categoryCode;
  final String nameEn;
  final String? nameMm;
  final String? sku;
  final String? barcode;
  final String unit;
  final int costPrice;
  final int sellPrice;
  final double stockQty;
  final double lowStockThreshold;
  final int? expiryDate; // ms since epoch
  final bool isFavorite;
  final bool isActive;

  const Product({
    required this.id,
    required this.categoryCode,
    required this.nameEn,
    this.nameMm,
    this.sku,
    this.barcode,
    this.unit = 'pcs',
    this.costPrice = 0,
    this.sellPrice = 0,
    this.stockQty = 0,
    this.lowStockThreshold = 0,
    this.expiryDate,
    this.isFavorite = false,
    this.isActive = true,
  });

  String displayName(String lang) =>
      (lang == 'mm' && nameMm != null && nameMm!.isNotEmpty) ? nameMm! : nameEn;

  bool get isLowStock => stockQty > 0 && stockQty <= lowStockThreshold;
  bool get isOutOfStock => stockQty <= 0;

  factory Product.fromRow(Row r) => Product(
        id: r['id'] as String,
        categoryCode: r['category_code'] as String,
        nameEn: r['name_en'] as String,
        nameMm: r['name_mm'] as String?,
        sku: r['sku'] as String?,
        barcode: r['barcode'] as String?,
        unit: (r['unit'] as String?) ?? 'pcs',
        costPrice: (r['cost_price'] as num?)?.toInt() ?? 0,
        sellPrice: (r['sell_price'] as num?)?.toInt() ?? 0,
        stockQty: (r['stock_qty'] as num?)?.toDouble() ?? 0,
        lowStockThreshold: (r['low_stock_threshold'] as num?)?.toDouble() ?? 0,
        expiryDate: (r['expiry_date'] as num?)?.toInt(),
        isFavorite: ((r['is_favorite'] as num?) ?? 0) != 0,
        isActive: ((r['is_active'] as num?) ?? 1) != 0,
      );

  Product copyWith({double? stockQty}) => Product(
        id: id,
        categoryCode: categoryCode,
        nameEn: nameEn,
        nameMm: nameMm,
        sku: sku,
        barcode: barcode,
        unit: unit,
        costPrice: costPrice,
        sellPrice: sellPrice,
        stockQty: stockQty ?? this.stockQty,
        lowStockThreshold: lowStockThreshold,
        expiryDate: expiryDate,
        isFavorite: isFavorite,
        isActive: isActive,
      );
}

class CartItem {
  final Product product;
  double qty;
  CartItem(this.product, this.qty);
  int get lineTotal => (product.sellPrice * qty).round();
}

class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? address;

  /// Outstanding credit balance. Rows read through
  /// [CustomerRepository.listWithBalances] carry the computed value
  /// (Credit sales − repayments); other rows carry the stored column.
  final int balanceDue;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.balanceDue = 0,
  });

  factory Customer.fromRow(Row r) => Customer(
        id: r['id'] as String,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        address: r['address'] as String?,
        balanceDue: ((r['computed_balance'] ?? r['balance_due']) as num?)
                ?.toInt() ??
            0,
      );

  Customer copyWith({int? balanceDue}) => Customer(
        id: id,
        name: name,
        phone: phone,
        address: address,
        balanceDue: balanceDue ?? this.balanceDue,
      );
}

/// One row of the Sales History list (a row of `sales` + its item count).
class SaleRecord {
  final String id;
  final String? receiptNo;
  final String? customerId;
  final int total;
  final int costTotal;
  final String paymentMethod;
  final String? paymentBank;
  final int amountPaid;
  final int changeDue;
  final String status; // 'completed' | 'void'
  final int createdAt; // ms since epoch

  /// Total quantity sold across all lines (SUM of qty), not the number of
  /// distinct lines — "3 items" for 3 × the same product.
  final double itemCount;

  const SaleRecord({
    required this.id,
    this.receiptNo,
    this.customerId,
    required this.total,
    required this.costTotal,
    required this.paymentMethod,
    this.paymentBank,
    this.amountPaid = 0,
    this.changeDue = 0,
    this.status = 'completed',
    required this.createdAt,
    this.itemCount = 0,
  });

  bool get isVoid => status == 'void';
  int get profit => total - costTotal;

  /// "Cash", or "Bank Transfer (KBZ Bank)" for bank transfers.
  String get paymentLabel {
    final base = paymentMethodLabel(paymentMethod);
    if (paymentMethod == 'bank_transfer' &&
        paymentBank != null &&
        paymentBank!.isNotEmpty) {
      return '$base ($paymentBank)';
    }
    return base;
  }

  factory SaleRecord.fromRow(Row r) => SaleRecord(
        id: r['id'] as String,
        receiptNo: r['receipt_no'] as String?,
        customerId: r['customer_id'] as String?,
        total: (r['total'] as num?)?.toInt() ?? 0,
        costTotal: (r['cost_total'] as num?)?.toInt() ?? 0,
        paymentMethod: (r['payment_method'] as String?) ?? 'cash',
        paymentBank: r['payment_bank'] as String?,
        amountPaid: (r['amount_paid'] as num?)?.toInt() ?? 0,
        changeDue: (r['change_due'] as num?)?.toInt() ?? 0,
        status: (r['status'] as String?) ?? 'completed',
        createdAt: (r['created_at'] as num?)?.toInt() ?? 0,
        itemCount: (r['item_count'] as num?)?.toDouble() ?? 0,
      );
}

/// One line of a recorded sale (`sale_items`).
class SaleItemRecord {
  final String id;
  final String? productId;
  final String name;
  final double qty;
  final int unitPrice;
  final int costPrice;

  const SaleItemRecord({
    this.id = '',
    this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.costPrice = 0,
  });

  int get amount => (qty * unitPrice).round();

  factory SaleItemRecord.fromRow(Row r) => SaleItemRecord(
        id: (r['id'] as String?) ?? '',
        productId: r['product_id'] as String?,
        name: (r['product_name_snapshot'] as String?) ?? '',
        qty: (r['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (r['unit_price'] as num?)?.toInt() ?? 0,
        costPrice: (r['cost_price_snapshot'] as num?)?.toInt() ?? 0,
      );
}

class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  const Supplier({required this.id, required this.name, this.phone, this.address});

  factory Supplier.fromRow(Row r) => Supplier(
        id: r['id'] as String,
        name: r['name'] as String,
        phone: r['phone'] as String?,
        address: r['address'] as String?,
      );
}

/// One input line of a stock-in (purchase) entry.
class PurchaseLine {
  final String productId;
  final double qty;
  final int unitCost;
  const PurchaseLine({
    required this.productId,
    required this.qty,
    required this.unitCost,
  });
  int get lineTotal => (qty * unitCost).round();
}

/// One row of the purchases list (`purchases` + supplier name + item count).
class PurchaseRecord {
  final String id;
  final String? supplierId;
  final String? supplierName;
  final int total;
  final int createdAt;
  final int itemCount;

  const PurchaseRecord({
    required this.id,
    this.supplierId,
    this.supplierName,
    required this.total,
    required this.createdAt,
    this.itemCount = 0,
  });

  factory PurchaseRecord.fromRow(Row r) => PurchaseRecord(
        id: r['id'] as String,
        supplierId: r['supplier_id'] as String?,
        supplierName: r['supplier_name'] as String?,
        total: (r['total'] as num?)?.toInt() ?? 0,
        createdAt: (r['created_at'] as num?)?.toInt() ?? 0,
        itemCount: (r['item_count'] as num?)?.toInt() ?? 0,
      );
}

/// Display label for a payment-method code (Foundation §4). Unknown/legacy
/// codes are shown as stored so old records keep their labels.
String paymentMethodLabel(String code) {
  for (final m in kPaymentMethods) {
    if (m.code == code) return m.label;
  }
  return code;
}

class CompletedSale {
  final String id;
  final String receiptNo;
  final int total;
  final int changeDue;
  const CompletedSale({
    required this.id,
    required this.receiptNo,
    required this.total,
    required this.changeDue,
  });
}
