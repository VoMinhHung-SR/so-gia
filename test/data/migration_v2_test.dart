import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrate v1 items → catalog + store_items keeps purchase totals', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final dir = await Directory.systemTemp.createTemp('so_gia_mig_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File('${dir.path}/v1.sqlite');

    // Build a v1 DB with raw sqlite3, then close before Drift opens it.
    final sqlite = sqlite3.open(file.path);
    sqlite.execute('''
CREATE TABLE items (
  id TEXT NOT NULL PRIMARY KEY,
  barcode TEXT NULL,
  name TEXT NOT NULL,
  brand TEXT NULL,
  unit_size REAL NULL,
  unit_type TEXT NOT NULL,
  category TEXT NULL,
  is_weighed INTEGER NOT NULL DEFAULT 0 CHECK (is_weighed IN (0, 1)),
  source TEXT NOT NULL,
  image_url TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
    sqlite.execute('''
CREATE TABLE suppliers (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
    sqlite.execute('''
CREATE TABLE purchases (
  id TEXT NOT NULL PRIMARY KEY,
  item_id TEXT NOT NULL,
  supplier_id TEXT NULL,
  cost_price INTEGER NOT NULL,
  qty REAL NOT NULL DEFAULT 1.0,
  date INTEGER NOT NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER NULL
);
''');
    sqlite.execute('''
CREATE TABLE ref_prices (
  id TEXT NOT NULL PRIMARY KEY,
  item_id TEXT NOT NULL,
  source TEXT NOT NULL,
  price INTEGER NOT NULL,
  unit_size REAL NULL,
  url TEXT NULL,
  observed_at INTEGER NOT NULL,
  note TEXT NULL
);
''');
    sqlite.execute('''
CREATE TABLE sell_prices (
  id TEXT NOT NULL PRIMARY KEY,
  item_id TEXT NOT NULL,
  price INTEGER NOT NULL,
  margin_pct REAL NOT NULL,
  effective_from INTEGER NOT NULL
);
''');

    final nowMs = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    sqlite.execute(
      'INSERT INTO items (id, barcode, name, brand, unit_size, unit_type, '
      'category, is_weighed, source, created_at, updated_at) VALUES '
      '(?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
      [
        'item-1',
        '893111',
        'Coca 330ml',
        'Coca',
        330.0,
        'ml',
        'nước giải khát',
        'manual',
        nowMs,
        nowMs,
      ],
    );
    sqlite.execute(
      'INSERT INTO purchases (id, item_id, cost_price, qty, date, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'p-1',
        'item-1',
        7000,
        1.0,
        nowMs,
        nowMs,
        nowMs,
      ],
    );
    sqlite.execute(
      'INSERT INTO ref_prices (id, item_id, source, price, observed_at) '
      'VALUES (?, ?, ?, ?, ?)',
      ['r-1', 'item-1', 'bhx', 11000, nowMs],
    );
    sqlite.execute('PRAGMA user_version = 1');
    sqlite.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    expect(await db.ping(), isTrue);
    expect(db.schemaVersion, 2);

    final items = await db.listActiveItems(kDefaultStoreId);
    expect(items, hasLength(1));
    expect(items.single.id, 'item-1');
    expect(items.single.catalogId, 'item-1');
    expect(items.single.resolvedName, 'Coca 330ml');
    expect(items.single.categoryId, 'nuoc-giai-khat');

    final purchases = await db.listPurchasesForItem('item-1');
    expect(purchases, hasLength(1));
    expect(purchases.single.costPrice, 7000);

    final refs = await db.listRefPricesForCatalog('item-1');
    expect(refs, hasLength(1));
    expect(refs.single.price, 11000);
  });
}
