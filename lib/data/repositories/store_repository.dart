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
}
