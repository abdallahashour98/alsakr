import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/models/expense_model.dart';

class ExpenseLocalRepository {
  final Database db;
  static const _uuid = Uuid();

  ExpenseLocalRepository(this.db);

  Future<List<ExpenseModel>> getExpenses({
    String? startDate,
    String? endDate,
  }) async {
    String where = '${DbConstants.colSyncStatus} != ? AND is_deleted = ?';
    List<dynamic> args = [SyncStatus.pendingDelete, 0];
    if (startDate != null && endDate != null) {
      where += ' AND date >= ? AND date <= ?';
      args.addAll([startDate, endDate]);
    } else if (startDate != null) {
      where += ' AND date >= ?';
      args.add(startDate);
    } else if (endDate != null) {
      where += ' AND date <= ?';
      args.add(endDate);
    }
    final rows = await db.query(
      DbConstants.tableExpenses,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );
    return rows.map((r) => ExpenseModel.fromMap(r)).toList();
  }

  Future<ExpenseModel?> getExpenseById(String id) async {
    final rows = await db.query(
      DbConstants.tableExpenses,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExpenseModel.fromMap(rows.first);
  }

  Future<ExpenseModel> createExpense(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = _uuid.v4();
    final expense = ExpenseModel(
      id: localId,
      localId: localId,
      syncStatus: SyncStatus.pendingCreate,
      created: now,
      updated: now,
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '',
      date: data['date'] ?? now,
    );
    await db.insert(
      DbConstants.tableExpenses,
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return expense;
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    final existing = await getExpenseById(id);
    if (existing == null) return;
    final newStatus = existing.syncStatus == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = existing.copyWith(
      syncStatus: newStatus,
      updated: now,
      description: data['description'] as String? ?? existing.description,
      amount: data.containsKey('amount')
          ? (data['amount'] as num).toDouble()
          : existing.amount,
      category: data['category'] as String? ?? existing.category,
      date: data['date'] as String? ?? existing.date,
    );
    await db.update(
      DbConstants.tableExpenses,
      updated.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(String id) async {
    final existing = await getExpenseById(id);
    if (existing == null) return;
    if (existing.syncStatus == SyncStatus.pendingCreate) {
      await db.delete(
        DbConstants.tableExpenses,
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        DbConstants.tableExpenses,
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
