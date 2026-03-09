import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'sales_repository.g.dart';

class SalesRepository {
  final PocketBase globalPb;

  SalesRepository(this.globalPb);

  Future<List<RecordModel>> getSales({
    String? startDate,
    String? endDate,
  }) async {
    String filter = 'is_deleted = false';
    if (startDate != null && endDate != null) {
      filter += ' && date >= "$startDate" && date <= "$endDate"';
    }
    return await globalPb
        .collection('sales')
        .getFullList(sort: '-date', expand: 'client', filter: filter);
  }

  Future<RecordModel> createSale(Map<String, dynamic> body) async {
    return await globalPb.collection('sales').create(body: body);
  }

  Future<void> updateSale(String id, Map<String, dynamic> body) async {
    await globalPb.collection('sales').update(id, body: body);
  }

  Future<void> deleteSale(String id) async {
    await globalPb.collection('sales').delete(id);
  }

  // Returns
  Future<List<RecordModel>> getReturns({
    String? startDate,
    String? endDate,
  }) async {
    String filter = '';
    if (startDate != null && endDate != null) {
      filter = 'date >= "$startDate" && date <= "$endDate"';
    }
    return await globalPb
        .collection('returns')
        .getFullList(sort: '-date', expand: 'client', filter: filter);
  }

  // Receipts
  Future<List<RecordModel>> getAllReceipts() async {
    return await globalPb
        .collection('receipts')
        .getFullList(sort: '-date', expand: 'client');
  }

  Future<RecordModel> createReceipt(
    Map<String, dynamic> body, {
    List<dynamic>? files,
  }) async {
    // Handling files separately if needed, simplified for repo layer
    return await globalPb.collection('receipts').create(body: body);
  }

  // Delivery Orders
  Future<List<RecordModel>> getAllDeliveryOrders() async {
    return await globalPb
        .collection('delivery_orders')
        .getFullList(sort: '-date', expand: 'client');
  }

  Future<List<RecordModel>> getDeliveryOrderItems(String orderId) async {
    return await globalPb
        .collection('delivery_order_items')
        .getFullList(filter: 'delivery_order = "$orderId"', expand: 'product');
  }

  Future<RecordModel> createDeliveryOrder(Map<String, dynamic> body) async {
    return await globalPb.collection('delivery_orders').create(body: body);
  }

  Future<RecordModel> createDeliveryOrderItem(Map<String, dynamic> body) async {
    return await globalPb.collection('delivery_order_items').create(body: body);
  }

  Future<void> updateDeliveryOrder(String id, Map<String, dynamic> body) async {
    await globalPb.collection('delivery_orders').update(id, body: body);
  }

  Future<void> deleteDeliveryOrderForever(String id) async {
    await globalPb.collection('delivery_orders').delete(id);
  }

  Future<void> restoreDeliveryOrder(String id) async {
    await globalPb
        .collection('delivery_orders')
        .update(id, body: {'is_deleted': false});
  }

  Future<void> restoreSale(String id) async {
    await globalPb.collection('sales').update(id, body: {'is_deleted': false});
  }

  Future<void> toggleOrderLock(
    String id,
    bool isLocked, {
    String? imagePath,
  }) async {
    final Map<String, dynamic> body = {'isLocked': isLocked};
    List<http.MultipartFile> files = [];
    if (imagePath != null) {
      files.add(await http.MultipartFile.fromPath('image', imagePath));
    }
    await globalPb
        .collection('delivery_orders')
        .update(id, body: body, files: files);
  }

  Future<void> updateOrderImage(String id, String? imagePath) async {
    if (imagePath != null) {
      List<http.MultipartFile> files = [
        await http.MultipartFile.fromPath('image', imagePath),
      ];
      await globalPb.collection('delivery_orders').update(id, files: files);
    } else {
      await globalPb
          .collection('delivery_orders')
          .update(id, body: {'image': ''});
    }
  }
}

@riverpod
Future<SalesRepository> salesRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return SalesRepository(pb);
}
