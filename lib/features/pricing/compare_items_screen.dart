import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/pricing.dart';
import '../../core/vietnamese.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/purchase_repository.dart';

/// Compare unit prices for items that share a category (or all if blank).
class CompareItemsScreen extends ConsumerStatefulWidget {
  const CompareItemsScreen({super.key, this.category});

  final String? category;

  @override
  ConsumerState<CompareItemsScreen> createState() => _CompareItemsScreenState();
}

class _CompareItemsScreenState extends ConsumerState<CompareItemsScreen> {
  late final TextEditingController _cat;

  @override
  void initState() {
    super.initState();
    _cat = TextEditingController(text: widget.category ?? '');
  }

  @override
  void dispose() {
    _cat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('So sánh đơn giá')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _cat,
              decoration: const InputDecoration(
                labelText: 'Lọc nhóm hàng',
                hintText: 'VD: nước, rau',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                final q = _cat.text.trim();
                final filtered = q.isEmpty
                    ? items
                    : items
                        .where(
                          (i) => matchesSearch(i.category ?? i.name, q),
                        )
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Không có mặt hàng phù hợp.'));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return FutureBuilder(
                      future: ref
                          .read(purchaseRepositoryProvider)
                          .latestForItem(item.id),
                      builder: (context, snap) {
                        final price = snap.data?.costPrice;
                        final units = price == null
                            ? <String>[]
                            : unitPriceLabels(
                                price: price,
                                unitSize: item.unitSize,
                                unitType: item.unitType,
                              );
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              if (price != null) formatVnd(price),
                              ...units,
                            ].join(' · '),
                          ),
                          onTap: () => context.push('/items/${item.id}'),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
