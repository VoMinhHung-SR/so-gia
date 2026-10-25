import '../db/tables.dart';

/// UI-facing row: one store listing joined with its catalog product.
///
/// [id] is `store_items.id` (used by purchases / sell_prices / routes).
/// [catalogId] is used by ref_prices.
class Item {
  const Item({
    required this.id,
    required this.catalogId,
    required this.storeId,
    required this.name,
    required this.unitType,
    required this.categoryId,
    required this.isWeighed,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.barcode,
    this.brand,
    this.unitSize,
    this.category,
    this.displayName,
    this.deletedAt,
  });

  final String id;
  final String catalogId;
  final String storeId;
  final String? barcode;
  final String name;
  final String? brand;
  final double? unitSize;
  final UnitType unitType;
  final String categoryId;
  final String? category;
  final bool isWeighed;
  final CatalogSource source;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get resolvedName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : name;
}
