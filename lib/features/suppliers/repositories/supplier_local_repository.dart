import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/supplier_model.dart';

class SupplierLocalRepository {
  final Database db;
  static const _uuid = Uuid();

  SupplierLocalRepository(this.db);

  Future<List<SupplierModel>> getSuppliers() async {
    final rows = await db.query(
      DbConstants.tableSuppliers,
      where: '${DbConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.pendingDelete],
      orderBy: 'name ASC',
    );
    return rows.map((r) => SupplierModel.fromMap(r)).toList();
  }

  Future<SupplierModel?> getSupplierById(String id) async {
    final rows = await db.query(
      DbConstants.tableSuppliers,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SupplierModel.fromMap(rows.first);
  }

  Future<SupplierModel> createSupplier(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = _uuid.v4();
    final supplier = SupplierModel(
      id: localId,
      localId: localId,
      syncStatus: SyncStatus.pendingCreate,
      created: now,
      updated: now,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
    );
    await db.insert(
      DbConstants.tableSuppliers,
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return supplier;
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> data) async {
    final existing = await getSupplierById(id);
    if (existing == null) return;
    final newStatus = existing.syncStatus == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = existing.copyWith(
      syncStatus: newStatus,
      updated: now,
      name: data['name'] as String? ?? existing.name,
      phone: data['phone'] as String? ?? existing.phone,
      address: data['address'] as String? ?? existing.address,
    );
    await db.update(
      DbConstants.tableSuppliers,
      updated.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSupplier(String id) async {
    final existing = await getSupplierById(id);
    if (existing == null) return;
    if (existing.syncStatus == SyncStatus.pendingCreate) {
      await db.delete(
        DbConstants.tableSuppliers,
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        DbConstants.tableSuppliers,
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
