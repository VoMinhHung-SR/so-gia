import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/vietnamese.dart';
import '../db/app_database.dart';
import '../db/category_seed.dart';
import '../db/tables.dart';

const kCatalogAssetPath = 'assets/catalog/catalog_v1.json';
const kStarterPacksAssetPath = 'assets/catalog/starter_packs.json';

UnitType _parseUnitType(String raw) {
  return UnitType.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => UnitType.piece,
  );
}

/// Loads bundled seed catalog + starter packs.
///
/// Skips catalog rows whose existing DB [CatalogSource] is [CatalogSource.user].
/// Overwrites or inserts when missing or [CatalogSource.seed] / [CatalogSource.off].
Future<int> loadSeedCatalog(AppDatabase db) async {
  final catalogUpserted = await _loadCatalogProducts(db);
  await _loadStarterPacks(db);
  return catalogUpserted;
}

Future<int> _loadCatalogProducts(AppDatabase db) async {
  final jsonText = await rootBundle.loadString(kCatalogAssetPath);
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
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
    final barcode = m['barcode'] as String?;
    final brand = m['brand'] as String?;
    final unitSizeRaw = m['unit_size'];
    final unitSize = unitSizeRaw == null
        ? null
        : (unitSizeRaw is int ? unitSizeRaw.toDouble() : unitSizeRaw as num)
            .toDouble();
    final unitType = _parseUnitType(m['unit_type'] as String);
    final categoryId = m['category_id'] as String;
    final isWeighed = m['is_weighed'] as bool;
    final source = parseCatalogSource(m['source'] as String?);

    await db.upsertCatalogProduct(
      CatalogProductsCompanion(
        id: Value(id),
        barcode: Value(barcode),
        name: Value(name),
        nameSearch: Value(removeDiacritics(name)),
        brand: Value(brand),
        unitSize: Value(unitSize),
        unitType: Value(unitType),
        categoryId: Value(categoryId),
        isWeighed: Value(isWeighed),
        source: Value(source == CatalogSource.user ? CatalogSource.seed : source),
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

Future<void> _loadStarterPacks(AppDatabase db) async {
  final jsonText = await rootBundle.loadString(kStarterPacksAssetPath);
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  final packVersion = root['pack_version'] as int? ?? 1;
  final packs = root['packs'] as List<dynamic>;

  final byId = <String, Map<String, dynamic>>{};
  for (final entry in packs) {
    final m = entry as Map<String, dynamic>;
    byId[m['id'] as String] = m;
  }

  List<Map<String, dynamic>> resolveItems(Map<String, dynamic> pack) {
    final includes = pack['includes'] as List<dynamic>?;
    if (includes == null || includes.isEmpty) {
      return (pack['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
    }
    final merged = <String, Map<String, dynamic>>{};
    for (final rawId in includes) {
      final child = byId[rawId as String];
      if (child == null) continue;
      for (final item in resolveItems(child)) {
        merged[item['catalog_id'] as String] = item;
      }
    }
    for (final item in (pack['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()) {
      merged[item['catalog_id'] as String] = item;
    }
    return merged.values.toList();
  }

  for (final pack in byId.values) {
    final packId = pack['id'] as String;
    await db.upsertStarterPack(
      StarterPacksCompanion(
        id: Value(packId),
        name: Value(pack['name'] as String),
        description: Value(pack['description'] as String?),
        version: Value(packVersion),
      ),
    );
    await db.replaceStarterPackItems(
      packId: packId,
      items: resolveItems(pack).map((item) {
        return (
          catalogId: item['catalog_id'] as String,
          defaultSelected: item['default_selected'] as bool? ?? true,
        );
      }).toList(),
    );
  }
}
