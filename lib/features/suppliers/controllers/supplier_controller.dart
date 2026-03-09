import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/features/suppliers/repositories/supplier_local_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'supplier_controller.g.dart';

@riverpod
class SupplierController extends _$SupplierController {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = SupplierLocalRepository(db);
    final suppliers = await repo.getSuppliers();
    return suppliers.map((s) => s.toMap()).toList();
  }

  Future<String> createSupplier(Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SupplierLocalRepository(db);
    final supplier = await repo.createSupplier(data);
    ref.invalidateSelf();
    return supplier.id;
  }

  Future<void> updateSupplier(String id, Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SupplierLocalRepository(db);
    await repo.updateSupplier(id, data);
    ref.invalidateSelf();
  }

  Future<void> deleteSupplier(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SupplierLocalRepository(db);
    await repo.deleteSupplier(id);
    ref.invalidateSelf();
  }
}
