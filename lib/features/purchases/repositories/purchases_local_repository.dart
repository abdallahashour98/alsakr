import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/models/transaction_item_model.dart';

/// Local SQLite repository for Purchases, Purchase Returns, and Supplier Payments.
class PurchasesLocalRepository {
  final Database db;
  static const _uuid = Uuid();

  PurchasesLocalRepository(this.db);

  // ════════════════════════════════════════════════════════════════════
  // PURCHASES
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPurchases({
    String? supplierId,
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
    if (supplierId != null) {
      where += ' AND supplier = ?';
      args.add(supplierId);
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
    return db.query(
      DbConstants.tablePurchases,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>?> getPurchaseById(String id) async {
    final rows = await db.query(
      DbConstants.tablePurchases,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<TransactionItemModel>> getPurchaseItems(String purchaseId) async {
    final rows = await db.rawQuery(
      '''
      SELECT 
        i.*,
        p.name AS productName
      FROM ${DbConstants.tablePurchaseItems} i
      LEFT JOIN ${DbConstants.tableProducts} p ON i.product = p.id
      WHERE i.purchase = ?
      ''',
      [purchaseId],
    );
    return rows
        .map((row) => TransactionItemModel.fromPurchaseItem(row))
        .toList();
  }

  /// Create a purchase with line items in a single transaction.
  /// Stock is increased for each item (buying adds stock).
  Future<String> createPurchase({
    required String supplierId,
    required double totalAmount,
    required double discount,
    required String paymentType,
    required String date,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final purchaseId = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert(DbConstants.tablePurchases, {
        DbConstants.colId: purchaseId,
        DbConstants.colLocalId: purchaseId,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'supplier': supplierId,
        'totalAmount': totalAmount,
        'discount': discount,
        'paymentType': paymentType,
        'date': date,
        'notes': notes,
        'is_deleted': 0,
      });

      // Insert purchase items, update product stock, and compute new average cost
      for (final item in items) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final productId =
            (item['productId'] ?? item['product']) as String? ?? '';
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;

        if (productId.isNotEmpty && qty > 0) {
          // Insert into purchase_items table
          final itemId = _uuid.v4();
          await txn.insert(DbConstants.tablePurchaseItems, {
            DbConstants.colId: itemId,
            DbConstants.colLocalId: itemId,
            DbConstants.colSyncStatus: SyncStatus.pendingCreate,
            DbConstants.colCreated: now,
            DbConstants.colUpdated: now,
            'purchase': purchaseId,
            'product': productId,
            'quantity': qty,
            'costPrice': price,
          });

          // Fetch current stock and buyPrice to calculate Weighted Average Cost
          final prodRes = await txn.query(
            DbConstants.tableProducts,
            columns: ['stock', 'buyPrice'],
            where: '${DbConstants.colId} = ?',
            whereArgs: [productId],
            limit: 1,
          );

          if (prodRes.isNotEmpty) {
            final int oldStock = (prodRes.first['stock'] as num?)?.toInt() ?? 0;
            final double oldBuyPrice =
                (prodRes.first['buyPrice'] as num?)?.toDouble() ?? 0.0;

            final int newStock = oldStock + qty;
            final double newAverageCost = newStock > 0
                ? ((oldStock * oldBuyPrice) + (qty * price)) / newStock
                : price;

            // Increase local stock and update buyPrice (Average Cost)
            await txn.rawUpdate(
              'UPDATE ${DbConstants.tableProducts} SET stock = ?, buyPrice = ? WHERE ${DbConstants.colId} = ?',
              [newStock, newAverageCost, productId],
            );
          } else {
            // Fallback if product not found (should not happen usually)
            await txn.rawUpdate(
              'UPDATE ${DbConstants.tableProducts} SET stock = stock + ?, buyPrice = ? WHERE ${DbConstants.colId} = ?',
              [qty, price, productId],
            );
          }
        }
      }

      // Increase supplier balance ONLY if it's a CREDIT (آجل) purchase
      if (paymentType == 'credit') {
        await txn.rawUpdate(
          'UPDATE ${DbConstants.tableSuppliers} SET balance = balance + ? WHERE ${DbConstants.colId} = ?',
          [totalAmount, supplierId],
        );
      }
    });
    return purchaseId;
  }

  Future<void> softDeletePurchase(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tablePurchases,
      {
        'is_deleted': 1,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> restorePurchase(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DbConstants.tablePurchases,
      {
        'is_deleted': 0,
        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
        DbConstants.colUpdated: now,
      },
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getDeletedPurchases() async {
    return db.query(
      DbConstants.tablePurchases,
      where: 'is_deleted = ?',
      whereArgs: [1],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // PURCHASE RETURNS
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getPurchaseReturns({
    String? supplierId,
    String? startDate,
    String? endDate,
    int? limit,
    int? offset,
  }) async {
    String where = '${DbConstants.colSyncStatus} != ?';
    List<dynamic> args = [SyncStatus.pendingDelete];
    if (supplierId != null) {
      where += ' AND supplier = ?';
      args.add(supplierId);
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
    return db.query(
      DbConstants.tablePurchaseReturns,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<TransactionItemModel>> getPurchaseReturnItems(
    String returnId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT 
        i.*,
        p.name AS productName
      FROM ${DbConstants.tablePurchaseReturnItems} i
      LEFT JOIN ${DbConstants.tableProducts} p ON i.product = p.id
      WHERE i.purchase_return = ?
      ''',
      [returnId],
    );
    return rows
        .map((row) => TransactionItemModel.fromPurchaseReturnItem(row))
        .toList();
  }

  Future<String> createPurchaseReturn({
    required String purchaseId,
    required String supplierId,
    required double totalAmount,
    required String paymentType,
    required String date,
    required List<Map<String, dynamic>> items,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();
    await db.transaction((txn) async {
      await txn.insert(DbConstants.tablePurchaseReturns, {
        DbConstants.colId: id,
        DbConstants.colLocalId: id,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'purchase': purchaseId,
        'supplier': supplierId,
        'totalAmount': totalAmount,
        'date': date,
      });

      // Insert return items and restore stock
      for (final item in items) {
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        final productId =
            (item['productId'] ?? item['product'] ?? '') as String;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;

        if (productId.isNotEmpty && qty > 0) {
          final itemId = _uuid.v4();
          await txn.insert(DbConstants.tablePurchaseReturnItems, {
            DbConstants.colId: itemId,
            DbConstants.colLocalId: itemId,
            DbConstants.colSyncStatus: SyncStatus.pendingCreate,
            DbConstants.colCreated: now,
            DbConstants.colUpdated: now,
            'purchase_return': id,
            'product': productId,
            'quantity': qty,
            'price': price,
          });

          // Decrease stock (items are returned to supplier)
          await txn.rawUpdate(
            'UPDATE ${DbConstants.tableProducts} SET stock = stock - ? WHERE ${DbConstants.colId} = ?',
            [qty, productId],
          );
        }
      }

      // Decrease supplier balance ONLY if the return is for a CREDIT transaction
      if (paymentType == 'credit') {
        await txn.rawUpdate(
          'UPDATE ${DbConstants.tableSuppliers} SET balance = balance - ? WHERE ${DbConstants.colId} = ?',
          [totalAmount, supplierId],
        );
      }
    });
    return id;
  }

  // ════════════════════════════════════════════════════════════════════
  // SUPPLIER PAYMENTS
  // ════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getSupplierPayments({
    String? supplierId,
  }) async {
    String where = '${DbConstants.colSyncStatus} != ?';
    List<dynamic> args = [SyncStatus.pendingDelete];
    if (supplierId != null) {
      where += ' AND supplier = ?';
      args.add(supplierId);
    }
    return db.query(
      DbConstants.tableSupplierPayments,
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );
  }

  Future<String> createSupplierPayment({
    required String supplierId,
    required double amount,
    required String date,
    required String notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert(DbConstants.tableSupplierPayments, {
        DbConstants.colId: id,
        DbConstants.colLocalId: id,
        DbConstants.colSyncStatus: SyncStatus.pendingCreate,
        DbConstants.colCreated: now,
        DbConstants.colUpdated: now,
        'supplier': supplierId,
        'amount': amount,
        'date': date,
        'notes': notes,
      });

      // Decrease supplier balance (payment made / refund received)
      await txn.rawUpdate(
        'UPDATE ${DbConstants.tableSuppliers} SET balance = balance - ? WHERE ${DbConstants.colId} = ?',
        [amount, supplierId],
      );
    });

    return id;
  }

  Future<void> deleteSupplierPayment(String id) async {
    final rows = await db.query(
      DbConstants.tableSupplierPayments,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final status = rows.first[DbConstants.colSyncStatus] as String?;
    if (status == SyncStatus.pendingCreate) {
      await db.delete(
        DbConstants.tableSupplierPayments,
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        DbConstants.tableSupplierPayments,
        {
          DbConstants.colSyncStatus: SyncStatus.pendingDelete,
          DbConstants.colUpdated: DateTime.now().toUtc().toIso8601String(),
        },
        where: '${DbConstants.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // OPENING BALANCES (Supplier)
  // ════════════════════════════════════════════════════════════════════

  Future<double> getSupplierOpeningBalance(String supplierId) async {
    // We reuse opening_balances table with supplier as "client" field
    // or we could query purchases total - payments. For now, simple approach:
    final rows = await db.query(
      DbConstants.tableOpeningBalances,
      where: 'client = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['amount'] as num?)?.toDouble() ?? 0.0;
  }
}
