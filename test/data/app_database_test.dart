import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/ids.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('ping and schema v2', () async {
    expect(await db.ping(), isTrue);
    expect(db.schemaVersion, 3);
    final stores = await db.listActiveStores();
    expect(stores, isNotEmpty);
    expect(stores.first.id, kDefaultStoreId);
    final cats = await db.listCategories();
    expect(cats.length, greaterThanOrEqualTo(18));
  });

  test('upsert store item and purchase', () async {
    final storeId = kDefaultStoreId;
    final item = await db.saveStoreItem(
      storeId: storeId,
      barcode: '8934588012345',
      name: 'Coca 330ml',
      unitSize: 330,
      unitType: UnitType.ml,
      categoryId: 'nuoc-giai-khat',
      source: CatalogSource.user,
    );

    final found = await db.getItemByBarcode(storeId, '8934588012345');
    expect(found?.resolvedName, 'Coca 330ml');

    final now = DateTime.now().toUtc();
    await db.insertPurchase(
      PurchasesCompanion.insert(
        id: newId(),
        itemId: item.id,
        costPrice: 7000,
        date: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final latest = await db.latestPurchaseForItem(item.id);
    expect(latest?.costPrice, 7000);
  });

  test('two stores do not mix items', () async {
    final a = kDefaultStoreId;
    final b = (await db.createStore(name: 'Cửa hàng 2')).id;

    await db.saveStoreItem(
      storeId: a,
      name: 'Chỉ A',
      unitType: UnitType.piece,
      categoryId: 'khac',
    );
    await db.saveStoreItem(
      storeId: b,
      name: 'Chỉ B',
      unitType: UnitType.piece,
      categoryId: 'khac',
    );

    final listA = await db.listActiveItems(a);
    final listB = await db.listActiveItems(b);
    expect(listA.map((e) => e.resolvedName), contains('Chỉ A'));
    expect(listA.map((e) => e.resolvedName), isNot(contains('Chỉ B')));
    expect(listB.map((e) => e.resolvedName), contains('Chỉ B'));
    expect(listB.map((e) => e.resolvedName), isNot(contains('Chỉ A')));
  });
}
