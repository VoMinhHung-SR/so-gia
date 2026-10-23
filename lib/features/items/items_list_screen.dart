import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../core/settings.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/db/tables.dart';
import '../../data/ref/supermarket_sources.dart';
import '../../data/repositories/catalog_repository.dart';
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

final catalogSearchProvider =
    FutureProvider.autoDispose<CatalogSearchResult?>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return null;
  final storeId = ref.watch(currentStoreIdProvider);
  return ref.read(catalogRepositoryProvider).search(
        storeId: storeId,
        query: query,
      );
});

class ItemsListScreen extends ConsumerWidget {
  const ItemsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(seedCatalogLoadedProvider);

    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

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
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Card(
                color: colors.errorContainer,
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
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.outlineVariant,
                  width: 1,
                ),
              ),
              child: TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm tên, hãng, mã vạch…',
                  prefixIcon: Icon(Icons.search, color: colors.primary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (v) => ref.read(searchQueryProvider.notifier).set(v),
              ),
            ),
          ),
          Expanded(
            child: searching
                ? _CatalogSearchBody(query: query)
                : _StoreItemsBody(ref: ref),
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
            label: const Text('Tạo hàng mới'),
          ),
        ],
      ),
    );
  }
}

class _StoreItemsBody extends ConsumerWidget {
  const _StoreItemsBody({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final itemsAsync = ref.watch(itemsStreamProvider);

    return itemsAsync.when(
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
    );
  }
}

class _CatalogSearchBody extends ConsumerWidget {
  const _CatalogSearchBody({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchAsync = ref.watch(catalogSearchProvider);

    return searchAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tìm kiếm: $e')),
      data: (result) {
        if (result == null) {
          return const SizedBox.shrink();
        }
        if (result.inStore.isEmpty && result.inCatalog.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Không có kết quả cho “$query”',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView(
          children: [
            if (result.inStore.isNotEmpty) ...[
              _SectionHeader(title: 'Trong cửa hàng'),
              ...result.inStore.map((item) => _ItemTile(item: item)),
              const Divider(height: 1),
            ],
            if (result.inCatalog.isNotEmpty) ...[
              _SectionHeader(title: 'Trong danh mục'),
              ...result.inCatalog.map(
                (p) => _CatalogProductTile(product: p),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _CatalogProductTile extends ConsumerStatefulWidget {
  const _CatalogProductTile({required this.product});

  final CatalogProduct product;

  @override
  ConsumerState<_CatalogProductTile> createState() =>
      _CatalogProductTileState();
}

class _CatalogProductTileState extends ConsumerState<_CatalogProductTile> {
  bool _adding = false;

  Future<void> _addToStore() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final storeId = ref.read(currentStoreIdProvider);
      final item = await ref.read(catalogRepositoryProvider).addToStore(
            storeId: storeId,
            catalogId: widget.product.id,
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã thêm'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () {
              ref.read(catalogRepositoryProvider).undoAddToStore(item.id);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thêm được: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _openSupermarket(SupermarketSource source) async {
    final uri = source.searchUri(widget.product.name);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được ${source.label}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final subtitle = [
      if (p.brand != null && p.brand!.isNotEmpty) p.brand!,
      if (p.unitSize != null)
        '${_fmtSize(p.unitSize!)} ${_unitLabel(p.unitType)}',
      if (p.barcode != null && p.barcode!.isNotEmpty) p.barcode!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(p.name),
              subtitle: Text(subtitle.isEmpty ? '—' : subtitle),
              trailing: _adding
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Thêm vào cửa hàng',
                      icon: const Icon(Icons.add),
                      onPressed: _addToStore,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final s in kSupermarketSources)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _openSupermarket(s),
                      child: Text(s.label),
                    ),
                ],
              ),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              item.isWeighed ? Icons.scale : Icons.local_offer_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 18,
            ),
          ),
          title: Text(item.resolvedName),
          subtitle: Text(subtitle.isEmpty ? '—' : subtitle),
          trailing: _latestPrice == null
              ? null
              : Text(
                  formatVnd(_latestPrice!),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
          onTap: () => context.push('/items/${item.id}'),
        ),
      ),
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
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
                            final storeId = widget.ref.read(currentStoreIdProvider);
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
        ),
      ),
    );
  }
}
