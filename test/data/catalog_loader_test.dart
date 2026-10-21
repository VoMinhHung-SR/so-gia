import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/vietnamese.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';

/// Loads catalog JSON via File (no Flutter asset binder in unit tests).
Future<int> _loadCatalogFromFile(AppDatabase db, File file) async {
  final root = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final catalogVersion = root['catalog_version'] as int;
  final products = root['products'] as List<dynamic>;
  final now = DateTime.now().toUtc();
  var upserted = 0;

  for (final entry in products) {
    final m = entry as Map<String, dynamic>;
    final id = m['id'] as String;
    final existing = await db.getCatalogRowById(id);
    if (existing?.source == CatalogSource.user) {
      continue;
    }
    final name = m['name'] as String;
    final unitSizeRaw = m['unit_size'];
    final unitSize = unitSizeRaw == null
        ? null
        : (unitSizeRaw is num ? unitSizeRaw.toDouble() : null);
    await db.upsertCatalogProduct(
      CatalogProductsCompanion(
        id: Value(id),
        barcode: Value(m['barcode'] as String?),
        name: Value(name),
        nameSearch: Value(removeDiacritics(name)),
        brand: Value(m['brand'] as String?),
        unitSize: Value(unitSize),
        unitType: Value(
          UnitType.values.firstWhere(
            (e) => e.name == m['unit_type'],
            orElse: () => UnitType.piece,
          ),
        ),
        categoryId: Value(m['category_id'] as String),
        isWeighed: Value(m['is_weighed'] as bool),
        source: const Value(CatalogSource.seed),
        catalogVersion: Value(catalogVersion),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
      ),
    );
    upserted++;
  }
  return upserted;
}

void main() {
  test('catalog asset has ≥150 SKUs, stable ids, no duplicate barcodes', () async {
    final file = File('assets/catalog/catalog_v1.json');
    expect(file.existsSync(), isTrue);
    final root = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final products = root['products'] as List<dynamic>;
    expect(root['catalog_version'], greaterThanOrEqualTo(2));
    expect(products.length, greaterThanOrEqualTo(150));

    final ids = <String>{};
    final barcodes = <String>{};
    for (final entry in products) {
      final m = entry as Map<String, dynamic>;
      final id = m['id'] as String;
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      expect(m['category_id'], isNotEmpty);
      expect(m['unit_type'], isNotEmpty);
      final barcode = m['barcode'] as String?;
      if (barcode != null && barcode.isNotEmpty) {
        expect(barcodes.add(barcode), isTrue, reason: 'duplicate barcode $barcode');
      }
    }
    // P7 sample ids must survive rebuild
    expect(ids.contains('c7a00001-0000-4000-8000-000000000001'), isTrue);
  });

  test('starter packs reference existing catalog ids', () async {
    final catalog = jsonDecode(
      await File('assets/catalog/catalog_v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final ids = {
      for (final p in catalog['products'] as List<dynamic>)
        (p as Map<String, dynamic>)['id'] as String,
    };

    final packsRoot = jsonDecode(
      await File('assets/catalog/starter_packs.json').readAsString(),
    ) as Map<String, dynamic>;
    final packs = packsRoot['packs'] as List<dynamic>;
    expect(packs.length, greaterThanOrEqualTo(3));

    final byId = {
      for (final p in packs) (p as Map<String, dynamic>)['id'] as String: p,
    };
    expect(byId.containsKey('tap-hoa'), isTrue);
    expect(byId.containsKey('rau-cu-thit'), isTrue);
    expect(byId.containsKey('sieu-thi-mini'), isTrue);

    for (final pack in packs) {
      final m = pack as Map<String, dynamic>;
      for (final item in (m['items'] as List<dynamic>? ?? const [])) {
        final cid = (item as Map<String, dynamic>)['catalog_id'] as String;
        expect(ids.contains(cid), isTrue, reason: 'missing $cid in ${m['id']}');
      }
    }
  });

  test('loader upsert skips user rows and bumps seed version', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final file = File('assets/catalog/catalog_v1.json');
    final root = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final first = (root['products'] as List).first as Map<String, dynamic>;
    final id = first['id'] as String;
    final now = DateTime.now().toUtc();

    await db.upsertCatalogProduct(
      CatalogProductsCompanion.insert(
        id: id,
        name: 'Tên user giữ nguyên',
        nameSearch: 'ten user giu nguyen',
        unitType: UnitType.piece,
        categoryId: first['category_id'] as String,
        source: CatalogSource.user,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final upserted = await _loadCatalogFromFile(db, file);
    expect(upserted, greaterThanOrEqualTo(149));

    final userRow = await db.getCatalogRowById(id);
    expect(userRow!.source, CatalogSource.user);
    expect(userRow.name, 'Tên user giữ nguyên');

    final other = (root['products'] as List)[1] as Map<String, dynamic>;
    final seedRow = await db.getCatalogRowById(other['id'] as String);
    expect(seedRow!.source, CatalogSource.seed);
    expect(seedRow.catalogVersion, root['catalog_version']);
  });

  test('starter pack replace writes DB rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final catalog = jsonDecode(
      await File('assets/catalog/catalog_v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final products = catalog['products'] as List<dynamic>;
    final a = products[0] as Map<String, dynamic>;
    final b = products[1] as Map<String, dynamic>;
    final now = DateTime.now().toUtc();

    for (final m in [a, b]) {
      await db.upsertCatalogProduct(
        CatalogProductsCompanion.insert(
          id: m['id'] as String,
          name: m['name'] as String,
          nameSearch: removeDiacritics(m['name'] as String),
          unitType: UnitType.kg,
          categoryId: m['category_id'] as String,
          source: CatalogSource.seed,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await db.upsertStarterPack(
      StarterPacksCompanion.insert(
        id: 'tap-hoa',
        name: 'Tạp hóa',
        description: const Value('test'),
      ),
    );
    await db.replaceStarterPackItems(
      packId: 'tap-hoa',
      items: [
        (catalogId: a['id'] as String, defaultSelected: true),
        (catalogId: b['id'] as String, defaultSelected: false),
      ],
    );

    final items = await db.listStarterPackItems('tap-hoa');
    expect(items, hasLength(2));
    expect(items.where((e) => e.defaultSelected), hasLength(1));
  });
}
