import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/client_model.dart';

/// Repository that reads and writes ONLY to the local SQLite database.
/// All CRUD operations mark records with the appropriate `sync_status`
/// so that the SyncManager can push changes to PocketBase.
class ClientLocalRepository {
  final Database db;
  static const _uuid = Uuid();

  ClientLocalRepository(this.db);

  // ─────────────────────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────────────────────

  /// Stream all non-deleted clients, sorted by name.
  /// Emits a new list whenever the stream is polled.
  Stream<List<ClientModel>> watchClients() async* {
    // Initial emission
    yield await getClients();

    // Poll-based reactivity – the controller will re-trigger via
    // invalidateSelf() after any write operation. This avoids complex
    // SQLite change-notification setups.
  }

  /// Get all non-deleted clients.
  Future<List<ClientModel>> getClients() async {
    final rows = await db.query(
      DbConstants.tableClients,
      where: '${DbConstants.colSyncStatus} != ? AND is_deleted = ?',
      whereArgs: [SyncStatus.pendingDelete, 0],
      orderBy: 'name ASC',
    );
    return rows.map((row) => ClientModel.fromMap(row)).toList();
  }

  /// Get all deleted clients.
  Future<List<ClientModel>> getDeletedClients() async {
    final rows = await db.query(
      DbConstants.tableClients,
      where: 'is_deleted = ? AND ${DbConstants.colSyncStatus} != ?',
      whereArgs: [1, SyncStatus.pendingDelete],
      orderBy: 'name ASC',
    );
    return rows.map((row) => ClientModel.fromMap(row)).toList();
  }

  /// Get a single client by ID.
  Future<ClientModel?> getClientById(String id) async {
    final rows = await db.query(
      DbConstants.tableClients,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ClientModel.fromMap(rows.first);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────────────────────────────────

  /// Insert a new client locally. Returns the created model with a local UUID.
  Future<ClientModel> createClient(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = _uuid.v4();

    final client = ClientModel(
      id: localId,
      localId: localId,
      syncStatus: SyncStatus.pendingCreate,
      lastSyncedAt: null,
      pbUpdated: null,
      created: now,
      updated: now,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      isDeleted: false,
    );

    await db.insert(
      DbConstants.tableClients,
      client.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return client;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────────────────────────────────

  /// Update an existing client. If the record was already synced,
  /// its status changes to `pending_update`. If it's still `pending_create`,
  /// it stays as `pending_create` (no need for a separate update status).
  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    final existing = await getClientById(id);
    if (existing == null) return;

    final newStatus = existing.syncStatus == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;

    final now = DateTime.now().toUtc().toIso8601String();

    // Merge data onto existing fields
    final updated = existing.copyWith(
      syncStatus: newStatus,
      updated: now,
      name: data['name'] as String? ?? existing.name,
      phone: data['phone'] as String? ?? existing.phone,
      address: data['address'] as String? ?? existing.address,
      balance: data.containsKey('balance')
          ? (data['balance'] as num).toDouble()
          : existing.balance,
    );

    await db.update(
      DbConstants.tableClients,
      updated.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  /// Mark a client as pending deletion.
  /// If the record was never synced (`pending_create`), just remove it.
  Future<void> deleteClient(String id) async {
    final existing = await getClientById(id);
    if (existing == null) return;

    if (existing.syncStatus == SyncStatus.pendingCreate) {
      // Never synced — just remove locally
      await db.delete(
        DbConstants.tableClients,
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    } else {
      // Mark for server deletion
      await db.update(
        DbConstants.tableClients,
        {
          DbConstants.colSyncStatus: SyncStatus.pendingDelete,
          DbConstants.colUpdated: DateTime.now().toUtc().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    }
  }
}
