import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

part 'database_provider.g.dart';

/// Riverpod provider that exposes the local SQLite [Database] instance.
/// Uses keepAlive to ensure the database connection persists across the app.
@Riverpod(keepAlive: true)
Future<Database> localDatabase(Ref ref) async {
  final db = await DatabaseHelper().database;
  ref.onDispose(() async {
    await DatabaseHelper().close();
  });
  return db;
}
