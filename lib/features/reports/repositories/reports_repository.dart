import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../sales/repositories/sales_repository.dart';
import '../../purchases/repositories/purchases_repository.dart';
import '../../store/repositories/store_repository.dart';

part 'reports_repository.g.dart';

class ReportsRepository {
  final PocketBase globalPb;
  final SalesRepository _salesRepo;
  final PurchasesRepository _purchasesRepo;
  final StoreRepository _storeRepo;

  ReportsRepository(this.globalPb, this._salesRepo, this._purchasesRepo, this._storeRepo);

  Future<Map<String, double>> getGeneralReportData({
    String? startDate,
    String? endDate,
  }) async {
    // 1. Fetch data using existing repositories with date filters
    final sales = await _salesRepo.getSales(startDate: startDate, endDate: endDate);
    final returns = await _salesRepo.getReturns(startDate: startDate, endDate: endDate);
    
    // We need an expenses provider or method here if it's separate. 
    // For now we assume we fetch it directly or via another repo.
    String expenseFilter = 'is_deleted = false';
    if (startDate != null && endDate != null) {
      expenseFilter += ' && date >= "$startDate" && date <= "$endDate"';
    }
    final expenses = await globalPb.collection('expenses').getFullList(sort: '-date', filter: expenseFilter);

    final purchases = await _purchasesRepo.getPurchases(startDate: startDate, endDate: endDate);
    final purchaseReturns = await _purchasesRepo.getPurchaseReturns(startDate: startDate, endDate: endDate);
    
    // Supplier Payments
    final supplierPayments = await _purchasesRepo.getAllSupplierPayments(); 

    // 2. Aggregate
    double totalSales = sales.fold(0.0, (sum, item) => sum + ((item.data['netAmount'] ?? item.data['totalAmount']) as num).toDouble());
    double totalClientReturns = returns.fold(0.0, (sum, item) => sum + (item.data['totalAmount'] as num).toDouble());
    double totalExpenses = expenses.fold(0.0, (sum, item) => sum + (item.data['amount'] as num).toDouble());
    double totalPurchasesBills = purchases.fold(0.0, (sum, item) => sum + (item.data['totalAmount'] as num).toDouble());
    double totalSupplierReturns = purchaseReturns.fold(0.0, (sum, item) => sum + (item.data['totalAmount'] as num).toDouble());

    // Manual filtering for supplier payments if needed
    double totalSupplierPayments = 0.0;
    if (startDate != null && endDate != null) {
      DateTime start = DateTime.parse(startDate);
      DateTime end = DateTime.parse(endDate);
      for (var p in supplierPayments) {
        if (p.data['date'] != null) {
          DateTime pDate = DateTime.parse(p.data['date']);
          if (pDate.isAfter(start) && pDate.isBefore(end)) {
            totalSupplierPayments += (p.data['amount'] as num).toDouble();
          }
        }
      }
    } else {
      totalSupplierPayments = supplierPayments.fold(0.0, (sum, item) => sum + (item.data['amount'] as num).toDouble());
    }

    double inventoryVal = 0.0;
    try {
      inventoryVal = await _storeRepo.getInventoryValue();
    } catch (_) {}

    return {
      'monthlySales': totalSales,
      'clientReturns': totalClientReturns,
      'monthlyReturns': totalClientReturns, // Same as clientReturns
      'monthlyExpenses': totalExpenses,
      'monthlyBills': totalPurchasesBills,
      'supplierReturns': totalSupplierReturns,
      'monthlyPayments': totalSupplierPayments,
      'inventory': inventoryVal,
      'receivables': 0.0, // To be added from Client/Supplier
      'payables': 0.0, 
    };
  }
}

@riverpod
Future<ReportsRepository> reportsRepository(Ref ref) async {
  final pb = await ref.watch(pbHelperProvider.future);
  final salesRepo = await ref.watch(salesRepositoryProvider.future);
  final purchasesRepo = await ref.watch(purchasesRepositoryProvider.future);
  final storeRepo = await ref.watch(storeRepositoryProvider.future);
  
  return ReportsRepository(pb, salesRepo, purchasesRepo, storeRepo);
}
