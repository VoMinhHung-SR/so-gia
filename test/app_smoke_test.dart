import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_gia/app/app.dart';
import 'package:so_gia/core/settings.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/database_provider.dart';
import 'package:so_gia/data/repositories/item_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home list screen loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          itemsStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const SoGiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sổ giá'), findsWidgets);
    expect(find.textContaining('Chưa có mặt hàng'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
