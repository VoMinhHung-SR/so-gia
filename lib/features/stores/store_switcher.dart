import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/store_repository.dart';

/// Compact store picker for the home AppBar (under the "Sổ giá" title).
class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storesStreamProvider);
    final currentId = ref.watch(currentStoreIdProvider);
    final style = Theme.of(context).textTheme.bodySmall;

    return storesAsync.when(
      loading: () => Text('…', style: style),
      error: (e, st) => Text('—', style: style),
      data: (stores) {
        if (stores.isEmpty) {
          return Text('Chưa có cửa hàng', style: style);
        }

        final selectedId = stores.any((s) => s.id == currentId)
            ? currentId
            : stores.first.id;
        final selected = stores.firstWhere((s) => s.id == selectedId);

        if (stores.length == 1) {
          return Text(selected.name, style: style);
        }

        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId,
            isDense: true,
            style: style?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            items: [
              for (final s in stores)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (id) {
              if (id != null) {
                ref.read(currentStoreIdProvider.notifier).select(id);
              }
            },
          ),
        );
      },
    );
  }
}
