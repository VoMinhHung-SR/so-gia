import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/settings.dart';
import '../../core/vietnamese.dart';
import '../../data/db/database_provider.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../data/repositories/store_repository.dart';
import '../../data/seed/demo_seed.dart';
import '../stores/store_switcher.dart';
import 'item_form_screen.dart';

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider =
    NotifierProvider<SearchQuery, String>(SearchQuery.new);

final filteredItemsProvider = Provider<AsyncValue<List<Item>>>((ref) {
  final query = ref.watch(searchQueryProvider);
  final itemsAsync = ref.watch(itemsStreamProvider);

  return itemsAsync.whenData((items) {
    final q = query.trim();
    if (q.isEmpty) return items;
    return items.where((item) {
      final bag = [
        item.resolvedName,
        item.brand ?? '',
        item.barcode ?? '',
        item.category ?? '',
        item.categoryId,
      ].join(' ');
      return matchesSearch(bag, q);
    }).toList();
  });
});

class ItemsListScreen extends ConsumerWidget {
  const ItemsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sổ giá'),
            StoreSwitcher(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nhà cung cấp',
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () => context.push('/suppliers'),
          ),
          IconButton(
            tooltip: 'So sánh đơn giá',
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => context.push('/compare'),
          ),
          IconButton(
            tooltip: 'Quét / tra mã',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/scan'),
          ),
          IconButton(
            tooltip: 'Sao lưu',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => context.push('/backup'),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (ref.watch(appSettingsProvider).needsBackupReminder)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                dense: true,
                title: const Text('Nên xuất sao lưu CSV'),
                subtitle: const Text('Đã > 7 ngày hoặc chưa từng xuất.'),
                trailing: TextButton(
                  onPressed: () => context.push('/backup'),
                  child: const Text('Sao lưu'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm tên, hãng, mã vạch…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyCatalog(ref: ref);
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ItemTile(item: list[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'weighed',
            onPressed: () => context.push(
              '/items/new',
              extra: const ItemFormArgs(forceWeighed: true),
            ),
            icon: const Icon(Icons.scale),
            label: const Text('Hàng cân ký'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => context.push('/items/new'),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mặt hàng'),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile({required this.item});

  final Item item;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  int? _latestPrice;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  @override
  void didUpdateWidget(covariant _ItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _loadPrice();
    }
  }

  Future<void> _loadPrice() async {
    final p = await ref
        .read(purchaseRepositoryProvider)
        .latestForItem(widget.item.id);
    if (mounted) setState(() => _latestPrice = p?.costPrice);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final subtitle = [
      if (item.brand != null && item.brand!.isNotEmpty) item.brand!,
      if (item.unitSize != null)
        '${_fmtSize(item.unitSize!)} ${_unitLabel(item.unitType)}',
      if (item.isWeighed) 'cân ký',
      if (item.barcode != null) item.barcode!,
    ].join(' · ');

    return ListTile(
      title: Text(item.resolvedName),
      subtitle: Text(subtitle.isEmpty ? '—' : subtitle),
      trailing: _latestPrice == null
          ? null
          : Text(
              formatVnd(_latestPrice!),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
      onTap: () => context.push('/items/${item.id}'),
    );
  }
}

String _fmtSize(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _unitLabel(UnitType t) => switch (t) {
      UnitType.ml => 'ml',
      UnitType.l => 'l',
      UnitType.g => 'g',
      UnitType.kg => 'kg',
      UnitType.piece => 'cái',
    };

class _EmptyCatalog extends StatefulWidget {
  const _EmptyCatalog({required this.ref});

  final WidgetRef ref;

  @override
  State<_EmptyCatalog> createState() => _EmptyCatalogState();
}

class _EmptyCatalogState extends State<_EmptyCatalog> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa có mặt hàng',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Quét mã, thêm mới, hoặc nạp bộ demo ~24 SKU để thử P4.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        final storeId =
                            widget.ref.read(currentStoreIdProvider);
                        final r = await DemoSeedService(
                          widget.ref.read(databaseProvider),
                        ).seedIfEmpty(storeId: storeId);
                        if (!context.mounted) return;
                        if (r == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã có dữ liệu')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã nạp ${r.items} mặt hàng · ${r.suppliers} NCC',
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.dataset),
              label: Text(_busy ? 'Đang nạp…' : 'Nạp dữ liệu demo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/scan'),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Quét / tra mã'),
            ),
          ],
        ),
      ),
    );
  }
}
