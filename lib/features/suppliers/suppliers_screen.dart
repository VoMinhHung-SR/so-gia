import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/supplier_repository.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nhà cung cấp')),
      body: suppliers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Chưa có nhà cung cấp.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _SupplierTile(supplier: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm NCC'),
      ),
    );
  }
}

class _SupplierTile extends ConsumerWidget {
  const _SupplierTile({required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(supplier.name),
      subtitle: Text(
        [
          if (supplier.phone != null) supplier.phone!,
          if (supplier.note != null) supplier.note!,
        ].join(' · ').ifEmpty('—'),
      ),
      trailing: supplier.phone == null
          ? null
          : IconButton(
              tooltip: 'Gọi',
              icon: const Icon(Icons.phone),
              onPressed: () => _dial(supplier.phone!),
            ),
      onTap: () => _openForm(context, ref, existing: supplier),
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xóa nhà cung cấp?'),
            content: Text(supplier.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(supplierRepositoryProvider).softDelete(supplier.id);
        }
      },
    );
  }
}

Future<void> _dial(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), ''));
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  Supplier? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'Thêm nhà cung cấp' : 'Sửa nhà cung cấp',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(supplierRepositoryProvider).save(
                      id: existing?.id,
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      note: noteCtrl.text,
                    );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      );
    },
  );

  nameCtrl.dispose();
  phoneCtrl.dispose();
  noteCtrl.dispose();
  if (saved == true) {
    // stream auto-updates
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
