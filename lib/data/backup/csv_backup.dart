import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../../core/csv.dart';
import '../../core/vietnamese.dart';
import '../db/app_database.dart';
import '../db/category_seed.dart';
import '../db/tables.dart';

class CsvMergePreview {
  const CsvMergePreview({
    required this.table,
    required this.toInsert,
    required this.toUpdate,
    required this.unchanged,
  });

  final String table;
  final int toInsert;
  final int toUpdate;
  final int unchanged;
}

class CsvBackupService {
  CsvBackupService(this._db);

  final AppDatabase _db;

  static const formatVersion = 2;

  Future<Uint8List> exportZip() async {
    final archive = Archive();

    void add(String name, String csv) {
      final bytes = utf8.encode(csv);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add(
      'manifest.json',
      const JsonEncoder.withIndent('  ').convert({
        'format_version': formatVersion,
        'app': 'so_gia',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    add('stores.csv', await _exportStores());
    add('categories.csv', await _exportCategories());
    add('catalog_products.csv', await _exportCatalog());
    add('store_items.csv', await _exportStoreItems());
    add('margin_by_category.csv', await _exportMargins());
    add('suppliers.csv', await _exportSuppliers());
    add('purchases.csv', await _exportPurchases());
    add('ref_prices.csv', await _exportRefPrices());
    add('sell_prices.csv', await _exportSellPrices());

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  Future<List<CsvMergePreview>> previewImport(Uint8List zipBytes) async {
    final files = _unzipCsv(zipBytes);
    final previews = <CsvMergePreview>[];
    if (files.containsKey('items.csv') &&
        !files.containsKey('catalog_products.csv')) {
      previews.add(await _previewLegacyItems(files['items.csv']!));
    }
    if (files.containsKey('catalog_products.csv')) {
      previews.add(await _previewCatalog(files['catalog_products.csv']!));
    }
    if (files.containsKey('store_items.csv')) {
      previews.add(await _previewStoreItems(files['store_items.csv']!));
    }
    if (files.containsKey('suppliers.csv')) {
      previews.add(await _previewSuppliers(files['suppliers.csv']!));
    }
    if (files.containsKey('purchases.csv')) {
      previews.add(await _previewPurchases(files['purchases.csv']!));
    }
    if (files.containsKey('ref_prices.csv')) {
      previews.add(await _previewRefPrices(files['ref_prices.csv']!));
    }
    if (files.containsKey('sell_prices.csv')) {
      previews.add(await _previewSellPrices(files['sell_prices.csv']!));
    }
    return previews;
  }

  Future<void> importZip(Uint8List zipBytes) async {
    final files = _unzipCsv(zipBytes);
    final storeId = await ensureDefaultStore(_db);

    if (files.containsKey('stores.csv')) {
      await _importStores(files['stores.csv']!);
    }
    if (files.containsKey('categories.csv')) {
      await _importCategories(files['categories.csv']!);
    } else {
      await seedCategories(_db);
    }

    // v1 zip: items.csv only → map into default store.
    if (files.containsKey('items.csv') &&
        !files.containsKey('catalog_products.csv')) {
      await _importLegacyItems(files['items.csv']!, storeId);
    }

    if (files.containsKey('catalog_products.csv')) {
      await _importCatalog(files['catalog_products.csv']!);
    }
    if (files.containsKey('store_items.csv')) {
      await _importStoreItems(files['store_items.csv']!);
    }
    if (files.containsKey('margin_by_category.csv')) {
      await _importMargins(files['margin_by_category.csv']!);
    }
    if (files.containsKey('suppliers.csv')) {
      await _importSuppliers(files['suppliers.csv']!, fallbackStoreId: storeId);
    }
    if (files.containsKey('purchases.csv')) {
      await _importPurchases(files['purchases.csv']!);
    }
    if (files.containsKey('ref_prices.csv')) {
      await _importRefPrices(files['ref_prices.csv']!);
    }
    if (files.containsKey('sell_prices.csv')) {
      await _importSellPrices(files['sell_prices.csv']!);
    }
  }

  Map<String, String> _unzipCsv(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final out = <String, String>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.split('/').last;
      if (name.endsWith('.csv') || name.endsWith('.json')) {
        out[name] = utf8.decode(f.content as List<int>);
      }
    }
    return out;
  }

  Future<String> _exportStores() async {
    final all = await (_db.select(_db.stores)).get();
    return encodeCsv(
      headers: [
        'id',
        'name',
        'type',
        'default_margin_pct',
        'rounding_step',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
      rows: [
        for (final s in all)
          [
            s.id,
            s.name,
            s.type,
            s.defaultMarginPct,
            s.roundingStep,
            s.createdAt,
            s.updatedAt,
            s.deletedAt,
          ],
      ],
    );
  }

  Future<String> _exportCategories() async {
    final all = await _db.listCategories();
    return encodeCsv(
      headers: ['id', 'name', 'parent_id', 'sort', 'is_weighed'],
      rows: [
        for (final c in all)
          [c.id, c.name, c.parentId, c.sort, c.isWeighed],
      ],
    );
  }

  Future<String> _exportCatalog() async {
    final all = await _db.listAllCatalogProducts();
    return encodeCsv(
      headers: [
        'id',
        'barcode',
        'name',
        'name_search',
        'brand',
        'unit_size',
        'unit_type',
        'category_id',
        'is_weighed',
        'source',
        'catalog_version',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
      rows: [
        for (final i in all)
          [
            i.id,
            i.barcode,
            i.name,
            i.nameSearch,
            i.brand,
            i.unitSize,
            i.unitType.name,
            i.categoryId,
            i.isWeighed,
            i.source.name,
            i.catalogVersion,
            i.createdAt,
            i.updatedAt,
            i.deletedAt,
          ],
      ],
    );
  }

  Future<String> _exportStoreItems() async {
    final all = await _db.listAllStoreItems();
    return encodeCsv(
      headers: [
        'id',
        'store_id',
        'catalog_id',
        'display_name',
        'is_active',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
      rows: [
        for (final i in all)
          [
            i.id,
            i.storeId,
            i.catalogId,
            i.displayName,
            i.isActive,
            i.createdAt,
            i.updatedAt,
            i.deletedAt,
          ],
      ],
    );
  }

  Future<String> _exportMargins() async {
    final all = await (_db.select(_db.marginByCategory)).get();
    return encodeCsv(
      headers: ['store_id', 'category_id', 'margin_pct'],
      rows: [
        for (final m in all) [m.storeId, m.categoryId, m.marginPct],
      ],
    );
  }

  Future<String> _exportSuppliers() async {
    final all = await (_db.select(_db.suppliers)).get();
    return encodeCsv(
      headers: [
        'id',
        'store_id',
        'name',
        'phone',
        'note',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
      rows: [
        for (final s in all)
          [
            s.id,
            s.storeId,
            s.name,
            s.phone,
            s.note,
            s.createdAt,
            s.updatedAt,
            s.deletedAt,
          ],
      ],
    );
  }

  Future<String> _exportPurchases() async {
    final all = await (_db.select(_db.purchases)).get();
    return encodeCsv(
      headers: [
        'id',
        'item_id',
        'supplier_id',
        'cost_price',
        'qty',
        'date',
        'note',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
      rows: [
        for (final p in all)
          [
            p.id,
            p.itemId,
            p.supplierId,
            p.costPrice,
            p.qty,
            p.date,
            p.note,
            p.createdAt,
            p.updatedAt,
            p.deletedAt,
          ],
      ],
    );
  }

  Future<String> _exportRefPrices() async {
    final all = await _db.listAllRefPrices();
    return encodeCsv(
      headers: [
        'id',
        'catalog_id',
        'source',
        'price',
        'unit_size',
        'url',
        'observed_at',
        'note',
      ],
      rows: [
        for (final r in all)
          [
            r.id,
            r.catalogId,
            r.source.name,
            r.price,
            r.unitSize,
            r.url,
            r.observedAt,
            r.note,
          ],
      ],
    );
  }

  Future<String> _exportSellPrices() async {
    final all = await _db.listAllSellPrices();
    return encodeCsv(
      headers: ['id', 'item_id', 'price', 'margin_pct', 'effective_from'],
      rows: [
        for (final s in all)
          [s.id, s.itemId, s.price, s.marginPct, s.effectiveFrom],
      ],
    );
  }

  Future<CsvMergePreview> _previewLegacyItems(String csv) async {
    return _previewByUpdatedAtCatalogish(
      table: 'items',
      csv: csv,
      getLocal: (id) async {
        final row = await _db.getCatalogRowById(id);
        return row?.updatedAt;
      },
    );
  }

  Future<CsvMergePreview> _previewCatalog(String csv) async {
    return _previewByUpdatedAtCatalogish(
      table: 'catalog_products',
      csv: csv,
      getLocal: (id) async {
        final row = await _db.getCatalogRowById(id);
        return row?.updatedAt;
      },
    );
  }

  Future<CsvMergePreview> _previewStoreItems(String csv) async {
    return _previewByUpdatedAtCatalogish(
      table: 'store_items',
      csv: csv,
      getLocal: (id) async {
        final row = await _db.getStoreItemRowById(id);
        return row?.updatedAt;
      },
    );
  }

  Future<CsvMergePreview> _previewByUpdatedAtCatalogish({
    required String table,
    required String csv,
    required Future<DateTime?> Function(String id) getLocal,
  }) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) {
      return CsvMergePreview(
        table: table,
        toInsert: 0,
        toUpdate: 0,
        unchanged: 0,
      );
    }
    final header = rows.first;
    var insert = 0, update = 0, same = 0;
    for (final row in rows.skip(1)) {
      final map = _rowMap(header, row);
      final id = map['id'] ?? '';
      if (id.isEmpty) continue;
      final localAt = await getLocal(id);
      if (localAt == null) {
        insert++;
      } else {
        final incomingAt = DateTime.tryParse(map['updated_at'] ?? '');
        if (incomingAt != null && !incomingAt.isBefore(localAt)) {
          update++;
        } else {
          same++;
        }
      }
    }
    return CsvMergePreview(
      table: table,
      toInsert: insert,
      toUpdate: update,
      unchanged: same,
    );
  }

  Future<CsvMergePreview> _previewSuppliers(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) {
      return const CsvMergePreview(
        table: 'suppliers',
        toInsert: 0,
        toUpdate: 0,
        unchanged: 0,
      );
    }
    final header = rows.first;
    var insert = 0, update = 0, same = 0;
    for (final row in rows.skip(1)) {
      final map = _rowMap(header, row);
      final id = map['id'] ?? '';
      if (id.isEmpty) continue;
      final local = await _db.getSupplierRowById(id);
      if (local == null) {
        insert++;
      } else {
        final incomingAt = DateTime.tryParse(map['updated_at'] ?? '');
        if (incomingAt != null && !incomingAt.isBefore(local.updatedAt)) {
          update++;
        } else {
          same++;
        }
      }
    }
    return CsvMergePreview(
      table: 'suppliers',
      toInsert: insert,
      toUpdate: update,
      unchanged: same,
    );
  }

  Future<CsvMergePreview> _previewPurchases(String csv) async {
    return _previewByUpdatedAt(
      table: 'purchases',
      csv: csv,
      getLocal: _db.getPurchaseById,
      localUpdated: (p) => p.updatedAt,
    );
  }

  Future<CsvMergePreview> _previewRefPrices(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) {
      return const CsvMergePreview(
        table: 'ref_prices',
        toInsert: 0,
        toUpdate: 0,
        unchanged: 0,
      );
    }
    final header = rows.first;
    var insert = 0, update = 0;
    for (final row in rows.skip(1)) {
      final map = _rowMap(header, row);
      final id = map['id'] ?? '';
      if (id.isEmpty) continue;
      final local = await _db.getRefPriceById(id);
      if (local == null) {
        insert++;
      } else {
        update++;
      }
    }
    return CsvMergePreview(
      table: 'ref_prices',
      toInsert: insert,
      toUpdate: update,
      unchanged: 0,
    );
  }

  Future<CsvMergePreview> _previewSellPrices(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) {
      return const CsvMergePreview(
        table: 'sell_prices',
        toInsert: 0,
        toUpdate: 0,
        unchanged: 0,
      );
    }
    final header = rows.first;
    var insert = 0, update = 0;
    for (final row in rows.skip(1)) {
      final map = _rowMap(header, row);
      final id = map['id'] ?? '';
      if (id.isEmpty) continue;
      final local = await _db.getSellPriceById(id);
      if (local == null) {
        insert++;
      } else {
        update++;
      }
    }
    return CsvMergePreview(
      table: 'sell_prices',
      toInsert: insert,
      toUpdate: update,
      unchanged: 0,
    );
  }

  Future<CsvMergePreview> _previewByUpdatedAt<T>({
    required String table,
    required String csv,
    required Future<T?> Function(String id) getLocal,
    required DateTime Function(T) localUpdated,
  }) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) {
      return CsvMergePreview(
        table: table,
        toInsert: 0,
        toUpdate: 0,
        unchanged: 0,
      );
    }
    final header = rows.first;
    var insert = 0, update = 0, same = 0;
    for (final row in rows.skip(1)) {
      final map = _rowMap(header, row);
      final id = map['id'] ?? '';
      if (id.isEmpty) continue;
      final local = await getLocal(id);
      if (local == null) {
        insert++;
      } else {
        final incomingAt = DateTime.tryParse(map['updated_at'] ?? '');
        if (incomingAt != null && !incomingAt.isBefore(localUpdated(local))) {
          update++;
        } else {
          same++;
        }
      }
    }
    return CsvMergePreview(
      table: table,
      toInsert: insert,
      toUpdate: update,
      unchanged: same,
    );
  }

  Future<void> _importStores(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      if (id.isEmpty || (m['name'] ?? '').isEmpty) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getStoreById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;
      await _db.upsertStore(
        StoresCompanion(
          id: Value(id),
          name: Value(m['name']!),
          type: Value(_emptyToNull(m['type'])),
          defaultMarginPct: Value(
            double.tryParse(m['default_margin_pct'] ?? '') ?? 20,
          ),
          roundingStep: Value(int.tryParse(m['rounding_step'] ?? '') ?? 500),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importCategories(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      if (id.isEmpty || (m['name'] ?? '').isEmpty) continue;
      await _db.into(_db.categories).insertOnConflictUpdate(
            CategoriesCompanion(
              id: Value(id),
              name: Value(m['name']!),
              parentId: Value(_emptyToNull(m['parent_id'])),
              sort: Value(int.tryParse(m['sort'] ?? '') ?? 0),
              isWeighed: Value(m['is_weighed'] == 'true'),
            ),
          );
    }
  }

  Future<void> _importLegacyItems(String csv, String storeId) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      if (id.isEmpty || (m['name'] ?? '').isEmpty) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getCatalogRowById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;

      final name = m['name']!;
      final sourceRaw = m['source'];
      await _db.upsertCatalogProduct(
        CatalogProductsCompanion(
          id: Value(id),
          barcode: Value(_emptyToNull(m['barcode'])),
          name: Value(name),
          nameSearch: Value(removeDiacritics(name)),
          brand: Value(_emptyToNull(m['brand'])),
          unitSize: Value(double.tryParse(m['unit_size'] ?? '')),
          unitType: Value(
            _parseEnum(UnitType.values, m['unit_type'], UnitType.piece),
          ),
          categoryId: Value(mapLegacyCategoryId(_emptyToNull(m['category']))),
          isWeighed: Value(m['is_weighed'] == 'true'),
          source: Value(parseCatalogSource(sourceRaw)),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
      await _db.upsertStoreItem(
        StoreItemsCompanion(
          id: Value(id),
          storeId: Value(storeId),
          catalogId: Value(id),
          isActive: Value(m['deleted_at'] == null || m['deleted_at']!.isEmpty),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importCatalog(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      if (id.isEmpty || (m['name'] ?? '').isEmpty) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getCatalogRowById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;
      final name = m['name']!;
      await _db.upsertCatalogProduct(
        CatalogProductsCompanion(
          id: Value(id),
          barcode: Value(_emptyToNull(m['barcode'])),
          name: Value(name),
          nameSearch: Value(
            _emptyToNull(m['name_search']) ?? removeDiacritics(name),
          ),
          brand: Value(_emptyToNull(m['brand'])),
          unitSize: Value(double.tryParse(m['unit_size'] ?? '')),
          unitType: Value(
            _parseEnum(UnitType.values, m['unit_type'], UnitType.piece),
          ),
          categoryId: Value(m['category_id']?.isNotEmpty == true
              ? m['category_id']!
              : 'khac'),
          isWeighed: Value(m['is_weighed'] == 'true'),
          source: Value(parseCatalogSource(m['source'])),
          catalogVersion: Value(int.tryParse(m['catalog_version'] ?? '')),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importStoreItems(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      final storeId = m['store_id'] ?? '';
      final catalogId = m['catalog_id'] ?? '';
      if (id.isEmpty || storeId.isEmpty || catalogId.isEmpty) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getStoreItemRowById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;
      await _db.upsertStoreItem(
        StoreItemsCompanion(
          id: Value(id),
          storeId: Value(storeId),
          catalogId: Value(catalogId),
          displayName: Value(_emptyToNull(m['display_name'])),
          isActive: Value(m['is_active'] != 'false'),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importMargins(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final storeId = m['store_id'] ?? '';
      final categoryId = m['category_id'] ?? '';
      final pct = double.tryParse(m['margin_pct'] ?? '');
      if (storeId.isEmpty || categoryId.isEmpty || pct == null) continue;
      await _db.upsertMargin(
        MarginByCategoryCompanion(
          storeId: Value(storeId),
          categoryId: Value(categoryId),
          marginPct: Value(pct),
        ),
      );
    }
  }

  Future<void> _importSuppliers(
    String csv, {
    required String fallbackStoreId,
  }) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      if (id.isEmpty || (m['name'] ?? '').isEmpty) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getSupplierRowById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;

      await _db.upsertSupplier(
        SuppliersCompanion(
          id: Value(id),
          storeId: Value(
            _emptyToNull(m['store_id']) ?? fallbackStoreId,
          ),
          name: Value(m['name']!),
          phone: Value(_emptyToNull(m['phone'])),
          note: Value(_emptyToNull(m['note'])),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importPurchases(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      final itemId = m['item_id'] ?? '';
      final cost = int.tryParse(m['cost_price'] ?? '');
      if (id.isEmpty || itemId.isEmpty || cost == null) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getPurchaseById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;

      await _db.upsertPurchase(
        PurchasesCompanion(
          id: Value(id),
          itemId: Value(itemId),
          supplierId: Value(_emptyToNull(m['supplier_id'])),
          costPrice: Value(cost),
          qty: Value(double.tryParse(m['qty'] ?? '') ?? 1),
          date: Value(
            DateTime.tryParse(m['date'] ?? '') ?? incomingAt,
          ),
          note: Value(_emptyToNull(m['note'])),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importRefPrices(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      // Accept v1 column `item_id` as catalog_id.
      final catalogId = m['catalog_id'] ?? m['item_id'] ?? '';
      final price = int.tryParse(m['price'] ?? '');
      if (id.isEmpty || catalogId.isEmpty || price == null) continue;
      await _db.upsertRefPrice(
        RefPricesCompanion(
          id: Value(id),
          catalogId: Value(catalogId),
          source: Value(
            _parseEnum(
              RefPriceSource.values,
              m['source'],
              RefPriceSource.other,
            ),
          ),
          price: Value(price),
          unitSize: Value(double.tryParse(m['unit_size'] ?? '')),
          url: Value(_emptyToNull(m['url'])),
          observedAt: Value(
            DateTime.tryParse(m['observed_at'] ?? '') ?? DateTime.now().toUtc(),
          ),
          note: Value(_emptyToNull(m['note'])),
        ),
      );
    }
  }

  Future<void> _importSellPrices(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      final itemId = m['item_id'] ?? '';
      final price = int.tryParse(m['price'] ?? '');
      if (id.isEmpty || itemId.isEmpty || price == null) continue;
      await _db.upsertSellPrice(
        SellPricesCompanion(
          id: Value(id),
          itemId: Value(itemId),
          price: Value(price),
          marginPct: Value(double.tryParse(m['margin_pct'] ?? '') ?? 0),
          effectiveFrom: Value(
            DateTime.tryParse(m['effective_from'] ?? '') ??
                DateTime.now().toUtc(),
          ),
        ),
      );
    }
  }

  Map<String, String> _rowMap(List<String> header, List<String> row) {
    final map = <String, String>{};
    for (var i = 0; i < header.length; i++) {
      map[header[i]] = i < row.length ? row[i] : '';
    }
    return map;
  }

  String? _emptyToNull(String? s) =>
      (s == null || s.isEmpty || s == 'null') ? null : s;

  T _parseEnum<T extends Enum>(List<T> values, String? raw, T fallback) {
    if (raw == null || raw.isEmpty) return fallback;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }
}
