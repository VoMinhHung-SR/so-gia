import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/tables.dart';

class DemoSeedResult {
  const DemoSeedResult({
    required this.suppliers,
    required this.items,
    required this.purchases,
  });

  final int suppliers;
  final int items;
  final int purchases;
}

/// Seeds ~24 stall-like SKUs (≈2/3 barcode, ≈1/3 weighed) + 3 suppliers.
/// Safe to re-run: skips if any active item already exists.
class DemoSeedService {
  DemoSeedService(this._db);

  final AppDatabase _db;

  Future<DemoSeedResult?> seedIfEmpty() async {
    final existing = await _db.listActiveItems();
    if (existing.isNotEmpty) return null;
    return seed(force: true);
  }

  Future<DemoSeedResult> seed({bool force = false}) async {
    if (!force) {
      final existing = await _db.listActiveItems();
      if (existing.isNotEmpty) {
        return DemoSeedResult(
          suppliers: 0,
          items: 0,
          purchases: 0,
        );
      }
    }

    final now = DateTime.now().toUtc();
    DateTime day(int d) => now.subtract(Duration(days: d));

    final s1 = newId();
    final s2 = newId();
    final s3 = newId();

    Future<void> supplier(String id, String name, String phone) {
      return _db.upsertSupplier(
        SuppliersCompanion.insert(
          id: id,
          name: name,
          phone: Value(phone),
          createdAt: now,
          updatedAt: now,
          note: const Value('Demo P4'),
        ),
      );
    }

    await supplier(s1, 'Anh Tư (chợ đầu mối)', '0901000001');
    await supplier(s2, 'Cô Lan tạp hóa sỉ', '0901000002');
    await supplier(s3, 'Xe nước ngọt Minh', '0901000003');

    var purchaseCount = 0;

    Future<String> item({
      required String name,
      String? barcode,
      String? brand,
      double? unitSize,
      required UnitType unitType,
      String? category,
      bool weighed = false,
    }) async {
      final id = newId();
      await _db.upsertItem(
        ItemsCompanion.insert(
          id: id,
          name: name,
          unitType: unitType,
          source: ItemSource.manual,
          createdAt: now,
          updatedAt: now,
          barcode: Value(barcode),
          brand: Value(brand),
          unitSize: Value(unitSize),
          category: Value(category),
          isWeighed: Value(weighed),
        ),
      );
      return id;
    }

    Future<void> buy(
      String itemId,
      String? supplierId,
      int price,
      int daysAgo, {
      double qty = 1,
    }) async {
      await _db.insertPurchase(
        PurchasesCompanion.insert(
          id: newId(),
          itemId: itemId,
          supplierId: Value(supplierId),
          costPrice: price,
          qty: Value(qty),
          date: day(daysAgo),
          createdAt: now,
          updatedAt: now,
        ),
      );
      purchaseCount++;
    }

    // --- Barcode / packaged (~16) ---
    final coca = await item(
      name: 'Coca-Cola',
      barcode: '8934588234011',
      brand: 'Coca-Cola',
      unitSize: 330,
      unitType: UnitType.ml,
      category: 'nước giải khát',
    );
    await buy(coca, s3, 7200, 20);
    await buy(coca, s3, 7000, 7);
    await buy(coca, s2, 6900, 1);

    final pepsi = await item(
      name: 'Pepsi',
      barcode: '8934588020014',
      brand: 'Pepsi',
      unitSize: 330,
      unitType: UnitType.ml,
      category: 'nước giải khát',
    );
    await buy(pepsi, s3, 6800, 10);
    await buy(pepsi, s3, 7000, 2);

    final sting = await item(
      name: 'Sting dâu',
      barcode: '8934588062341',
      brand: 'Sting',
      unitSize: 330,
      unitType: UnitType.ml,
      category: 'nước giải khát',
    );
    await buy(sting, s3, 6500, 5);

    final aquafina = await item(
      name: 'Aquafina',
      barcode: '8934588011001',
      brand: 'Aquafina',
      unitSize: 500,
      unitType: UnitType.ml,
      category: 'nước',
    );
    await buy(aquafina, s2, 4000, 14);
    await buy(aquafina, s3, 3800, 3);

    final milo = await item(
      name: 'Milo hộp',
      barcode: '8934673120015',
      brand: 'Nestlé',
      unitSize: 180,
      unitType: UnitType.ml,
      category: 'sữa',
    );
    await buy(milo, s2, 8500, 6);

    final vinamilk = await item(
      name: 'Sữa tươi Vinamilk',
      barcode: '8934673012345',
      brand: 'Vinamilk',
      unitSize: 180,
      unitType: UnitType.ml,
      category: 'sữa',
    );
    await buy(vinamilk, s2, 7800, 4);

    final omachi = await item(
      name: 'Mì Omachi tôm chua cay',
      barcode: '8934563120008',
      brand: 'Omachi',
      unitSize: 80,
      unitType: UnitType.g,
      category: 'mì',
    );
    await buy(omachi, s2, 5500, 9);
    await buy(omachi, s1, 5200, 2);

    final haohao = await item(
      name: 'Mì Hảo Hảo',
      barcode: '8934563010001',
      brand: 'Acecook',
      unitSize: 75,
      unitType: UnitType.g,
      category: 'mì',
    );
    await buy(haohao, s2, 3500, 8);

    final knorr = await item(
      name: 'Hạt nêm Knorr',
      barcode: '8934804011002',
      brand: 'Knorr',
      unitSize: 400,
      unitType: UnitType.g,
      category: 'gia vị',
    );
    await buy(knorr, s2, 28000, 12);
    await buy(knorr, s1, 26500, 3);

    final namngu = await item(
      name: 'Nước mắm Nam Ngư',
      barcode: '8934804022003',
      brand: 'Nam Ngư',
      unitSize: 500,
      unitType: UnitType.ml,
      category: 'gia vị',
    );
    await buy(namngu, s2, 22000, 11);

    final tuongot = await item(
      name: 'Tương ớt Cholimex',
      barcode: '8936036021004',
      brand: 'Cholimex',
      unitSize: 270,
      unitType: UnitType.g,
      category: 'gia vị',
    );
    await buy(tuongot, s2, 12000, 7);

    final oreo = await item(
      name: 'Bánh Oreo',
      barcode: '8936012345001',
      brand: 'Oreo',
      unitSize: 133,
      unitType: UnitType.g,
      category: 'bánh kẹo',
    );
    await buy(oreo, s2, 15000, 5);

    final chupachups = await item(
      name: 'Kẹo Chupa Chups',
      barcode: '8936012987002',
      brand: 'Chupa Chups',
      unitSize: 1,
      unitType: UnitType.piece,
      category: 'bánh kẹo',
    );
    await buy(chupachups, s2, 3000, 4);

    final sunsilk = await item(
      name: 'Dầu gội Sunsilk',
      barcode: '8934868011005',
      brand: 'Sunsilk',
      unitSize: 650,
      unitType: UnitType.ml,
      category: 'hóa mỹ phẩm',
    );
    await buy(sunsilk, s2, 65000, 15);

    final omo = await item(
      name: 'Bột giặt OMO',
      barcode: '8934868022006',
      brand: 'OMO',
      unitSize: 720,
      unitType: UnitType.g,
      category: 'hóa mỹ phẩm',
    );
    await buy(omo, s2, 48000, 10);

    final lavie = await item(
      name: 'Lavie',
      barcode: '8934588099001',
      brand: 'Lavie',
      unitSize: 1.5,
      unitType: UnitType.l,
      category: 'nước',
    );
    await buy(lavie, s3, 7000, 6);
    await buy(lavie, s3, 6800, 1);

    // --- Weighed (~8) ---
    final caChua = await item(
      name: 'Cà chua',
      unitType: UnitType.kg,
      category: 'rau',
      weighed: true,
    );
    await buy(caChua, s1, 18000, 3, qty: 5);
    await buy(caChua, s1, 20000, 0, qty: 3);

    final caiThia = await item(
      name: 'Cải thìa',
      unitType: UnitType.kg,
      category: 'rau',
      weighed: true,
    );
    await buy(caiThia, s1, 15000, 1, qty: 2);

    final hanhTim = await item(
      name: 'Hành tím',
      unitType: UnitType.kg,
      category: 'rau',
      weighed: true,
    );
    await buy(hanhTim, s1, 45000, 4, qty: 1);

    final toi = await item(
      name: 'Tỏi',
      unitType: UnitType.kg,
      category: 'rau',
      weighed: true,
    );
    await buy(toi, s1, 55000, 5, qty: 1);

    final gung = await item(
      name: 'Gừng',
      unitType: UnitType.kg,
      category: 'gia vị',
      weighed: true,
    );
    await buy(gung, s1, 40000, 2, qty: 0.5);

    final ot = await item(
      name: 'Ớt hiểm',
      unitType: UnitType.kg,
      category: 'gia vị',
      weighed: true,
    );
    await buy(ot, s1, 60000, 2, qty: 0.3);

    final duDu = await item(
      name: 'Đu đủ xanh',
      unitType: UnitType.kg,
      category: 'rau',
      weighed: true,
    );
    await buy(duDu, s1, 12000, 1, qty: 4);

    final khoaiTay = await item(
      name: 'Khoai tây',
      unitType: UnitType.kg,
      category: 'rau',
      weighed: true,
    );
    await buy(khoaiTay, s1, 22000, 3, qty: 5);
    await buy(khoaiTay, s1, 25000, 0, qty: 3);

    // Sample sell + ref prices for Coca
    await _db.insertSellPrice(
      SellPricesCompanion.insert(
        id: newId(),
        itemId: coca,
        price: 10000,
        marginPct: 15,
        effectiveFrom: day(1),
      ),
    );
    await _db.insertRefPrice(
      RefPricesCompanion.insert(
        id: newId(),
        itemId: coca,
        source: RefPriceSource.bhx,
        price: 11000,
        unitSize: const Value(330),
        observedAt: day(2),
        note: const Value('Demo — giá bán lẻ siêu thị'),
      ),
    );

    final items = await _db.listActiveItems();
    return DemoSeedResult(
      suppliers: 3,
      items: items.length,
      purchases: purchaseCount,
    );
  }
}
