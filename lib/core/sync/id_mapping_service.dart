import 'package:sqflite/sqflite.dart';
import 'package:al_sakr/core/sync/sync_constants.dart';
import 'package:al_sakr/core/sync/sync_logger.dart';

/// Handles mapping offline local UUIDs to PocketBase server IDs
/// and cascading the new ID to all child FK references.
class IdMappingService {
  final Database db;

  IdMappingService(this.db);

  /// After a local record with [oldId] is upsynced and receives [newServerId],
  /// this method:
  /// 1. Updates the record's own `id` in [tableName]
  /// 2. Cascades the new ID to all child tables that reference it via FK
  Future<void> remapId({
    required String tableName,
    required String oldId,
    required String newServerId,
  }) async {
    SyncLogger.info('Remapping ID in "$tableName": $oldId → $newServerId');

    await db.transaction((txn) async {
      // 1. Update the parent record's own ID.
      await txn.rawUpdate('UPDATE $tableName SET id = ? WHERE id = ?', [
        newServerId,
        oldId,
      ]);

      // 2. Cascade to child tables.
      final relations = fkCascadeMap[tableName];
      if (relations != null) {
        for (final rel in relations) {
          final updated = await txn.rawUpdate(
            'UPDATE ${rel.childTable} SET ${rel.childColumn} = ? '
            'WHERE ${rel.childColumn} = ?',
            [newServerId, oldId],
          );
          if (updated > 0) {
            SyncLogger.info(
              '  ↳ Cascaded to ${rel.childTable}.${rel.childColumn}: '
              '$updated row(s)',
            );
          }
        }
      }
    });
  }

  /// Batch remap multiple IDs in one transaction.
  /// [mappings] is a list of (oldId, newServerId) pairs for [tableName].
  Future<void> remapIds({
    required String tableName,
    required List<MapEntry<String, String>> mappings,
  }) async {
    if (mappings.isEmpty) return;

    await db.transaction((txn) async {
      for (final entry in mappings) {
        final oldId = entry.key;
        final newId = entry.value;

        await txn.rawUpdate('UPDATE $tableName SET id = ? WHERE id = ?', [
          newId,
          oldId,
        ]);

        final relations = fkCascadeMap[tableName];
        if (relations != null) {
          for (final rel in relations) {
            await txn.rawUpdate(
              'UPDATE ${rel.childTable} SET ${rel.childColumn} = ? '
              'WHERE ${rel.childColumn} = ?',
              [newId, oldId],
            );
          }
        }
      }
    });

    SyncLogger.info('Batch remapped ${mappings.length} IDs in "$tableName"');
  }
}
