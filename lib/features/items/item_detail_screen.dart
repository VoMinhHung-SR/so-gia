import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/pricing.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../data/repositories/sell_price_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../pricing/sell_price_calculator.dart';
import '../purchases/purchase_chart.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

final purchasesForItemProvider =
    StreamProvider.autoDispose.family<List<Purchase>, String>((ref, itemId) {
  return ref.watch(purchaseRepositoryProvider).watchForItem(itemId);
});

final itemByIdProvider =
    FutureProvider.autoDispose.family<Item?, String>((ref, itemId) {
  return ref.watch(itemRepositoryProvider).getById(itemId);
});

final supplierCompareProvider = FutureProvider.autoDispose
    .family<List<SupplierPriceStat>, String>((ref, itemId) {
  return ref.watch(purchaseRepositoryProvider).compareSuppliers(itemId);
});

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemByIdProvider(itemId));

    return itemAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Lỗi: $e')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Không tìm thấy')),
            body: const Center(child: Text('Mặt hàng không tồn tại.')),
          );
        }
        return _ItemDetailBody(item: item);
      },
    );
  }
}

class _ItemDetailBody extends ConsumerStatefulWidget {
  const _ItemDetailBody({required this.item});

  final Item item;

  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}

class _ItemDetailBodyState extends ConsumerState<_ItemDetailBody> {
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  DateTime _date = DateTime.now();
  String? _supplierId;
  bool _saving = false;
  bool _prefilled = false;
  int _chartDays = 90;

  @override
  void initState() {
    super.initState();
    _loadPrefill();
  }

  Future<void> _loadPrefill() async {
    final prefill =
        await ref.read(purchaseRepositoryProvider).prefillForItem(widget.item.id);
    if (!mounted) return;
    setState(() {
      if (prefill.costPrice != null) {
        _priceCtrl.text = prefill.costPrice.toString();
      }
      _supplierId = prefill.supplierId;
      _prefilled = true;
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePurchase() async {
    final price = parseVnd(_priceCtrl.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập giá hợp lệ (VD: 25000 hoặc 25k)')),
      );
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1;

    setState(() => _saving = true);
    try {
      await ref.read(purchaseRepositoryProvider).addPurchase(
            itemId: widget.item.id,
            costPrice: price,
            qty: qty,
            date: _date,
            supplierId: _supplierId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã ghi giá nhập ${formatVnd(price)}')),
      );
      ref.invalidate(itemByIdProvider(widget.item.id));
      ref.invalidate(supplierCompareProvider(widget.item.id));
      ref.invalidate(currentSellProvider(widget.item.id));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final purchases = ref.watch(purchasesForItemProvider(item.id));
    final suppliers = ref.watch(suppliersStreamProvider);
    final sellAsync = ref.watch(currentSellProvider(item.id));
    final compare = ref.watch(supplierCompareProvider(item.id));

    final meta = [
      if (item.brand != null) item.brand!,
      if (item.unitSize != null)
        '${item.unitSize} ${_unitLabel(item.unitType)}',
      if (item.isWeighed) 'cân ký',
      if (item.category != null) item.category!,
    ].join(' · ');

    final costForCalc = parseVnd(_priceCtrl.text) ??
        (purchases.asData?.value.isNotEmpty == true
            ? purchases.asData!.value.first.costPrice
            : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/items/${item.id}/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item.barcode != null)
            Text(
              'Mã: ${item.barcode}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta),
          ],
          if (costForCalc > 0) ...[
            const SizedBox(height: 8),
            Text(
              unitPriceLabels(
                price: costForCalc,
                unitSize: item.unitSize,
                unitType: item.unitType,
              ).join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Ghi giá nhập', style: Theme.of(context).textTheme.titleMedium),
          if (_prefilled)
            const Text(
              'Đã điền sẵn giá / NCC lần trước — sửa nếu khác.',
              style: TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 8),
          suppliers.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('NCC: $e'),
            data: (list) => DropdownButtonFormField<String?>(
              key: ValueKey('supplier-${_supplierId ?? 'none'}-$_prefilled'),
              initialValue: _supplierId,
              decoration: const InputDecoration(
                labelText: 'Nhà cung cấp',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— Không chọn —'),
                ),
                for (final s in list)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _supplierId = v),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Giá nhập (đ)',
              hintText: '25000 hoặc 25k',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Text(_dateFmt.format(_date)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _savePurchase,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu giá nhập'),
          ),
          const SizedBox(height: 24),
          sellAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (sell) => SellPriceCalculator(
              itemId: item.id,
              costPrice: costForCalc,
              category: item.category,
              currentSellPrice: sell?.price,
            ),
          ),
          const SizedBox(height: 24),
          Text('So sánh NCC', style: Theme.of(context).textTheme.titleMedium),
          compare.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (stats) {
              if (stats.isEmpty) {
                return const Text('Chưa có dữ liệu theo nhà cung cấp.');
              }
              return Column(
                children: [
                  for (var i = 0; i < stats.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: i == 0
                          ? const Icon(Icons.emoji_events, color: Colors.amber)
                          : Text('#${i + 1}'),
                      title: Text(stats[i].supplierName),
                      subtitle: Text(
                        'TB ${formatVnd(stats[i].averagePrice.round())}'
                        ' · ${stats[i].count} lần',
                      ),
                      trailing: Text(
                        formatVnd(stats[i].latestPrice),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Biểu đồ', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              for (final d in [30, 90, 365])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text('${d}n'),
                    selected: _chartDays == d,
                    onSelected: (_) => setState(() => _chartDays = d),
                  ),
                ),
            ],
          ),
          purchases.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (list) {
              final nameMap = <String, String>{
                for (final s in suppliers.asData?.value ?? []) s.id: s.name,
              };
              return PurchaseChart(
                purchases: list,
                supplierNames: nameMap,
                days: _chartDays,
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Lịch sử nhập', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          purchases.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Lỗi: $e'),
            data: (list) {
              if (list.isEmpty) {
                return const Text('Chưa có lần nhập nào.');
              }
              final nameMap = <String, String>{
                for (final s in suppliers.asData?.value ?? []) s.id: s.name,
              };
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatVnd(list[i].costPrice)),
                      subtitle: Text(
                        '${_dateFmt.format(list[i].date.toLocal())}'
                        ' · SL ${list[i].qty}'
                        '${list[i].supplierId == null ? '' : ' · ${nameMap[list[i].supplierId] ?? ''}'}',
                      ),
                      trailing: i + 1 < list.length
                          ? _DeltaChip(
                              current: list[i].costPrice,
                              previous: list[i + 1].costPrice,
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.current, required this.previous});

  final int current;
  final int previous;

  @override
  Widget build(BuildContext context) {
    final d = current - previous;
    if (d == 0) return const Text('=');
    final up = d > 0;
    return Text(
      '${up ? '▲' : '▼'} ${formatVnd(d.abs())}',
      style: TextStyle(
        color: up ? Colors.red.shade700 : Colors.green.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

String _unitLabel(UnitType t) => switch (t) {
      UnitType.ml => 'ml',
      UnitType.l => 'l',
      UnitType.g => 'g',
      UnitType.kg => 'kg',
      UnitType.piece => 'cái',
    };
