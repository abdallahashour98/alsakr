import 'dart:async';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/features/clients/repositories/client_local_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'client_controller.g.dart';

/// Client controller that reads ONLY from the local SQLite database.
///
/// All mutations (create, update, delete) write to the local DB
/// with the appropriate `sync_status`. The [SyncManager] handles
/// pushing those changes to PocketBase in the background.
@riverpod
class ClientController extends _$ClientController {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = ClientLocalRepository(db);

    // Initial fetch from local DB
    final clients = await repo.getClients();
    return clients.map((c) => c.toMap()).toList();

    // Keep alive — any mutation calls invalidateSelf() to re-emit.
  }

  // ────────────────────────────────────────────────────────────────────
  // Mutations
  // ────────────────────────────────────────────────────────────────────

  /// Create a new client in the local DB. Returns the new client's ID.
  Future<String> createClient(Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ClientLocalRepository(db);
    final client = await repo.createClient(data);
    ref.invalidateSelf(); // Re-emit the updated list
    return client.id;
  }

  /// Update an existing client in the local DB.
  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ClientLocalRepository(db);
    await repo.updateClient(id, data);
    ref.invalidateSelf();
  }

  /// Soft-delete a client in the local DB.
  Future<void> deleteClient(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ClientLocalRepository(db);
    await repo.deleteClient(id);
    ref.invalidateSelf();
  }

  /// Get a single client by ID from local DB.
  Future<Map<String, dynamic>?> getClientById(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ClientLocalRepository(db);
    final client = await repo.getClientById(id);
    return client?.toMap();
  }

  /// Get all deleted clients
  Future<List<Map<String, dynamic>>> getDeletedClients() async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ClientLocalRepository(db);
    final clients = await repo.getDeletedClients();
    return clients.map((c) => c.toMap()).toList();
  }

  /// Get the opening balance for a specific client from the local DB.
  Future<double> getClientOpeningBalance(String clientId) async {
    final db = await ref.read(localDatabaseProvider.future);
    final rows = await db.query(
      DbConstants.tableOpeningBalances,
      where: 'client = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['amount'] as num?)?.toDouble() ?? 0.0;
  }

  /// Update or create the opening balance for a client.
  Future<void> updateClientOpeningBalance(
    String clientId,
    double amount,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();

    // Check if an opening balance already exists
    final existing = await db.query(
      DbConstants.tableOpeningBalances,
      where: 'client = ?',
      whereArgs: [clientId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final currentStatus =
          existing.first[DbConstants.colSyncStatus] as String?;
      final newStatus = currentStatus == SyncStatus.pendingCreate
          ? SyncStatus.pendingCreate
          : SyncStatus.pendingUpdate;

      await db.update(
        DbConstants.tableOpeningBalances,
        {
          'amount': amount,
          'date': now,
          DbConstants.colSyncStatus: newStatus,
          DbConstants.colUpdated: now,
        },
        where: 'client = ?',
        whereArgs: [clientId],
      );
    } else {
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      await db.insert(DbConstants.tableOpeningBalances, {
        DbConstants.colId: localId,
        DbConstants.colLocalId: localId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'client': clientId,
        'amount': amount,
        'date': now,
        'notes': '',
      });
    }
    ref.invalidateSelf();
  }
}
