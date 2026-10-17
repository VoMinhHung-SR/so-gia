import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../../core/csv.dart';
import '../db/app_database.dart';
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

  Future<Uint8List> exportZip() async {
    final archive = Archive();

    void add(String name, String csv) {
      final bytes = utf8.encode(csv);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('items.csv', await _exportItems());
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
    if (files.containsKey('items.csv')) {
      previews.add(await _previewItems(files['items.csv']!));
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
    // Parents first.
    if (files.containsKey('suppliers.csv')) {
      await _importSuppliers(files['suppliers.csv']!);
    }
    if (files.containsKey('items.csv')) {
      await _importItems(files['items.csv']!);
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
      if (!name.endsWith('.csv')) continue;
      out[name] = utf8.decode(f.content as List<int>);
    }
    return out;
  }

  Future<String> _exportItems() async {
    final all = await (_db.select(_db.items)).get();
    return encodeCsv(
      headers: [
        'id',
        'barcode',
        'name',
        'brand',
        'unit_size',
        'unit_type',
        'category',
        'is_weighed',
        'source',
        'image_url',
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
            i.brand,
            i.unitSize,
            i.unitType.name,
            i.category,
            i.isWeighed,
            i.source.name,
            i.imageUrl,
            i.createdAt,
            i.updatedAt,
            i.deletedAt,
          ],
      ],
    );
  }

  Future<String> _exportSuppliers() async {
    final all = await (_db.select(_db.suppliers)).get();
    return encodeCsv(
      headers: [
        'id',
        'name',
        'phone',
        'note',
        'created_at',
        'updated_at',
        'deleted_at',
      ],
      rows: [
        for (final s in all)
          [s.id, s.name, s.phone, s.note, s.createdAt, s.updatedAt, s.deletedAt],
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
        'item_id',
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
            r.itemId,
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

  Future<CsvMergePreview> _previewItems(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) {
      return const CsvMergePreview(
        table: 'items',
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
      final local = await _db.getItemRowById(id);
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
      table: 'items',
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
    // Ref prices have no updated_at — always insert-or-replace by id.
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

  Future<void> _importItems(String csv) async {
    final rows = parseCsv(csv);
    if (rows.length < 2) return;
    final header = rows.first;
    for (final row in rows.skip(1)) {
      final m = _rowMap(header, row);
      final id = m['id'] ?? '';
      if (id.isEmpty || (m['name'] ?? '').isEmpty) continue;
      final incomingAt =
          DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now().toUtc();
      final local = await _db.getItemRowById(id);
      if (local != null && local.updatedAt.isAfter(incomingAt)) continue;

      await _db.upsertItem(
        ItemsCompanion(
          id: Value(id),
          barcode: Value(_emptyToNull(m['barcode'])),
          name: Value(m['name']!),
          brand: Value(_emptyToNull(m['brand'])),
          unitSize: Value(double.tryParse(m['unit_size'] ?? '')),
          unitType: Value(_parseEnum(UnitType.values, m['unit_type'], UnitType.piece)),
          category: Value(_emptyToNull(m['category'])),
          isWeighed: Value(m['is_weighed'] == 'true'),
          source: Value(_parseEnum(ItemSource.values, m['source'], ItemSource.manual)),
          imageUrl: Value(_emptyToNull(m['image_url'])),
          createdAt: Value(
            DateTime.tryParse(m['created_at'] ?? '') ?? incomingAt,
          ),
          updatedAt: Value(incomingAt),
          deletedAt: Value(DateTime.tryParse(m['deleted_at'] ?? '')),
        ),
      );
    }
  }

  Future<void> _importSuppliers(String csv) async {
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
      final itemId = m['item_id'] ?? '';
      final price = int.tryParse(m['price'] ?? '');
      if (id.isEmpty || itemId.isEmpty || price == null) continue;
      await _db.upsertRefPrice(
        RefPricesCompanion(
          id: Value(id),
          itemId: Value(itemId),
          source: Value(
            _parseEnum(RefPriceSource.values, m['source'], RefPriceSource.other),
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
