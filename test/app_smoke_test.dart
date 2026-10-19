import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_gia/app/app.dart';
import 'package:so_gia/core/settings.dart';
import 'package:so_gia/data/db/app_database.dart';
import 'package:so_gia/data/db/database_provider.dart';
import 'package:so_gia/data/db/tables.dart';
import 'package:so_gia/data/repositories/item_repository.dart';
import 'package:so_gia/data/repositories/store_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home list screen loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
    });

    final now = DateTime.utc(2026, 1, 1);
    final defaultStore = Store(
      id: kDefaultStoreId,
      name: kDefaultStoreName,
      type: null,
      defaultMarginPct: 20,
      roundingStep: 500,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          itemsStreamProvider.overrideWith((ref) => Stream.value(const [])),
          storesStreamProvider.overrideWith(
            (ref) => Stream.value([defaultStore]),
          ),
        ],
        child: const SoGiaApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sổ giá'), findsWidgets);
    expect(find.textContaining('Chưa có mặt hàng'), findsOneWidget);

    // Drop the tree, then flush Drift stream-cancel timers before close.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
