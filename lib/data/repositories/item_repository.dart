import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/vietnamese.dart';
import '../db/app_database.dart';
import '../db/category_seed.dart';
import '../db/database_provider.dart';
import '../db/tables.dart';
import '../models/store_item_view.dart';
import '../off/open_food_facts_client.dart';
import 'store_repository.dart';

export '../models/store_item_view.dart' show Item;

final openFoodFactsClientProvider = Provider<OpenFoodFactsClient>((ref) {
  final client = OpenFoodFactsClient();
  ref.onDispose(client.close);
  return client;
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(
    ref.watch(databaseProvider),
    ref.watch(openFoodFactsClientProvider),
  );
});

final itemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  return ref.watch(databaseProvider).watchActiveItems(storeId);
});

class ItemRepository {
  ItemRepository(this._db, this._off);

  final AppDatabase _db;
  final OpenFoodFactsClient _off;

  Stream<List<Item>> watchItems(String storeId) =>
      _db.watchActiveItems(storeId);

  Future<List<Item>> search(String storeId, String query) async {
    final all = await _db.listActiveItems(storeId);
    final q = query.trim();
    if (q.isEmpty) return all;

    final byBarcode = await _db.getItemByBarcode(storeId, q);
    if (byBarcode != null) return [byBarcode];

    return all.where((item) {
      final bag = [
        item.resolvedName,
        item.brand ?? '',
        item.barcode ?? '',
        item.category ?? '',
        item.categoryId,
      ].join(' ');
      return matchesSearch(bag, q);
    }).toList();
  }

  Future<Item?> getById(String id) => _db.getItemById(id);

  Future<Item?> getByBarcode(String storeId, String barcode) =>
      _db.getItemByBarcode(storeId, barcode);

  Future<Item> saveItem({
    required String storeId,
    String? id,
    String? catalogId,
    String? barcode,
    required String name,
    String? brand,
    double? unitSize,
    required UnitType unitType,
    String? category,
    String? categoryId,
    String? displayName,
    bool isWeighed = false,
    CatalogSource source = CatalogSource.user,
  }) {
    final resolvedCategoryId =
        categoryId ?? mapLegacyCategoryId(category);
    return _db.saveStoreItem(
      storeId: storeId,
      storeItemId: id,
      catalogId: catalogId,
      barcode: barcode,
      name: name,
      brand: brand,
      unitSize: unitSize,
      unitType: unitType,
      categoryId: resolvedCategoryId,
      displayName: displayName,
      isWeighed: isWeighed,
      source: source,
    );
  }

  Future<BarcodeResolveResult> resolveBarcode(
    String storeId,
    String barcode,
  ) async {
    final code = barcode.trim();
    final local = await _db.getItemByBarcode(storeId, code);
    if (local != null) {
      return BarcodeResolveResult.foundLocal(local);
    }

    final off = await _off.fetchByBarcode(code);
    if (off != null && (off.name != null || off.brand != null)) {
      return BarcodeResolveResult.fromOff(off);
    }

    return BarcodeResolveResult.unknown(code);
  }

  Future<void> softDelete(String id) => _db.softDeleteItem(id);
}

sealed class BarcodeResolveResult {
  const BarcodeResolveResult();

  factory BarcodeResolveResult.foundLocal(Item item) = FoundLocal;
  factory BarcodeResolveResult.fromOff(OffProduct product) = PrefillFromOff;
  factory BarcodeResolveResult.unknown(String barcode) = UnknownBarcode;
}

class FoundLocal extends BarcodeResolveResult {
  const FoundLocal(this.item);
  final Item item;
}

class PrefillFromOff extends BarcodeResolveResult {
  const PrefillFromOff(this.product);
  final OffProduct product;
}

class UnknownBarcode extends BarcodeResolveResult {
  const UnknownBarcode(this.barcode);
  final String barcode;
}
