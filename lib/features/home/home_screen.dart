import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(databaseReadyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sổ giá')),
      body: Center(
        child: ready.when(
          data: (ok) => Text(ok ? 'Dữ liệu sẵn sàng (offline)' : 'Lỗi dữ liệu'),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Không mở được dữ liệu: $e'),
        ),
      ),
    );
  }
}
