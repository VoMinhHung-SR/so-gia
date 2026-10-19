import 'package:drift/drift.dart';

import '../../core/vietnamese.dart';
import 'app_database.dart';
import 'category_seed.dart';
import 'tables.dart';

Future<void> createV2Indexes(GeneratedDatabase db) async {
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS catalog_barcode_unique '
    'ON catalog_products(barcode) '
    'WHERE barcode IS NOT NULL AND deleted_at IS NULL',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS catalog_name_search '
    'ON catalog_products(name_search)',
  );
  await db.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS store_items_store_catalog '
    'ON store_items(store_id, catalog_id) '
    'WHERE deleted_at IS NULL',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS purchases_item_date '
    'ON purchases(item_id, date)',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS ref_prices_catalog_observed '
    'ON ref_prices(catalog_id, observed_at)',
  );
}

Future<void> seedFreshV2(AppDatabase db) async {
  await seedCategories(db);
  await ensureDefaultStore(db);
}

/// Upgrade path from schema v1 (`items`) → v2 (catalog + stores).
Future<void> migrateV1toV2(AppDatabase db, Migrator m) async {
  await m.createTable(db.categories);
  await m.createTable(db.stores);
  await m.createTable(db.catalogProducts);
  await m.createTable(db.storeItems);
  await m.createTable(db.marginByCategory);
  await m.createTable(db.starterPacks);
  await m.createTable(db.starterPackItems);

  await seedCategories(db);
  final storeId = await ensureDefaultStore(db);

  // Add store_id to suppliers (v1 had no store scope).
  await db.customStatement(
    'ALTER TABLE suppliers ADD COLUMN store_id TEXT '
    "NOT NULL DEFAULT '$kDefaultStoreId'",
  );

  // Copy items → catalog_products + store_items (same id on both rows).
  final itemRows = await db.customSelect('SELECT * FROM items').get();
  for (final row in itemRows) {
    final id = row.read<String>('id');
    final name = row.read<String>('name');
    final barcode = row.readNullable<String>('barcode');
    final brand = row.readNullable<String>('brand');
    final unitSize = row.readNullable<double>('unit_size');
    final unitTypeRaw = row.read<String>('unit_type');
    final categoryRaw = row.readNullable<String>('category');
    final isWeighed = row.read<bool>('is_weighed');
    final sourceRaw = row.read<String>('source');
    final createdAt = row.read<DateTime>('created_at');
    final updatedAt = row.read<DateTime>('updated_at');
    final deletedAt = row.readNullable<DateTime>('deleted_at');

    final unitType = UnitType.values.firstWhere(
      (e) => e.name == unitTypeRaw,
      orElse: () => UnitType.piece,
    );
    final categoryId = mapLegacyCategoryId(categoryRaw);
    final source = parseCatalogSource(sourceRaw);

    await db.into(db.catalogProducts).insert(
          CatalogProductsCompanion.insert(
            id: id,
            barcode: Value(barcode),
            name: name,
            nameSearch: removeDiacritics(name),
            brand: Value(brand),
            unitSize: Value(unitSize),
            unitType: unitType,
            categoryId: categoryId,
            isWeighed: Value(isWeighed),
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: Value(deletedAt),
          ),
        );

    await db.into(db.storeItems).insert(
          StoreItemsCompanion.insert(
            id: id,
            storeId: storeId,
            catalogId: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: Value(deletedAt),
            isActive: Value(deletedAt == null),
          ),
        );
  }

  // Rebuild ref_prices: item_id → catalog_id (same UUID values).
  await db.customStatement('ALTER TABLE ref_prices RENAME TO ref_prices_v1');
  await m.createTable(db.refPrices);
  await db.customStatement('''
    INSERT INTO ref_prices
      (id, catalog_id, source, price, unit_size, url, observed_at, note)
    SELECT id, item_id, source, price, unit_size, url, observed_at, note
    FROM ref_prices_v1
  ''');
  await db.customStatement('DROP TABLE ref_prices_v1');

  // Drop legacy items table.
  await db.customStatement('DROP TABLE IF EXISTS items');

  // Recreate purchases / sell_prices FK targets if SQLite still points at items.
  // Existing item_id values already match store_items.id — no row rewrite.

  await createV2Indexes(db);
}
