import 'package:sqflite/sqflite.dart';
import 'package:al_sakr/core/database/database_constants.dart';

class ReportsLocalRepository {
  final Database db;

  ReportsLocalRepository(this.db);

  Future<Map<String, double>> getGeneralReportData({
    String? startDate,
    String? endDate,
  }) async {
    try {
      print("getGeneralReportData START: $startDate -> $endDate");
      String dateFilter = '';
      String rDateFilter = '';
      String prDateFilter = '';
      List<dynamic> dateArgs = [];

      if (startDate != null && endDate != null) {
        dateFilter = ' AND date >= ? AND date <= ?';
        rDateFilter = ' AND r.date >= ? AND r.date <= ?';
        prDateFilter = ' AND pr.date >= ? AND pr.date <= ?';
        dateArgs = [startDate, endDate];
      }

      print("Running cashSalesQuery");
      // 1. Sales (netAmount) split by paymentType
      final cashSalesQuery =
          "SELECT SUM(netAmount) as total FROM ${DbConstants.tableSales} WHERE paymentType = 'cash' AND is_deleted = 0 AND sync_status != ? $dateFilter";
      final cashSalesRes = await db.rawQuery(cashSalesQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      print("Running creditSalesQuery");
      double cashSales =
          (cashSalesRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final creditSalesQuery =
          "SELECT SUM(netAmount) as total FROM ${DbConstants.tableSales} WHERE paymentType = 'credit' AND is_deleted = 0 AND sync_status != ? $dateFilter";
      final creditSalesRes = await db.rawQuery(creditSalesQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double creditSales =
          (creditSalesRes.first['total'] as num?)?.toDouble() ?? 0.0;

      double totalSales = cashSales + creditSales;

      print("Running cashReturnsQuery");
      // 2. Returns (totalAmount) joined with sales to check paymentType
      final cashReturnsQuery =
          '''SELECT SUM(r.totalAmount) as total 
             FROM ${DbConstants.tableReturns} r 
             LEFT JOIN ${DbConstants.tableSales} s ON r.sale = s.id 
             WHERE s.paymentType = 'cash' AND r.sync_status != ? $rDateFilter''';
      final cashReturnsRes = await db.rawQuery(cashReturnsQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double cashClientReturns =
          (cashReturnsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running creditReturnsQuery");
      final creditReturnsQuery =
          '''SELECT SUM(r.totalAmount) as total 
             FROM ${DbConstants.tableReturns} r 
             LEFT JOIN ${DbConstants.tableSales} s ON r.sale = s.id 
             WHERE s.paymentType = 'credit' AND r.sync_status != ? $rDateFilter''';
      final creditReturnsRes = await db.rawQuery(creditReturnsQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double creditClientReturns =
          (creditReturnsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      double totalClientReturns = cashClientReturns + creditClientReturns;

      print("Running expensesQuery");
      // 3. Expenses (amount)
      final expensesQuery =
          'SELECT SUM(amount) as total FROM ${DbConstants.tableExpenses} WHERE is_deleted = 0 AND sync_status != ? $dateFilter';
      final expensesRes = await db.rawQuery(expensesQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double totalExpenses =
          (expensesRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running cashPurchasesQuery");
      // 4. Purchases (totalAmount)
      final cashPurchasesQuery =
          "SELECT SUM(totalAmount) as total FROM ${DbConstants.tablePurchases} WHERE paymentType = 'cash' AND is_deleted = 0 AND sync_status != ? $dateFilter";
      final cashPurchasesRes = await db.rawQuery(cashPurchasesQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double cashPurchases =
          (cashPurchasesRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running creditPurchasesQuery");
      final creditPurchasesQuery =
          "SELECT SUM(totalAmount) as total FROM ${DbConstants.tablePurchases} WHERE paymentType = 'credit' AND is_deleted = 0 AND sync_status != ? $dateFilter";
      final creditPurchasesRes = await db.rawQuery(creditPurchasesQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double creditPurchases =
          (creditPurchasesRes.first['total'] as num?)?.toDouble() ?? 0.0;

      double totalPurchasesBills = cashPurchases + creditPurchases;

      print("Running cashPurchaseReturnsQuery");
      // 5. Purchase Returns joined with purchases to check paymentType
      final cashPurchaseReturnsQuery =
          '''SELECT SUM(pr.totalAmount) as total 
             FROM ${DbConstants.tablePurchaseReturns} pr 
             LEFT JOIN ${DbConstants.tablePurchases} p ON pr.purchase = p.id 
             WHERE p.paymentType = 'cash' AND pr.sync_status != ? $prDateFilter''';
      final cashPurchaseReturnsRes = await db.rawQuery(
        cashPurchaseReturnsQuery,
        [SyncStatus.pendingDelete, ...dateArgs],
      );
      double cashSupplierReturns =
          (cashPurchaseReturnsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running creditPurchaseReturnsQuery");
      final creditPurchaseReturnsQuery =
          '''SELECT SUM(pr.totalAmount) as total 
             FROM ${DbConstants.tablePurchaseReturns} pr 
             LEFT JOIN ${DbConstants.tablePurchases} p ON pr.purchase = p.id 
             WHERE p.paymentType = 'credit' AND pr.sync_status != ? $prDateFilter''';
      final creditPurchaseReturnsRes = await db.rawQuery(
        creditPurchaseReturnsQuery,
        [SyncStatus.pendingDelete, ...dateArgs],
      );
      double creditSupplierReturns =
          (creditPurchaseReturnsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      double totalSupplierReturns = cashSupplierReturns + creditSupplierReturns;

      print("Running supplierPaymentsQuery");
      // 6. Supplier Payments & Client Receipts
      final supplierPaymentsQuery =
          'SELECT SUM(amount) as total FROM ${DbConstants.tableSupplierPayments} WHERE sync_status != ? $dateFilter';
      final supplierPaymentsRes = await db.rawQuery(supplierPaymentsQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double totalSupplierPayments =
          (supplierPaymentsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running clientReceiptsQuery");
      final clientReceiptsQuery =
          'SELECT SUM(amount) as total FROM ${DbConstants.tableReceipts} WHERE sync_status != ? $dateFilter';
      final clientReceiptsRes = await db.rawQuery(clientReceiptsQuery, [
        SyncStatus.pendingDelete,
        ...dateArgs,
      ]);
      double totalClientReceipts =
          (clientReceiptsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running inventoryQuery");
      // 7. Inventory Value (stock * buyPrice)
      final inventoryQuery =
          'SELECT SUM(stock * buyPrice) as total FROM ${DbConstants.tableProducts} WHERE is_deleted = 0 AND sync_status != ?';
      final inventoryRes = await db.rawQuery(inventoryQuery, [
        SyncStatus.pendingDelete,
      ]);
      double inventoryVal =
          (inventoryRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running clientsQuery");
      // 8. Receivables (Clients balances sum > 0)
      final clientsQuery =
          'SELECT SUM(balance) as total FROM ${DbConstants.tableClients} WHERE balance > 0 AND is_deleted = 0 AND sync_status != ?';
      final clientsRes = await db.rawQuery(clientsQuery, [
        SyncStatus.pendingDelete,
      ]);
      double receivables =
          (clientsRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("Running suppliersQuery");
      // 9. Payables (Suppliers balances > 0 means we owe them)
      final suppliersQuery =
          'SELECT SUM(balance) as total FROM ${DbConstants.tableSuppliers} WHERE balance > 0 AND sync_status != ? AND is_deleted = 0';
      final suppliersRes = await db.rawQuery(suppliersQuery, [
        SyncStatus.pendingDelete,
      ]);
      double payables =
          (suppliersRes.first['total'] as num?)?.toDouble() ?? 0.0;

      print("getGeneralReportData DONE successfully!");
      return {
        'monthlySales': totalSales,
        'cashSales': cashSales,
        'creditSales': creditSales,
        'clientReturns': totalClientReturns,
        'cashClientReturns': cashClientReturns,
        'creditClientReturns': creditClientReturns,
        'monthlyReturns': totalClientReturns, // Legacy fallback
        'monthlyExpenses': totalExpenses,
        'monthlyBills': totalPurchasesBills,
        'cashPurchases': cashPurchases,
        'creditPurchases': creditPurchases,
        'supplierReturns': totalSupplierReturns,
        'cashSupplierReturns': cashSupplierReturns,
        'creditSupplierReturns': creditSupplierReturns,
        'monthlyPayments': totalSupplierPayments,
        'clientReceipts': totalClientReceipts,
        'inventory': inventoryVal,
        'receivables': receivables,
        'payables': payables,
      };
    } catch (e, st) {
      print("Error in getGeneralReportData: $e\n$st");
      rethrow;
    }
  }
}
