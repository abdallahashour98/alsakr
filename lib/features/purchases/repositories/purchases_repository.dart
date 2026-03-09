import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'purchases_repository.g.dart';

class PurchasesRepository {
  final PocketBase globalPb;

  PurchasesRepository(this.globalPb);

  Future<List<RecordModel>> getPurchases({String? startDate, String? endDate}) async {
    String filter = 'is_deleted = false';
    if (startDate != null && endDate != null) {
      filter += ' && date >= "$startDate" && date <= "$endDate"';
    }
    return await globalPb.collection('purchases').getFullList(sort: '-date', expand: 'supplier', filter: filter);
  }

  Future<RecordModel> createPurchase(Map<String, dynamic> body) async {
    return await globalPb.collection('purchases').create(body: body);
  }

  Future<void> updatePurchase(String id, Map<String, dynamic> body) async {
    await globalPb.collection('purchases').update(id, body: body);
  }

  Future<void> deletePurchase(String id) async {
     await globalPb.collection('purchases').delete(id);
  }

  // Returns
  Future<List<RecordModel>> getPurchaseReturns({String? startDate, String? endDate}) async {
    String filter = '';
    if (startDate != null && endDate != null) {
      filter = 'date >= "$startDate" && date <= "$endDate"';
    }
     return await globalPb.collection('purchase_returns').getFullList(sort: '-date', expand: 'supplier', filter: filter);
  }

  // Payments
  Future<List<RecordModel>> getAllSupplierPayments() async {
    return await globalPb.collection('supplier_payments').getFullList(sort: '-date', expand: 'supplier');
  }
}

@riverpod
Future<PurchasesRepository> purchasesRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return PurchasesRepository(pb);
}
