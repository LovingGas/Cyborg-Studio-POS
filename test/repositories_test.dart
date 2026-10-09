// Repository tests against an in-memory SQLite database (no platform
// channels; the host's versioned libsqlite3 soname is loaded explicitly
// because the package default looks for the dev symlink `libsqlite3.so`).
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cyborg_studio_pos/db/app_database.dart';
import 'package:cyborg_studio_pos/models/models.dart';
import 'package:cyborg_studio_pos/repositories/repositories.dart';
import 'package:sqlite3/open.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  late AppDatabase holder;
  late ProductRepository products;
  late SaleRepository sales;
  late CustomerRepository customers;
  late PurchaseRepository purchases;
  const identity = Identity('shop-test', 'device-test');

  setUp(() {
    holder = AppDatabase.inMemory();
    products = ProductRepository(holder, identity);
    sales = SaleRepository(holder, identity);
    customers = CustomerRepository(holder, identity);
    purchases = PurchaseRepository(holder, identity);
  });

  tearDown(() => holder.db.dispose());

  Product seedProduct({double stock = 10, int cost = 1000, int sell = 1500}) {
    final p = Product(
      id: newId(),
      categoryCode: 'grocery',
      nameEn: 'Test Item',
      costPrice: cost,
      sellPrice: sell,
      stockQty: stock,
    );
    products.save(p);
    return p;
  }

  test('credit balance = credit sales - repayments (pure helper)', () {
    expect(
      creditBalance(creditSalesTotal: 7000, repaymentsTotal: 2500),
      4500,
    );
    expect(creditBalance(creditSalesTotal: 0, repaymentsTotal: 0), 0);
  });

  test('credit balance from records: sale, repayment, then void', () {
    final p = seedProduct();
    final c = customers.save(Customer(id: newId(), name: 'Aung Aung'));

    sales.completeSale(
      items: [CartItem(p, 2)],
      paymentMethod: 'credit',
      customerId: c.id,
    );
    var list = customers.listWithBalances();
    expect(list.single.balanceDue, 3000); // 2 x 1,500

    customers.recordRepayment(customerId: c.id, amount: 1000, method: 'cash');
    list = customers.listWithBalances();
    expect(list.single.balanceDue, 2000);

    // Voiding the credit sale removes its amount from the balance.
    final saleId = sales.listSales().single.id;
    sales.voidSale(saleId, 'entered by mistake');
    list = customers.listWithBalances();
    expect(list.single.balanceDue, -1000); // repayment stands, sale is gone
  });

  test('manual credit charge raises balance, repayment lowers it', () {
    final c = customers.save(Customer(id: newId(), name: 'Ma Lay'));

    customers.recordCharge(customerId: c.id, amount: 5000, note: 'goods on credit');
    var list = customers.listWithBalances();
    expect(list.single.balanceDue, 5000);

    customers.recordRepayment(customerId: c.id, amount: 2000, method: 'cash');
    list = customers.listWithBalances();
    expect(list.single.balanceDue, 3000);

    expect(
      creditBalance(creditSalesTotal: 1000, chargesTotal: 5000, repaymentsTotal: 2000),
      4000,
    );
  });

  test('purchase increments stock and updates cost price', () {
    final p = seedProduct(stock: 5, cost: 1000);
    final supplier = purchases.addSupplier(name: 'Yangon Wholesale');

    final record = purchases.recordPurchase(
      supplierId: supplier.id,
      lines: [PurchaseLine(productId: p.id, qty: 10, unitCost: 1200)],
    );
    expect(record.total, 12000);

    final after = products.list().single;
    expect(after.stockQty, 15);
    expect(after.costPrice, 1200);

    final history = purchases.listPurchases();
    expect(history.length, 1);
    expect(history.single.supplierName, 'Yangon Wholesale');
    expect(history.single.itemCount, 1);
    expect(history.single.total, 12000);
  });

  test('void sale restores stock and writes the audit ledger', () {
    final p = seedProduct(stock: 10);
    final done = sales.completeSale(
      items: [CartItem(p, 3)],
      paymentMethod: 'cash',
      amountPaid: 4500,
    );
    expect(products.list().single.stockQty, 7);

    sales.voidSale(done.id, 'customer changed mind');
    expect(products.list().single.stockQty, 10);
    expect(sales.saleById(done.id)!.isVoid, isTrue);

    final adj = holder.db.select(
      "SELECT * FROM stock_adjustments WHERE reason = 'void_sale'",
    );
    expect(adj.length, 1);
    expect((adj.first['qty_delta'] as num).toDouble(), 3);
    expect(adj.first['note'], contains('customer changed mind'));

    // Second void is a no-op (stock must not be restored twice).
    sales.voidSale(done.id, 'again');
    expect(products.list().single.stockQty, 10);
  });

  test('dashboard aggregates ignore voided sales', () {
    final p = seedProduct();
    final keep = sales.completeSale(
      items: [CartItem(p, 3)],
      paymentMethod: 'cash',
      amountPaid: 4500,
    );
    final drop = sales.completeSale(
      items: [CartItem(p, 1)],
      paymentMethod: 'kbz_pay',
    );
    sales.voidSale(drop.id, 'test');

    final today = sales.todaySummary();
    expect(today.count, 1);
    expect(today.total, keep.total);
    final breakdown = sales.paymentBreakdown(
      fromMs: 0,
      toMs: DateTime.now().millisecondsSinceEpoch + 86400000,
    );
    expect(breakdown.length, 1);
    expect(breakdown.single.method, 'cash');
    expect(breakdown.single.count, 1); // one transaction…
    expect(breakdown.single.items, 3); // …of three pieces
  });
}
