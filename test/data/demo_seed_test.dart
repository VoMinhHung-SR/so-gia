import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/seed/demo_seed.dart';

void main() {
  test('demo seed creates barcode + weighed mix', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final result = await DemoSeedService(db).seed(force: true);
    expect(result.items, greaterThanOrEqualTo(20));
    expect(result.suppliers, 3);
    expect(result.purchases, greaterThan(result.items));

    final items = await db.listActiveItems();
    final weighed = items.where((i) => i.isWeighed).length;
    final coded = items.where((i) => i.barcode != null).length;
    expect(weighed, greaterThanOrEqualTo(6));
    expect(coded, greaterThanOrEqualTo(12));

    final again = await DemoSeedService(db).seedIfEmpty();
    expect(again, isNull);
  });
}
