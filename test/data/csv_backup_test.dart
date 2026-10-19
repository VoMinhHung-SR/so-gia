import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/ids.dart';
import 'package:so_gia/data/backup/csv_backup.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';

void main() {
  late AppDatabase db;
  late CsvBackupService backup;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    backup = CsvBackupService(db);
  });

  tearDown(() => db.close());

  test('export zip then import roundtrip v2', () async {
    final item = await db.saveStoreItem(
      storeId: kDefaultStoreId,
      barcode: '893',
      name: 'Coca 330ml',
      unitSize: 330,
      unitType: UnitType.ml,
      categoryId: 'nuoc-giai-khat',
      source: CatalogSource.user,
    );
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

    final zip = await backup.exportZip();
    expect(zip.length, greaterThan(100));

    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final backup2 = CsvBackupService(db2);
    final preview = await backup2.previewImport(zip);
    expect(
      preview.any((p) => p.table == 'catalog_products' && p.toInsert == 1),
      isTrue,
    );

    await backup2.importZip(zip);
    final items = await db2.listActiveItems(kDefaultStoreId);
    expect(items.single.name, 'Coca 330ml');
    final purchases = await db2.listPurchasesForItem(item.id);
    expect(purchases.single.costPrice, 7000);
  });

  test('newer updated_at wins on catalog merge', () async {
    final id = newId();
    final old = DateTime.utc(2024, 1, 1);
    final neu = DateTime.utc(2026, 1, 1);

    await db.upsertCatalogProduct(
      CatalogProductsCompanion.insert(
        id: id,
        name: 'Old name',
        nameSearch: 'old name',
        unitType: UnitType.piece,
        categoryId: 'khac',
        source: CatalogSource.user,
        createdAt: old,
        updatedAt: old,
      ),
    );
    await db.upsertStoreItem(
      StoreItemsCompanion.insert(
        id: id,
        storeId: kDefaultStoreId,
        catalogId: id,
        createdAt: old,
        updatedAt: old,
      ),
    );

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.upsertCatalogProduct(
      CatalogProductsCompanion.insert(
        id: id,
        name: 'New name',
        nameSearch: 'new name',
        unitType: UnitType.piece,
        categoryId: 'khac',
        source: CatalogSource.user,
        createdAt: old,
        updatedAt: neu,
      ),
    );
    await other.upsertStoreItem(
      StoreItemsCompanion.insert(
        id: id,
        storeId: kDefaultStoreId,
        catalogId: id,
        createdAt: old,
        updatedAt: neu,
      ),
    );
    final zip = await CsvBackupService(other).exportZip();
    await backup.importZip(zip);

    final item = await db.getCatalogRowById(id);
    expect(item?.name, 'New name');
  });
}
