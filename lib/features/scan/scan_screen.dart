import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/repositories/item_repository.dart';
import '../items/item_form_screen.dart';

bool get canUseCameraScanner {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
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

  Future<void> _resolve(String code) async {
    final barcode = code.trim();
    if (barcode.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _status = 'Đang tra…';
    });

    try {
      final result =
          await ref.read(itemRepositoryProvider).resolveBarcode(barcode);
      if (!mounted) return;

      switch (result) {
        case FoundLocal(:final item):
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét / tra mã'),
        actions: [
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
