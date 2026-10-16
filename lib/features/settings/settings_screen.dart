import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pricing.dart';
import '../../core/settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _markup;

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
