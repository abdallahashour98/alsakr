import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/product_model.dart';
import 'package:al_sakr/core/database/models/unit_model.dart';

class StoreLocalRepository {
  final Database db;
  static const _uuid = Uuid();

  StoreLocalRepository(this.db);

  // ── Products ────────────────────────────────────────────────────────
  Future<List<ProductModel>> getProducts() async {
    final rows = await db.query(
      DbConstants.tableProducts,
      where: '${DbConstants.colSyncStatus} != ? AND is_deleted = ?',
      whereArgs: [SyncStatus.pendingDelete, 0],
      orderBy: 'name ASC',
    );
    return rows.map((r) => ProductModel.fromMap(r)).toList();
  }

  Future<ProductModel?> getProductById(String id) async {
    final rows = await db.query(
      DbConstants.tableProducts,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProductModel.fromMap(rows.first);
  }

  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = _uuid.v4();
    final product = ProductModel(
      id: localId,
      localId: localId,
      syncStatus: SyncStatus.pendingCreate,
      created: now,
      updated: now,
      name: data['name'] ?? '',
      buyPrice: (data['buyPrice'] as num?)?.toDouble() ?? 0.0,
      sellPrice: (data['sellPrice'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      unit: data['unit'] ?? '',
      supplier: data['supplier'] ?? '',
      image: data['image'] ?? '',
    );
    await db.insert(
      DbConstants.tableProducts,
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return product;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    final existing = await getProductById(id);
    if (existing == null) return;
    final newStatus = existing.syncStatus == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = existing.copyWith(
      syncStatus: newStatus,
      updated: now,
      name: data['name'] as String? ?? existing.name,
      buyPrice: data.containsKey('buyPrice')
          ? (data['buyPrice'] as num).toDouble()
          : existing.buyPrice,
      sellPrice: data.containsKey('sellPrice')
          ? (data['sellPrice'] as num).toDouble()
          : existing.sellPrice,
      stock: data.containsKey('stock')
          ? (data['stock'] as num).toInt()
          : existing.stock,
      unit: data['unit'] as String? ?? existing.unit,
      supplier: data['supplier'] as String? ?? existing.supplier,
    );
    await db.update(
      DbConstants.tableProducts,
      updated.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(String id) async {
    final existing = await getProductById(id);
    if (existing == null) return;
    if (existing.syncStatus == SyncStatus.pendingCreate) {
      await db.delete(
        DbConstants.tableProducts,
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        DbConstants.tableProducts,
        {
          DbConstants.colSyncStatus: SyncStatus.pendingDelete,
          DbConstants.colUpdated: DateTime.now().toUtc().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  Future<List<ProductModel>> getDeletedProducts() async {
    final rows = await db.query(
      DbConstants.tableProducts,
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
    return rows.map((r) => ProductModel.fromMap(r)).toList();
  }

  // ── Units ───────────────────────────────────────────────────────────
  Future<List<String>> getUnits() async {
    final rows = await db.query(
      DbConstants.tableUnits,
      where: '${DbConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.pendingDelete],
      orderBy: 'name ASC',
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  Future<void> createUnit(String name) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = _uuid.v4();
    final unit = UnitModel(
      id: localId,
      localId: localId,
      syncStatus: SyncStatus.pendingCreate,
      created: now,
      updated: now,
      name: name,
    );
    await db.insert(
      DbConstants.tableUnits,
      unit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteUnit(String name) async {
    final rows = await db.query(
      DbConstants.tableUnits,
      where: 'name = ?',
      whereArgs: [name],
    );
    for (final row in rows) {
      final status = row[DbConstants.colSyncStatus] as String?;
      final id = row[DbConstants.colId] as String;
      if (status == SyncStatus.pendingCreate) {
        await db.delete(
          DbConstants.tableUnits,
          where: '${DbConstants.colId} = ?',
          whereArgs: [id],
        );
      } else {
        await db.update(
          DbConstants.tableUnits,
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
}
