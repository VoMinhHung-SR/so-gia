import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'so_gia'));

  @override
  int get schemaVersion => 1;

  Future<bool> ping() async {
    final row = await customSelect('SELECT 1 AS ok').getSingle();
    return row.read<int>('ok') == 1;
  }
}
