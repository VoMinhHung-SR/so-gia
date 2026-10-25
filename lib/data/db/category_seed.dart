import 'package:drift/drift.dart';

import '../../core/vietnamese.dart';
import 'app_database.dart';
import 'tables.dart';

/// Built-in category tree (matches assets/catalog/categories.json + `khac`).
class SeedCategory {
  const SeedCategory({
    required this.id,
    required this.name,
    required this.sort,
    required this.isWeighed,
    required this.marginPct,
  });

  final String id;
  final String name;
  final int sort;
  final bool isWeighed;
  final double marginPct;
}

const kSeedCategories = <SeedCategory>[
  SeedCategory(
    id: 'dau-an',
    name: 'Dầu ăn',
    sort: 1,
    isWeighed: false,
    marginPct: 10,
  ),
  SeedCategory(
    id: 'nuoc-cham',
    name: 'Nước mắm, nước tương, nước chấm',
    sort: 2,
    isWeighed: false,
    marginPct: 12,
  ),
  SeedCategory(
    id: 'gia-vi-goi',
    name: 'Gia vị gói, hạt nêm, bột ngọt',
    sort: 3,
    isWeighed: false,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'gia-vi-can',
    name: 'Gia vị cân / bán lẻ',
    sort: 4,
    isWeighed: true,
    marginPct: 25,
  ),
  SeedCategory(
    id: 'gao-bot',
    name: 'Gạo, bột, đồ khô',
    sort: 5,
    isWeighed: false,
    marginPct: 8,
  ),
  SeedCategory(
    id: 'mi-chao',
    name: 'Mì, cháo, phở ăn liền',
    sort: 6,
    isWeighed: false,
    marginPct: 10,
  ),
  SeedCategory(
    id: 'sua',
    name: 'Sữa và sản phẩm từ sữa',
    sort: 7,
    isWeighed: false,
    marginPct: 8,
  ),
  SeedCategory(
    id: 'nuoc-giai-khat',
    name: 'Nước giải khát',
    sort: 8,
    isWeighed: false,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'banh-keo',
    name: 'Bánh kẹo, snack',
    sort: 9,
    isWeighed: false,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'rau-cu',
    name: 'Rau, củ',
    sort: 10,
    isWeighed: true,
    marginPct: 30,
  ),
  SeedCategory(
    id: 'trai-cay',
    name: 'Trái cây',
    sort: 11,
    isWeighed: true,
    marginPct: 25,
  ),
  SeedCategory(
    id: 'thit',
    name: 'Thịt',
    sort: 12,
    isWeighed: true,
    marginPct: 12,
  ),
  SeedCategory(
    id: 'ca-hai-san',
    name: 'Cá, tôm, hải sản',
    sort: 13,
    isWeighed: true,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'trung',
    name: 'Trứng',
    sort: 14,
    isWeighed: false,
    marginPct: 8,
  ),
  SeedCategory(
    id: 'dong-lanh',
    name: 'Đồ đông lạnh, chế biến sẵn',
    sort: 15,
    isWeighed: false,
    marginPct: 12,
  ),
  SeedCategory(
    id: 'giat-tay',
    name: 'Giặt giũ, vệ sinh nhà cửa',
    sort: 16,
    isWeighed: false,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'giay-tui',
    name: 'Giấy, túi, đồ dùng một lần',
    sort: 17,
    isWeighed: false,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'cham-soc-ca-nhan',
    name: 'Chăm sóc cá nhân',
    sort: 18,
    isWeighed: false,
    marginPct: 15,
  ),
  SeedCategory(
    id: 'khac',
    name: 'Khác',
    sort: 99,
    isWeighed: false,
    marginPct: 20,
  ),
];

Future<void> seedCategories(AppDatabase db) async {
  for (final c in kSeedCategories) {
    await db.into(db.categories).insertOnConflictUpdate(
          CategoriesCompanion(
            id: Value(c.id),
            name: Value(c.name),
            sort: Value(c.sort),
            isWeighed: Value(c.isWeighed),
          ),
        );
  }
}

