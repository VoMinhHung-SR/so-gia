import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/store_repository.dart';
import '../items/item_form_screen.dart';

final pendingSupplementsStreamProvider =
    StreamProvider<List<PendingSupplement>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  return ref.watch(databaseProvider).watchPendingSupplements(storeId);
});

class PendingSupplementsScreen extends ConsumerWidget {
  const PendingSupplementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSupplementsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chờ bổ sung'),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không có mã chờ bổ sung.\n'
                  'Quét liên tục sẽ thêm mã chưa có trong danh mục.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _PendingRow(pending: list[i]),
          );
        },
      ),
    );
  }
}

class _PendingRow extends ConsumerStatefulWidget {
  const _PendingRow({required this.pending});

  final PendingSupplement pending;

  @override
  ConsumerState<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends ConsumerState<_PendingRow> {
  bool _busy = false;

  Future<void> _tryResolveAfterForm(String barcode) async {
    final storeId = ref.read(currentStoreIdProvider);
    final db = ref.read(databaseProvider);
    final pending = await db.findOpenPending(storeId, barcode);
    if (pending == null) return;

    final inStore = await db.getItemByBarcode(storeId, barcode);
    if (inStore != null) {
      await db.resolvePendingSupplement(pending.id);
    } else {
      final inCatalog = await db.getCatalogByBarcode(barcode);
      if (inCatalog != null) {
        await db.resolvePendingSupplement(pending.id);
      }
    }
  }

  Future<void> _lookupOff() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final storeId = ref.read(currentStoreIdProvider);
      final barcode = widget.pending.barcode;
      final result = await ref
          .read(itemRepositoryProvider)
          .resolveBarcode(storeId, barcode);
      if (!mounted) return;

      switch (result) {
        case FoundLocal(:final item):
          await ref
              .read(databaseProvider)
              .resolvePendingSupplement(widget.pending.id);
          if (!mounted) return;
          context.push('/items/${item.id}');
        case FoundCatalog(:final product):
          final item = await ref.read(catalogRepositoryProvider).addToStore(
                storeId: storeId,
                catalogId: product.id,
              );
          await ref
              .read(databaseProvider)
              .resolvePendingSupplement(widget.pending.id);
          if (!mounted) return;
          context.push('/items/${item.id}');
        case PrefillFromOff(:final product):
          if (!mounted) return;
          await context.push(
            '/items/new',
            extra: ItemFormArgs(prefillFromOff: product),
          );
          await _tryResolveAfterForm(barcode);
        case UnknownBarcode():
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OFF chưa có — thử điền tay')),
          );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualFill() async {
    final barcode = widget.pending.barcode;
    await context.push(
      '/items/new',
      extra: ItemFormArgs(prefillBarcode: barcode),
    );
    await _tryResolveAfterForm(barcode);
  }

  Future<void> _delete() async {
    await ref
        .read(databaseProvider)
        .deletePendingSupplement(widget.pending.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.pending.barcode),
      subtitle: Text(
        'Thêm ${ _formatWhen(widget.pending.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Wrap(
              spacing: 0,
              children: [
                TextButton(
                  onPressed: _lookupOff,
                  child: const Text('Tra OFF'),
                ),
                TextButton(
                  onPressed: _manualFill,
                  child: const Text('Điền tay'),
                ),
                IconButton(
                  tooltip: 'Xóa',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              ],
            ),
    );
  }
}

String _formatWhen(DateTime utc) {
  final local = utc.toLocal();
  return '${local.day}/${local.month} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}
