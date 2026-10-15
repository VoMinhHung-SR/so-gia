import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/app/app.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/database_provider.dart';

void main() {
  testWidgets('home screen reports the database is ready', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const SoGiaApp(),
      ),
    );
    await tester.runAsync(() => db.ping());
    await tester.pumpAndSettle();

    expect(find.text('Sổ giá'), findsOneWidget);
    expect(find.text('Dữ liệu sẵn sàng (offline)'), findsOneWidget);
  });
}
