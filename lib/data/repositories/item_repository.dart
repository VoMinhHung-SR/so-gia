import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/vietnamese.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../db/tables.dart'; // UnitType, ItemSource
import '../off/open_food_facts_client.dart';

export '../db/app_database.dart' show Item, Purchase;

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
  return ref.watch(databaseProvider).watchActiveItems();
});

class ItemRepository {
  ItemRepository(this._db, this._off);

  final AppDatabase _db;
  final OpenFoodFactsClient _off;

  Stream<List<Item>> watchItems() => _db.watchActiveItems();

  Future<List<Item>> search(String query) async {
    final all = await _db.listActiveItems();
    final q = query.trim();
    if (q.isEmpty) return all;

    // Exact barcode hit first.
    final byBarcode = await _db.getItemByBarcode(q);
    if (byBarcode != null) return [byBarcode];

    return all.where((item) {
      final bag = [
        item.name,
        item.brand ?? '',
        item.barcode ?? '',
        item.category ?? '',
      ].join(' ');
      return matchesSearch(bag, q);
    }).toList();
  }

  Future<Item?> getById(String id) => _db.getItemById(id);

  Future<Item?> getByBarcode(String barcode) => _db.getItemByBarcode(barcode);

  Future<Item> saveItem({
    String? id,
    String? barcode,
    required String name,
    String? brand,
    double? unitSize,
    required UnitType unitType,
    String? category,
    bool isWeighed = false,
    ItemSource source = ItemSource.manual,
    String? imageUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final itemId = id ?? newId();
    final existing = id == null ? null : await _db.getItemById(id);

    final row = ItemsCompanion(
      id: Value(itemId),
      barcode: Value(barcode?.trim().isEmpty == true ? null : barcode?.trim()),
      name: Value(name.trim()),
      brand: Value(brand?.trim().isEmpty == true ? null : brand?.trim()),
      unitSize: Value(unitSize),
      unitType: Value(unitType),
      category: Value(category?.trim().isEmpty == true ? null : category?.trim()),
      isWeighed: Value(isWeighed),
      source: Value(source),
      imageUrl: Value(imageUrl),
      createdAt: Value(existing?.createdAt ?? now),
      updatedAt: Value(now),
      deletedAt: const Value(null),
    );
    await _db.upsertItem(row);
    return (await _db.getItemById(itemId))!;
  }

  /// After a barcode read: local hit, else OFF prefill map, else empty draft.
  Future<BarcodeResolveResult> resolveBarcode(String barcode) async {
    final code = barcode.trim();
    final local = await _db.getItemByBarcode(code);
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
