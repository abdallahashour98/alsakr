import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expenses_repository.g.dart';

class ExpensesRepository {
  final PocketBase globalPb;

  ExpensesRepository(this.globalPb);

  Future<List<RecordModel>> getExpenses({String? startDate, String? endDate}) async {
    String filter = 'is_deleted = false';
    if (startDate != null && endDate != null) {
      filter += ' && date >= "$startDate" && date <= "$endDate"';
    }
    return await globalPb.collection('expenses').getFullList(sort: '-date', filter: filter);
  }

  Future<RecordModel> createExpense(Map<String, dynamic> body) async {
    return await globalPb.collection('expenses').create(body: body);
  }

  Future<void> updateExpense(String id, Map<String, dynamic> body) async {
    await globalPb.collection('expenses').update(id, body: body);
  }

  Future<void> deleteExpense(String id) async {
    await globalPb.collection('expenses').update(id, body: {'is_deleted': true});
  }
}

@riverpod
Future<ExpensesRepository> expensesRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return ExpensesRepository(pb);
}
