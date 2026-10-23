import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_gia/app/app.dart';
import 'package:so_gia/core/settings.dart';
import 'package:so_gia/core/vietnamese.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/database_provider.dart';
import 'package:so_gia/data/db/tables.dart';
import 'package:so_gia/data/repositories/catalog_repository.dart';
import 'package:so_gia/data/repositories/item_repository.dart';
import 'package:so_gia/data/repositories/store_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P9 asset catalog ≥150 and packs valid', () async {
    final catalog = jsonDecode(
      await File('assets/catalog/catalog_v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final products = catalog['products'] as List<dynamic>;
    expect(products.length, greaterThanOrEqualTo(150));
    expect(catalog['catalog_version'], greaterThanOrEqualTo(2));

    final packs = jsonDecode(
      await File('assets/catalog/starter_packs.json').readAsString(),
    ) as Map<String, dynamic>;
    final packList = packs['packs'] as List<dynamic>;
    expect(packList.length, greaterThanOrEqualTo(3));
  });

  test('P9 repo: search + add-to-store against seeded catalog', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final root = jsonDecode(
      await File('assets/catalog/catalog_v1.json').readAsString(),
    ) as Map<String, dynamic>;
    final version = root['catalog_version'] as int;
    final now = DateTime.now().toUtc();

    // Seed a small subset for speed (oil + veggies).
    final subset = (root['products'] as List<dynamic>).where((e) {
      final m = e as Map<String, dynamic>;
      final cat = m['category_id'] as String;
      return cat == 'dau-an' || cat == 'rau-cu';
    }).take(12);

    for (final entry in subset) {
      final m = entry as Map<String, dynamic>;
      final name = m['name'] as String;
      final unitSizeRaw = m['unit_size'];
      await db.upsertCatalogProduct(
        CatalogProductsCompanion.insert(
          id: m['id'] as String,
          name: name,
          nameSearch: removeDiacritics(name),
          brand: Value(m['brand'] as String?),
          unitSize: Value(
            unitSizeRaw == null ? null : (unitSizeRaw as num).toDouble(),
          ),
          unitType: UnitType.values.firstWhere(
            (e) => e.name == m['unit_type'],
            orElse: () => UnitType.piece,
          ),
          categoryId: m['category_id'] as String,
          isWeighed: Value(m['is_weighed'] as bool),
          source: CatalogSource.seed,
          catalogVersion: Value(version),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final repo = CatalogRepository(db);
    final hit = await repo.search(storeId: kDefaultStoreId, query: 'dau an');
    expect(hit.inCatalog, isNotEmpty);

    final added = await repo.addToStore(
      storeId: kDefaultStoreId,
      catalogId: hit.inCatalog.first.id,
    );
    expect(added.catalogId, hit.inCatalog.first.id);

    final again = await repo.search(storeId: kDefaultStoreId, query: 'dau an');
    expect(again.inStore.any((i) => i.catalogId == added.catalogId), isTrue);
  });

  testWidgets('P9: settings opens Nguồn dữ liệu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime.utc(2026, 1, 1);
    final defaultStore = Store(
      id: kDefaultStoreId,
      name: kDefaultStoreName,
      type: null,
      defaultMarginPct: 20,
      roundingStep: 500,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          seedCatalogLoadedProvider.overrideWith((ref) async => 0),
          itemsStreamProvider.overrideWith((ref) => Stream.value(const [])),
          storesStreamProvider.overrideWith(
            (ref) => Stream.value([defaultStore]),
          ),
        ],
        child: const SoGiaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sổ giá'), findsWidgets);

    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cài đặt'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Giới thiệu / Nguồn dữ liệu'),
      find.byType(ListView).first,
      const Offset(0, -80),
    );
    await tester.tap(find.text('Giới thiệu / Nguồn dữ liệu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nguồn dữ liệu'), findsOneWidget);
    expect(find.textContaining('Open Food Facts'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
