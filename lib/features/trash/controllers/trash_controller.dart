import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trash_controller.g.dart';

/// Trash controller — queries the local DB for soft-deleted items.
@riverpod
class TrashController extends _$TrashController {
  @override
  FutureOr<void> build() async {}

  /// Get deleted items from a specific table.
  Future<List<Map<String, dynamic>>> getDeletedItems(
    String collectionName,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    try {
      return await db.query(
        collectionName,
        where: 'is_deleted = ?',
        whereArgs: [1],
        orderBy: '${DbConstants.colUpdated} DESC',
      );
    } catch (e) {
      print('Error fetching deleted items for $collectionName: $e');
      return [];
    }
  }

  /// Restore a soft-deleted item by setting is_deleted = 0.
  Future<void> restoreItem(String collectionName, String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      collectionName,
      {
        'is_deleted': 0,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Permanently delete an item (mark for server deletion).
  Future<void> deleteItemForever(String collectionName, String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      collectionName,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final status = rows.first[DbConstants.colSyncStatus] as String?;
    if (status == SyncStatus.pendingCreate) {
      await db.delete(
        collectionName,
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        collectionName,
        {
          DbConstants.colSyncStatus: SyncStatus.pendingDelete,
          DbConstants.colUpdated: now,
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  String getItemName(dynamic item, String collectionName) {
    if (collectionName == 'products' ||
        collectionName == 'clients' ||
        collectionName == 'suppliers') {
      return item['name'] ?? 'غيـر معـروف';
    } else if (collectionName == 'expenses') {
      return item['title']?.toString().isNotEmpty == true
          ? item['title']
          : item['category'] ?? 'مصروف';
    } else if (collectionName == 'announcements') {
      return item['title']?.toString().isNotEmpty == true
          ? item['title']
          : 'إشعار بدون عنوان';
    }
    return item['id'] ?? 'عنصـر';
  }
}
