import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../db/tables.dart';

export '../db/app_database.dart' show Store;

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(ref.watch(databaseProvider));
});

final storesStreamProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(databaseProvider).watchActiveStores();
});

/// Currently selected store id (SharedPreferences-backed).
final currentStoreIdProvider =
    NotifierProvider<CurrentStoreId, String>(CurrentStoreId.new);

class CurrentStoreId extends Notifier<String> {
  @override
  String build() {
    final settings = ref.watch(appSettingsProvider);
    final saved = settings.currentStoreId;
    if (saved != null && saved.isNotEmpty) return saved;
    return kDefaultStoreId;
  }

  Future<void> select(String storeId) async {
    await ref.read(appSettingsProvider).setCurrentStoreId(storeId);
    state = storeId;
  }
}

final currentStoreProvider = Provider<AsyncValue<Store?>>((ref) {
  final id = ref.watch(currentStoreIdProvider);
  final stores = ref.watch(storesStreamProvider);
  return stores.whenData((list) {
    for (final s in list) {
      if (s.id == id) return s;
    }
    return list.isEmpty ? null : list.first;
  });
});

class StoreRepository {
  StoreRepository(this._db);

  final AppDatabase _db;

  Stream<List<Store>> watchAll() => _db.watchActiveStores();

  Future<List<Store>> listAll() => _db.listActiveStores();

  Future<Store?> getById(String id) => _db.getStoreById(id);

  Future<Store> create({
    required String name,
    String? type,
  }) {
    return _db.createStore(name: name, type: type);
  }

  Future<List<StarterPack>> listStarterPacks() => _db.listStarterPacks();

  Future<List<StoreCreatePreviewRow>> previewStarterPack(String packId) async {
    final items = await _db.listStarterPackItems(packId);
    return _previewFromCatalogIds(
      items.map(
        (e) => (catalogId: e.catalogId, defaultSelected: e.defaultSelected),
      ),
    );
  }

  Future<List<StoreCreatePreviewRow>> previewStoreItems(String storeId) async {
    final rows = await _db.listActiveStoreItemRows(storeId);
    return _previewFromCatalogIds(
      rows.map((e) => (catalogId: e.catalogId, defaultSelected: true)),
    );
  }

  Future<List<StoreCreatePreviewRow>> _previewFromCatalogIds(
    Iterable<({String catalogId, bool defaultSelected})> entries,
  ) async {
    final categories = {
      for (final c in await _db.listCategories()) c.id: c,
    };
    final out = <StoreCreatePreviewRow>[];
    for (final e in entries) {
      final product = await _db.getCatalogRowById(e.catalogId);
      if (product == null || product.deletedAt != null) continue;
      final cat = categories[product.categoryId];
      out.add(
        StoreCreatePreviewRow(
          catalogId: product.id,
          name: product.name,
          categoryId: product.categoryId,
          categoryName: cat?.name ?? product.categoryId,
          categorySort: cat?.sort ?? 999,
          defaultSelected: e.defaultSelected,
        ),
      );
    }
    out.sort((a, b) {
      final byCat = a.categorySort.compareTo(b.categorySort);
      if (byCat != 0) return byCat;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  Future<Store> createFromStarterPack({
    required String name,
    String? type,
    required Iterable<String> catalogIds,
  }) {
    return _db.createStoreWithCatalogIds(
      name: name,
      type: type,
      catalogIds: catalogIds,
    );
  }

  Future<Store> cloneStore({
    required String sourceStoreId,
    required String name,
    String? type,
    required Iterable<String> catalogIds,
    bool copySuppliers = false,
    bool copyMargins = false,
  }) {
    return _db.cloneStore(
      sourceStoreId: sourceStoreId,
      name: name,
      type: type,
      catalogIds: catalogIds,
      copySuppliers: copySuppliers,
      copyMargins: copyMargins,
    );
  }
}

class StoreCreatePreviewRow {
  const StoreCreatePreviewRow({
    required this.catalogId,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.categorySort,
    required this.defaultSelected,
  });

  final String catalogId;
  final String name;
  final String categoryId;
  final String categoryName;
  final int categorySort;
  final bool defaultSelected;
}
