// import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
// import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
// import 'package:al_sakr/features/store/controllers/store_controller.dart';
// import 'package:al_sakr/features/trash/controllers/trash_controller.dart';
// import 'package:al_sakr/features/notices/controllers/notices_controller.dart';
// import 'package:al_sakr/features/auth/controllers/auth_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../repositories/auth_repository.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:sqflite/sqflite.dart';

part 'auth_controller.g.dart';

@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<bool> build() async {
    final repository = await ref.watch(authRepositoryProvider.future);
    return repository.isLoggedIn;
  }

  Future<void> updateUserPassword(String userId, String newPassword) async {
    await globalPb
        .collection('users')
        .update(
          userId,
          body: {'password': newPassword, 'passwordConfirm': newPassword},
        );
  }

  Future<void> login(String email, String password) async {
    final repository = await ref.read(authRepositoryProvider.future);
    await repository.login(email, password);
  }

  Future<void> logout() async {
    final repository = await ref.read(authRepositoryProvider.future);
    repository.logout();
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final db = await ref.read(localDatabaseProvider.future);
      return await db.query('users', orderBy: 'created DESC');
    } catch (e) {
      if (globalPb.authStore.isValid) {
        final records = await globalPb
            .collection('users')
            .getFullList(sort: '-created');
        return records.map((e) => {'id': e.id, ...e.data}).toList();
      }
      return [];
    }
  }

  Future<void> deleteUser(String id) async {
    final db = await ref.read(localDatabaseProvider.future);

    // Soft delete locally so sync manager can handle it later if offline
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'users',
      {'is_deleted': 1, 'sync_status': 'pending_delete', 'updated': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (globalPb.authStore.isValid) {
      try {
        await globalPb.collection('users').delete(id);
      } catch (e) {
        // Ignore if failed, it might be synced later
      }
    }
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    // For creating users we typically need PocketBase first to generate an ID and handle password hashing
    // but we can try local first or just push to PB and let it sync down.
    if (globalPb.authStore.isValid) {
      final record = await globalPb.collection('users').create(body: data);
      final db = await ref.read(localDatabaseProvider.future);
      await db.insert('users', {
        'id': record.id,
        'sync_status': 'synced',
        'created': DateTime.now().toUtc().toIso8601String(),
        'updated': DateTime.now().toUtc().toIso8601String(),
        ...record.data,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      throw Exception("Cannot create user offline.");
    }
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);

    // SQLite doesn't natively support booleans. Convert them to 1/0 for the local DB.
    final localData = Map<String, dynamic>.from(data);
    localData.forEach((key, value) {
      if (value is bool) {
        localData[key] = value ? 1 : 0;
      }
    });

    localData['sync_status'] = 'pending_update';
    localData['updated'] = DateTime.now().toUtc().toIso8601String();

    await db.update('users', localData, where: 'id = ?', whereArgs: [id]);

    if (globalPb.authStore.isValid) {
      try {
        await globalPb.collection('users').update(id, body: data);
      } catch (e) {
        // Ignore if failed
      }
    }
  }
}
