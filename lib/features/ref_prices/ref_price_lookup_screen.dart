import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/money.dart';
import '../../data/ref/supermarket_sources.dart';
import '../../data/repositories/item_repository.dart'; // Item
import '../../data/repositories/ref_price_repository.dart';

bool get _canEmbedWebView {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class RefPriceLookupScreen extends ConsumerStatefulWidget {
  const RefPriceLookupScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<RefPriceLookupScreen> createState() =>
      _RefPriceLookupScreenState();
}

class _RefPriceLookupScreenState extends ConsumerState<RefPriceLookupScreen> {
  late SupermarketSource _source;
  WebViewController? _web;
  String? _currentUrl;
  final _priceCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  bool _saving = false;
  Item? _item;

  @override
  void initState() {
    super.initState();
    _source = kSupermarketSources.first;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final item = await ref.read(itemRepositoryProvider).getById(widget.itemId);
    if (!mounted) return;
    setState(() {
      _item = item;
      if (item?.unitSize != null) {
        _sizeCtrl.text = item!.unitSize.toString();
      }
    });
    await _loadSource(_source);
  }

  String get _query {
    final item = _item;
    if (item == null) return '';
    final parts = [
      item.name,
      if (item.brand != null) item.brand!,
      if (item.unitSize != null) '${item.unitSize}${item.unitType.name}',
    ];
    return parts.join(' ');
  }

  Future<void> _loadSource(SupermarketSource source) async {
    final uri = source.searchUri(_query);
    setState(() {
      _source = source;
      _currentUrl = uri.toString();
    });

    if (_canEmbedWebView) {
      final controller = _web ??
          (WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onUrlChange: (change) {
                  if (change.url != null) {
                    setState(() => _currentUrl = change.url);
                  }
                },
              ),
            ));
      await controller.loadRequest(uri);
      if (mounted) setState(() => _web = controller);
    }
  }

  Future<void> _openExternal() async {
    final url = _currentUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    final price = parseVnd(_priceCtrl.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập giá bán lẻ siêu thị hợp lệ')),
      );
      return;
    }
    final size = double.tryParse(_sizeCtrl.text.replaceAll(',', '.'));

    setState(() => _saving = true);
    try {
      await ref.read(refPriceRepositoryProvider).save(
            itemId: widget.itemId,
            source: _source.refSource,
            price: price,
            unitSize: size,
            url: _currentUrl,
            note: 'Giá bán lẻ siêu thị (nhập tay)',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu giá bán lẻ ${_source.label}: ${formatVnd(price)}',
          ),
        ),
      );
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giá bán lẻ siêu thị'),
        actions: [
          IconButton(
            tooltip: 'Mở trình duyệt',
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openExternal,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Chỉ là mốc so sánh — không dùng làm giá nhập.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                for (final s in kSupermarketSources)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s.label),
                      selected: _source.id == s.id,
                      onSelected: (_) => _loadSource(s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _canEmbedWebView && _web != null
                ? WebViewWidget(controller: _web!)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Trên máy tính: mở trang tìm kiếm trong trình duyệt, '
                            'xem giá rồi gõ vào ô bên dưới.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentUrl ?? '',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _openExternal,
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Mở trang tìm kiếm'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Lưu giá này (${_source.label})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Giá bán lẻ (đ)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _sizeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Dung tích',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Đang lưu…' : 'Lưu giá này'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
