import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/vietnamese.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';
import 'package:so_gia/data/repositories/catalog_repository.dart';

void main() {
  test('seed catalog search finds dau an and add-to-store isolates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final file = File('assets/catalog/catalog_v1.json');
    expect(file.existsSync(), isTrue);
    final root = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final catalogVersion = root['catalog_version'] as int;
    final products = root['products'] as List<dynamic>;
    final now = DateTime.now().toUtc();

    for (final entry in products) {
      final m = entry as Map<String, dynamic>;
      final name = m['name'] as String;
      final unitSizeRaw = m['unit_size'];
      final unitSize = unitSizeRaw == null
          ? null
          : (unitSizeRaw is num ? unitSizeRaw.toDouble() : null);
      await db.upsertCatalogProduct(
        CatalogProductsCompanion.insert(
          id: m['id'] as String,
          barcode: Value(m['barcode'] as String?),
          name: name,
          nameSearch: removeDiacritics(name),
          brand: Value(m['brand'] as String?),
          unitSize: Value(unitSize),
          unitType: UnitType.values.firstWhere(
            (e) => e.name == m['unit_type'],
            orElse: () => UnitType.piece,
          ),
          categoryId: m['category_id'] as String,
          isWeighed: Value(m['is_weighed'] as bool),
          source: CatalogSource.seed,
          catalogVersion: Value(catalogVersion),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final repo = CatalogRepository(db);
    final result = await repo.search(storeId: kDefaultStoreId, query: 'dau an');
    expect(result.inCatalog, isNotEmpty);

    final first = result.inCatalog.first;
    final added = await repo.addToStore(
      storeId: kDefaultStoreId,
      catalogId: first.id,
    );
    expect(added.catalogId, first.id);

    final again = await repo.search(storeId: kDefaultStoreId, query: 'dau an');
    expect(again.inStore.any((i) => i.catalogId == first.id), isTrue);
    expect(again.inCatalog.any((p) => p.id == first.id), isFalse);

    await repo.undoAddToStore(added.id);
    final afterUndo =
        await repo.search(storeId: kDefaultStoreId, query: first.name);
    expect(afterUndo.inStore.any((i) => i.catalogId == first.id), isFalse);
  });

  test('pending supplements enqueue dedupes barcode', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final a = await db.enqueuePendingSupplement(
      storeId: kDefaultStoreId,
      barcode: '8939999000001',
    );
    final b = await db.enqueuePendingSupplement(
      storeId: kDefaultStoreId,
      barcode: '8939999000001',
    );
    expect(a.id, b.id);
    expect(await db.listPendingSupplements(kDefaultStoreId), hasLength(1));
  });
}
