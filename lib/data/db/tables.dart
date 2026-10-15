import 'package:drift/drift.dart';

enum UnitType { ml, l, g, kg, piece }

enum ItemSource { off, manual }

enum RefPriceSource { bhx, winmart, coopmart, other, govAgri }

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get unitSize => real().nullable()();
  TextColumn get unitType => textEnum<UnitType>()();
  TextColumn get category => text().nullable()();
  BoolColumn get isWeighed => boolean().withDefault(const Constant(false))();
  TextColumn get source => textEnum<ItemSource>()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
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
  TextColumn get itemId => text().references(Items, #id)();
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
  TextColumn get itemId => text().references(Items, #id)();
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
  TextColumn get itemId => text().references(Items, #id)();
  IntColumn get price => integer()();
  RealColumn get marginPct => real()();
  DateTimeColumn get effectiveFrom => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
