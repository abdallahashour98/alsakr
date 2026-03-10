import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'package:sqflite/sqflite.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/network/pb_helper.dart';
import 'package:al_sakr/core/sync/sync_constants.dart';
import 'package:al_sakr/core/sync/sync_logger.dart';

/// Handles pulling changes from PocketBase into the local SQLite database
/// using delta sync (only records updated since the last sync).
class DownsyncService {
  final Database db;
  final PocketBase pb;

  int _successCount = 0;
  int get successCount => _successCount;

  // Cache for valid column names per table to avoid PRAGMA queries on every sync
  final Map<String, Set<String>> _tableColumnsCache = {};

  DownsyncService({required this.db, required this.pb});

  /// Reset counters before a new cycle.
  void resetCounters() {
    _successCount = 0;
  }

  /// Get valid columns for a table.
  Future<Set<String>> _getValidColumns(String tableName) async {
    if (_tableColumnsCache.containsKey(tableName)) {
      return _tableColumnsCache[tableName]!;
    }
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    final columns = result.map((row) => row['name'] as String).toSet();
    _tableColumnsCache[tableName] = columns;
    return columns;
  }

  /// Downsync all collections in dependency order.
  Future<void> downsyncAll() async {
    resetCounters();

    for (final table in syncTableOrder) {
      final collection = collectionToTable.entries
          .firstWhere(
            (e) => e.value == table,
            orElse: () => MapEntry(table, table),
          )
          .key;

      await _downsyncCollection(collection, table);
    }

    SyncLogger.info('Downsync totals: ⬇$_successCount');
  }

