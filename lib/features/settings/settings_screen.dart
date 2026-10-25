import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pricing.dart';
import '../../core/settings.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/repositories/store_repository.dart';
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
      final storeId = ref.read(currentStoreIdProvider);
      final service = DemoSeedService(ref.read(databaseProvider));
      final result = force
          ? await service.seed(force: true, storeId: storeId)
          : await service.seedIfEmpty(storeId: storeId);
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('Giới thiệu / Nguồn dữ liệu'),
            subtitle: const Text('Open Food Facts (ODbL)'),
            onTap: () => context.push('/about-sources'),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            title: 'Dùng thử (P4)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Giao diện quầy',
            child: Column(
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Khác',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Sao lưu / khôi phục CSV'),
                  onTap: () => context.push('/backup'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Cài đặt làm giá',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _StoreCategoryMarginsSection(),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StoreCategoryMarginsSection extends ConsumerStatefulWidget {
  const _StoreCategoryMarginsSection();

  @override
  ConsumerState<_StoreCategoryMarginsSection> createState() =>
      _StoreCategoryMarginsSectionState();
}

class _StoreCategoryMarginsSectionState
    extends ConsumerState<_StoreCategoryMarginsSection> {
  List<Category>? _categories;
  Map<String, double> _margins = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final storeId = ref.read(currentStoreIdProvider);
    final categories = await db.listCategories();
    final rows = await db.listMarginsForStore(storeId);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _margins = {for (final r in rows) r.categoryId: r.marginPct};
      _loading = false;
    });
  }

  Future<void> _saveMargin(String categoryId, String text) async {
    final pct = double.tryParse(text.replaceAll(',', '.'));
    if (pct == null) return;
    final storeId = ref.read(currentStoreIdProvider);
    await ref.read(databaseProvider).upsertMargin(
          MarginByCategoryCompanion.insert(
            storeId: storeId,
            categoryId: categoryId,
            marginPct: pct,
          ),
        );
    setState(() => _margins[categoryId] = pct);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentStoreIdProvider, (prev, next) {
      if (prev != next) _load();
    });

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    final categories = _categories ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '% lời theo nhóm (cửa hàng hiện tại)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final c in categories)
          _MarginRow(
            key: ValueKey(c.id),
            label: c.name,
            initialPct: _margins[c.id]?.toStringAsFixed(0) ?? '',
            onSubmitted: (v) => _saveMargin(c.id, v),
          ),
      ],
    );
  }
}

class _MarginRow extends StatefulWidget {
  const _MarginRow({
    super.key,
    required this.label,
    required this.initialPct,
    required this.onSubmitted,
  });

  final String label;
  final String initialPct;
  final ValueChanged<String> onSubmitted;

  @override
  State<_MarginRow> createState() => _MarginRowState();
}

class _MarginRowState extends State<_MarginRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialPct);
  }

  @override
  void didUpdateWidget(covariant _MarginRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPct != widget.initialPct) {
      _ctrl.text = widget.initialPct;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 82,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.end,
              decoration: const InputDecoration(
                suffixText: '%',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              onSubmitted: widget.onSubmitted,
              onEditingComplete: () => widget.onSubmitted(_ctrl.text),
            ),
          ),
        ],
      ),
    );
  }
}
