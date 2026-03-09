import 'package:al_sakr/features/trash/controllers/trash_controller.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
import 'package:al_sakr/features/clients/controllers/client_controller.dart';
import 'package:al_sakr/features/notices/controllers/notices_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // //   final TrashService _trashService = ref.read(trashControllerProvider);

  // 1. القائمة المحدثة
  final Map<String, String> _collections = {
    'sales': 'المبيعات',
    'purchases': 'المشتريات',
    'delivery_orders': 'أذونات التسليم', // ✅ تمت الإضافة
    'products': 'المنتجات',
    'clients': 'العملاء',
    'suppliers': 'الموردين',
    'expenses': 'المصروفات',
    'announcements': 'الإشعارات',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _collections.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- دوال العمليات (الحذف والاسترجاع) ---
  Future<void> _restore(String collection, String id) async {
    try {
      if (collection == 'sales') {
        await ref.read(salesControllerProvider.notifier).restoreSale(id);
      } else if (collection == 'purchases') {
        await ref
            .read(purchasesControllerProvider.notifier)
            .restorePurchase(id);
      } else if (collection == 'delivery_orders') {
        await ref
            .read(salesControllerProvider.notifier)
            .restoreDeliveryOrder(id); // ✅ استرجاع الإذن
      } else if (collection == 'announcements') {
        await ref
            .read(noticesControllerProvider.notifier)
            .restoreAnnouncement(id);
      } else {
        await ref
            .read(trashControllerProvider.notifier)
            .restoreItem(collection, id);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الاسترجاع بنجاح ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _deleteForever(String collection, String id) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('حذف نهائي'),
            content: const Text(
              'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        if (collection == 'sales') {
          await ref
              .read(salesControllerProvider.notifier)
              .deleteSaleForever(id);
        } else if (collection == 'delivery_orders') {
          await ref
              .read(salesControllerProvider.notifier)
              .deleteDeliveryOrderForever(id); // ✅ حذف نهائي للإذن
        } else if (collection == 'announcements') {
          await ref
              .read(noticesControllerProvider.notifier)
              .deleteAnnouncementForever(id);
        } else {
          // باقي الأنواع (مشتريات، منتجات، إلخ) يتم التعامل معها عبر TrashService إذا كانت مدعومة
          // أو يمكنك إضافة شروط ref.read(purchasesControllerProvider.notifier).deletePurchaseForever(id) إذا كانت لديك
          await ref
              .read(trashControllerProvider.notifier)
              .deleteItemForever(collection, id);
        }
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف نهائياً 🗑️'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  // --- دوال العرض المساعدة ---
  Widget _buildDetailRow(String label, String value, BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    BuildContext context, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            intl.NumberFormat('#,##0.00').format(value),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // --- دالة المعاينة الشاملة ---
  void _showDetails(Map<String, dynamic> item, String type) async {
    // 1️⃣ معالجة الفواتير (مبيعات / مشتريات)
    if (type == 'sales' || type == 'purchases') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      List<dynamic> items = [];
      try {
        if (type == 'sales') {
          items = await ref
              .read(salesControllerProvider.notifier)
              .getSaleItems(item['id']);
        } else {
          items = await ref
              .read(purchasesControllerProvider.notifier)
              .getPurchaseItems(item['id']);
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        return;
      }

      if (!mounted) return;

      double dbTotal = (item['totalAmount'] ?? 0).toDouble();
      double discount = (item['discount'] ?? 0).toDouble();
      double taxAmount = (item['taxAmount'] ?? 0).toDouble();
      double whtAmount = (item['whtAmount'] ?? 0).toDouble();

      double displaySubTotal = 0.0;
      double displayNetTotal = 0.0;

      if (type == 'sales') {
        displaySubTotal = dbTotal;
        displayNetTotal =
            (item['netAmount'] ??
                    (displaySubTotal - discount + taxAmount - whtAmount))
                .toDouble();
      } else {
        displayNetTotal = dbTotal;
        displaySubTotal = displayNetTotal - taxAmount + discount + whtAmount;
      }

      String dateStr = (item['date'] ?? '').toString().split(' ')[0];
      String name = 'غير معروف';
      var expand = item['expand'];

      if (type == 'sales') {
        var c = expand?['client'];
        name = (c is List && c.isNotEmpty)
            ? c[0]['name']
            : (c is Map ? c['name'] : 'عميل نقدي');
      } else {
        var s = expand?['supplier'];
        name = (s is List && s.isNotEmpty)
            ? s[0]['name']
            : (s is Map ? s['name'] : 'مورد عام');
      }

      _showInvoiceDialog(
        title: type == 'sales' ? "فاتورة مبيعات" : "فاتورة مشتريات",
        nameLabel: type == 'sales' ? "العميل:" : "المورد:",
        nameValue: name,
        date: dateStr,
        refNumber:
            "#${item['referenceNumber'] ?? item['id'].toString().substring(0, 5)}",
        items: items,
        subTotal: displaySubTotal,
        discount: discount,
        tax: taxAmount,
        wht: whtAmount,
        netTotal: displayNetTotal,
        isSales: type == 'sales',
      );
      return;
    }

    // 2️⃣ معالجة أذونات التسليم
    if (type == 'delivery_orders') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );
      List<dynamic> items = [];
      try {
        items = await ref
            .read(salesControllerProvider.notifier)
            .getDeliveryOrderItems(item['id']);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) Navigator.pop(context);
        return;
      }
      if (!mounted) return;

      String manualNo = item['manualNo'] ?? item['supplyOrderNumber'] ?? '-';
      String dateStr = (item['date'] ?? '').toString().split(' ')[0];
      String address = item['address'] ?? 'لا يوجد عنوان';
      String clientName = 'عميل غير معروف';
      if (item['expand'] != null && item['expand']['client'] != null) {
        var c = item['expand']['client'];
        clientName = (c is List && c.isNotEmpty)
            ? c[0]['name']
            : (c is Map ? c['name'] : clientName);
      }

      _showDeliveryOrderDialog(clientName, manualNo, dateStr, address, items);
      return;
    }

    // 3️⃣ باقي الأنواع
    String title = ref
        .read(trashControllerProvider.notifier)
        .getItemName(item, type);
    List<Widget> detailsRows = [];

    if (type == 'products') {
      title = item['name'] ?? 'منتج';
      detailsRows = [
        _buildDetailRow("السعر:", "${item['sellingPrice'] ?? 0} ج.م", context),
        _buildDetailRow("المخزون:", "${item['stock'] ?? 0}", context),
      ];
    } else if (type == 'clients' || type == 'suppliers') {
      title = item['name'] ?? 'شخص';
      detailsRows = [
        _buildDetailRow("الهاتف:", "${item['phone'] ?? '-'}", context),
        _buildDetailRow(
          "الرصيد:",
          "${intl.NumberFormat('#,##0').format(item['balance'] ?? 0)} ج.م",
          context,
        ),
      ];
    } else if (type == 'expenses') {
      title = item['title'].toString().isNotEmpty
          ? item['title']
          : item['category'];
      detailsRows = [
        _buildDetailRow("التصنيف:", "${item['category']}", context),
        _buildDetailRow("المبلغ:", "${item['amount']} ج.م", context),
      ];
    } else if (type == 'announcements') {
      title = item['title'].toString().isNotEmpty
          ? item['title']
          : 'إشعار بدون عنوان';
      detailsRows = [
        _buildDetailRow("الأولوية:", item['priority'] ?? 'normal', context),
      ];
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "محذوف",
                style: TextStyle(color: Colors.red, fontSize: 10),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [...detailsRows],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  // --- ديلوج الفواتير ---
  void _showInvoiceDialog({
    required String title,
    required String nameLabel,
    required String nameValue,
    required String date,
    required String refNumber,
    required List<dynamic> items,
    required double subTotal,
    required double discount,
    required double tax,
    required double wht,
    required double netTotal,
    required bool isSales,
  }) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color highlightColor = isDark
        ? Colors.lightBlueAccent
        : Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        insetPadding: const EdgeInsets.all(15),
        child: Container(
          width: isMobile ? double.infinity : 500,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      "محذوفة",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(thickness: 1.5),
              _buildDetailRow(nameLabel, nameValue, context),
              _buildDetailRow("التاريخ:", date, context),
              _buildDetailRow("رقم المرجع:", refNumber, context),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        "الصنف",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        "العدد × السعر",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "الإجمالي",
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxHeight: isMobile ? 200 : 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = items[index];
                      String pName =
                          p['productName'] ??
                          (p['expand']?['product']?['name']) ??
                          'منتج';
                      double price =
                          (isSales
                                  ? p['price']
                                  : (p['costPrice'] ?? p['price'] ?? 0))
                              .toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                pName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                "${p['quantity']} × $price",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                intl.NumberFormat(
                                  '#,##0',
                                ).format(p['quantity'] * price),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: highlightColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow("الإجمالي:", subTotal, context),
                    if (discount > 0)
                      _buildSummaryRow(
                        "الخصم:",
                        -discount,
                        context,
                        color: Colors.red,
                      ),
                    if (tax > 0)
                      _buildSummaryRow(
                        "الضريبة:",
                        tax,
                        context,
                        color: Colors.orange,
                      ),
                    if (wht > 0)
                      _buildSummaryRow(
                        "خصم المنبع:",
                        -wht,
                        context,
                        color: Colors.teal,
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "الصافي:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          intl.NumberFormat('#,##0.00').format(netTotal),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: highlightColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("إغلاق"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } // --- 🚚 2. ديلوج أذونات التسليم (تم إصلاح الأخطاء) ---

  void _showDeliveryOrderDialog(
    String client,
    String manualNo,
    String date,
    String address,
    List<dynamic> items,
  ) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    // ❌ حذفنا isDark عشان التحذير يروح

    // ✅ تصحيح الخطأ: استخدام MaterialColor بدلاً من Color عشان يقبل [800]
    MaterialColor tealColor = Colors.teal;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        insetPadding: const EdgeInsets.all(15),
        child: Container(
          width: isMobile ? double.infinity : 500,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الهيدر
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tealColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.local_shipping, color: tealColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "إذن تسليم #$manualNo",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      "محذوف",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Divider(),
              _buildDetailRow("العميل:", client, context),
              _buildDetailRow("العنوان:", address, context),
              const SizedBox(height: 15),

              // الهيدر بتاع الجدول
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: tealColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    // ✅ هنا كان الخطأ، ودلوقتي هيشتغل صح لأننا عرفناه كـ MaterialColor
                    Expanded(
                      flex: 2,
                      child: Text(
                        "العدد",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: tealColor[800],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        "الصنف / الوصف",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: tealColor[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),

              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxHeight: isMobile ? 250 : 350),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (c, i) =>
                        const Divider(height: 1, indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${item['quantity']}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['productName'] ??
                                        item['description'] ??
                                        'صنف',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item['description'] != null &&
                                      item['description'] !=
                                          item['productName'])
                                    Text(
                                      item['description'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("إغلاق"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    var keys = _collections.keys.toList();
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color highlightColor = isDark
        ? Colors.lightBlueAccent
        : Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المهملات ♻️'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: screenWidth < 600 ? true : false,
          tabAlignment: screenWidth < 600
              ? TabAlignment.start
              : TabAlignment.fill,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: _collections.values.map((e) => Tab(text: e)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: keys.map((collectionKey) {
          Future<List<dynamic>> future;
          if (collectionKey == 'sales') {
            future = ref
                .read(salesControllerProvider.notifier)
                .getDeletedSales();
          } else if (collectionKey == 'purchases') {
            future = ref
                .read(purchasesControllerProvider.notifier)
                .getDeletedPurchases();
          } else if (collectionKey == 'delivery_orders') {
            future = ref
                .read(salesControllerProvider.notifier)
                .getDeletedDeliveryOrders();
          } else if (collectionKey == 'products') {
            future = ref
                .read(storeControllerProvider.notifier)
                .getDeletedProducts();
          } else if (collectionKey == 'clients') {
            future = ref
                .read(clientControllerProvider.notifier)
                .getDeletedClients();
          } else if (collectionKey == 'suppliers') {
            future = ref
                .read(purchasesControllerProvider.notifier)
                .getDeletedSuppliers();
          } else if (collectionKey == 'expenses') {
            future = ref
                .read(salesControllerProvider.notifier)
                .getDeletedExpenses();
          } else if (collectionKey == 'announcements') {
            future = ref
                .read(noticesControllerProvider.notifier)
                .getDeletedAnnouncements();
          } else {
            future = ref
                .read(trashControllerProvider.notifier)
                .getDeletedItems(collectionKey);
          }

          return FutureBuilder<List<dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 70,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "لا يوجد ${_collections[collectionKey]} محذوفة",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final items = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  String name = ref
                      .read(trashControllerProvider.notifier)
                      .getItemName(item, collectionKey);
                  String dateStr = (item['updated'] ?? item['created'] ?? '')
                      .toString()
                      .split(' ')[0];
                  if (item['date'] != null)
                    dateStr = item['date'].toString().split(' ')[0];

                  IconData iconData = Icons.delete_outline;
                  Color iconColor = Colors.grey;

                  if (collectionKey == 'sales') {
                    iconData = Icons.receipt;
                    iconColor = Colors.blue;
                  } else if (collectionKey == 'purchases') {
                    iconData = Icons.shopping_cart;
                    iconColor = Colors.orange;
                  } else if (collectionKey == 'delivery_orders') {
                    iconData = Icons.local_shipping;
                    iconColor = Colors.teal;
                  } else if (collectionKey == 'products') {
                    iconData = Icons.inventory_2;
                    iconColor = Colors.purple;
                  } else if (collectionKey == 'clients' ||
                      collectionKey == 'suppliers') {
                    iconData = Icons.person;
                    iconColor = Colors.green;
                  } else if (collectionKey == 'expenses') {
                    iconData = Icons.money_off;
                    iconColor = Colors.red;
                  } else if (collectionKey == 'announcements') {
                    iconData = Icons.campaign;
                    iconColor = Colors.amber;
                  }

                  Widget? subtitleWidget;
                  Widget? trailingWidget;

                  if (collectionKey == 'delivery_orders') {
                    name =
                        "إذن تسليم #${item['manualNo'] ?? item['supplyOrderNumber'] ?? '-'}";
                    String clientName = "عميل غير معروف";
                    if (item['expand'] != null &&
                        item['expand']['client'] != null) {
                      var c = item['expand']['client'];
                      clientName = (c is List && c.isNotEmpty)
                          ? c[0]['name']
                          : (c is Map ? c['name'] : clientName);
                    }
                    subtitleWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              clientName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        if (item['address'] != null &&
                            item['address'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item['address'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  } else if (collectionKey == 'products') {
                    var price =
                        item['price'] ??
                        item['sellingPrice'] ??
                        item['costPrice'] ??
                        0;
                    var stock = item['stock'] ?? 0;
                    subtitleWidget = Text(
                      "سعر: $price | مخزون: $stock",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    );
                  } else if (collectionKey == 'clients' ||
                      collectionKey == 'suppliers') {
                    subtitleWidget = Text(
                      "هاتف: ${item['phone'] ?? '-'} | رصيد: ${item['balance'] ?? 0}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    );
                  } else if (collectionKey == 'expenses') {
                    subtitleWidget = Text(
                      "${item['category'] ?? 'مصروف'} • $dateStr",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    );
                    trailingWidget = Text(
                      "${item['amount'] ?? 0} ج.م",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    );
                  } else if (collectionKey == 'sales' ||
                      collectionKey == 'purchases') {
                    var expand = item['expand'];
                    String secondParty = "";
                    if (collectionKey == 'sales') {
                      var c = expand?['client'];
                      secondParty = (c is List && c.isNotEmpty)
                          ? c[0]['name'] ?? 'عميل نقدي'
                          : (c is Map ? c['name'] ?? 'عميل نقدي' : 'عميل نقدي');
                    } else {
                      var s = expand?['supplier'];
                      secondParty = (s is List && s.isNotEmpty)
                          ? s[0]['name'] ?? 'مورد غير معروف'
                          : (s is Map
                                ? s['name'] ?? 'مورد غير معروف'
                                : 'مورد غير معروف');
                    }
                    subtitleWidget = Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          secondParty,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _showDetails(item, collectionKey),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, color: iconColor),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (subtitleWidget != null) subtitleWidget,
                                  const SizedBox(height: 5),
                                  if (collectionKey != 'expenses')
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 12,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (collectionKey == 'sales' ||
                                      collectionKey == 'purchases')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        "${intl.NumberFormat('#,##0').format(item['netAmount'] ?? item['totalAmount'] ?? 0)} ج.م",
                                        style: TextStyle(
                                          color: highlightColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                if (trailingWidget != null) ...[
                                  trailingWidget,
                                  const SizedBox(height: 5),
                                ],
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.restore,
                                        color: Colors.green,
                                      ),
                                      onPressed: () =>
                                          _restore(collectionKey, item['id']),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: "استرجاع",
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deleteForever(
                                        collectionKey,
                                        item['id'],
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: "حذف نهائي",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
