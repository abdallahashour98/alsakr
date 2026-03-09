import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/features/store/repositories/store_local_repository.dart';
import 'package:al_sakr/core/services/notification_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_sakr/features/expenses/controllers/expenses_controller.dart';
import 'package:uuid/uuid.dart';

part 'store_controller.g.dart';

@riverpod
class StoreController extends _$StoreController {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    final products = await repo.getProducts();
    final productsMap = products.map((p) => p.toMap()).toList();

    // ✅ فحص الكميات وتواريخ الصلاحية بعد تحميل المنتجات (لو الإشعارات مفعّلة)
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('inventory_notifications') ?? true;
    if (notificationsEnabled) {
      NotificationService.checkInventoryAndNotify(productsMap);
    }

    return productsMap;
  }

  Future<String> insertProduct(
    Map<String, dynamic> data, [
    String? imagePath,
  ]) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    // Store the image path locally — will be uploaded during upsync
    if (imagePath != null) data['image'] = imagePath;
    final product = await repo.createProduct(data);
    ref.invalidateSelf();
    return product.id;
  }

  Future<void> updateProduct(
    String id,
    Map<String, dynamic> data, [
    String? imagePath,
  ]) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    if (imagePath != null) data['image'] = imagePath;
    await repo.updateProduct(id, data);
    ref.invalidateSelf();
  }

  Future<void> deleteProduct(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    await repo.deleteProduct(id);
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    final products = await repo.getProducts();
    return products.map((p) => p.toMap()).toList();
  }

  Future<List<String>> getUnits() async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    return repo.getUnits();
  }

  Future<void> insertUnit(String name) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    await repo.createUnit(name);
    ref.invalidateSelf();
  }

  Future<void> deleteUnit(String name) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    await repo.deleteUnit(name);
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getDeletedProducts() async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);
    final products = await repo.getDeletedProducts();
    return products.map((p) => p.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> getProductHistory(String id) async {
    // TODO: Implement once product history tracking is added
    return [];
  }

  Future<void> approveInventory(
    List<Map<String, dynamic>> productsWithActual,
    int settlementOption,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = StoreLocalRepository(db);

    String now = DateTime.now().toUtc().toIso8601String();

    for (var product in productsWithActual) {
      int systemStock = (product['stock'] as num?)?.toInt() ?? 0;
      int actualStock = product['actual_stock'] as int;
      int diff = actualStock - systemStock;

      if (diff != 0) {
        double buyPrice = (product['buyPrice'] as num?)?.toDouble() ?? 0.0;

        // Update product stock globally first
        await repo.updateProduct(product['id'], {
          'stock': actualStock,
          'sync_status': 'pending_update', // Set to sync this up
          'updated': now,
        });

        if (settlementOption == 1) {
          if (diff > 0) {
            // SURPLUS (زيادة)
            print('>>> SURPLUS DETECTED for ${product['name']}. Diff: $diff');
            try {
              final localId = const Uuid().v4();
              final String creationTime = DateTime.now()
                  .toUtc()
                  .toIso8601String();
              final gain = diff * buyPrice;

              print('>>> Inserting revenue: $gain');
              await db.insert('revenues', {
                'id': localId,
                'local_id': localId,
                'sync_status': 'pending_create',
                'created': creationTime,
                'updated': creationTime,
                'description': 'زيادة جرد - ${product['name']}',
                'amount': gain,
                'category': 'إيرادات جرد',
                'date': creationTime,
                'is_deleted': 0,
              });
              print('>>> Inserted revenue successfully.');
            } catch (e) {
              print('>>> ERROR inserting revenue: $e');
            }
          } else if (diff < 0) {
            // SHORTAGE (عجز)
            print('>>> SHORTAGE DETECTED for ${product['name']}. Diff: $diff');
            try {
              final expenseId = const Uuid().v4();
              final String creationTime = DateTime.now()
                  .toUtc()
                  .toIso8601String();
              final loss = diff.abs() * buyPrice;

              print('>>> Inserting expense: $loss');
              await db.insert('expenses', {
                'id': expenseId,
                'local_id': expenseId,
                'description': 'عجز جرد - ${product['name']}',
                'amount': loss,
                'category': 'عجز جرد',
                'date': creationTime,
                'sync_status': 'pending_create',
                'created': creationTime,
                'updated': creationTime,
                'is_deleted': 0,
              });
              print('>>> Inserted expense successfully.');

              // Invalidate the expenses provider so the UI updates
              ref.invalidate(expensesControllerProvider);
            } catch (e) {
              print('>>> ERROR inserting expense: $e');
            }
          }
        }
      }
    }

    ref.invalidateSelf(); // refresh products
  }
}
