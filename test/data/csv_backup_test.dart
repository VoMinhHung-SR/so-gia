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

  test('export zip then import roundtrip', () async {
    final now = DateTime.now().toUtc();
    final itemId = newId();
    await db.upsertItem(
      ItemsCompanion.insert(
        id: itemId,
        name: 'Coca 330ml',
        unitType: UnitType.ml,
        source: ItemSource.manual,
        createdAt: now,
        updatedAt: now,
        barcode: const Value('893'),
        unitSize: const Value(330),
      ),
    );
    await db.insertPurchase(
      PurchasesCompanion.insert(
        id: newId(),
        itemId: itemId,
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
    expect(preview.any((p) => p.table == 'items' && p.toInsert == 1), isTrue);

    await backup2.importZip(zip);
    final items = await db2.listActiveItems();
    expect(items.single.name, 'Coca 330ml');
    final purchases = await db2.listPurchasesForItem(itemId);
    expect(purchases.single.costPrice, 7000);
  });

  test('newer updated_at wins on merge', () async {
    final id = newId();
    final old = DateTime.utc(2024, 1, 1);
    final neu = DateTime.utc(2026, 1, 1);
    await db.upsertItem(
      ItemsCompanion.insert(
        id: id,
        name: 'Old name',
        unitType: UnitType.piece,
        source: ItemSource.manual,
        createdAt: old,
        updatedAt: old,
      ),
    );

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.upsertItem(
      ItemsCompanion.insert(
        id: id,
        name: 'New name',
        unitType: UnitType.piece,
        source: ItemSource.manual,
        createdAt: old,
        updatedAt: neu,
      ),
    );
    final zip = await CsvBackupService(other).exportZip();
    await backup.importZip(zip);

    final item = await db.getItemRowById(id);
    expect(item?.name, 'New name');
  });
}
