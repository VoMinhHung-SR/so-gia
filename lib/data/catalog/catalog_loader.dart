import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/vietnamese.dart';
import '../db/app_database.dart';
import '../db/tables.dart';

const _kCatalogAssetPath = 'assets/catalog/catalog_v1.json';

UnitType _parseUnitType(String raw) {
  return UnitType.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => UnitType.piece,
  );
}

/// Loads bundled seed catalog JSON and upserts [CatalogProducts] rows.
///
/// Skips rows whose existing DB [CatalogSource] is [CatalogSource.user].
/// Overwrites or inserts when missing or [CatalogSource.seed] / [CatalogSource.off].
Future<int> loadSeedCatalog(AppDatabase db) async {
  final jsonText = await rootBundle.loadString(_kCatalogAssetPath);
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
