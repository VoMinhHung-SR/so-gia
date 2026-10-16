import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/vietnamese.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/purchase_repository.dart';
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
        item.name,
        item.brand ?? '',
        item.barcode ?? '',
        item.category ?? '',
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
        title: const Text('Sổ giá'),
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
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  return const Center(
                    child: Text('Chưa có mặt hàng. Quét mã hoặc thêm mới.'),
                  );
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
      title: Text(item.name),
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
