import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';

final sellPriceRepositoryProvider = Provider<SellPriceRepository>((ref) {
  return SellPriceRepository(ref.watch(databaseProvider));
});

final currentSellProvider =
    FutureProvider.autoDispose.family<SellPrice?, String>((ref, itemId) {
  return ref.watch(sellPriceRepositoryProvider).current(itemId);
});

class SellPriceRepository {
  SellPriceRepository(this._db);

  final AppDatabase _db;

  Future<SellPrice?> current(String itemId) => _db.currentSellPrice(itemId);

  Stream<List<SellPrice>> watch(String itemId) => _db.watchSellPrices(itemId);

  Future<SellPrice> apply({
    required String itemId,
    required int price,
    required double marginPct,
    DateTime? effectiveFrom,
  }) async {
    final id = newId();
    final from = (effectiveFrom ?? DateTime.now()).toUtc();
    await _db.insertSellPrice(
      SellPricesCompanion.insert(
        id: id,
        itemId: itemId,
        price: price,
        marginPct: marginPct,
        effectiveFrom: from,
      ),
    );
    return (await _db.currentSellPrice(itemId))!;
  }
}
