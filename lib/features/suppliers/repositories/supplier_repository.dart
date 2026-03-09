import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'supplier_repository.g.dart';

class SupplierRepository {
  final PocketBase globalPb;

  SupplierRepository(this.globalPb);

  Future<List<RecordModel>> getSuppliers() async {
    return await globalPb.collection('suppliers').getFullList(sort: 'name');
  }

  Future<RecordModel> createSupplier(Map<String, dynamic> data) async {
    return await globalPb.collection('suppliers').create(body: data);
  }

  Future<RecordModel> updateSupplier(String id, Map<String, dynamic> data) async {
    return await globalPb.collection('suppliers').update(id, body: data);
  }

  Future<void> deleteSupplier(String id) async {
    await globalPb.collection('suppliers').delete(id);
  }
}

@riverpod
Future<SupplierRepository> supplierRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return SupplierRepository(pb);
}
