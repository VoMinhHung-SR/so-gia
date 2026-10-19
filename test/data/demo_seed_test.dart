import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/tables.dart';
import 'package:so_gia/data/seed/demo_seed.dart';

void main() {
  test('demo seed creates store-scoped items', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final result = await DemoSeedService(db).seed(force: true);
    expect(result.items, greaterThanOrEqualTo(20));
    expect(result.suppliers, 3);
    expect(result.purchases, greaterThan(0));

    final items = await db.listActiveItems(kDefaultStoreId);
    expect(items.length, result.items);
  });
}
