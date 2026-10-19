import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/ids.dart';
import '../../core/vietnamese.dart';
import '../models/store_item_view.dart';
import 'category_seed.dart';
import 'migration_v2.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    CatalogProducts,
    Stores,
    StoreItems,
    Suppliers,
    Purchases,
    RefPrices,
    SellPrices,
    MarginByCategory,
    StarterPacks,
    StarterPackItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'so_gia'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createV2Indexes(this);
          await seedFreshV2(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await migrateV1toV2(this, m);
          }
        },
      );

  Future<bool> ping() async {
    final row = await customSelect('SELECT 1 AS ok').getSingle();
    return row.read<int>('ok') == 1;
  }

  // --- Stores ---

  Stream<List<Store>> watchActiveStores() {
    return (select(stores)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Store>> listActiveStores() {
    return (select(stores)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<Store?> getStoreById(String id) {
    return (select(stores)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<void> upsertStore(StoresCompanion row) {
    return into(stores).insertOnConflictUpdate(row);
  }

  Future<Store> createStore({
    required String name,
    String? type,
    double defaultMarginPct = 20,
    int roundingStep = 500,
  }) async {
    final now = DateTime.now().toUtc();
    final id = newId();
    await upsertStore(
      StoresCompanion.insert(
        id: id,
        name: name.trim(),
        type: Value(type),
        defaultMarginPct: Value(defaultMarginPct),
        roundingStep: Value(roundingStep),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await seedMarginsForStore(this, id);
    return (await getStoreById(id))!;
  }

  // --- Categories / margins ---

  Future<List<Category>> listCategories() {
    return (select(categories)..orderBy([(t) => OrderingTerm.asc(t.sort)]))
        .get();
  }

  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<double?> marginPctFor(String storeId, String categoryId) async {
    final row = await (select(marginByCategory)
          ..where(
            (t) => t.storeId.equals(storeId) & t.categoryId.equals(categoryId),
          ))
        .getSingleOrNull();
    return row?.marginPct;
  }

  Future<List<MarginByCategoryData>> listMarginsForStore(String storeId) {
    return (select(marginByCategory)..where((t) => t.storeId.equals(storeId)))
        .get();
  }

  Future<void> upsertMargin(MarginByCategoryCompanion row) {
    return into(marginByCategory).insertOnConflictUpdate(row);
  }

  // --- Catalog + store items (joined view) ---

  SimpleSelectStatement<$StoreItemsTable, StoreItem> _activeStoreItems(
    String storeId,
  ) {
    return select(storeItems)
      ..where(
        (t) =>
            t.storeId.equals(storeId) &
            t.deletedAt.isNull() &
            t.isActive.equals(true),
      );
  }

  Future<Item?> _toView(StoreItem si) async {
    final cp = await (select(catalogProducts)
          ..where((t) => t.id.equals(si.catalogId)))
        .getSingleOrNull();
    if (cp == null) return null;
    final cat = await getCategoryById(cp.categoryId);
    return Item(
      id: si.id,
      catalogId: si.catalogId,
      storeId: si.storeId,
      barcode: cp.barcode,
      name: cp.name,
      brand: cp.brand,
      unitSize: cp.unitSize,
      unitType: cp.unitType,
      categoryId: cp.categoryId,
      category: cat?.name,
      isWeighed: cp.isWeighed,
      source: cp.source,
      displayName: si.displayName,
      createdAt: si.createdAt,
      updatedAt: si.updatedAt,
      deletedAt: si.deletedAt,
    );
  }

  Future<List<Item>> listActiveItems(String storeId) async {
    final rows = await (_activeStoreItems(storeId)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final out = <Item>[];
    for (final si in rows) {
      final view = await _toView(si);
      if (view != null) out.add(view);
    }
    out.sort(
      (a, b) => a.resolvedName.toLowerCase().compareTo(
            b.resolvedName.toLowerCase(),
          ),
    );
    return out;
  }

  Stream<List<Item>> watchActiveItems(String storeId) {
    return (_activeStoreItems(storeId)).watch().asyncMap((rows) async {
      final out = <Item>[];
      for (final si in rows) {
        final view = await _toView(si);
        if (view != null) out.add(view);
      }
      out.sort(
        (a, b) => a.resolvedName.toLowerCase().compareTo(
              b.resolvedName.toLowerCase(),
            ),
      );
      return out;
    });
  }

  Future<Item?> getItemById(String storeItemId) async {
    final si = await (select(storeItems)
          ..where((t) => t.id.equals(storeItemId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (si == null) return null;
    return _toView(si);
  }

  Future<StoreItem?> getStoreItemRowById(String id) {
    return (select(storeItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<CatalogProduct?> getCatalogRowById(String id) {
    return (select(catalogProducts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Item?> getItemByBarcode(String storeId, String barcode) async {
    final cp = await (select(catalogProducts)
          ..where(
            (t) => t.barcode.equals(barcode) & t.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (cp == null) return null;
    final si = await (select(storeItems)
          ..where(
            (t) =>
                t.storeId.equals(storeId) &
                t.catalogId.equals(cp.id) &
                t.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (si == null) return null;
    return _toView(si);
  }

  Future<void> upsertCatalogProduct(CatalogProductsCompanion row) {
    return into(catalogProducts).insertOnConflictUpdate(row);
  }

  Future<void> upsertStoreItem(StoreItemsCompanion row) {
    return into(storeItems).insertOnConflictUpdate(row);
  }

  Future<Item> saveStoreItem({
    required String storeId,
    String? storeItemId,
    String? catalogId,
    String? barcode,
    required String name,
    String? brand,
    double? unitSize,
    required UnitType unitType,
    String? categoryId,
    String? displayName,
    bool isWeighed = false,
    CatalogSource source = CatalogSource.user,
  }) async {
    final now = DateTime.now().toUtc();
    final sid = storeItemId ?? newId();
    final cid = catalogId ?? sid;
    final existingSi =
        storeItemId == null ? null : await getStoreItemRowById(storeItemId);
    final existingCp = await getCatalogRowById(cid);
    final resolvedCategory = categoryId ??
        existingCp?.categoryId ??
        mapLegacyCategoryId(null);

    await upsertCatalogProduct(
      CatalogProductsCompanion(
        id: Value(cid),
        barcode: Value(barcode?.trim().isEmpty == true ? null : barcode?.trim()),
        name: Value(name.trim()),
        nameSearch: Value(removeDiacritics(name.trim())),
        brand: Value(brand?.trim().isEmpty == true ? null : brand?.trim()),
        unitSize: Value(unitSize),
        unitType: Value(unitType),
        categoryId: Value(resolvedCategory),
        isWeighed: Value(isWeighed),
        source: Value(existingCp?.source ?? source),
        catalogVersion: Value(existingCp?.catalogVersion),
        createdAt: Value(existingCp?.createdAt ?? now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
      ),
    );

    await upsertStoreItem(
      StoreItemsCompanion(
        id: Value(sid),
        storeId: Value(storeId),
        catalogId: Value(cid),
        displayName: Value(
          displayName?.trim().isEmpty == true ? null : displayName?.trim(),
        ),
        isActive: const Value(true),
        createdAt: Value(existingSi?.createdAt ?? now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
      ),
    );

    return (await getItemById(sid))!;
  }

  Future<void> softDeleteItem(String storeItemId) async {
    final now = DateTime.now().toUtc();
    await (update(storeItems)..where((t) => t.id.equals(storeItemId))).write(
      StoreItemsCompanion(
        deletedAt: Value(now),
        isActive: const Value(false),
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

  // --- Suppliers ---

  Stream<List<Supplier>> watchActiveSuppliers(String storeId) {
    return (select(suppliers)
          ..where((t) => t.storeId.equals(storeId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<List<Supplier>> listActiveSuppliers(String storeId) {
    return (select(suppliers)
          ..where((t) => t.storeId.equals(storeId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Future<Supplier?> getSupplierById(String id) {
    return (select(suppliers)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Supplier?> getSupplierRowById(String id) {
    return (select(suppliers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertSupplier(SuppliersCompanion row) {
    return into(suppliers).insertOnConflictUpdate(row);
  }

  Future<void> softDeleteSupplier(String id) async {
    final now = DateTime.now().toUtc();
    await (update(suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  // --- Sell prices ---

  Future<SellPrice?> currentSellPrice(String itemId, {DateTime? asOf}) {
    final when = (asOf ?? DateTime.now()).toUtc();
    return (select(sellPrices)
          ..where(
            (t) =>
                t.itemId.equals(itemId) &
                t.effectiveFrom.isSmallerOrEqualValue(when),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<List<SellPrice>> watchSellPrices(String itemId) {
    return (select(sellPrices)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)]))
        .watch();
  }

  Future<void> insertSellPrice(SellPricesCompanion row) {
    return into(sellPrices).insert(row);
  }

  // --- Ref prices (by catalog id) ---

  Stream<List<RefPrice>> watchRefPricesForCatalog(String catalogId) {
    return (select(refPrices)
          ..where((t) => t.catalogId.equals(catalogId))
          ..orderBy([(t) => OrderingTerm.desc(t.observedAt)]))
        .watch();
  }

  Future<List<RefPrice>> listRefPricesForCatalog(String catalogId) {
    return (select(refPrices)
          ..where((t) => t.catalogId.equals(catalogId))
          ..orderBy([(t) => OrderingTerm.desc(t.observedAt)]))
        .get();
  }

  Future<RefPrice?> latestRefPriceForCatalog(String catalogId) {
    return (select(refPrices)
          ..where((t) => t.catalogId.equals(catalogId))
          ..orderBy([(t) => OrderingTerm.desc(t.observedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> insertRefPrice(RefPricesCompanion row) {
    return into(refPrices).insert(row);
  }

  // --- Backup helpers ---

  Future<List<SellPrice>> listAllSellPrices() => select(sellPrices).get();

  Future<List<RefPrice>> listAllRefPrices() => select(refPrices).get();

  Future<List<CatalogProduct>> listAllCatalogProducts() =>
      select(catalogProducts).get();

  Future<List<StoreItem>> listAllStoreItems() => select(storeItems).get();

  Future<void> upsertPurchase(PurchasesCompanion row) {
    return into(purchases).insertOnConflictUpdate(row);
  }

  Future<void> upsertRefPrice(RefPricesCompanion row) {
    return into(refPrices).insertOnConflictUpdate(row);
  }

  Future<void> upsertSellPrice(SellPricesCompanion row) {
    return into(sellPrices).insertOnConflictUpdate(row);
  }

  Future<Purchase?> getPurchaseById(String id) {
    return (select(purchases)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<RefPrice?> getRefPriceById(String id) {
    return (select(refPrices)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<SellPrice?> getSellPriceById(String id) {
    return (select(sellPrices)..where((t) => t.id.equals(id))).getSingleOrNull();
  }
}
