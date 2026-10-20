import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/data/backup/csv_backup.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';
import 'package:so_gia/data/seed/demo_seed.dart';

/// Agent soft-stop checks for P6 before starting P7.
void main() {
  test('P6 soft-stop: seed, 2-store isolation, margins, CSV roundtrip', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final seed = await DemoSeedService(db).seed(force: true);
    expect(seed.items, greaterThanOrEqualTo(20));
    expect(seed.purchases, greaterThan(0));

    final store1 = kDefaultStoreId;
    final items1 = await db.listActiveItems(store1);
    expect(items1, isNotEmpty);

    var costSum = 0;
    for (final item in items1) {
      for (final p in await db.listPurchasesForItem(item.id)) {
        costSum += p.costPrice;
      }
    }
    expect(costSum, greaterThan(0));

    final store2 = await db.createStore(name: 'Cửa hàng 2');
    expect(await db.listActiveItems(store2.id), isEmpty);

    await db.saveStoreItem(
      storeId: store2.id,
      name: 'Chỉ cửa hàng 2',
      unitType: UnitType.piece,
      categoryId: 'khac',
    );

    final only2 = await db.listActiveItems(store2.id);
    final still1 = await db.listActiveItems(store1);
    expect(only2, hasLength(1));
    expect(only2.single.resolvedName, 'Chỉ cửa hàng 2');
    expect(still1.any((e) => e.resolvedName == 'Chỉ cửa hàng 2'), isFalse);
    expect(still1.length, items1.length);

    final margins = await db.listMarginsForStore(store1);
    expect(margins, isNotEmpty);

    final zip = await CsvBackupService(db).exportZip();
    expect(zip.length, greaterThan(100));

    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    await CsvBackupService(db2).importZip(zip);
    final imported = await db2.listActiveItems(store1);
    expect(imported.length, items1.length);
  });
}
