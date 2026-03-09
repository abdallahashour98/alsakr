import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:al_sakr/features/reports/controllers/reports_controller.dart';
import 'package:al_sakr/features/reports/presentations/reports_screen.dart';
import 'package:al_sakr/features/purchases/presentations/purchase_history_screen.dart';
import 'package:al_sakr/features/expenses/presentations/expenses_screen.dart';
import 'package:al_sakr/features/store/presentations/store_screen.dart';
import 'package:al_sakr/features/suppliers/presentations/suppliers_screen.dart';
import 'package:al_sakr/features/clients/presentations/clients_screen.dart';
import 'package:al_sakr/features/dashboard/presentations/returns_list_screen.dart';

enum ReportFilter { monthly, yearly }

class GeneralReportsScreen extends ConsumerStatefulWidget {
  const GeneralReportsScreen({super.key});

  @override
  ConsumerState<GeneralReportsScreen> createState() =>
      _GeneralReportsScreenState();
}

class _GeneralReportsScreenState extends ConsumerState<GeneralReportsScreen> {
  ReportFilter _filterType = ReportFilter.monthly;
  DateTime _selectedDate = DateTime.now();

  void _changeDate(int offset) {
    setState(() {
      if (_filterType == ReportFilter.monthly) {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + offset,
          1,
        );
      } else {
        _selectedDate = DateTime(_selectedDate.year + offset, 1, 1);
      }
    });
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  String _getMonthName(int month) {
    const months = [
      "يناير",
      "فبراير",
      "مارس",
      "أبريل",
      "مايو",
      "يونيو",
      "يوليو",
      "أغسطس",
      "سبتمبر",
      "أكتوبر",
      "نوفمبر",
      "ديسمبر",
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String startDate;
    String endDate;

    if (_filterType == ReportFilter.monthly) {
      DateTime start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      DateTime end = DateTime(
        _selectedDate.year,
        _selectedDate.month + 1,
        0,
        23,
        59,
        59,
      );
      startDate = start.toUtc().toIso8601String();
      endDate = end.toUtc().toIso8601String();
    } else {
      DateTime start = DateTime(_selectedDate.year, 1, 1);
      DateTime end = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
      startDate = start.toUtc().toIso8601String();
      endDate = end.toUtc().toIso8601String();
    }

    final reportsAsync = ref.watch(
      reportsDataProvider(startDate: startDate, endDate: endDate),
    );

    String filterTitle = _filterType == ReportFilter.monthly
        ? "${_getMonthName(_selectedDate.month)} ${_selectedDate.year}"
        : "${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير المالي الشامل'),
        centerTitle: true,
        actions: [
          PopupMenuButton<ReportFilter>(
            icon: const Icon(Icons.filter_alt_outlined),
            onSelected: (ReportFilter result) {
              setState(() {
                _filterType = result;
                _selectedDate = DateTime.now();
              });
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: ReportFilter.monthly,
                child: Text('عرض شهري'),
              ),
              const PopupMenuItem(
                value: ReportFilter.yearly,
                child: Text('عرض سنوي'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _changeDate(-1),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _filterType == ReportFilter.monthly
                            ? Icons.calendar_month
                            : Icons.calendar_today,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        filterTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _changeDate(1),
                  icon: const Icon(Icons.arrow_forward_ios, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
        data: (_data) {
          double sales = _data['monthlySales'] ?? 0.0;
          double cashSales = _data['cashSales'] ?? 0.0;

          double clientReturns = _data['clientReturns'] ?? 0.0;
          double cashClientReturns = _data['cashClientReturns'] ?? 0.0;

          double supplierReturns = _data['supplierReturns'] ?? 0.0;
          double cashSupplierReturns = _data['cashSupplierReturns'] ?? 0.0;

          double purchasesBills = _data['monthlyBills'] ?? 0.0;
          double cashPurchases = _data['cashPurchases'] ?? 0.0;

          double expenses = _data['monthlyExpenses'] ?? 0.0;
          double supplierPayments = _data['monthlyPayments'] ?? 0.0;
          double clientReceipts = _data['clientReceipts'] ?? 0.0;

          double totalCashIn = cashSales + cashSupplierReturns + clientReceipts;
          double totalCashOut =
              cashPurchases +
              cashClientReturns +
              expenses.abs() +
              supplierPayments.abs();
          double netCashFlow = totalCashIn - totalCashOut;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                  reportsDataProvider(startDate: startDate, endDate: endDate),
                );
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 2000),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          "حركة الخزينة / السيولة النقدية ($filterTitle)",
                        ),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildCashRow(
                                "مبيعات نقدية (+)",
                                cashSales,
                                Colors.green,
                              ),
                              if (cashSupplierReturns > 0)
                                _buildCashRow(
                                  "استرداد مرتجعات مشتريات (+)",
                                  cashSupplierReturns,
                                  Colors.green,
                                ),
                              if (clientReceipts > 0)
                                _buildCashRow(
                                  "قبض من عملاء (+)",
                                  clientReceipts,
                                  Colors.green,
                                ),
                              const Divider(),
                              _buildCashRow(
                                "مشتريات نقدية (-)",
                                -cashPurchases,
                                Colors.red,
                              ),
                              if (cashClientReturns > 0)
                                _buildCashRow(
                                  "رد أموال مرتجعات مبيعات (-)",
                                  -cashClientReturns,
                                  Colors.red,
                                ),
                              _buildCashRow(
                                "مصاريف تشغيل (-)",
                                -expenses.abs(),
                                Colors.red,
                              ),
                              if (supplierPayments > 0)
                                _buildCashRow(
                                  "سداد للموردين (-)",
                                  -supplierPayments.abs(),
                                  Colors.orange[800]!,
                                ),
                              const Divider(thickness: 2),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "صافي السيولة :",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "${netCashFlow.toStringAsFixed(1)} ج.م",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: netCashFlow >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),

                        _buildSectionHeader("النشاط التجاري ($filterTitle)"),

                        _buildListTileCard(
                          "إجمالي المبيعات",
                          sales,
                          Icons.point_of_sale,
                          Colors.teal,
                          cardBg,
                          textColor,
                          () => _navigateTo(const ReportsScreen()),
                        ),
                        _buildListTileCard(
                          "إجمالي فواتير الشراء",
                          purchasesBills,
                          Icons.inventory,
                          Colors.blue,
                          cardBg,
                          textColor,
                          () => _navigateTo(const PurchaseHistoryScreen()),
                        ),
                        _buildListTileCard(
                          "مرتجعات العملاء",
                          -clientReturns,
                          Icons.assignment_return,
                          Colors.deepPurple,
                          cardBg,
                          textColor,
                          () => _navigateTo(const ReturnsListScreen()),
                        ),
                        _buildListTileCard(
                          "مرتجعات الموردين",
                          -supplierReturns,
                          Icons.unarchive,
                          Colors.orange,
                          cardBg,
                          textColor,
                          () => _navigateTo(const ReturnsListScreen()),
                        ),
                        _buildListTileCard(
                          "المصروفات",
                          -expenses,
                          Icons.money_off,
                          Colors.redAccent,
                          cardBg,
                          textColor,
                          () => _navigateTo(const ExpensesScreen()),
                        ),

                        const SizedBox(height: 25),

                        _buildSectionHeader("المركز المالي (الأرصدة الحالية)"),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                "قيمة المخزون",
                                _data['inventory'] ?? 0,
                                Icons.store,
                                Colors.blue,
                                isDark,
                                () => _navigateTo(const StoreScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                "لنا عند العملاء",
                                _data['receivables'] ?? 0,
                                Icons.account_balance_wallet,
                                Colors.green,
                                isDark,
                                () => _navigateTo(const ClientsScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSummaryCard(
                                "علينا للموردين",
                                _data['payables'] ?? 0,
                                Icons.money_off,
                                Colors.red,
                                isDark,
                                () => _navigateTo(const SuppliersScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, right: 5),
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    ),
  );

  Widget _buildCashRow(String title, double amount, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14)),
        Text(
          "${amount.toStringAsFixed(1)} ج.م",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            FittedBox(
              child: Text(
                "${amount.abs().toStringAsFixed(1)} ج.م",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildListTileCard(
    String title,
    double amount,
    IconData icon,
    Color color,
    Color cardBg,
    Color textColor,
    VoidCallback onTap,
  ) => Card(
    color: cardBg,
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${amount.toStringAsFixed(1)} ج.م",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Colors.grey.withOpacity(0.5),
          ),
        ],
      ),
    ),
  );
}
