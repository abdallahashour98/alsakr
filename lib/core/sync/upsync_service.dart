import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:sqflite/sqflite.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/sync/id_mapping_service.dart';
import 'package:al_sakr/core/sync/sync_constants.dart';
import 'package:al_sakr/core/sync/sync_logger.dart';

/// Handles pushing local pending changes to PocketBase.
///
/// Processes records with `sync_status` of:
/// - `pending_create` → POST to PocketBase, remap ID
/// - `pending_update` → PUT to PocketBase
/// - `pending_delete` → DELETE from PocketBase, remove locally
class UpsyncService {
  final Database db;
  final PocketBase pb;
  final IdMappingService idMapper;

  int _successCount = 0;
  int _failureCount = 0;

  int get successCount => _successCount;
  int get failureCount => _failureCount;

  UpsyncService({required this.db, required this.pb, required this.idMapper});

  /// Reset counters before a new sync cycle.
  void resetCounters() {
    _successCount = 0;
    _failureCount = 0;
  }

  /// Upsync all pending records across all tables, in dependency order.
  Future<void> upsyncAll() async {
    resetCounters();

    for (final table in syncTableOrder) {
      final collection = collectionToTable.entries
          .firstWhere(
            (e) => e.value == table,
            orElse: () => MapEntry(table, table),
          )
          .key;

      await _upsyncTable(table, collection);
    }

    SyncLogger.info('Upsync totals: ⬆$_successCount ❌$_failureCount');
  }