  /// Fetch records updated since last sync and upsert them locally.
  Future<void> _downsyncCollection(
    String collectionName,
    String tableName,
  ) async {
    try {
      // 1. Read last sync time for this collection.
      final lastSyncTime = await _getLastSyncTime(collectionName);

      // 2. Build filter for delta sync.
      String? filter;
      if (lastSyncTime != null) {
        filter = 'updated >= "$lastSyncTime"';
      }

      // 3. Fetch from PocketBase.
      final records = await pb
          .collection(collectionName)
          .getFullList(
            filter: filter,
            sort: 'updated', // oldest first for ordered insertion
          );

      if (records.isEmpty) return;

      SyncLogger.info(
        'Downsyncing ${records.length} records for "$collectionName"',
      );

      // Get valid columns for this table to prevent SQLite schema mismatch errors
      final validColumns = await _getValidColumns(tableName);

      // 4. Upsert each record into local DB.
      final batch = db.batch();
      int batchCount = 0;
      for (final record in records) {
        try {
          // ── Fix 2: Handle soft-deleted records and Cascade ──
          if (record.data['is_deleted'] == true) {
            await db.delete(
              tableName,
              where: '${DbConstants.colId} = ?',
              whereArgs: [record.id],
            );

            // Manual CASCADE: SQLite PRAGMA OFF by default or missing on older schemas.
            // We strip orphans here.
            if (tableName == DbConstants.tableSales) {
              await db.delete(
                DbConstants.tableSaleItems,
                where: 'sale = ?',
                whereArgs: [record.id],
              );
            } else if (tableName == DbConstants.tablePurchases) {
              await db.delete(
                DbConstants.tablePurchaseItems,
                where: 'purchase = ?',
                whereArgs: [record.id],
              );
            } else if (tableName == DbConstants.tableReturns) {
              await db.delete(
                DbConstants.tableReturnItems,
                where: 'return_id = ?',
                whereArgs: [record.id],
              );
            } else if (tableName == DbConstants.tablePurchaseReturns) {
              await db.delete(
                DbConstants.tablePurchaseReturnItems,
                where: 'purchase_return = ?',
                whereArgs: [record.id],
              );
            } else if (tableName == DbConstants.tableDeliveryOrders) {
              await db.delete(
                DbConstants.tableDeliveryOrderItems,
                where: 'delivery_order = ?',
                whereArgs: [record.id],
              );
            }

            _successCount++;
            SyncLogger.info(
              'Deleted soft-deleted record ${record.id} from "$tableName"',
            );
            continue;
          }

          // ── Fix 3: Local Wins — skip if local record has pending changes ──
          final existingRows = await db.query(
            tableName,
            columns: [DbConstants.colSyncStatus],
            where: '${DbConstants.colId} = ?',
            whereArgs: [record.id],
            limit: 1,
          );
          if (existingRows.isNotEmpty) {
            final localStatus =
                existingRows.first[DbConstants.colSyncStatus] as String?;
            if (localStatus == SyncStatus.pendingUpdate ||
                localStatus == SyncStatus.pendingDelete) {
              SyncLogger.info(
                'Skipping downsync for ${record.id} in "$tableName"'
                ' — local change pending ($localStatus)',
              );
              continue;
            }
          }

          final localRow = _recordToLocalRow(record, tableName);

          // Strip any keys from the PB record that don't exist in SQLite
          // AND strip explicit null values so SQLite applies DEFAULTs correctly
          localRow.removeWhere(
            (key, value) =>
                !validColumns.contains(key) || value == null || value == 'null',
          );

          batch.insert(
            tableName,
            localRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          batchCount++;
        } catch (e) {
          SyncLogger.error(
            'Failed to prepare row for $tableName: ${record.id}',
            e,
          );
        }
      }
      try {
        await batch.commit(noResult: true);
        _successCount += batchCount;
      } catch (e) {
        SyncLogger.error('Batch commit failed for "$collectionName"', e);
        throw Exception('Batch commit failed: $e');
      }

      // 5. Update sync_meta with current time.
      await _updateLastSyncTime(
        collectionName,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      SyncLogger.error('Downsync failed for "$collectionName"', e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // sync_meta helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _getLastSyncTime(String collectionName) async {
    final rows = await db.query(
      DbConstants.tableSyncMeta,
      where: 'collection_name = ?',
      whereArgs: [collectionName],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['last_sync_time'] as String?;
  }

  Future<void> _updateLastSyncTime(
    String collectionName,
    String timestamp,
  ) async {
    await db.insert(DbConstants.tableSyncMeta, {
      'collection_name': collectionName,
      'last_sync_time': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Record → Local Row conversion
  // ─────────────────────────────────────────────────────────────────────────

  /// Converts a PocketBase [RecordModel] to a map suitable for SQLite upsert.
  /// All records coming from the server are marked as `synced`.
  Map<String, dynamic> _recordToLocalRow(RecordModel record, String tableName) {
    final data = Map<String, dynamic>.from(PBHelper.recordToMap(record));

    // Ensure core sync fields are set
    data[DbConstants.colId] = record.id;
    data[DbConstants.colLocalId] = data[DbConstants.colLocalId] ?? record.id;
    data[DbConstants.colSyncStatus] = SyncStatus.synced;
    data[DbConstants.colLastSyncedAt] = DateTime.now()
        .toUtc()
        .toIso8601String();
    data[DbConstants.colPbUpdated] = record.updated;
    data[DbConstants.colCreated] = record.created;
    data[DbConstants.colUpdated] = record.updated;

    // Remove expand-generated fields (they don't exist in SQLite tables)
    data.remove('collectionId');
    data.remove('collectionName');
    data.remove('supplierName');
    data.remove('clientName');
    data.remove('productName');
    data.remove('userName');
    data.remove('seen_by_names');
    data.remove('imagePath');
    data.remove('expand');

    // 1. Convert ALL native booleans from PocketBase JSON into SQLite integers.
    // This dynamically handles the 30+ permission columns and any other boolean type.
    for (final key in data.keys.toList()) {
      if (data[key] is bool) {
        data[key] = (data[key] as bool) ? 1 : 0;
      }
    }

    // 2. Fallback: handle legacy boolean string/num values for specific known columns
    for (final key in [
      'is_deleted',
      'is_complete',
      'isLocked',
      'allow_add_clients',
      'allow_edit_clients',
      'allow_delete_clients',
      'allow_add_purchases',
      'allow_add_orders',
      'allow_change_price',
      'allow_add_discount',
      'show_buy_price',
      'allow_view_drawer',
      'allow_add_revenues',
      'allow_inventory_settlement',
    ]) {
      if (data.containsKey(key) && data[key] is! int) {
        final val = data[key];
        if (val is String) {
          final lower = val.toLowerCase();
          data[key] = (lower == 'true' || lower == '1') ? 1 : 0;
        } else if (val is num) {
          data[key] = val > 0 ? 1 : 0;
        } else {
          data[key] = 0; // Default fallback
        }
      }
    }

    // For return_items: PocketBase uses 'return', SQLite uses 'return_id'
    if (tableName == 'return_items' && data.containsKey('return')) {
      data['return_id'] = data.remove('return');
    }

    // Ensure stock_delta defaults to 0 for downsynced records
    if (stockDeltaTables.contains(tableName)) {
      data['stock_delta'] = 0;
    }

    // Convert ALL List-type values to JSON strings for SQLite compatibility.
    // PocketBase returns Lists for file fields, relation fields, etc.
    // SQLite only accepts: null, bool, int, num, String, or List<int>.
    for (final key in data.keys.toList()) {
      if (data[key] is List) {
        data[key] = jsonEncode(data[key]);
      }
    }

    return data;
  }
}
