import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vietnamese.dart';
import '../catalog/catalog_loader.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../models/store_item_view.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(databaseProvider));
});

final seedCatalogLoadedProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  return loadSeedCatalog(db);
});

class CatalogSearchResult {
  const CatalogSearchResult({
    required this.inStore,
    required this.inCatalog,
  });

  final List<Item> inStore;
  final List<CatalogProduct> inCatalog;
}

class CatalogRepository {
  CatalogRepository(this._db);

  final AppDatabase _db;

  Future<CatalogSearchResult> search({
    required String storeId,
    required String query,
  }) async {
    final q = query.trim();
    final storeItems = await _db.listActiveItems(storeId);
    final inStore = q.isEmpty
        ? storeItems
        : storeItems.where((item) {
            final bag = [
              item.resolvedName,
              item.brand ?? '',
              item.barcode ?? '',
              item.category ?? '',
              item.categoryId,
            ].join(' ');
            return matchesSearchTokens(bag, q);
          }).toList();

    final storeCatalogIds = storeItems.map((e) => e.catalogId).toSet();
    final catalogHits = await _db.searchCatalog(q);
    final inCatalog = catalogHits
        .where((p) => !storeCatalogIds.contains(p.id))
        .toList();

    return CatalogSearchResult(inStore: inStore, inCatalog: inCatalog);
  }

  Future<Item> addToStore({
    required String storeId,
    required String catalogId,
  }) {
    return _db.addCatalogToStore(storeId: storeId, catalogId: catalogId);
  }

  Future<void> undoAddToStore(String storeItemId) {
    return _db.softDeleteItem(storeItemId);
  }

  Future<List<CatalogProduct>> suggestDuplicates(String name, {int limit = 5}) {
    return _db.searchCatalog(name, limit: limit);
  }

  Future<CatalogProduct?> byBarcode(String barcode) {
    return _db.getCatalogByBarcode(barcode);
  }
}
