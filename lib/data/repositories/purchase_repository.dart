import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(databaseProvider));
});

class PurchaseRepository {
  PurchaseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Purchase>> watchForItem(String itemId) =>
      _db.watchPurchasesForItem(itemId);

  Future<Purchase?> latestForItem(String itemId) =>
      _db.latestPurchaseForItem(itemId);

  Future<Purchase> addPurchase({
    required String itemId,
    required int costPrice,
    double qty = 1,
    DateTime? date,
    String? note,
    String? supplierId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = newId();
    final purchaseDate = (date ?? DateTime.now()).toUtc();

    await _db.insertPurchase(
      PurchasesCompanion.insert(
        id: id,
        itemId: itemId,
        supplierId: Value(supplierId),
        costPrice: costPrice,
        qty: Value(qty),
        date: purchaseDate,
        note: Value(note),
        createdAt: now,
        updatedAt: now,
      ),
    );

    return (await _db.listPurchasesForItem(itemId))
        .firstWhere((p) => p.id == id);
  }
}
