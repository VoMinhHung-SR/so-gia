import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../db/tables.dart';

final refPriceRepositoryProvider = Provider<RefPriceRepository>((ref) {
  return RefPriceRepository(ref.watch(databaseProvider));
});

final latestRefPricesProvider =
    StreamProvider.autoDispose.family<List<RefPrice>, String>((ref, itemId) {
  return ref.watch(refPriceRepositoryProvider).watchForItem(itemId);
});

class RefPriceRepository {
  RefPriceRepository(this._db);

  final AppDatabase _db;

  Stream<List<RefPrice>> watchForItem(String itemId) =>
      _db.watchRefPricesForItem(itemId);

  Future<RefPrice?> latestForItem(String itemId) =>
      _db.latestRefPriceForItem(itemId);

  Future<RefPrice> save({
    required String itemId,
    required RefPriceSource source,
    required int price,
    double? unitSize,
    String? url,
    String? note,
    DateTime? observedAt,
  }) async {
    final id = newId();
    final at = (observedAt ?? DateTime.now()).toUtc();
    await _db.insertRefPrice(
      RefPricesCompanion.insert(
        id: id,
        itemId: itemId,
        source: source,
        price: price,
        unitSize: Value(unitSize),
        url: Value(url),
        observedAt: at,
        note: Value(note),
      ),
    );
    return (await _db.listRefPricesForItem(itemId))
        .firstWhere((e) => e.id == id);
  }
}
