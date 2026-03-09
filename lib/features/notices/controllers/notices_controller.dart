import 'dart:convert';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'notices_controller.g.dart';

class UnreadNoticesCount extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
  void reset() => state = 0;
  void set(int val) => state = val;
}

final unreadNoticesCountProvider = NotifierProvider<UnreadNoticesCount, int>(
  UnreadNoticesCount.new,
);

@riverpod
class NoticesController extends _$NoticesController {
  static const _uuid = Uuid();

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final rows = await db.query(
      DbConstants.tableAnnouncements,
      where: '${DbConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.pendingDelete],
      orderBy: '${DbConstants.colCreated} DESC',
    );
    return rows;
  }

  Future<void> createAnnouncement(
    Map<String, dynamic> data, {
    List<String>? targetUserIds,
    List<dynamic>? files,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = _uuid.v4();
    await db.insert(DbConstants.tableAnnouncements, {
      DbConstants.colId: localId,
      DbConstants.colLocalId: localId,
      DbConstants.colSyncStatus: SyncStatus.pendingCreate,
      DbConstants.colCreated: now,
      DbConstants.colUpdated: now,
      'title': data['title'] ?? '',
      'body': data['body'] ?? '',
      'image': '',
      'target_users': jsonEncode(targetUserIds ?? []),
      'seen_by': '[]',
      'type': data['type'] ?? 'general',
    });
    ref.invalidateSelf();
  }

  Future<void> updateAnnouncement(
    String id,
    Map<String, dynamic> data, {
    List<String>? targetUserIds,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final updateData = <String, dynamic>{
      DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
      DbConstants.colUpdated: now,
    };
    if (data.containsKey('title')) updateData['title'] = data['title'];
    if (data.containsKey('body')) updateData['body'] = data['body'];
    if (targetUserIds != null)
      updateData['target_users'] = jsonEncode(targetUserIds);
    await db.update(
      DbConstants.tableAnnouncements,
      updateData,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }

  Future<void> deleteAnnouncement(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableAnnouncements,
      {
        DbConstants.colSyncStatus: SyncStatus.pendingDelete,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }

  Future<void> markAnnouncementAsSeen(String id, String userId) async {
    final db = await ref.read(localDatabaseProvider.future);
    final rows = await db.query(
      DbConstants.tableAnnouncements,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    List<dynamic> seenBy = [];
    try {
      seenBy = jsonDecode(rows.first['seen_by']?.toString() ?? '[]');
    } catch (_) {}
    if (!seenBy.contains(userId)) {
      seenBy.add(userId);
      final now = DateTime.now().toUtc().toIso8601String();
      await db.update(
        DbConstants.tableAnnouncements,
        {
          'seen_by': jsonEncode(seenBy),
          DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
          DbConstants.colUpdated: now,
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<dynamic>> getUsersNoticesScreen(String userId) async {
    return [];
  }

  // --- دوال سلة المهملات ---
  Future<List<Map<String, dynamic>>> getDeletedAnnouncements() async {
    final db = await ref.read(localDatabaseProvider.future);
    return await db.query(
      DbConstants.tableAnnouncements,
      where: '${DbConstants.colSyncStatus} = ?',
      whereArgs: [SyncStatus.pendingDelete],
      orderBy: '${DbConstants.colCreated} DESC',
    );
  }

  Future<void> restoreAnnouncement(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableAnnouncements,
      {
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }

  Future<void> deleteAnnouncementForever(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    await db.delete(
      DbConstants.tableAnnouncements,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    ref.invalidateSelf();
  }
}
