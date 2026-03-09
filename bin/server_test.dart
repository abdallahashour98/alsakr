import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:al_sakr/core/sync/downsync_service.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = '/home/boody/Documents/al_sakr_local.db';
  print('Opening db at $dbPath');
  final db = await databaseFactory.openDatabase(dbPath);

  final pb = PocketBase('http://161.35.25.12:8090');

  print('Trying to authenticate...');
  try {
    await pb.admins.authWithPassword(
      'karimelnahas49@gmail.com',
      'Kemo01124618776#',
    );
    print('Auth valid: ${pb.authStore.isValid}');
  } catch (e) {
    print('Auth admin failed: $e');
    exit(1);
  }

  print('Testing getValidColumns for clients...');
  final res = await db.rawQuery('PRAGMA table_info(clients)');
  print('Client columns: ${res.map((r) => r['name']).toList()}');

  final downsync = DownsyncService(db: db, pb: pb);
  try {
    print('Starting downsync for all...');
    await downsync.downsyncAll();
    print('Success downsync! Count: ${downsync.successCount}');
  } catch (e, st) {
    print('Error: $e');
    print(st);
  }

  final clients = await db.query('clients');
  print('Total clients in DB: ${clients.length}');
  final suppliers = await db.query('suppliers');
  print('Total suppliers in DB: ${suppliers.length}');
  exit(0);
}
