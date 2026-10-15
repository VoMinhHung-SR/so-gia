import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/tables.dart';
import '../../data/off/open_food_facts_client.dart';
import '../../data/repositories/item_repository.dart';

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
  ItemSource _source = ItemSource.manual;
  String? _imageUrl;
  String? _existingId;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final args = widget.args;
    if (args.editId != null) {
      setState(() => _loading = true);
      final item = await ref.read(itemRepositoryProvider).getById(args.editId!);
      if (item != null && mounted) {
        _existingId = item.id;
        _name.text = item.name;
        _brand.text = item.brand ?? '';
        _barcode.text = item.barcode ?? '';
        _unitSize.text = item.unitSize?.toString() ?? '';
        _category.text = item.category ?? '';
        _unitType = item.unitType;
        _isWeighed = item.isWeighed;
        _source = item.source;
        _imageUrl = item.imageUrl;
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
      _imageUrl = off.imageUrl;
      _source = ItemSource.off;
    }
  }

  @override
  void dispose() {
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

      final item = await ref.read(itemRepositoryProvider).saveItem(
            id: _existingId,
            barcode: _barcode.text,
            name: _name.text,
            brand: _brand.text,
            unitSize: size,
            unitType: _isWeighed ? UnitType.kg : _unitType,
            category: _category.text,
            isWeighed: _isWeighed,
            source: _source,
            imageUrl: _imageUrl,
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
        title: Text(isEdit ? 'Sửa mặt hàng' : 'Thêm mặt hàng'),
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
