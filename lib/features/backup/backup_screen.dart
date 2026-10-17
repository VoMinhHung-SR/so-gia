import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/settings.dart';
import '../../data/backup/csv_backup.dart';
import '../../data/db/database_provider.dart';

final csvBackupProvider = Provider<CsvBackupService>((ref) {
  return CsvBackupService(ref.watch(databaseProvider));
});

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  List<CsvMergePreview>? _preview;
  Uint8List? _pendingImport;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(csvBackupProvider).exportZip();
      final name =
          'so-gia-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/zip',
              name: name,
            ),
          ],
          subject: 'Sao lưu Sổ giá',
          text: 'File sao lưu CSV (zip) từ app Sổ giá',
        ),
      );
      await ref.read(appSettingsProvider).markBackupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo file sao lưu')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xuất lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImport() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (files.isEmpty) return;

    setState(() => _busy = true);
    try {
      final bytes = await files.first.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được file')),
        );
        return;
      }
      final preview = await ref.read(csvBackupProvider).previewImport(bytes);
      setState(() {
        _preview = preview;
        _pendingImport = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đọc zip lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    final bytes = _pendingImport;
    if (bytes == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(csvBackupProvider).importZip(bytes);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _pendingImport = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã nhập xong')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nhập lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final last = settings.lastBackupAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu / khôi phục')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (settings.needsBackupReminder)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('Nên sao lưu'),
                subtitle: Text('Đã hơn 7 ngày chưa xuất CSV (hoặc chưa từng xuất).'),
              ),
            ),
          Text(
            last == null
                ? 'Chưa từng xuất sao lưu trên máy này.'
                : 'Lần xuất gần nhất: ${DateFormat('dd/MM/yyyy HH:mm').format(last.toLocal())}',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload),
            label: const Text('Xuất CSV (zip)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickImport,
            icon: const Icon(Icons.download),
            label: const Text('Chọn file zip để nhập'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_preview != null) ...[
            const SizedBox(height: 24),
            Text('Xem trước nhập', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in _preview!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.table),
                subtitle: Text(
                  'Thêm ${p.toInsert} · Sửa ${p.toUpdate} · Giữ ${p.unchanged}',
                ),
              ),
            FilledButton(
              onPressed: _busy ? null : _confirmImport,
              child: const Text('Xác nhận nhập (bản mới hơn thắng)'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Mỗi bảng một file CSV (UTF-8 BOM), gói trong zip. '
            'Merge theo UUID + updated_at.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
