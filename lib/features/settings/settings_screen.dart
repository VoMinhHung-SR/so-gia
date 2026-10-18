import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pricing.dart';
import '../../core/settings.dart';
import '../../data/db/database_provider.dart';
import '../../data/seed/demo_seed.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _markup;
  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _markup = TextEditingController(text: s.defaultMarkupPct.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _markup.dispose();
    super.dispose();
  }

  Future<void> _seedDemo({required bool force}) async {
    setState(() => _seeding = true);
    try {
      final service = DemoSeedService(ref.read(databaseProvider));
      final result = force
          ? await service.seed(force: true)
          : await service.seedIfEmpty();
      if (!mounted) return;
      if (result == null || (result.items == 0 && !force)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã có dữ liệu — dùng “Nạp lại (ghi thêm)” nếu muốn seed thêm.'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã nạp ${result.items} mặt hàng, ${result.suppliers} NCC, '
            '${result.purchases} lần nhập',
          ),
        ),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dùng thử (P4)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _seeding ? null : () => _seedDemo(force: false),
            icon: const Icon(Icons.dataset),
            label: Text(_seeding ? 'Đang nạp…' : 'Nạp dữ liệu demo (~24 SKU)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _seeding
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Nạp thêm demo?'),
                        content: const Text(
                          'Sẽ thêm bộ SKU/NCC mới vào DB hiện tại (không xóa dữ liệu cũ).',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Nạp thêm'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await _seedDemo(force: true);
                  },
            child: const Text('Nạp thêm (giữ dữ liệu cũ)'),
          ),
          const SizedBox(height: 8),
          Text(
            'Ghi trải nghiệm vào notes/field-trial.md trong repo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 32),
          Text('Giao diện quầy', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chữ lớn'),
            subtitle: const Text('Dễ đọc ngoài nắng / một tay'),
            value: settings.largeText,
            onChanged: (v) async {
              await settings.setLargeText(v);
              ref.read(uiPrefsProvider.notifier).bump();
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tương phản cao'),
            value: settings.highContrast,
            onChanged: (v) async {
              await settings.setHighContrast(v);
              ref.read(uiPrefsProvider.notifier).bump();
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mở app vào màn quét / tra mã'),
            subtitle: const Text('Áp dụng lần khởi động tiếp theo'),
            value: settings.startOnScan,
            onChanged: (v) async {
              await settings.setStartOnScan(v);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Sẽ áp dụng khi mở lại app'),
                ),
              );
            },
          ),
          const Divider(height: 32),
          TextField(
            controller: _markup,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '% lời mặc định (markup)',
              border: OutlineInputBorder(),
              helperText: 'Dùng khi nhóm hàng không khớp bảng gợi ý',
            ),
            onChanged: (v) {
              final n = double.tryParse(v.replaceAll(',', '.'));
              if (n != null) settings.setDefaultMarkupPct(n);
            },
          ),
          const SizedBox(height: 16),
          Text('Bước làm tròn', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('500đ'),
                selected: settings.roundStep == 500,
                onSelected: (_) async {
                  await settings.setRoundStep(500);
                  setState(() {});
                },
              ),
              ChoiceChip(
                label: const Text('1.000đ'),
                selected: settings.roundStep == 1000,
                onSelected: (_) async {
                  await settings.setRoundStep(1000);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Cách làm tròn', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Làm tròn lên'),
                selected: settings.roundMode == RoundMode.up,
                onSelected: (_) async {
                  await settings.setRoundMode(RoundMode.up);
                  setState(() {});
                },
              ),
              ChoiceChip(
                label: const Text('Gần nhất'),
                selected: settings.roundMode == RoundMode.nearest,
                onSelected: (_) async {
                  await settings.setRoundMode(RoundMode.nearest);
                  setState(() {});
                },
              ),
            ],
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Sao lưu / khôi phục CSV'),
            onTap: () => context.push('/backup'),
          ),
          const Divider(height: 32),
          Text(
            'Gợi ý theo nhóm hàng (cố định trong app)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final e in kDefaultCategoryMarkups.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              trailing: Text('${e.value.toStringAsFixed(0)}%'),
            ),
        ],
      ),
    );
  }
}
