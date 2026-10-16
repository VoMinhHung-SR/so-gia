import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/pricing.dart';
import '../../core/settings.dart';
import '../../data/repositories/sell_price_repository.dart';

class SellPriceCalculator extends ConsumerStatefulWidget {
  const SellPriceCalculator({
    super.key,
    required this.itemId,
    required this.costPrice,
    required this.category,
    this.currentSellPrice,
  });

  final String itemId;
  final int costPrice;
  final String? category;
  final int? currentSellPrice;

  @override
  ConsumerState<SellPriceCalculator> createState() =>
      _SellPriceCalculatorState();
}

class _SellPriceCalculatorState extends ConsumerState<SellPriceCalculator> {
  TextEditingController? _markupCtrl;
  int _step = 500;
  RoundMode _mode = RoundMode.up;
  bool _saving = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final settings = ref.read(appSettingsProvider);
    _step = settings.roundStep;
    _mode = settings.roundMode;
    final pct = settings.markupForCategory(widget.category);
    _markupCtrl = TextEditingController(text: pct.toStringAsFixed(0));
    _ready = true;
  }

  @override
  void dispose() {
    _markupCtrl?.dispose();
    super.dispose();
  }

  double get _markupPct =>
      double.tryParse(_markupCtrl?.text.replaceAll(',', '.') ?? '') ?? 0;

  int get _suggested => suggestedSellPrice(
        costPrice: widget.costPrice,
        markupPct: _markupPct,
        step: _step,
        mode: _mode,
      );

  Future<void> _apply() async {
    setState(() => _saving = true);
    try {
      await ref.read(sellPriceRepositoryProvider).apply(
            itemId: widget.itemId,
            price: _suggested,
            marginPct: _markupPct,
          );
      if (!mounted) return;
      ref.invalidate(currentSellProvider(widget.itemId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã áp dụng giá bán ${formatVnd(_suggested)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _markupCtrl == null) {
      return const SizedBox.shrink();
    }

    final sell = _suggested;
    final profit = profitPerUnit(sell, widget.costPrice);
    final margin = marginOnSellPct(sell, widget.costPrice);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Máy tính giá bán',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Giá nhập: ${formatVnd(widget.costPrice)}'
              '${widget.currentSellPrice == null ? '' : ' · Đang bán: ${formatVnd(widget.currentSellPrice!)}'}',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _markupCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '% lời trên giá nhập (markup)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Làm tròn 500đ'),
                  selected: _step == 500,
                  onSelected: (_) => setState(() => _step = 500),
                ),
                ChoiceChip(
                  label: const Text('1.000đ'),
                  selected: _step == 1000,
                  onSelected: (_) => setState(() => _step = 1000),
                ),
                ChoiceChip(
                  label: Text(
                    _mode == RoundMode.up ? 'Làm tròn lên' : 'Gần nhất',
                  ),
                  selected: true,
                  onSelected: (_) => setState(() {
                    _mode = _mode == RoundMode.up
                        ? RoundMode.nearest
                        : RoundMode.up;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Gợi ý: ${formatVnd(sell)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Lời/đơn vị ${formatVnd(profit)} · biên trên giá bán ${margin.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving || widget.costPrice <= 0 ? null : _apply,
              child: Text(_saving ? 'Đang lưu…' : 'Áp dụng giá bán'),
            ),
          ],
        ),
      ),
    );
  }
}
