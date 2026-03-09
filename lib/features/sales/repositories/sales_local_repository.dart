import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/models/transaction_item_model.dart';

/// Local SQLite repository for Sales, Returns, Receipts, and Delivery Orders.
class SalesLocalRepository {
  final Database db;
  static const _uuid = Uuid();

  SalesLocalRepository(this.db);

  // ════════════════════════════════════════════════════════════════════
  // SALES
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getSales({
    String? clientId,
    bool includeDeleted = false,
    String? startDate,
    String? endDate,
    int? limit,
    int? offset,
  }) async {
    String where = '${DbConstants.colSyncStatus} != ?';
    List<dynamic> args = [SyncStatus.pendingDelete];
    if (!includeDeleted) {
      where += ' AND is_deleted = ?';
      args.add(0);
    }
    if (clientId != null) {
      where += ' AND client = ?';
      args.add(clientId);
    }
    if (startDate != null && endDate != null) {
      where += ' AND date >= ? AND date <= ?';
      args.addAll([startDate, endDate]);
    } else if (startDate != null) {
      where += ' AND date >= ?';
      args.add(startDate);
    } else if (endDate != null) {
      where += ' AND date <= ?';
      args.add(endDate);
    }
    final rows = await db.query(
      DbConstants.tableSales,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return rows;
  }

  Future<Map<String, dynamic>?> getSaleById(String id) async {
    final rows = await db.query(
      DbConstants.tableSales,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Create a sale + its line items in a single transaction.
  Future<String> createSale({
    required String clientId,
    required double totalAmount,
    required double netAmount,
    required double discount,
    required double taxAmount,
    required double whtAmount,
    required String paymentType,
    required String date,
    required String referenceNumber,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final saleId = _uuid.v4();

    await db.transaction((txn) async {
      // Insert sale
      await txn.insert(DbConstants.tableSales, {
        DbConstants.colId: saleId,
        DbConstants.colLocalId: saleId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'client': clientId,
        'totalAmount': totalAmount,
        'discount': discount,
        'taxAmount': taxAmount,
        'whtAmount': whtAmount,
        'netAmount': netAmount,
        'paymentType': paymentType,
        'date': date,
        'referenceNumber': referenceNumber,
        'is_deleted': 0,
        'is_complete': 0,
      });

      // Insert line items with stock deltas
      for (final item in items) {
        final itemId = _uuid.v4();
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final productId =
            (item['productId'] ?? item['product'] ?? '') as String;
        await txn.insert(DbConstants.tableSaleItems, {
          DbConstants.colId: itemId, DbConstants.colLocalId: itemId,
          DbConstants.colSyncStatus: SyncStatus.pendingCreate,
          DbConstants.colCreated: now, DbConstants.colUpdated: now,
          'sale': saleId, 'product': productId,
          'quantity': qty, 'price': (item['price'] as num?)?.toDouble() ?? 0.0,
          'stock_delta': -qty, // Negative for sales
        });

        // Update local stock
        await txn.rawUpdate(
          'UPDATE ${DbConstants.tableProducts} SET stock = stock - ? WHERE ${DbConstants.colId} = ?',
          [qty, productId],
        );
      }

      // Update client balance ONLY if it's a CREDIT (آجل) sale
      if (paymentType == 'credit') {
        await txn.rawUpdate(
          'UPDATE ${DbConstants.tableClients} SET balance = balance + ? WHERE ${DbConstants.colId} = ?',
          [netAmount, clientId],
        );
      }
    });

    return saleId;
  }

  Future<List<TransactionItemModel>> getSaleItems(String saleId) async {
    final rows = await db.rawQuery(
      '''
      SELECT 
        i.*,
        p.name AS productName
      FROM ${DbConstants.tableSaleItems} i
      LEFT JOIN ${DbConstants.tableProducts} p ON i.product = p.id
      WHERE i.sale = ?
      ''',
      [saleId],
    );
    return rows.map((row) => TransactionItemModel.fromSaleItem(row)).toList();
  }

  Future<void> softDeleteSale(String saleId) async {
    final sale = await getSaleById(saleId);
    if (sale == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final status = sale[DbConstants.colSyncStatus] as String?;
    final newStatus = status == SyncStatus.pendingCreate
        ? SyncStatus.pendingCreate
        : SyncStatus.pendingUpdate;
    await db.update(
      DbConstants.tableSales,
      {
        'is_deleted': 1,
        DbConstants.colSyncStatus: newStatus,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [saleId],
    );
  }

  Future<void> restoreSale(String saleId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableSales,
      {
        'is_deleted': 0,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [saleId],
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedSales() async {
    return db.query(
      DbConstants.tableSales,
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateSaleReference(String saleId, String newRef) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableSales,
      {
        'referenceNumber': newRef,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [saleId],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // RETURNS
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getReturns({
    String? clientId,
    int? limit,
    int? offset,
  }) async {
    String where = '${DbConstants.colSyncStatus} != ?';
    List<dynamic> args = [SyncStatus.pendingDelete];
    if (clientId != null) {
      where += ' AND client = ?';
      args.add(clientId);
    }
    return db.query(
      DbConstants.tableReturns,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<String> createReturn({
    required String saleId,
    required String clientId,
    required double totalAmount,
    required double discount,
    required String date,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final returnId = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert(DbConstants.tableReturns, {
        DbConstants.colId: returnId,
        DbConstants.colLocalId: returnId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'sale': saleId,
        'client': clientId,
        'totalAmount': totalAmount,
        'discount': discount,
        'date': date,
        'notes': '',
        'is_complete': 0,
      });

      for (final item in items) {
        final itemId = _uuid.v4();
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final productId =
            (item['productId'] ?? item['product'] ?? '') as String;
        await txn.insert(DbConstants.tableReturnItems, {
          DbConstants.colId: itemId, DbConstants.colLocalId: itemId,
          DbConstants.colSyncStatus: SyncStatus.pendingCreate,
          DbConstants.colCreated: now, DbConstants.colUpdated: now,
          'return_id': returnId, 'product': productId,
          'quantity': qty, 'price': (item['price'] as num?)?.toDouble() ?? 0.0,
          'stock_delta': qty, // Positive for returns
        });
        await txn.rawUpdate(
          'UPDATE ${DbConstants.tableProducts} SET stock = stock + ? WHERE ${DbConstants.colId} = ?',
          [qty, productId],
        );
      }

      // Fetch the original sale to determine paymentType
      final saleResult = await txn.query(
        DbConstants.tableSales,
        columns: ['paymentType'],
        where: '${DbConstants.colId} = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      final String paymentType = saleResult.isNotEmpty
          ? (saleResult.first['paymentType'] as String? ?? 'cash')
          : 'cash';

      // Decrease client balance ONLY if it was a CREDIT sale
      if (paymentType == 'credit') {
        await txn.rawUpdate(
          'UPDATE ${DbConstants.tableClients} SET balance = balance - ? WHERE ${DbConstants.colId} = ?',
          [totalAmount, clientId],
        );
      }
    });
    return returnId;
  }

  Future<List<TransactionItemModel>> getReturnItems(String returnId) async {
    final rows = await db.rawQuery(
      '''
      SELECT 
        i.*,
        p.name AS productName
      FROM ${DbConstants.tableReturnItems} i
      LEFT JOIN ${DbConstants.tableProducts} p ON i.product = p.id
      WHERE i.return_id = ?
      ''',
      [returnId],
    );
    return rows.map((row) => TransactionItemModel.fromReturnItem(row)).toList();
  }

  // ════════════════════════════════════════════════════════════════════
  // RECEIPTS
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getReceipts({String? clientId}) async {
    String where = '${DbConstants.colSyncStatus} != ?';
    List<dynamic> args = [SyncStatus.pendingDelete];
    if (clientId != null) {
      where += ' AND client = ?';
      args.add(clientId);
    }
    return db.query(
      DbConstants.tableReceipts,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );
  }

  Future<String> createReceipt({
    required String clientId,
    required double amount,
    required String notes,
    required String date,
    String method = 'cash',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await db.insert(DbConstants.tableReceipts, {
      DbConstants.colId: id,
      DbConstants.colLocalId: id,
      DbConstants.colSyncStatus: SyncStatus.pendingCreate,
      DbConstants.colCreated: now,
      DbConstants.colUpdated: now,
      'client': clientId,
      'amount': amount,
      'notes': notes,
      'date': date,
      'method': method,
    });

    // Decrease client balance (payment received)
    await db.rawUpdate(
      'UPDATE ${DbConstants.tableClients} SET balance = balance - ? WHERE ${DbConstants.colId} = ?',
      [amount, clientId],
    );

    return id;
  }

  // ════════════════════════════════════════════════════════════════════
  // DELIVERY ORDERS
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getDeliveryOrders({
    bool includeDeleted = false,
  }) async {
    String where = '${DbConstants.colSyncStatus} != ?';
    List<dynamic> args = [SyncStatus.pendingDelete];
    if (!includeDeleted) {
      where += ' AND is_deleted = ?';
      args.add(0);
    }
    return db.query(
      DbConstants.tableDeliveryOrders,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );
  }

  Future<String> createDeliveryOrder({
    required String clientId,
    required String supplyOrderNumber,
    required String manualNo,
    required String address,
    required String date,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final orderId = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert(DbConstants.tableDeliveryOrders, {
        DbConstants.colId: orderId,
        DbConstants.colLocalId: orderId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'client': clientId,
        'supplyOrderNumber': supplyOrderNumber,
        'manualNo': manualNo,
        'address': address,
        'date': date,
        'notes': notes,
        'is_complete': 0,
        'isLocked': 0,
        'image': '',
        'is_deleted': 0,
      });

      for (final item in items) {
        final itemId = _uuid.v4();
        await txn.insert(DbConstants.tableDeliveryOrderItems, {
          DbConstants.colId: itemId,
          DbConstants.colLocalId: itemId,
          DbConstants.colSyncStatus: SyncStatus.pendingCreate,
          DbConstants.colCreated: now,
          DbConstants.colUpdated: now,
          'delivery_order': orderId,
          'product': item['product'] ?? '',
          'quantity': (item['quantity'] as num?)?.toInt() ?? 0,
          'description': item['description'] ?? '',
          'relatedSupplyOrder': item['relatedSupplyOrder'] ?? '',
        });
      }
    });
    return orderId;
  }

  Future<List<Map<String, dynamic>>> getDeliveryOrderItems(
    String orderId,
  ) async {
    return db.rawQuery(
      '''
      SELECT 
        i.*,
        p.name AS productName,
        p.id AS productId,
        p.unit AS unit
      FROM ${DbConstants.tableDeliveryOrderItems} i
      LEFT JOIN ${DbConstants.tableProducts} p ON i.product = p.id
      WHERE i.delivery_order = ?
      ''',
      [orderId],
    );
  }

  Future<void> toggleOrderLock(String id, bool isLocked) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableDeliveryOrders,
      {
        'isLocked': isLocked ? 1 : 0,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> softDeleteDeliveryOrder(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableDeliveryOrders,
      {
        'is_deleted': 1,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreDeliveryOrder(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tableDeliveryOrders,
      {
        'is_deleted': 0,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedDeliveryOrders() async {
    return db.query(
      DbConstants.tableDeliveryOrders,
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
  }
}
