import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:al_sakr/models/transaction_item_model.dart';

const _superAdminId = 'admin123';

/// ============================================================
/// ↩️ شاشة سجل المرتجعات (Returns Log) - Refactored
/// ============================================================
class ReturnsListScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final DateTime? initialDate;

  const ReturnsListScreen({super.key, this.initialIndex = 0, this.initialDate});

  @override
  ConsumerState<ReturnsListScreen> createState() => _ReturnsListScreenState();
}

class _ReturnsListScreenState extends ConsumerState<ReturnsListScreen> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month + offset,
        1,
      );
    });
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
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل المرتجعات'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                // شريط التنقل بين الشهور
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          "${_getMonthName(_currentDate.month)} ${_currentDate.year}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      ),
                    ],
                  ),
                ),
                // عناوين التابات
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.person), text: "مرتجعات العملاء"),
                    Tab(
                      icon: Icon(Icons.local_shipping),
                      text: "مرتجعات الموردين",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            ClientReturnsTab(selectedDate: _currentDate),
            SupplierReturnsTab(selectedDate: _currentDate),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 1️⃣ تاب مرتجعات العملاء (Client Returns Tab)
// =============================================================================
class ClientReturnsTab extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  const ClientReturnsTab({super.key, required this.selectedDate});

  @override
  ConsumerState<ClientReturnsTab> createState() => _ClientReturnsTabState();
}

