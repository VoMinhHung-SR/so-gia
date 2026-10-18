import 'package:drift/drift.dart';

enum UnitType { ml, l, g, kg, piece }

/// Catalog row provenance (v2). CSV v1 `manual` maps to [user].
enum CatalogSource { seed, off, user }

enum RefPriceSource { bhx, winmart, coopmart, other, govAgri }

/// Stable default store created on migrate / fresh install.
const kDefaultStoreId = 'a0000000-0000-4000-8000-000000000001';
const kDefaultStoreName = 'Cửa hàng của tôi';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  IntColumn get sort => integer()();
  BoolColumn get isWeighed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CatalogProducts extends Table {
  TextColumn get id => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get nameSearch => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get unitSize => real().nullable()();
  TextColumn get unitType => textEnum<UnitType>()();
  TextColumn get categoryId => text().references(Categories, #id)();
  BoolColumn get isWeighed => boolean().withDefault(const Constant(false))();
  TextColumn get source => textEnum<CatalogSource>()();
  IntColumn get catalogVersion => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text().nullable()();
  RealColumn get defaultMarginPct =>
      real().withDefault(const Constant(20))();
  IntColumn get roundingStep => integer().withDefault(const Constant(500))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StoreItems extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text().references(Stores, #id)();
  TextColumn get catalogId => text().references(CatalogProducts, #id)();
  TextColumn get displayName => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text().references(Stores, #id)();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(StoreItems, #id)();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id)();
  IntColumn get costPrice => integer()();
  RealColumn get qty => real().withDefault(const Constant(1))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RefPrices extends Table {
  TextColumn get id => text()();
  TextColumn get catalogId => text().references(CatalogProducts, #id)();
  TextColumn get source => textEnum<RefPriceSource>()();
  IntColumn get price => integer()();
  RealColumn get unitSize => real().nullable()();
  TextColumn get url => text().nullable()();
  DateTimeColumn get observedAt => dateTime()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SellPrices extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(StoreItems, #id)();
  IntColumn get price => integer()();
  RealColumn get marginPct => real()();
  DateTimeColumn get effectiveFrom => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MarginByCategory extends Table {
  TextColumn get storeId => text().references(Stores, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get marginPct => real()();

  @override
  Set<Column<Object>> get primaryKey => {storeId, categoryId};
}

class StarterPacks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class StarterPackItems extends Table {
  TextColumn get packId => text().references(StarterPacks, #id)();
  TextColumn get catalogId => text().references(CatalogProducts, #id)();
  BoolColumn get defaultSelected =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {packId, catalogId};
}
