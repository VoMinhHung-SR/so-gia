import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_database.dart';
import '../../data/db/tables.dart';
import '../../data/off/open_food_facts_client.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/store_repository.dart';

class ItemFormArgs {
  const ItemFormArgs({
    this.editId,
    this.prefillBarcode,
    this.prefillFromOff,
    this.forceWeighed = false,
  });

  final String? editId;
  final String? prefillBarcode;
  final OffProduct? prefillFromOff;
  final bool forceWeighed;
}

class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.args = const ItemFormArgs()});

  final ItemFormArgs args;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _unitSize = TextEditingController();
  final _category = TextEditingController();

  UnitType _unitType = UnitType.piece;
  bool _isWeighed = false;
  CatalogSource _source = CatalogSource.user;
  String? _existingId;
  String? _catalogId;
  bool _loading = false;
  bool _saving = false;
  Timer? _duplicateDebounce;
  List<CatalogProduct> _duplicateSuggestions = [];
  bool _loadingDuplicates = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
    _bootstrap();
  }

  void _onNameChanged() {
    if (_existingId != null) return;
    _duplicateDebounce?.cancel();
    _duplicateDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchDuplicateSuggestions(_name.text);
    });
  }

  Future<void> _fetchDuplicateSuggestions(String raw) async {
    final name = raw.trim();
    if (name.length < 2) {
      if (mounted) setState(() => _duplicateSuggestions = []);
      return;
    }
    setState(() => _loadingDuplicates = true);
    try {
      final hits = await ref
          .read(catalogRepositoryProvider)
          .suggestDuplicates(name, limit: 5);
      if (!mounted) return;
      setState(() => _duplicateSuggestions = hits);
    } finally {
      if (mounted) setState(() => _loadingDuplicates = false);
    }
  }

  Future<void> _applyDuplicate(CatalogProduct product) async {
    final storeId = ref.read(currentStoreIdProvider);
    try {
      await ref.read(catalogRepositoryProvider).addToStore(
            storeId: storeId,
            catalogId: product.id,
          );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thêm được: $e')),
      );
    }
  }

  void _fillFromCatalog(CatalogProduct product) {
    setState(() {
      _catalogId = product.id;
      _name.text = product.name;
      _brand.text = product.brand ?? '';
      _barcode.text = product.barcode ?? _barcode.text;
      if (product.unitSize != null) {
        _unitSize.text = product.unitSize.toString();
      }
      _unitType = product.unitType;
      _isWeighed = product.isWeighed;
      _source = product.source;
      _duplicateSuggestions = [];
    });
  }

  Future<void> _bootstrap() async {
    final args = widget.args;
    if (args.editId != null) {
      setState(() => _loading = true);
      final item = await ref.read(itemRepositoryProvider).getById(args.editId!);
      if (item != null && mounted) {
        _existingId = item.id;
        _catalogId = item.catalogId;
        _name.text = item.resolvedName;
        _brand.text = item.brand ?? '';
        _barcode.text = item.barcode ?? '';
        _unitSize.text = item.unitSize?.toString() ?? '';
        _category.text = item.category ?? '';
        _unitType = item.unitType;
        _isWeighed = item.isWeighed;
        _source = item.source;
      }
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (args.forceWeighed) {
      _isWeighed = true;
      _unitType = UnitType.kg;
    }

    if (args.prefillBarcode != null) {
      _barcode.text = args.prefillBarcode!;
    }

    final off = args.prefillFromOff;
    if (off != null) {
      _barcode.text = off.barcode;
      _name.text = off.name ?? '';
      _brand.text = off.brand ?? '';
      if (off.unitSize != null) _unitSize.text = off.unitSize.toString();
      if (off.unitType != null) _unitType = off.unitType!;
      _source = CatalogSource.off;
    }
  }

  @override
  void dispose() {
    _duplicateDebounce?.cancel();
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _brand.dispose();
    _barcode.dispose();
    _unitSize.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final sizeRaw = _unitSize.text.trim();
      final size = sizeRaw.isEmpty ? null : double.tryParse(sizeRaw.replaceAll(',', '.'));

      final storeId = ref.read(currentStoreIdProvider);
      final item = await ref.read(itemRepositoryProvider).saveItem(
            storeId: storeId,
            id: _existingId,
            catalogId: _catalogId,
            barcode: _barcode.text,
            name: _name.text,
            brand: _brand.text,
            unitSize: size,
            unitType: _isWeighed ? UnitType.kg : _unitType,
            category: _category.text,
            isWeighed: _isWeighed,
            source: _source,
          );

      if (!mounted) return;
      context.go('/items/${item.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _existingId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa mặt hàng' : 'Tạo hàng mới'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Tên mặt hàng *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên' : null,
                  ),
                  if (!isEdit &&
                      (_duplicateSuggestions.isNotEmpty || _loadingDuplicates))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Có thể trùng',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          if (_loadingDuplicates)
                            const LinearProgressIndicator(minHeight: 2),
                          ..._duplicateSuggestions.map(
                            (p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.name),
                              subtitle: Text(
                                [
                                  if (p.brand != null && p.brand!.isNotEmpty)
                                    p.brand!,
                                  if (p.barcode != null) p.barcode!,
                                ].join(' · '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _applyDuplicate(p),
                              onLongPress: () => _fillFromCatalog(p),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brand,
                    decoration: const InputDecoration(
                      labelText: 'Hãng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mã vạch',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hàng cân ký (rau, gia vị…)'),
                    value: _isWeighed,
                    onChanged: (v) => setState(() {
                      _isWeighed = v;
                      if (v) _unitType = UnitType.kg;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _unitSize,
                          enabled: !_isWeighed,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Dung tích / khối lượng',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<UnitType>(
                          initialValue: _unitType,
                          decoration: const InputDecoration(
                            labelText: 'Đơn vị',
                            border: OutlineInputBorder(),
                          ),
                          items: UnitType.values
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(_unitLabel(u)),
                                ),
                              )
                              .toList(),
                          onChanged: _isWeighed
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _unitType = v);
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _category,
                    decoration: const InputDecoration(
                      labelText: 'Nhóm hàng',
                      hintText: 'VD: nước giải khát, rau',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
                  ),
                ],
              ),
            ),
    );
  }
}

String _unitLabel(UnitType t) => switch (t) {
      UnitType.ml => 'ml',
      UnitType.l => 'lít',
      UnitType.g => 'g',
      UnitType.kg => 'kg',
      UnitType.piece => 'cái',
    };