class _ClientReturnsTabState extends ConsumerState<ClientReturnsTab>
    with AutomaticKeepAliveClientMixin {
  // ✅ 1. الصلاحيات
  bool _canDeleteReturn = false;
  bool _canSettlePayment = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void didUpdateWidget(covariant ClientReturnsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      setState(() {}); // Trigger rebuild to re-fetch
    }
  }

  // ✅ دالة جلب المرتجعات من قاعدة بيانات محلية
  Future<List<Map<String, dynamic>>> _fetchReturns() async {
    DateTime start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
    DateTime end = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month + 1,
      0,
      23,
      59,
      59,
    );
    final returns = await ref
        .read(salesControllerProvider.notifier)
        .getReturns(
          startDate: start.toIso8601String(),
          endDate: end.toIso8601String(),
        );
    return returns;
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;
    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canDeleteReturn = true;
          _canSettlePayment = true;
        });
      return;
    }
    try {
      final db = await ref.read(localDatabaseProvider.future);
      final rows = await db.query(
        'users',
        where: '${DbConstants.colId} = ?',
        whereArgs: [myId],
        limit: 1,
      );
      if (rows.isNotEmpty && mounted) {
        final u = rows.first;
        setState(() {
          _canDeleteReturn =
              u['allow_delete_returns'] == 1 ||
              u['allow_delete_returns'] == true;
          _canSettlePayment =
              (u['allow_add_orders'] == 1 || u['allow_add_orders'] == true) ||
              (u['allow_add_returns'] == 1 || u['allow_add_returns'] == true);
        });
      }
    } catch (e) {}
  }

  String fmt(dynamic number) {
    if (number == null) return "0.00";
    return double.tryParse(number.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  void _deleteReturn(String id) async {
    if (!_canDeleteReturn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية الحذف')));
      return;
    }
    try {
      await ref.read(salesControllerProvider.notifier).deleteReturnSafe(id);
      // لا نحتاج لإعادة تحميل البيانات يدوياً لأن الستريم سيحدث نفسه
      if (mounted) {
        setState(() {}); // Trigger FutureBuilder rebuild
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف بنجاح'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showDetails(Map<String, dynamic> ret) async {
    final items = await ref
        .read(salesControllerProvider.notifier)
        .getReturnItems(ret['id']);
    if (!mounted) return;
    final paymentType = ret['paymentType'] ?? 'cash';
    final isCash = paymentType == 'cash';
    _showUnifiedBottomSheet("مرتجع عميل", items, ret, isCash, false, true);
  }

  void _showUnifiedBottomSheet(
    String title,
    List<TransactionItemModel> items,
    Map ret,
    bool isCash,
    bool hasTax,
    bool isClient,
  ) {
    double total = (ret['totalAmount'] as num? ?? 0).toDouble();
    double paid = (ret['paidAmount'] as num? ?? 0).toDouble();
    double remaining = total - paid;
    if (remaining < 0) remaining = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 600,
        child: Column(
          children: [
            Text(
              "$title #${ret['id'].toString().substring(0, 5)}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(items[i].productName),
                  subtitle: Text(
                    "${items[i].quantity} × ${fmt(items[i].price)}",
                  ),
                  trailing: Text(fmt(items[i].total)),
                ),
              ),
            ),
            const Divider(),
            _summaryRow("الإجمالي النهائي", total, isBold: true, size: 16),
            _summaryRow(
              isClient ? "تم صرف:" : "تم استرداد:",
              paid,
              color: Colors.green,
            ),
            _summaryRow("المتبقي:", remaining, color: Colors.red, isBold: true),
            const SizedBox(height: 20),
            if (remaining > 0.1 && isCash)
              _canSettlePayment
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        fixedSize: const Size(double.maxFinite, 50),
                      ),
                      onPressed: () =>
                          _processPayment(ctx, ret, remaining, isClient),
                      child: Text(
                        isClient
                            ? "صرف نقدية للعميل"
                            : "استلام نقدية من المورد",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Text(
                      "⚠️ ليس لديك صلاحية صرف نقدية",
                      style: TextStyle(color: Colors.grey),
                    )
            else if (remaining > 0.1 && !isCash)
              Text(
                "هذا المرتجع آجل — لا يتم صرف نقدية",
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else
              const Text(
                "تمت التسوية المالية بالكامل ✅",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
    double size = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            fmt(val),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: size,
            ),
          ),
        ],
      ),
    );
  }

  void _processPayment(
    BuildContext ctx,
    Map ret,
    double maxAmount,
    bool isClient,
  ) {
    TextEditingController ctrl = TextEditingController(
      text: maxAmount.toString(),
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isClient ? "صرف نقدية" : "استلام نقدية"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "المبلغ"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              double val = double.tryParse(ctrl.text) ?? 0;
              if (val <= 0 || val > maxAmount + 0.1) return;
              Navigator.pop(dialogCtx);
              try {
                if (isClient) {
                  await ref
                      .read(salesControllerProvider.notifier)
                      .payReturnCash(
                        ret['id'],
                        ret['client'] ?? ret['clientId'],
                        val,
                      );
                } else {
                  // مورد: إضافة دفعة سالبة + تحديث paidAmount محلياً
                  await ref
                      .read(purchasesControllerProvider.notifier)
                      .addSupplierPayment(
                        supplierId: ret['supplier'],
                        amount: val * -1,
                        notes: 'استرداد نقدية عن مرتجع',
                        date: DateTime.now().toIso8601String(),
                      );
                  final db = await ref.read(localDatabaseProvider.future);
                  double old = (ret['paidAmount'] as num? ?? 0).toDouble();
                  await db.update(
                    'purchase_returns',
                    {
                      'paidAmount': old + val,
                      DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
                      DbConstants.colUpdated: DateTime.now()
                          .toUtc()
                          .toIso8601String(),
                    },
                    where: '${DbConstants.colId} = ?',
                    whereArgs: [ret['id']],
                  );
                }
                if (mounted) {
                  Navigator.pop(ctx); // Close bottom sheet
                  setState(() {}); // Trigger FutureBuilder rebuild
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم بنجاح"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
              }
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchReturns(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("خطأ: ${snapshot.error}"));
        }

        final returns = snapshot.data ?? [];
        if (returns.isEmpty)
          return const Center(child: Text("لا توجد بيانات لهذا الشهر"));

        // 📂 تجميع المرتجعات (Grouping)
        Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var ret in returns) {
          String clientName =
              ret['clientName'] ??
              ret['expand']?['client']?['name'] ??
              'عميل غير معروف';
          grouped.putIfAbsent(clientName, () => []).add(ret);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: grouped.keys.length,
          itemBuilder: (context, index) {
            String name = grouped.keys.elementAt(index);
            List<Map<String, dynamic>> list = grouped[name]!;
            double total = list.fold(
              0.0,
              (sum, item) =>
                  sum + (item['totalAmount'] as num? ?? 0).toDouble(),
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.person, color: Colors.orange),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("الإجمالي: ${fmt(total)} ج.م"),
                children: list.map((ret) => _buildReturnRow(ret)).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReturnRow(Map<String, dynamic> ret) {
    double total = (ret['totalAmount'] as num? ?? 0).toDouble();
    double paid = (ret['paidAmount'] as num? ?? 0).toDouble();
    bool isCompleted = paid >= (total - 0.1);

    return ListTile(
      onTap: () => _showDetails(ret),
      title: Text("مرتجع #${ret['id'].toString().substring(0, 5)}"),
      subtitle: Text(ret['date'].toString().split(' ')[0]),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${fmt(total)} ج.م",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                isCompleted ? "مكتمل" : "باقي: ${fmt(total - paid)}",
                style: TextStyle(
                  fontSize: 10,
                  color: isCompleted ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (_canDeleteReturn)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteReturn(ret['id']),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2️⃣ تاب مرتجعات الموردين (Supplier Returns Tab)
// =============================================================================
class SupplierReturnsTab extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  const SupplierReturnsTab({super.key, required this.selectedDate});

  @override
  ConsumerState<SupplierReturnsTab> createState() => _SupplierReturnsTabState();
}

class _SupplierReturnsTabState extends ConsumerState<SupplierReturnsTab>
    with AutomaticKeepAliveClientMixin {
  bool _canDeleteReturn = false;
  bool _canSettlePayment = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<List<Map<String, dynamic>>> _fetchReturns() async {
    DateTime start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
    DateTime end = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month + 1,
      0,
      23,
      59,
      59,
    );
    return ref
        .read(purchasesControllerProvider.notifier)
        .getAllPurchaseReturns(
          startDate: start.toIso8601String(),
          endDate: end.toIso8601String(),
        );
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;
    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canDeleteReturn = true;
          _canSettlePayment = true;
        });
      return;
    }
    try {
      final db = await ref.read(localDatabaseProvider.future);
      final rows = await db.query(
        'users',
        where: '${DbConstants.colId} = ?',
        whereArgs: [myId],
        limit: 1,
      );
      if (rows.isNotEmpty && mounted) {
        final u = rows.first;
        setState(() {
          _canDeleteReturn =
              u['allow_delete_returns'] == 1 ||
              u['allow_delete_returns'] == true;
          _canSettlePayment =
              (u['allow_add_purchases'] == 1 ||
                  u['allow_add_purchases'] == true) ||
              (u['allow_add_returns'] == 1 || u['allow_add_returns'] == true);
        });
      }
    } catch (e) {}
  }

  String fmt(dynamic number) {
    if (number == null) return "0.00";
    return double.tryParse(number.toString())?.toStringAsFixed(2) ?? "0.00";
  }

  void _deleteReturn(String id) async {
    if (!_canDeleteReturn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية الحذف')));
      return;
    }
    try {
      await ref
          .read(purchasesControllerProvider.notifier)
          .deletePurchaseReturnSafe(id);
      if (mounted) {
        setState(() {}); // Trigger FutureBuilder rebuild
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف بنجاح'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showDetails(Map<String, dynamic> ret) async {
    final items = await ref
        .read(purchasesControllerProvider.notifier)
        .getPurchaseReturnItems(ret['id']);
    if (!mounted) return;
    final paymentType = ret['paymentType'] ?? 'cash';
    final isCash = paymentType == 'cash';
    _showUnifiedBottomSheet("مرتجع مورد", items, ret, isCash, false, false);
  }

  void _showUnifiedBottomSheet(
    String title,
    List<TransactionItemModel> items,
    Map ret,
    bool isCash,
    bool hasTax,
    bool isClient,
  ) {
    double total = (ret['totalAmount'] as num? ?? 0).toDouble();
    double paid = (ret['paidAmount'] as num? ?? 0).toDouble();
    double remaining = total - paid;
    if (remaining < 0) remaining = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 600,
        child: Column(
          children: [
            Text(
              "$title #${ret['id'].toString().substring(0, 5)}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(items[i].productName),
                  subtitle: Text(
                    "${items[i].quantity} × ${fmt(items[i].price)}",
                  ),
                  trailing: Text(fmt(items[i].total)),
                ),
              ),
            ),
            const Divider(),
            _summaryRow("الإجمالي النهائي", total, isBold: true, size: 16),
            _summaryRow("تم استرداد:", paid, color: Colors.green),
            _summaryRow("المتبقي:", remaining, color: Colors.red, isBold: true),
            const SizedBox(height: 20),
            if (remaining > 0.1 && isCash)
              _canSettlePayment
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        fixedSize: const Size(double.maxFinite, 50),
                      ),
                      onPressed: () => _processPayment(ctx, ret, remaining),
                      child: const Text(
                        "استلام نقدية من المورد",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const Text(
                      "⚠️ ليس لديك صلاحية",
                      style: TextStyle(color: Colors.grey),
                    )
            else if (remaining > 0.1 && !isCash)
              Text(
                "هذا المرتجع آجل — لا يتم صرف نقدية",
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else
              const Text(
                "تمت التسوية ✅",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double val, {
    bool isBold = false,
    Color? color,
    double size = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: size,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            fmt(val),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: size,
            ),
          ),
        ],
      ),
    );
  }

  void _processPayment(BuildContext ctx, Map ret, double maxAmount) {
    TextEditingController ctrl = TextEditingController(
      text: maxAmount.toString(),
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("استلام نقدية"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "المبلغ"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              double val = double.tryParse(ctrl.text) ?? 0;
              if (val <= 0 || val > maxAmount + 0.1) return;
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(purchasesControllerProvider.notifier)
                    .addSupplierPayment(
                      supplierId: ret['supplier'],
                      amount: val * -1,
                      notes: 'استرداد نقدية عن مرتجع',
                      date: DateTime.now().toIso8601String(),
                    );
                final db = await ref.read(localDatabaseProvider.future);
                double old = (ret['paidAmount'] as num? ?? 0).toDouble();
                await db.update(
                  'purchase_returns',
                  {
                    'paidAmount': old + val,
                    DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
                    DbConstants.colUpdated: DateTime.now()
                        .toUtc()
                        .toIso8601String(),
                  },
                  where: '${DbConstants.colId} = ?',
                  whereArgs: [ret['id']],
                );
                // Update supplier balance locally
                try {
                  final suppRows = await db.query(
                    'suppliers',
                    where: '${DbConstants.colId} = ?',
                    whereArgs: [ret['supplier']],
                    limit: 1,
                  );
                  if (suppRows.isNotEmpty) {
                    double oldBal = (suppRows.first['balance'] as num? ?? 0)
                        .toDouble();
                    await db.update(
                      'suppliers',
                      {
                        'balance': oldBal + val,
                        DbConstants.colSyncStatus: SyncStatus.pendingUpdate,
                        DbConstants.colUpdated: DateTime.now()
                            .toUtc()
                            .toIso8601String(),
                      },
                      where: '${DbConstants.colId} = ?',
                      whereArgs: [ret['supplier']],
                    );
                  }
                } catch (_) {}

                if (mounted) {
                  Navigator.pop(ctx); // Close bottom sheet
                  setState(() {}); // Trigger FutureBuilder rebuild
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم بنجاح"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
              }
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchReturns(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("خطأ: ${snapshot.error}"));
        }

        final returns = snapshot.data ?? [];
        if (returns.isEmpty)
          return const Center(child: Text("لا توجد بيانات لهذا الشهر"));

        Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var ret in returns) {
          String supplierName =
              ret['supplierName'] ??
              ret['expand']?['supplier']?['name'] ??
              'مورد غير معروف';
          grouped.putIfAbsent(supplierName, () => []).add(ret);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: grouped.keys.length,
          itemBuilder: (context, index) {
            String name = grouped.keys.elementAt(index);
            List<Map<String, dynamic>> list = grouped[name]!;
            double total = list.fold(
              0.0,
              (sum, item) =>
                  sum + (item['totalAmount'] as num? ?? 0).toDouble(),
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                initiallyExpanded: true,
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("الإجمالي: ${fmt(total)} ج.م"),
                children: list.map((ret) => _buildReturnRow(ret)).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReturnRow(Map<String, dynamic> ret) {
    double total = (ret['totalAmount'] as num? ?? 0).toDouble();
    return ListTile(
      onTap: () => _showDetails(ret),
      title: Text("مرتجع #${ret['id'].toString().substring(0, 5)}"),
      subtitle: Text(ret['date'].toString().split(' ')[0]),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${fmt(total)} ج.م",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (_canDeleteReturn)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _deleteReturn(ret['id']),
            ),
        ],
      ),
    );
  }
}
