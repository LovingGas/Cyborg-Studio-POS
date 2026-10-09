import '../models/models.dart';
import '../repositories/repositories.dart';
import 'constants.dart';

/// One-tap starter catalog for the Grocery pilot, so a fresh install can be
/// test-sold immediately (mirrors the prototype's "Load sample catalog").
/// Prices are plausible Myanmar retail Ks; stock is opening quantity.
List<Product> grocerySampleProducts() {
  Product p(
    String sku,
    String nameEn,
    String nameMm,
    String unit,
    int cost,
    int sell,
    double stock,
  ) =>
      Product(
        id: newId(),
        categoryCode: pilotCategoryCode,
        sku: sku,
        nameEn: nameEn,
        nameMm: nameMm,
        unit: unit,
        costPrice: cost,
        sellPrice: sell,
        stockQty: stock,
        lowStockThreshold: 5,
      );

  return [
    p('GRC-001', 'Rice 5kg', 'ဆန် 5kg', 'bag', 18000, 22000, 50),
    p('GRC-002', 'Cooking Oil 1L', 'ဟင်းချက်ဆီ 1 လီတာ', 'bottle', 8500, 10000, 60),
    p('GRC-003', 'Sugar 1kg', 'သကြား 1kg', 'pack', 3200, 3800, 80),
    p('GRC-004', 'Salt 500g', 'ဆား 500g', 'pack', 800, 1000, 100),
    p('GRC-005', 'Instant Noodles', 'ခေါက်ဆွဲခြောက်', 'pack', 700, 900, 200),
    p('GRC-006', 'Coffee Mix 3-in-1', 'ကော်ဖီမှုန့် 3-in-1', 'pack', 6500, 7500, 40),
    p('GRC-007', 'Tea Leaves', 'လက်ဖက်ခြောက်', 'pack', 4000, 5000, 40),
    p('GRC-008', 'Eggs (10 pcs)', 'ကြက်ဥ (၁၀ လုံး)', 'pack', 4500, 5500, 60),
    p('GRC-009', 'Milk Powder', 'နို့မှုန့်', 'box', 12000, 14500, 30),
    p('GRC-010', 'Soft Drink', 'အချိုရည်', 'can', 1200, 1500, 120),
  ];
}
