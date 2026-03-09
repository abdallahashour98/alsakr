import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

part 'store_repository.g.dart';

class StoreRepository {
  final PocketBase globalPb;

  StoreRepository(this.globalPb);

  Future<List<RecordModel>> getProducts() async {
    return await globalPb
        .collection('products')
        .getFullList(sort: '-created', expand: 'supplier');
  }

  Future<RecordModel> insertProduct(
    Map<String, dynamic> body,
    String? imagePath,
  ) async {
    List<http.MultipartFile> files = [];
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
    }
    return await globalPb
        .collection('products')
        .create(body: body, files: files);
  }

  Future<RecordModel> updateProduct(
    String id,
    Map<String, dynamic> body,
    String? imagePath,
  ) async {
    List<http.MultipartFile> files = [];
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      final file = File(imagePath);
      if (await file.exists()) {
        files.add(await http.MultipartFile.fromPath('image', imagePath));
      }
    }
    return await globalPb
        .collection('products')
        .update(id, body: body, files: files);
  }

  Future<void> deleteProduct(String id) async {
    await globalPb
        .collection('products')
        .update(id, body: {'is_deleted': true});
  }

  Future<double> getInventoryValue() async {
    final products = await globalPb.collection('products').getFullList();
    double totalValue = 0.0;
    for (var p in products) {
      double stock = (p.data['stock'] as num? ?? 0).toDouble();
      double cost = (p.data['buyPrice'] as num? ?? 0).toDouble();
      if (stock > 0) {
        totalValue += (stock * cost);
      }
    }
    return totalValue;
  }

  Future<List<String>> getUnits() async {
    try {
      final records = await globalPb.collection('units').getFullList();
      return records.map((e) => e.data['name'].toString()).toList();
    } catch (e) {
      return ['قطعة', 'علبة', 'كرتونة'];
    }
  }
}

@riverpod
Future<StoreRepository> storeRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  return StoreRepository(pb);
}
