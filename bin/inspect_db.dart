import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

Future<void> main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final dbPath = '${Platform.environment['HOME']}/Documents/al_sakr_local.db';
  print('Opening db at $dbPath');

  try {
    var db = await databaseFactory.openDatabase(dbPath);

    var clients = await db.query('clients');
    print('Clients count: ${clients.length}');

    var suppliers = await db.query('suppliers');
    print('Suppliers count: ${suppliers.length}');

    var syncMeta = await db.query('sync_meta');
    print('Sync Meta: $syncMeta');

    await db.close();
  } catch (e) {
    print('Error: $e');
  }
}