  /// Process all pending records in a single table.
  Future<void> _upsyncTable(String tableName, String collectionName) async {
    // --- PENDING CREATES ---
    await _processPendingCreates(tableName, collectionName);

    // --- PENDING UPDATES ---
    await _processPendingUpdates(tableName, collectionName);

    // --- PENDING DELETES ---
    await _processPendingDeletes(tableName, collectionName);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PENDING CREATE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processPendingCreates(
    String tableName,
    String collectionName,
  ) async {
    final rows = await db.query(
      tableName,
      where: '${DbConstants.colSyncStatus} = ?',
      whereArgs: [SyncStatus.pendingCreate],
    );

    if (rows.isEmpty) return;
    SyncLogger.info('Upsyncing ${rows.length} creates for "$tableName"');

    for (final row in rows) {
      try {
        final localId = row[DbConstants.colId] as String;

        if (tableName == 'users') {
          // Users cannot be upsynced as CREATE because they require passwords not stored locally.
          // Any pending_create user is a remnant of a 404 downgrade bug. Clean it up.
          await db.delete(
            tableName,
            where: '${DbConstants.colId} = ?',
            whereArgs: [localId],
          );
          SyncLogger.warn('Cleaned up orphan pending_create user $localId');
          continue;
        }

        final body = _buildServerBody(row, tableName);

        // Attach local image file if present
        final imageFile = await _extractImageFile(body);
        final List<http.MultipartFile> files = imageFile != null
            ? [imageFile]
            : [];

        // POST to PocketBase
        final record = await pb
            .collection(collectionName)
            .create(body: body, files: files);
        final serverId = record.id;

        // Handle stock delta atomically (for sale_items / return_items)
        if (stockDeltaTables.contains(tableName)) {
          await _applyStockDelta(row);
          // Safegurad: Zero out locally immediately so a crash before sync completion doesn't double deduct stock.
          await db.update(
            tableName,
            {'stock_delta': 0},
            where: '${DbConstants.colId} = ?',
            whereArgs: [localId],
          );
        }

        // Remap ID: local UUID → server ID, cascade FKs
        await idMapper.remapId(
          tableName: tableName,
          oldId: localId,
          newServerId: serverId,
        );

        // Mark as synced
        await db.update(
          tableName,
          {
            DbConstants.colSyncStatus: SyncStatus.synced,
            DbConstants.colLastSyncedAt: DateTime.now()
                .toUtc()
                .toIso8601String(),
            DbConstants.colPbUpdated: record.updated,
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [serverId],
        );

        _successCount++;
      } catch (e) {
        _failureCount++;
        SyncLogger.error('Failed to upsync CREATE in "$tableName"', e);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PENDING UPDATE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processPendingUpdates(
    String tableName,
    String collectionName,
  ) async {
    final rows = await db.query(
      tableName,
      where: '${DbConstants.colSyncStatus} = ?',
      whereArgs: [SyncStatus.pendingUpdate],
    );

    if (rows.isEmpty) return;
    SyncLogger.info('Upsyncing ${rows.length} updates for "$tableName"');

    for (final row in rows) {
      try {
        final id = row[DbConstants.colId] as String;
        final body = _buildServerBody(row, tableName);

        // Attach local image file if present
        final imageFile = await _extractImageFile(body);
        final List<http.MultipartFile> files = imageFile != null
            ? [imageFile]
            : [];

        // PUT to PocketBase
        final record = await pb
            .collection(collectionName)
            .update(id, body: body, files: files);

        // Handle stock delta atomically
        if (stockDeltaTables.contains(tableName)) {
          await _applyStockDelta(row);
          // Safegurad: Zero out locally immediately.
          await db.update(
            tableName,
            {'stock_delta': 0},
            where: '${DbConstants.colId} = ?',
            whereArgs: [id],
          );
        }

        // Mark as synced
        await db.update(
          tableName,
          {
            DbConstants.colSyncStatus: SyncStatus.synced,
            DbConstants.colLastSyncedAt: DateTime.now()
                .toUtc()
                .toIso8601String(),
            DbConstants.colPbUpdated: record.updated,
          },
          where: '${DbConstants.colId} = ?',
          whereArgs: [id],
        );

        _successCount++;
      } catch (e) {
        if (e is ClientException && e.statusCode == 404) {
          final id = row[DbConstants.colId] as String;
          if (tableName == 'users') {
            // Cannot downgrade users to CREATE because passwords aren't stored locally.
            // A 404 means the user was deleted on the server, so delete locally too.
            SyncLogger.warn(
              'User $id not found on server (404). Removing locally instead of downgrading.',
            );
            await db.delete(
              tableName,
              where: '${DbConstants.colId} = ?',
              whereArgs: [id],
            );
            _successCount++;
          } else {
            SyncLogger.warn(
              'Record $id in "$tableName" not found on server (404). '
              'Downgrading to pending_create.',
            );
            await db.update(
              tableName,
              {DbConstants.colSyncStatus: SyncStatus.pendingCreate},
              where: '${DbConstants.colId} = ?',
              whereArgs: [id],
            );
          }
        } else {
          _failureCount++;
          SyncLogger.error('Failed to upsync UPDATE in "$tableName"', e);
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PENDING DELETE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processPendingDeletes(
    String tableName,
    String collectionName,
  ) async {
    final rows = await db.query(
      tableName,
      where: '${DbConstants.colSyncStatus} = ?',
      whereArgs: [SyncStatus.pendingDelete],
    );

    if (rows.isEmpty) return;
    SyncLogger.info('Upsyncing ${rows.length} deletes for "$tableName"');

    for (final row in rows) {
      try {
        final id = row[DbConstants.colId] as String;

        // DELETE from PocketBase
        await pb.collection(collectionName).delete(id);

        // Remove from local DB
        await db.delete(
          tableName,
          where: '${DbConstants.colId} = ?',
          whereArgs: [id],
        );

        _successCount++;
      } catch (e) {
        // If 404, the record was already deleted on server — remove locally.
        if (e is ClientException && e.statusCode == 404) {
          final id = row[DbConstants.colId] as String;
          await db.delete(
            tableName,
            where: '${DbConstants.colId} = ?',
            whereArgs: [id],
          );
          _successCount++;
          SyncLogger.warn(
            'Record already deleted on server for "$tableName", removed locally.',
          );
        } else {
          _failureCount++;
          SyncLogger.error('Failed to upsync DELETE in "$tableName"', e);
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a server-ready body from a local SQLite row,
  /// stripping out sync-specific columns and SQLite booleans.
  Map<String, dynamic> _buildServerBody(
    Map<String, dynamic> row,
    String tableName,
  ) {
    final body = Map<String, dynamic>.from(row);

    // Remove sync-only columns
    body.remove(DbConstants.colId);
    body.remove(DbConstants.colLocalId);
    body.remove(DbConstants.colSyncStatus);
    body.remove(DbConstants.colLastSyncedAt);
    body.remove(DbConstants.colPbUpdated);
    body.remove(DbConstants.colUpdated);

    // Prevent clients absolute balance from being overwritten entirely during an offline bulk sync.
    // Balances are typically recalculated on the server based on transactions/payments.
    if (tableName == DbConstants.tableClients ||
        tableName == DbConstants.tableSuppliers) {
      body.remove('balance');
    }

    // Remove stock_delta (handled atomically, not sent as a normal field)
    body.remove('stock_delta');

    // Convert SQLite integers back to booleans for PocketBase
    for (final key in [
      'is_deleted',
      'is_complete',
      'isLocked',
      // User Permissions
      'allow_manage_permissions',
      'allow_edit_settings',
      'allow_backup_data',
      'show_sales',
      'show_sales_history',
      'allow_add_orders',
      'allow_edit_orders',
      'allow_delete_orders',
      'allow_add_returns',
      'allow_change_price',
      'allow_add_discount',
      'show_purchases',
      'show_purchase_history',
      'allow_add_purchases',
      'allow_edit_purchases',
      'allow_delete_purchases',
      'show_stock',
      'allow_add_products',
      'allow_edit_products',
      'allow_delete_products',
      'show_delivery',
      'allow_add_delivery',
      'allow_delete_delivery',
      'allow_inventory_settlement',
      'show_buy_price',
      'show_clients',
      'show_suppliers',
      'allow_add_clients',
      'allow_edit_clients',
      'allow_delete_clients',
      'show_expenses',
      'allow_add_expenses',
      'allow_delete_expenses',
      'allow_view_drawer',
      'allow_add_revenues',
      'show_reports',
      'show_returns',
      'allow_delete_returns',
    ]) {
      if (body.containsKey(key) && body[key] is int) {
        body[key] = body[key] == 1;
      }
    }

    // For return_items, map 'return_id' back to PocketBase's 'return' field
    if (tableName == 'return_items' && body.containsKey('return_id')) {
      body['return'] = body.remove('return_id');
    }

    return body;
  }

  /// Applies the stock delta atomically to PocketBase.
  ///
  /// For sale_items: stock_delta is negative (e.g., -3 → send {'stock-': 3})
  /// For return_items: stock_delta is positive (e.g., +3 → send {'stock+': 3})
  Future<void> _applyStockDelta(Map<String, dynamic> row) async {
    final stockDelta = (row['stock_delta'] as num?)?.toInt() ?? 0;
    if (stockDelta == 0) return;

    final productId = row['product'] as String?;
    if (productId == null || productId.isEmpty) return;

    try {
      if (stockDelta < 0) {
        // Sale: decrease stock
        await pb
            .collection('products')
            .update(productId, body: {'stock-': stockDelta.abs()});
      } else {
        // Return: increase stock
        await pb
            .collection('products')
            .update(productId, body: {'stock+': stockDelta});
      }
      SyncLogger.info('Applied stock delta $stockDelta to product $productId');
    } catch (e) {
      SyncLogger.error('Failed to apply stock delta for product $productId', e);
      rethrow;
    }
  }

  /// Checks if `body['image']` is a local file path, converts it to a
  /// [http.MultipartFile], removes it from the body, and returns it.
  /// Returns `null` if there is no local image to upload.
  Future<http.MultipartFile?> _extractImageFile(
    Map<String, dynamic> body,
  ) async {
    final image = body['image'];
    if (image == null || image is! String || image.isEmpty) return null;

    // If it already starts with 'http', it's a server URL — nothing to upload.
    if (image.startsWith('http')) return null;

    final file = File(image);
    if (!file.existsSync()) {
      SyncLogger.warn('Image file not found at path: $image — skipping upload');
      body.remove('image');
      return null;
    }

    body.remove('image');
    return http.MultipartFile.fromPath('image', image);
  }
}
