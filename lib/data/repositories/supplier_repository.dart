import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'store_repository.dart';

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(databaseProvider));
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  return ref.watch(databaseProvider).watchActiveSuppliers(storeId);
});

class SupplierRepository {
  SupplierRepository(this._db);

  final AppDatabase _db;

  Stream<List<Supplier>> watchAll(String storeId) =>
      _db.watchActiveSuppliers(storeId);

  Future<List<Supplier>> listAll(String storeId) =>
      _db.listActiveSuppliers(storeId);

  Future<Supplier?> getById(String id) => _db.getSupplierById(id);

  Future<Supplier> save({
    required String storeId,
    String? id,
    required String name,
    String? phone,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final supplierId = id ?? newId();
    final existing = id == null ? null : await _db.getSupplierById(id);

    await _db.upsertSupplier(
      SuppliersCompanion(
        id: Value(supplierId),
        storeId: Value(storeId),
        name: Value(name.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
        note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
      ),
    );
    return (await _db.getSupplierById(supplierId))!;
  }

  Future<void> softDelete(String id) => _db.softDeleteSupplier(id);
}
