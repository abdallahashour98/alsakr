import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/features/expenses/repositories/expense_local_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expenses_controller.g.dart';

@riverpod
class ExpensesController extends _$ExpensesController {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = ExpenseLocalRepository(db);
    final expenses = await repo.getExpenses();
    return expenses.map((e) => e.toMap()).toList();
  }

  // ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getExpenses({
    String? startDate,
    String? endDate,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ExpenseLocalRepository(db);
    final expenses = await repo.getExpenses(
      startDate: startDate,
      endDate: endDate,
    );
    return expenses.map((e) => e.toMap()).toList();
  }

  Future<String> addExpense(Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ExpenseLocalRepository(db);
    final expense = await repo.createExpense(data);
    ref.invalidateSelf();
    return expense.id;
  }

  Future<void> updateExpense(String id, Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ExpenseLocalRepository(db);
    await repo.updateExpense(id, data);
    ref.invalidateSelf();
  }

  Future<void> deleteExpense(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = ExpenseLocalRepository(db);
    await repo.deleteExpense(id);
    ref.invalidateSelf();
  }
}
