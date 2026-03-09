import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/features/sales/repositories/sales_local_repository.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:al_sakr/models/transaction_item_model.dart';

part 'sales_controller.g.dart';

/// Sales controller — reads/writes exclusively from local SQLite.
/// Covers Sales, Returns, Receipts, and Delivery Orders.
@Riverpod(keepAlive: true)
class SalesController extends _$SalesController {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = SalesLocalRepository(db);
    return await repo.getSales();
  }

  // ── SALES ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSales({
    String? startDate,
    String? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final sales = await SalesLocalRepository(db).getSales(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      offset: offset,
    );
    // Enrich with client name
    List<Map<String, dynamic>> result = [];
    for (var s in sales) {
      final mutable = Map<String, dynamic>.from(s);
      final clientId = s['client'] as String? ?? '';
      if (clientId.isNotEmpty) {
        final clients = await db.query(
          DbConstants.tableClients,
          columns: ['name'],
          where: '${DbConstants.colId} = ?',
          whereArgs: [clientId],
          limit: 1,
        );
        if (clients.isNotEmpty) {
          mutable['clientName'] = clients.first['name'];
        }
      }
      result.add(mutable);
    }
    return result;
  }

  Future<String> createSale(
    String clientId,
    String clientName,
    double subTotal,
    double taxAmount,
    List<Map<String, dynamic>> items, {
    String? refNumber,
    double discount = 0.0,
    String paymentType = 'cash',
    double whtAmount = 0.0,
    String? date,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SalesLocalRepository(db);
    final now = DateTime.now().toUtc().toIso8601String();
    final netAmount = subTotal - discount + taxAmount - whtAmount;

    final saleId = await repo.createSale(
      clientId: clientId,
      totalAmount: subTotal,
      netAmount: netAmount,
      discount: discount,
      taxAmount: taxAmount,
      whtAmount: whtAmount,
      paymentType: paymentType,
      date: date ?? now,
      referenceNumber: refNumber ?? '',
      items: items,
    );
    ref.invalidateSelf();

    // ✅ تحديث قائمة المنتجات لفحص النواقص بعد إتمام البيع
    ref.invalidate(storeControllerProvider);

    return saleId;
  }

  Future<List<TransactionItemModel>> getSaleItems(String saleId) async {
    final db = await ref.read(localDatabaseProvider.future);
    return await SalesLocalRepository(db).getSaleItems(saleId);
  }

  Future<void> softDeleteSale(String saleId) async {
    final db = await ref.read(localDatabaseProvider.future);
    await SalesLocalRepository(db).softDeleteSale(saleId);
    ref.invalidateSelf();
  }

  Future<void> restoreSale(String saleId) async {
    final db = await ref.read(localDatabaseProvider.future);
    await SalesLocalRepository(db).restoreSale(saleId);
    ref.invalidateSelf();
  }

  Future<void> deleteSaleSafe(String saleId) async {
    await softDeleteSale(saleId);
  }

  Future<void> deleteSaleForever(String id) async {
    await softDeleteSale(id);
  }

  Future<List<Map<String, dynamic>>> getDeletedSales() async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getDeletedSales();
  }

  Future<void> updateSaleReference(String saleId, String newRef) async {
    final db = await ref.read(localDatabaseProvider.future);
    await SalesLocalRepository(db).updateSaleReference(saleId, newRef);
    ref.invalidateSelf();
  }

  // ── RETURNS ─────────────────────────────────────────────────────────

  Future<String> createReturn(
    String saleId,
    String clientId,
    double returnTotal,
    List<Map<String, dynamic>> itemsToReturn, {
    double discount = 0.0,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SalesLocalRepository(db);
    final now = DateTime.now().toUtc().toIso8601String();
    final id = await repo.createReturn(
      saleId: saleId,
      clientId: clientId,
      totalAmount: returnTotal,
      discount: discount,
      date: now,
      items: itemsToReturn,
    );
    ref.invalidateSelf();

    // ✅ تحديث قائمة المنتجات لفحص النواقص لوجود مرتجع
    ref.invalidate(storeControllerProvider);

    return id;
  }

  Future<List<Map<String, dynamic>>> getReturns({
    String? startDate,
    String? endDate,
    int? limit,
    int? offset,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final returns = await SalesLocalRepository(
      db,
    ).getReturns(limit: limit, offset: offset);
    // Enrich each return with clientName from the local clients table
    final enriched = <Map<String, dynamic>>[];
    for (final ret in returns) {
      final mutable = Map<String, dynamic>.from(ret);
      final clientId = ret['client'] as String? ?? '';
      if (clientId.isNotEmpty && mutable['clientName'] == null) {
        final rows = await db.query(
          DbConstants.tableClients,
          columns: ['name'],
          where: '${DbConstants.colId} = ?',
          whereArgs: [clientId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          mutable['clientName'] = rows.first['name'];
        }
      }
      // Enrich with paymentType from parent sale
      final saleId = ret['sale'] as String? ?? '';
      if (saleId.isNotEmpty && mutable['paymentType'] == null) {
        final saleRows = await db.query(
          DbConstants.tableSales,
          columns: ['paymentType'],
          where: '${DbConstants.colId} = ?',
          whereArgs: [saleId],
          limit: 1,
        );
        if (saleRows.isNotEmpty) {
          mutable['paymentType'] = saleRows.first['paymentType'] ?? 'cash';
        }
      }
      enriched.add(mutable);
    }
    return enriched;
  }

  Future<List<Map<String, dynamic>>> getReturnsByClient(String clientId) async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getReturns(clientId: clientId);
  }

  Future<List<Map<String, dynamic>>> getAlreadyReturnedItems(
    String saleId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    // Fetch all returns for this sale and their items
    final returns = await db.query(
      DbConstants.tableReturns,
      where: 'sale = ?',
      whereArgs: [saleId],
    );
    List<Map<String, dynamic>> allReturnItems = [];
    for (final r in returns) {
      final items = await db.query(
        DbConstants.tableReturnItems,
        where: 'return_id = ?',
        whereArgs: [r[DbConstants.colId]],
      );
      allReturnItems.addAll(items);
    }
    return allReturnItems;
  }

  Future<void> deleteReturnSafe(String returnId) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableReturns,
      {
        DbConstants.colSyncStatus: SyncStatus.pendingDelete,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [returnId],
    );
    ref.invalidateSelf();
  }

  Future<List<TransactionItemModel>> getReturnItems(String returnId) async {
    final db = await ref.read(localDatabaseProvider.future);
    return await SalesLocalRepository(db).getReturnItems(returnId);
  }

  Future<void> payReturnCash(
    String returnId,
    String clientId,
    double amount,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();

    // Read current return record to get totals
    final rows = await db.query(
      DbConstants.tableReturns,
      where: '${DbConstants.colId} = ?',
      whereArgs: [returnId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final ret = rows.first;
    final oldPaid = (ret['paidAmount'] as num? ?? 0).toDouble();
    final totalAmount = (ret['totalAmount'] as num? ?? 0).toDouble();
    final newPaid = oldPaid + amount;
    final isComplete = newPaid >= totalAmount - 0.1;

    await db.update(
      DbConstants.tableReturns,
      {
        'paidAmount': newPaid,
        'is_complete': isComplete ? 1 : 0,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [returnId],
    );

    // Update client balance (decrease by paid amount)
    await db.rawUpdate(
      'UPDATE ${DbConstants.tableClients} SET balance = balance - ?, ${DbConstants.colSyncStatus} = ?, ${DbConstants.colUpdated} = ? WHERE ${DbConstants.colId} = ?',
      [amount, SyncStatus.pendingUpdate, now, clientId],
    );

    ref.invalidateSelf();
  }

  // ── RECEIPTS ────────────────────────────────────────────────────────

  Future<String> createReceipt(
    String clientId,
    double amount,
    String notes,
    String date, {
    String? paymentMethod,
    String? imagePath,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SalesLocalRepository(db);
    final id = await repo.createReceipt(
      clientId: clientId,
      amount: amount,
      notes: notes,
      date: date,
      method: paymentMethod ?? 'cash',
    );
    ref.invalidateSelf();
    return id;
  }

  Future<List<Map<String, dynamic>>> getReceiptsByClient(
    String clientId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getReceipts(clientId: clientId);
  }

  // ── DELIVERY ORDERS ─────────────────────────────────────────────────

  Future<String> createDeliveryOrder(
    String clientId,
    String supplyOrderNumber,
    String manualNo,
    String address,
    String date,
    String notes,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final repo = SalesLocalRepository(db);
    final id = await repo.createDeliveryOrder(
      clientId: clientId,
      supplyOrderNumber: supplyOrderNumber,
      manualNo: manualNo,
      address: address,
      date: date,
      notes: notes,
      items: items,
    );
    ref.invalidateSelf();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllDeliveryOrders() async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getDeliveryOrders();
  }

  Future<List<Map<String, dynamic>>> getDeliveryOrderItems(
    String orderId,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getDeliveryOrderItems(orderId);
  }

  Future<void> toggleOrderLock(
    String id,
    bool isLocked, {
    String? imagePath,
  }) async {
    final db = await ref.read(localDatabaseProvider.future);
    await SalesLocalRepository(db).toggleOrderLock(id, isLocked);
    ref.invalidateSelf();
  }

  Future<void> deleteDeliveryOrderForever(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    await SalesLocalRepository(db).softDeleteDeliveryOrder(id);
    ref.invalidateSelf();
  }

  /// Alias used by delivery_orders_screen
  Future<void> softDeleteDeliveryOrder(String id) async {
    await deleteDeliveryOrderForever(id);
  }

  Future<void> updateDeliveryOrder(
    String id,
    String clientId,
    String supplyOrderNumber,
    String manualNo,
    String address,
    String date,
    String notes,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    // Soft delete old items (so upsync deletes them from PB)
    await db.update(
      DbConstants.tableDeliveryOrderItems,
      {
        DbConstants.colSyncStatus: SyncStatus.pendingDelete,
        DbConstants.colUpdated: now,
      },
      where: 'delivery_order = ?',
      whereArgs: [id],
    );
    // Update the order header
    final clientRow = await db.query(
      'clients',
      columns: ['name'],
      where: '${DbConstants.colId} = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    final clientName = clientRow.isNotEmpty
        ? clientRow.first['name'] as String? ?? ''
        : '';
    await db.update(
      DbConstants.tableDeliveryOrders,
      {
        'client': clientId,
        'clientName': clientName,
        'supplyOrderNumber': supplyOrderNumber,
        'manualNo': manualNo,
        'address': address,
        'date': date,
        'notes': notes,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
    // Re-insert items
    const uuid = Uuid();
    for (final item in items) {
      final itemId = uuid.v4();
      await db.insert(DbConstants.tableDeliveryOrderItems, {
        DbConstants.colId: itemId,
        DbConstants.colLocalId: itemId,
        'delivery_order': id,
        'product': item['productId'] ?? '',
        'productName': item['productName'] ?? '',
        'quantity': item['quantity'] ?? 1,
        'description': item['description'] ?? '',
        'relatedSupplyOrder': item['relatedSupplyOrder'] ?? '',
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
      });
    }
    ref.invalidateSelf();
  }

  Future<void> restoreDeliveryOrder(String id) async {
    final db = await ref.read(localDatabaseProvider.future);
    await SalesLocalRepository(db).restoreDeliveryOrder(id);
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getDeletedDeliveryOrders() async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getDeletedDeliveryOrders();
  }

  // ── CLIENT HELPERS (kept for backward compatibility) ────────────────

  Future<List<Map<String, dynamic>>> getSalesByClient(String clientId) async {
    final db = await ref.read(localDatabaseProvider.future);
    return SalesLocalRepository(db).getSales(clientId: clientId);
  }

  Future<double> getClientOpeningBalance(String clientId) async {
    final db = await ref.read(localDatabaseProvider.future);
    final rows = await db.query(
      DbConstants.tableOpeningBalances,
      where: 'client = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['amount'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> updateClientOpeningBalance(
    String clientId,
    double amount,
  ) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await db.query(
      DbConstants.tableOpeningBalances,
      where: 'client = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        DbConstants.tableOpeningBalances,
        {
          'amount': amount,
          'date': now,
          DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
          DbConstants.colUpdated: now,
        },
        where: 'client = ?',
        whereArgs: [clientId],
      );
    } else {
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      await db.insert(DbConstants.tableOpeningBalances, {
        DbConstants.colId: localId,
        DbConstants.colLocalId: localId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'client': clientId,
        'amount': amount,
        'date': now,
        'notes': '',
      });
    }
  }

  Future<dynamic> insertClient(Map<String, dynamic> data) async {
    // Backward compatibility — delegate to client controller
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert(DbConstants.tableClients, {
      DbConstants.colId: localId,
      DbConstants.colLocalId: localId,
      DbConstants.colSyncStatus: SyncStatus.pendingCreate,
      DbConstants.colCreated: now,
      DbConstants.colUpdated: now,
      'name': data['name'] ?? '',
      'phone': data['phone'] ?? '',
      'address': data['address'] ?? '',
      'balance': data['balance'] ?? 0.0,
      'is_deleted': 0,
    });
    return _FakeRecord(localId);
  }

  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    data[DbConstants.colSyncStatus] = SyncStatus.pendingUpdate;
    data[DbConstants.colUpdated] = now;
    await db.update(
      DbConstants.tableClients,
      data,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  // ── SYNC / OFFLINE COMPAT (no-ops, handled by SyncManager) ─────────

  Future<void> syncOfflineDeliveryOrders() async {
    /* handled by SyncManager */
  }

  Future<void> updateOrderImage(String orderId, String? imagePath) async {
    final db = await ref.read(localDatabaseProvider.future);
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableDeliveryOrders,
      {
        'signed_image': imagePath ?? '',
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [orderId],
    );
    ref.invalidateSelf();
  }

  Future<List<Map<String, dynamic>>> getDeletedExpenses() async {
    final db = await ref.read(localDatabaseProvider.future);
    final rows = await db.query(
      DbConstants.tableExpenses,
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
    return rows;
  }
}

/// Minimal shim to maintain backward compat with `rec.id` pattern.
class _FakeRecord {
  final String id;
  _FakeRecord(this.id);
}
