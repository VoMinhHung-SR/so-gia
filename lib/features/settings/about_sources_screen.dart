import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Attribution / data sources (P9.6) — Open Food Facts ODbL note.
class AboutSourcesScreen extends StatelessWidget {
  const AboutSourcesScreen({super.key});

  static final _offUri = Uri.parse('https://world.openfoodfacts.org/');
  static final _odblUri = Uri.parse('https://opendatacommons.org/licenses/odbl/');

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium;
    final title = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Nguồn dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Giới thiệu', style: title),
          const SizedBox(height: 8),
          Text(
            'Sổ giá thông minh giúp quản lý và nghiên cứu giá nhập / giá bán '
            'cho cửa hàng tạp hóa, quầy rau củ – thịt. Dữ liệu chạy offline '
            'trên máy; không đồng bộ lên máy chủ.',
            style: body,
          ),
          const SizedBox(height: 24),
          Text('Danh mục hàng đóng gói', style: title),
          const SizedBox(height: 8),
          Text(
            'Một phần thông tin sản phẩm đóng gói (tên, hãng, dung tích, mã vạch) '
            'có thể dựa trên dữ liệu Open Food Facts. Ứng dụng chỉ lấy các '
            'trường đó; không dùng ảnh, mô tả hay giá từ OFF.',
            style: body,
          ),
          const SizedBox(height: 12),
          Text(
            'Open Food Facts được cấp phép theo Open Database License (ODbL). '
            'Khi dùng dữ liệu từ OFF, bạn cần ghi nguồn và tuân thủ điều kiện '
            'của giấy phép (xem liên kết bên dưới).',
            style: body,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_new),
            title: const Text('Open Food Facts'),
            subtitle: const Text('world.openfoodfacts.org'),
            onTap: () => _open(_offUri),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Giấy phép ODbL'),
            subtitle: const Text('opendatacommons.org/licenses/odbl'),
            onTap: () => _open(_odblUri),
          ),
          const SizedBox(height: 16),
          Text('Hàng cân / biên soạn tay', style: title),
          const SizedBox(height: 8),
          Text(
            'Rau củ, thịt, hải sản và nhiều mặt hàng không mã vạch được biên '
            'soạn trong app (source = seed). Mã vạch chỉ đưa vào danh mục khi '
            'đã đối chiếu từ bao bì thật hoặc OFF — nếu chưa chắc sẽ để trống.',
            style: body,
          ),
        ],
      ),
    );
  }
}