Future<void> seedMarginsForStore(AppDatabase db, String storeId) async {
  for (final c in kSeedCategories) {
    await db.into(db.marginByCategory).insertOnConflictUpdate(
          MarginByCategoryCompanion(
            storeId: Value(storeId),
            categoryId: Value(c.id),
            marginPct: Value(c.marginPct),
          ),
        );
  }
}

Future<String> ensureDefaultStore(AppDatabase db) async {
  final existing = await (db.select(db.stores)
        ..where((t) => t.id.equals(kDefaultStoreId)))
      .getSingleOrNull();
  if (existing != null) return existing.id;

  final now = DateTime.now().toUtc();
  await db.into(db.stores).insert(
        StoresCompanion.insert(
          id: kDefaultStoreId,
          name: kDefaultStoreName,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await seedMarginsForStore(db, kDefaultStoreId);
  return kDefaultStoreId;
}

/// Map free-text v1 category labels onto stable category ids.
String mapLegacyCategoryId(String? category) {
  if (category == null || category.trim().isEmpty) return 'khac';
  final k = removeDiacritics(category);
  if (k.contains('dau an') || k.contains('dau an ')) return 'dau-an';
  if (k.contains('nuoc mam') ||
      k.contains('nuoc tuong') ||
      k.contains('nuoc cham') ||
      k.contains('tuong ot') ||
      k.contains('giam')) {
    return 'nuoc-cham';
  }
  if (k.contains('hat nem') ||
      k.contains('bot ngot') ||
      k.contains('gia vi goi') ||
      (k.contains('gia vi') && !k.contains('can'))) {
    return 'gia-vi-goi';
  }
  if (k.contains('gia vi') ||
      k.contains('tieu') ||
      k.contains('toi') ||
      k.contains('ot bot')) {
    return 'gia-vi-can';
  }
  if (k.contains('gao') || k.contains('bot mi') || k.contains('do kho')) {
    return 'gao-bot';
  }
  if (k.contains('mi') ||
      k.contains('chao') ||
      k.contains('pho') ||
      k.contains('bun')) {
    return 'mi-chao';
  }
  if (k.contains('sua') || k.contains('sua chua') || k.contains('bo ')) {
    return 'sua';
  }
  if (k.contains('nuoc giai') ||
      k.contains('nuoc ngot') ||
      k.contains('bia') ||
      k == 'nuoc' ||
      k.startsWith('nuoc ')) {
    return 'nuoc-giai-khat';
  }
  if (k.contains('banh') || k.contains('keo') || k.contains('snack')) {
    return 'banh-keo';
  }
  if (k.contains('rau') || k.contains('cu ')) return 'rau-cu';
  if (k.contains('trai cay') || k.contains('hoa qua')) return 'trai-cay';
  if (k.contains('thit') || k.contains('ga ') || k.contains('bo ')) {
    return 'thit';
  }
  if (k.contains('ca ') ||
      k.contains('tom') ||
      k.contains('hai san') ||
      k.contains('muc')) {
    return 'ca-hai-san';
  }
  if (k.contains('trung')) return 'trung';
  if (k.contains('dong lanh') || k.contains('xuc xich') || k.contains('cha ')) {
    return 'dong-lanh';
  }
  if (k.contains('giat') ||
      k.contains('rua chen') ||
      k.contains('lau san') ||
      k.contains('hoa my') ||
      k.contains('ve sinh')) {
    return 'giat-tay';
  }
  if (k.contains('giay') || k.contains('tui') || k.contains('mang boc')) {
    return 'giay-tui';
  }
  if (k.contains('goi') ||
      k.contains('tam') ||
      k.contains('danh rang') ||
      k.contains('cham soc')) {
    return 'cham-soc-ca-nhan';
  }
  return 'khac';
}

CatalogSource parseCatalogSource(String? raw) {
  switch (raw) {
    case 'seed':
      return CatalogSource.seed;
    case 'off':
      return CatalogSource.off;
    case 'manual':
    case 'user':
      return CatalogSource.user;
    default:
      return CatalogSource.user;
  }
}
