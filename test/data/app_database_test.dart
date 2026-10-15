import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/data/db/app_database.dart';

void main() {
  test('in-memory database opens and answers a query', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await db.ping(), isTrue);
    expect(db.schemaVersion, 1);
  });
}
