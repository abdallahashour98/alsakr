import 'package:al_sakr/models/transaction_item_model.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/features/purchases/repositories/purchases_local_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'purchases_controller.g.dart';

/// Purchases controller — reads/writes exclusively from local SQLite.
/// Covers Purchases, Purchase Returns, and Supplier Payments.
@Riverpod(keepAlive: true)
class PurchasesController extends _$PurchasesController {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = PurchasesLocalRepository(db);
    return await repo.getPurchases();
  }

  // ── PURCHASES ───────────────────────────────────────────────────────

  Future<String> createPurchase({
    required String supplierId,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? refNumber,
    String? customDate,
    double taxAmount = 0.0,
    double whtAmount = 0.0,
    double discount = 0.0,
    String paymentType = 'cash',
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = PurchasesLocalRepository(db);
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await repo.createPurchase(
      supplierId: supplierId,
      totalAmount: totalAmount,
      paymentType: paymentType,
      discount: discount,
      date: customDate ?? now,
      notes: '',
      items: items,
    );
    ref.invalidateSelf();
    return id;
  }

  Future<List<Map<String, dynamic>>> getPurchases({
    String? startDate,
    String? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final purchases = await PurchasesLocalRepository(db).getPurchases(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
    // Enrich with supplier name
    List<Map<String, dynamic>> result = [];
    for (var p in purchases) {
      final mutable = Map<String, dynamic>.from(p);
      final supplierId = p['supplier'] as String? ?? '';
      if (supplierId.isNotEmpty) {
        final suppliers = await db.query(
          DbConstants.tableSuppliers,
          columns: ['name'],
          where: '${DbConstants.colId} = ?',
          whereArgs: [supplierId],
          limit: 1,
        );
        if (suppliers.isNotEmpty) {
          mutable['supplierName'] = suppliers.first['name'];
        }
      }
      result.add(mutable);
    }
    return result;
  }

  Future<List<TransactionItemModel>> getPurchaseItems(String purchaseId) async {
    final db = await ref.read(localDatabaseProvider.future);
    return await PurchasesLocalRepository(db).getPurchaseItems(purchaseId);
  }

  Future<void> softDeletePurchase(String purchaseId) async {
    final db = await ref.read(localDatabaseProvider.future);
    await PurchasesLocalRepository(db).softDeletePurchase(purchaseId);
    ref.invalidateSelf();
  }

  Future<void> restorePurchase(String purchaseId) async {
    final db = await ref.read(localDatabaseProvider.future);
    await PurchasesLocalRepository(db).restorePurchase(purchaseId);
    ref.invalidateSelf();
  }

  Future<void> deletePurchaseSafe(String purchaseId) async {
    await softDeletePurchase(purchaseId);
  }

  Future<void> deletePurchase(String purchaseId) async {
    await softDeletePurchase(purchaseId);
  }

  Future<List<Map<String, dynamic>>> getDeletedPurchases() async {
    final db = await ref.read(localDatabaseProvider.future);
    return PurchasesLocalRepository(db).getDeletedPurchases();
  }

  Future<void> updatePurchaseReference(String purchaseId, String newRef) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tablePurchases,
      {
        'referenceNumber': newRef,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [purchaseId],
    );
    ref.invalidateSelf();
  }

  // ── PURCHASE RETURNS ────────────────────────────────────────────────

  Future<String> createPurchaseReturn(
    String purchaseId,
    String supplierId,
    double returnTotal,
    List<Map<String, dynamic>> itemsToReturn,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = PurchasesLocalRepository(db);
    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch original purchase to get the paymentType
    final purchaseRes = await db.query(
      DbConstants.tablePurchases,
      columns: ['paymentType'],
      where: '${DbConstants.colId} = ?',
      whereArgs: [purchaseId],
      limit: 1,
    );
    final String paymentType = purchaseRes.isNotEmpty
        ? (purchaseRes.first['paymentType'] as String? ?? 'cash')
        : 'cash';

    final id = await repo.createPurchaseReturn(
      purchaseId: purchaseId,
      supplierId: supplierId,
      totalAmount: returnTotal,
      paymentType: paymentType,
      date: now,
      items: itemsToReturn,
    );
    ref.invalidateSelf();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllPurchaseReturns({
    String? startDate,
    String? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final returns = await PurchasesLocalRepository(db).getPurchaseReturns(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
    // Enrich each return with supplierName from the local suppliers table
    final enriched = <Map<String, dynamic>>[];
    for (final ret in returns) {
      final mutable = Map<String, dynamic>.from(ret);
      final supplierId = ret['supplier'] as String? ?? '';
      if (supplierId.isNotEmpty && mutable['supplierName'] == null) {
        final rows = await db.query(
          DbConstants.tableSuppliers,
          columns: ['name'],
          where: '${DbConstants.colId} = ?',
          whereArgs: [supplierId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          mutable['supplierName'] = rows.first['name'];
        }
      }
      // Enrich with paymentType from parent purchase
      final purchaseId = ret['purchase'] as String? ?? '';
      if (purchaseId.isNotEmpty && mutable['paymentType'] == null) {
        final purchaseRows = await db.query(
          DbConstants.tablePurchases,
          columns: ['paymentType'],
          where: '${DbConstants.colId} = ?',
          whereArgs: [purchaseId],
          limit: 1,
        );
        if (purchaseRows.isNotEmpty) {
          mutable['paymentType'] = purchaseRows.first['paymentType'] ?? 'cash';
        }
      }
      enriched.add(mutable);
    }
    return enriched;
  }

  Future<List<TransactionItemModel>> getPurchaseReturnItems(
    String returnId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    return await PurchasesLocalRepository(db).getPurchaseReturnItems(returnId);
  }

  Future<void> deletePurchaseReturnSafe(String returnId) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tablePurchaseReturns,
      {
        DbConstants.colSyncStatus: SyncStatus.pendingDelete,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [returnId],
    );
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getAlreadyReturnedItems(
    String purchaseId,
  ) async {
    return [];
  }

  // ── SUPPLIER PAYMENTS ───────────────────────────────────────────────

  Future<void> addSupplierPayment({
    required String supplierId,
    required double amount,
    required String notes,
    required String date,
    String paymentMethod = 'cash',
    String? imagePath,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = PurchasesLocalRepository(db);
    await repo.createSupplierPayment(
      supplierId: supplierId,
      amount: amount,
      date: date,
      notes: notes,
    );
    ref.invalidateSelf();
  }

  Future<void> deleteSupplierPayment(
    String paymentId,
    String supplierId,
    double amount,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    await PurchasesLocalRepository(db).deleteSupplierPayment(paymentId);
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getAllSupplierPayments() async {
    final db = await ref.read(localDatabaseProvider.future);
    return PurchasesLocalRepository(db).getSupplierPayments();
  }

  // ── SUPPLIER QUERIES ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPurchasesBySupplier(
    String supplierId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    return PurchasesLocalRepository(db).getPurchases(supplierId: supplierId);
  }

  Future<List<Map<String, dynamic>>> getPaymentsBySupplier(
    String supplierId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    return PurchasesLocalRepository(
      db,
    ).getSupplierPayments(supplierId: supplierId);
  }

  Future<List<Map<String, dynamic>>> getReturnsBySupplier(
    String supplierId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    return PurchasesLocalRepository(
      db,
    ).getPurchaseReturns(supplierId: supplierId);
  }

  // ── OPENING BALANCES ────────────────────────────────────────────────

  Future<double> getSupplierOpeningBalance(String supplierId) async {
    final db = await ref.read(localDatabaseProvider.future);
    return PurchasesLocalRepository(db).getSupplierOpeningBalance(supplierId);
  }

  Future<void> updateSupplierOpeningBalance(
    String supplierId,
    double newAmount,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await db.query(
      DbConstants.tableOpeningBalances,
      where: 'client = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        DbConstants.tableOpeningBalances,
        {
          'amount': newAmount,
          'date': now,
          DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
          DbConstants.colUpdated: now,
        },
        where: 'client = ?',
        whereArgs: [supplierId],
      );
    } else {
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      await db.insert(DbConstants.tableOpeningBalances, {
        DbConstants.colId: localId,
        DbConstants.colLocalId: localId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'client': supplierId,
        'amount': newAmount,
        'date': now,
        'notes': '',
      });
    }
  }

  Future<List<Map<String, dynamic>>> getDeletedSuppliers() async {
    final db = await ref.read(localDatabaseProvider.future);
    return db.query(
      DbConstants.tableSuppliers,
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
  }
}
