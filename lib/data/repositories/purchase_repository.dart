import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(databaseProvider));
});

class SupplierPriceStat {
  const SupplierPriceStat({
    required this.supplierId,
    required this.supplierName,
    required this.latestPrice,
    required this.averagePrice,
    required this.count,
  });

  final String supplierId;
  final String supplierName;
  final int latestPrice;
  final double averagePrice;
  final int count;
}

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

  /// Latest cost + supplier for prefilling the entry form.
  Future<({int? costPrice, String? supplierId})> prefillForItem(
    String itemId,
  ) async {
    final latest = await _db.latestPurchaseForItem(itemId);
    return (costPrice: latest?.costPrice, supplierId: latest?.supplierId);
  }

  Future<List<SupplierPriceStat>> compareSuppliers(String itemId) async {
    final purchases = await _db.listPurchasesForItem(itemId);
    final bySupplier = <String, List<Purchase>>{};
    for (final p in purchases) {
      final sid = p.supplierId;
      if (sid == null) continue;
      bySupplier.putIfAbsent(sid, () => []).add(p);
    }

    final stats = <SupplierPriceStat>[];
    for (final entry in bySupplier.entries) {
      final list = entry.value
        ..sort((a, b) => b.date.compareTo(a.date));
      final supplier = await _db.getSupplierById(entry.key);
      if (supplier == null) continue;
      final avg =
          list.map((e) => e.costPrice).reduce((a, b) => a + b) / list.length;
      stats.add(
        SupplierPriceStat(
          supplierId: entry.key,
          supplierName: supplier.name,
          latestPrice: list.first.costPrice,
          averagePrice: avg,
          count: list.length,
        ),
      );
    }

    stats.sort((a, b) => a.latestPrice.compareTo(b.latestPrice));
    return stats;
  }
}
