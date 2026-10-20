import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/db/database_provider.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/item_repository.dart';
import '../../data/repositories/store_repository.dart';
import '../items/item_form_screen.dart';

bool get canUseCameraScanner {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final pendingSupplementsCountProvider = StreamProvider<int>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  return ref
      .watch(databaseProvider)
      .watchPendingSupplements(storeId)
      .map((list) => list.length);
});

enum _SessionHitStatus {
  added,
  alreadyInStore,
  pending,
  duplicate,
}

class _SessionHit {
  const _SessionHit({
    required this.barcode,
    required this.status,
    this.label,
  });

  final String barcode;
  final _SessionHitStatus status;
  final String? label;
}

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _manual = TextEditingController();
  MobileScannerController? _cameraController;

  bool _busy = false;
  bool _torch = false;
  String? _status;
  bool _continuousScan = true;
  // TODO(P8): optional "Nhập giá ngay" — push /items/:id after add when enabled.

  final List<_SessionHit> _sessionHits = [];
  String? _lastBarcode;
  DateTime? _lastBarcodeAt;

  @override
  void initState() {
    super.initState();
    if (canUseCameraScanner) {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  bool _shouldDebounce(String barcode) {
    final now = DateTime.now();
    if (_lastBarcode == barcode &&
        _lastBarcodeAt != null &&
        now.difference(_lastBarcodeAt!) < const Duration(seconds: 2)) {
      return true;
    }
    _lastBarcode = barcode;
    _lastBarcodeAt = now;
    return false;
  }

  void _appendHit(_SessionHit hit) {
    setState(() => _sessionHits.insert(0, hit));
  }

  Future<void> _resolveContinuous(String barcode, String storeId) async {
    if (_sessionHits.any((h) => h.barcode == barcode)) {
      _appendHit(_SessionHit(barcode: barcode, status: _SessionHitStatus.duplicate));
      return;
    }

    final result = await ref.read(itemRepositoryProvider).resolveBarcode(
          storeId,
          barcode,
        );
    if (!mounted) return;

    switch (result) {
      case FoundLocal(:final item):
        _appendHit(
          _SessionHit(
            barcode: barcode,
            status: _SessionHitStatus.alreadyInStore,
            label: item.resolvedName,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã có: ${item.resolvedName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      case FoundCatalog(:final product):
        await ref.read(databaseProvider).addCatalogToStore(
              storeId: storeId,
              catalogId: product.id,
            );
        _appendHit(
          _SessionHit(
            barcode: barcode,
            status: _SessionHitStatus.added,
            label: product.name,
          ),
        );
      case PrefillFromOff():
      case UnknownBarcode():
        final db = ref.read(databaseProvider);
        final hadPending = await db.findOpenPending(storeId, barcode);
        await db.enqueuePendingSupplement(storeId: storeId, barcode: barcode);
        _appendHit(
          _SessionHit(
            barcode: barcode,
            status: hadPending != null
                ? _SessionHitStatus.duplicate
                : _SessionHitStatus.pending,
          ),
        );
    }
  }

  Future<void> _resolveSingle(String barcode, String storeId) async {
    final result = await ref.read(itemRepositoryProvider).resolveBarcode(
          storeId,
          barcode,
        );
    if (!mounted) return;

    switch (result) {
      case FoundLocal(:final item):
        context.go('/items/${item.id}');
      case FoundCatalog(:final product):
        final item = await ref.read(catalogRepositoryProvider).addToStore(
              storeId: storeId,
              catalogId: product.id,
            );
        if (!mounted) return;
        context.go('/items/${item.id}');
      case PrefillFromOff(:final product):
        context.push(
          '/items/new',
          extra: ItemFormArgs(prefillFromOff: product),
        );
      case UnknownBarcode(:final barcode):
        context.push(
          '/items/new',
          extra: ItemFormArgs(prefillBarcode: barcode),
        );
    }
  }

  Future<void> _resolve(String code) async {
    final barcode = code.trim();
    if (barcode.isEmpty || _busy) return;
    if (_shouldDebounce(barcode)) return;

    setState(() {
      _busy = true;
      _status = 'Đang tra…';
    });

    try {
      final storeId = ref.read(currentStoreIdProvider);
      if (_continuousScan) {
        await _resolveContinuous(barcode, storeId);
      } else {
        await _resolveSingle(barcode, storeId);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _cameraController;
    final pendingCount = ref.watch(pendingSupplementsCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét / tra mã'),
        actions: [
          IconButton(
            tooltip: 'Chờ bổ sung',
            onPressed: () => context.push('/pending-supplements'),
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.pending_actions_outlined),
            ),
          ),
          if (camera != null)
            IconButton(
              tooltip: _torch ? 'Tắt đèn' : 'Bật đèn',
              icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
              onPressed: () async {
                await camera.toggleTorch();
                setState(() => _torch = !_torch);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Quét liên tục'),
            subtitle: const Text(
              'Bật: thêm vào danh sách phiên. Tắt: mở form/chi tiết như trước.',
            ),
            value: _continuousScan,
            onChanged: (v) => setState(() => _continuousScan = v),
          ),
          if (camera != null)
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: camera,
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null) _resolve(raw);
                    },
                  ),
                  if (_busy)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Camera quét chỉ có trên Android/iOS.\n'
                    'Trên máy tính: gõ mã vạch bên dưới.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          if (_continuousScan && _sessionHits.isNotEmpty)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Đã quét: ${_sessionHits.length}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sessionHits.length,
                      itemBuilder: (context, i) {
                        final hit = _sessionHits[i];
                        return ListTile(
                          dense: true,
                          title: Text(hit.barcode),
                          subtitle: hit.label != null ? Text(hit.label!) : null,
                          trailing: _StatusChip(status: hit.status),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_status != null) ...[
                  Text(_status!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _manual,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gõ mã vạch',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _resolve,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : () => _resolve(_manual.text),
                  child: const Text('Tra mã'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _SessionHitStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _SessionHitStatus.added => ('Đã thêm', Colors.green),
      _SessionHitStatus.alreadyInStore => ('Đã có', Colors.blue),
      _SessionHitStatus.pending => ('Chờ bổ sung', Colors.orange),
      _SessionHitStatus.duplicate => ('Trùng', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
