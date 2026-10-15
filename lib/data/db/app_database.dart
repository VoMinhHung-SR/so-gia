import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Items, Suppliers, Purchases, RefPrices, SellPrices])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'so_gia'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS items_barcode_unique '
            'ON items(barcode) WHERE barcode IS NOT NULL AND deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS purchases_item_date '
            'ON purchases(item_id, date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS ref_prices_item_observed '
            'ON ref_prices(item_id, observed_at)',
          );
        },
      );

  Future<bool> ping() async {
    final row = await customSelect('SELECT 1 AS ok').getSingle();
    return row.read<int>('ok') == 1;
  }

  // --- Items ---

  Stream<List<Item>> watchActiveItems() {
    return (select(items)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Item>> listActiveItems() {
    return (select(items)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<Item?> getItemById(String id) {
    return (select(items)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Item?> getItemByBarcode(String barcode) {
    return (select(items)
          ..where(
            (t) => t.barcode.equals(barcode) & t.deletedAt.isNull(),
          ))
        .getSingleOrNull();
  }

  Future<void> upsertItem(ItemsCompanion row) {
    return into(items).insertOnConflictUpdate(row);
  }

  Future<void> softDeleteItem(String id) async {
    final now = DateTime.now().toUtc();
    await (update(items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // --- Purchases ---

  Stream<List<Purchase>> watchPurchasesForItem(String itemId) {
    return (select(purchases)
          ..where((t) => t.itemId.equals(itemId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<List<Purchase>> listPurchasesForItem(String itemId) {
    return (select(purchases)
          ..where((t) => t.itemId.equals(itemId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<Purchase?> latestPurchaseForItem(String itemId) {
    return (select(purchases)
          ..where((t) => t.itemId.equals(itemId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> insertPurchase(PurchasesCompanion row) {
    return into(purchases).insert(row);
  }
}
