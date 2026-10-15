import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/ids.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('ping and schema', () async {
    expect(await db.ping(), isTrue);
    expect(db.schemaVersion, 1);
  });

  test('upsert item and purchase', () async {
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
        barcode: const Value('8934588012345'),
        unitSize: const Value(330),
      ),
    );

    final found = await db.getItemByBarcode('8934588012345');
    expect(found?.name, 'Coca 330ml');

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

    final latest = await db.latestPurchaseForItem(itemId);
    expect(latest?.costPrice, 7000);
  });
}
