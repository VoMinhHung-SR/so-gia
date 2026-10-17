import '../db/tables.dart';

/// Search URL templates for retail reference prices.
///
/// Verified lightly on 2026-10-17 (HTTP 200). Sites are SPA-heavy — if a
/// template stops landing on search results, update [searchUrlTemplate] only.
class SupermarketSource {
  const SupermarketSource({
    required this.id,
    required this.label,
    required this.searchUrlTemplate,
    required this.refSource,
  });

  final String id;
  final String label;
  /// Must contain `{query}` placeholder (already URI-encoded by caller).
  final String searchUrlTemplate;
  final RefPriceSource refSource;

  Uri searchUri(String query) {
    final encoded = Uri.encodeQueryComponent(query.trim());
    return Uri.parse(searchUrlTemplate.replaceAll('{query}', encoded));
  }
}

const kSupermarketSources = <SupermarketSource>[
  SupermarketSource(
    id: 'bhx',
    label: 'Bách hoá XANH',
    searchUrlTemplate: 'https://www.bachhoaxanh.com/tim-kiem?key={query}',
    refSource: RefPriceSource.bhx,
  ),
  SupermarketSource(
    id: 'winmart',
    label: 'WinMart',
    searchUrlTemplate: 'https://www.winmart.vn/tim-kiem?tu-khoa={query}',
    refSource: RefPriceSource.winmart,
  ),
  SupermarketSource(
    id: 'coopmart',
    label: 'Co.opmart / Co.op Online',
    searchUrlTemplate: 'https://cooponline.vn/?s={query}',
    refSource: RefPriceSource.coopmart,
  ),
];

String labelForRefSource(RefPriceSource s) => switch (s) {
      RefPriceSource.bhx => 'Bách hoá XANH',
      RefPriceSource.winmart => 'WinMart',
      RefPriceSource.coopmart => 'Co.opmart',
      RefPriceSource.govAgri => 'Giá nông sản (công khai)',
      RefPriceSource.other => 'Khác',
    };
