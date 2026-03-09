import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../purchases/controllers/purchases_controller.dart';
import '../../../../core/network/pb_helper_provider.dart';
import 'package:al_sakr/models/transaction_item_model.dart';

class SupplierDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> supplier;
  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _loading = true;
  String _typeFilter = "الكل";
  DateTimeRange? _dateRange;
  double _currentVisibleBalance = 0.0;

  bool _canAddPayment = false;
  bool _canManagePayments = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadDetails();
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canAddPayment = true;
          _canManagePayments = true;
        });
      return;
    }

    try {
      final userRecord = await globalPb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAddPayment =
              (userRecord.data['allow_add_clients'] ?? false) ||
              (userRecord.data['allow_add_orders'] ?? false);
          _canManagePayments =
              (userRecord.data['allow_delete_clients'] ?? false);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadDetails() async {
    setState(() => _loading = true);

    final sales = await ref
        .read(purchasesControllerProvider.notifier)
        .getPurchasesBySupplier(widget.supplier['id']);
    final receipts = await ref
        .read(purchasesControllerProvider.notifier)
        .getPaymentsBySupplier(widget.supplier['id']);
    final returns = await ref
        .read(purchasesControllerProvider.notifier)
        .getReturnsBySupplier(widget.supplier['id']);
    final openingBal = await ref
        .read(purchasesControllerProvider.notifier)
        .getSupplierOpeningBalance(widget.supplier['id']);

    List<Map<String, dynamic>> temp = [];

    for (var s in sales) {
      temp.add({
        'id': s['id'],
        'date': s['date'],
        'type': 'فاتورة مشتريات',
        'amount': ((s['netAmount'] ?? s['totalAmount']) as num? ?? 0)
            .toDouble(),
        'isDebit': true, // عليه
        'category': 'فواتير',
        'rawDate': DateTime.parse(s['date']),
        'rawRecord': s,
      });
    }
    for (var r in receipts) {
      temp.add({
        'id': r['id'],
        'date': r['date'],
        'type': 'سند صرف',
        'amount': (r['amount'] as num? ?? 0).toDouble(),
        'isDebit': false, // له (سداد)
        'category': 'دفعات',
        'rawDate': DateTime.parse(r['date']),
        'note': r['notes'],
        'rawRecord': r,
      });
    }
    for (var rt in returns) {
      temp.add({
        'id': rt['id'],
        'date': rt['date'],
        'type': 'مرتجع مشتريات',
        'amount': (rt['totalAmount'] as num? ?? 0).toDouble(),
        'isDebit': false, // له (بينقص من الدين)
        'category': 'مرتجعات',
        'rawDate': DateTime.parse(rt['date']),
        'rawRecord': rt,
      });
    }

    temp.sort((a, b) => (a['rawDate'] as DateTime).compareTo(b['rawDate']));

    List<Map<String, dynamic>> calculatedList = [];
    double runningBalance = openingBal;

    for (var t in temp) {
      if (t['isDebit'])
        runningBalance += t['amount'];
      else
        runningBalance -= t['amount'];
      t['runningBalance'] = runningBalance;
      calculatedList.add(t);
    }

    _applyFilters(calculatedList, openingBal);
  }

  void _applyFilters(
    List<Map<String, dynamic>> fullList,
    double initialOpening,
  ) {
    List<Map<String, dynamic>> result = [];
    double startBalance = initialOpening;

    if (_dateRange != null) {
      final beforeRange = fullList
          .where((t) => (t['rawDate'] as DateTime).isBefore(_dateRange!.start))
          .toList();
      if (beforeRange.isNotEmpty)
        startBalance = beforeRange.last['runningBalance'];
      result = fullList.where((t) {
        final d = t['rawDate'] as DateTime;
        return d.isAfter(
              _dateRange!.start.subtract(const Duration(seconds: 1)),
            ) &&
            d.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    } else {
      result = fullList;
    }

    List<Map<String, dynamic>> finalDisplay = [];
    finalDisplay.add({
      'type': _dateRange == null ? 'رصيد افتتاحي' : 'رصيد سابق',
      'amount': startBalance.abs(),
      'isDebit': startBalance >= 0,
      'runningBalance': startBalance,
      'isHeader': true,
      'date': '---',
      'category': 'الكل',
    });

    finalDisplay.addAll(result);

    if (_typeFilter != "الكل") {
      finalDisplay = finalDisplay
          .where((t) => t['category'] == _typeFilter || t['isHeader'] == true)
          .toList();
    }

    if (mounted) {
      setState(() {
        _allTransactions = fullList;
        _filteredTransactions = finalDisplay;
        _currentVisibleBalance = fullList.isNotEmpty
            ? fullList.last['runningBalance']
            : startBalance;
        _loading = false;
      });
    }
  }

  // ✅ دالة التعديل التي كانت ناقصة (تمت إضافتها بالكامل)
  void _showEditPaymentDialog(Map<String, dynamic> rawRecord) {
    final amountCtrl = TextEditingController(
      text: rawRecord['amount'].toString(),
    );
    final notesCtrl = TextEditingController(
      text: rawRecord['notes'] ?? rawRecord['note'],
    );
    String paymentMethod = rawRecord['method'] ?? 'cash';
    DateTime selectedDate = DateTime.parse(rawRecord['date']);
    double oldAmount = (rawRecord['amount'] as num? ?? 0).toDouble();

    String? currentServerImage =
        rawRecord['receiptImage'] != null &&
            rawRecord['receiptImage'].toString().isNotEmpty
        ? rawRecord['receiptImage']
        : null;
    String? newLocalImagePath;
    bool deleteImage = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txt = isDark ? Colors.white : Colors.black;
    final border = isDark ? Colors.grey[600]! : Colors.grey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: bg,
          title: Text("تعديل السند", style: TextStyle(color: txt)),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: "المبلغ",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: isDark ? Colors.grey : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    dropdownColor: isDark
                        ? const Color(0xFF333333)
                        : Colors.white,
                    decoration: InputDecoration(
                      labelText: "طريقة الدفع",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "cash",
                        child: Text(
                          "نـقـدي (Cash)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "cheque",
                        child: Text(
                          "شـيـك (Cheque)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "bank_transfer",
                        child: Text(
                          "تحويل (Transfer)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                    ],
                    onChanged: (v) => setStateDialog(() => paymentMethod = v!),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? const ColorScheme.dark(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF424242),
                                    onSurface: Colors.white,
                                  )
                                : const ColorScheme.light(primary: Colors.blue),
                            dialogTheme: DialogThemeData(
                              backgroundColor: isDark
                                  ? const Color(0xFF424242)
                                  : Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (d != null) setStateDialog(() => selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "التاريخ",
                        labelStyle: TextStyle(
                          color: isDark ? Colors.grey : null,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: border),
                        ),
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: isDark ? Colors.grey : null,
                        ),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: TextStyle(color: txt),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        setStateDialog(() {
                          newLocalImagePath = image.path;
                          deleteImage = false;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: isDark ? Colors.grey : Colors.blueGrey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              newLocalImagePath != null
                                  ? "تم اختيار صورة جديدة ✅"
                                  : (currentServerImage != null && !deleteImage
                                        ? "يوجد صورة حالية (اضغط للتغيير)"
                                        : "إرفاق صورة (اختياري)"),
                              style: TextStyle(
                                color: newLocalImagePath != null
                                    ? Colors.green
                                    : (isDark ? Colors.grey : Colors.black54),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (newLocalImagePath != null ||
                              (currentServerImage != null && !deleteImage))
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setStateDialog(() {
                                  newLocalImagePath = null;
                                  if (currentServerImage != null)
                                    deleteImage = true;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: "ملاحظات",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      prefixIcon: Icon(
                        Icons.note,
                        color: isDark ? Colors.grey : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                double newAmount = double.tryParse(amountCtrl.text) ?? 0;
                if (newAmount <= 0) return;

                try {
                  Map<String, dynamic> body = {
                    'amount': newAmount,
                    'notes': notesCtrl.text,
                    'method': paymentMethod,
                    'date': selectedDate.toIso8601String(),
                  };
                  if (deleteImage && newLocalImagePath == null) {
                    body['receiptImage'] = null;
                  }

                  if (newLocalImagePath != null) {
                    await globalPb
                        .collection('supplier_payments')
                        .update(
                          rawRecord['id'],
                          body: body,
                          files: [
                            await http.MultipartFile.fromPath(
                              'receiptImage',
                              newLocalImagePath!,
                            ),
                          ],
                        );
                  } else {
                    await globalPb
                        .collection('supplier_payments')
                        .update(rawRecord['id'], body: body);
                  }

                  // تحديث رصيد العميل بالفرق
                  // سند صرف زاد -> الدين يقل
                  // Balance = OldBalance - (NewAmount - OldAmount)
                  double diff = newAmount - oldAmount;
                  final suppRec = await globalPb
                      .collection('suppliers')
                      .getOne(widget.supplier['id']);
                  double currentBal = (suppRec.data['balance'] ?? 0).toDouble();

                  await globalPb
                      .collection('suppliers')
                      .update(
                        widget.supplier['id'],
                        body: {'balance': currentBal - diff},
                      );

                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadDetails();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم التعديل بنجاح ✅"),
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
              child: const Text("حفظ التعديلات"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePayment(String receiptId, double amount) async {
    try {
      await globalPb.collection('supplier_payments').delete(receiptId);
      final suppRec = await globalPb
          .collection('suppliers')
          .getOne(widget.supplier['id']);
      double currentBal = (suppRec.data['balance'] ?? 0).toDouble();
      // حذف سند صرف -> الدين يرجع يزيد
      await globalPb
          .collection('suppliers')
          .update(
            widget.supplier['id'],
            body: {'balance': currentBal + amount},
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حذف السند وتحديث الرصيد"),
            backgroundColor: Colors.red,
          ),
        );
        _loadDetails();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  void _showImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenericDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['type']),
        content: Text(
          "المبلغ: ${item['amount']}\nالتاريخ: ${item['date'].toString().split(' ')[0]}",
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _loadDetails();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.supplier['name']),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _dateRange != null ? Colors.orange : null,
            ),
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _dateRange = null;
                  _loadDetails();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.blue[50],
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 2000),
                child: Column(
                  children: [
                    Text(
                      _dateRange != null
                          ? "الرصيد في نهاية الفترة"
                          : "الرصيد الحالي",
                      style: TextStyle(color: subText),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "${_currentVisibleBalance.abs().toStringAsFixed(1)} ج.م",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _currentVisibleBalance > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    Text(
                      _currentVisibleBalance > 0 ? "عليه (لنا)" : "له (مقدم)",
                      style: TextStyle(color: subText),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: ["الكل", "فواتير", "دفعات", "مرتجعات"].map((
                          filter,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _typeFilter == filter,
                              onSelected: (val) {
                                setState(() {
                                  _typeFilter = filter;
                                  _loadDetails();
                                });
                              },
                              selectedColor: Colors.blue[800],
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_dateRange != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: Text(
                "عرض الفترة من: ${DateFormat('yyyy-MM-dd').format(_dateRange!.start)} إلى: ${DateFormat('yyyy-MM-dd').format(_dateRange!.end)}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 10, bottom: 150),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (ctx, i) {
                      final item = _filteredTransactions[i];
                      bool isDebit = item['isDebit'];
                      bool isHeader = item['isHeader'] == true;
                      bool isPayment = item['category'] == 'دفعات';

                      String? imageUrl;
                      if (isPayment) {
                        final raw = item['rawRecord'];
                        if (raw['receiptImage'] != null &&
                            raw['receiptImage'].toString().isNotEmpty) {
                          imageUrl =
                              "${globalPb.baseUrl}/api/files/${raw['collectionId']}/${raw['id']}/${raw['receiptImage']}";
                        }
                      }

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 2000),
                          child: Card(
                            color: isHeader
                                ? (isDark ? Colors.grey[900] : Colors.grey[200])
                                : cardColor,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            elevation: isHeader ? 0 : 2,
                            child:
                                isHeader ||
                                    (!item['category'].contains('فواتير') &&
                                        !item['category'].contains('مرتجعات'))
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (imageUrl != null) {
                                              _showImage(imageUrl);
                                            } else if (!isHeader) {
                                              _showGenericDetails(item);
                                            }
                                          },
                                          child: Stack(
                                            children: [
                                              Icon(
                                                isHeader
                                                    ? Icons.account_balance
                                                    : (isDebit
                                                          ? Icons.arrow_upward
                                                          : Icons
                                                                .arrow_downward),
                                                size: 30,
                                                color: isHeader
                                                    ? subText
                                                    : (isDebit
                                                          ? Colors.blue
                                                          : Colors.green),
                                              ),
                                              if (imageUrl != null)
                                                const Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Icon(
                                                    Icons.image,
                                                    size: 14,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (imageUrl != null) {
                                                _showImage(imageUrl);
                                              } else if (!isHeader) {
                                                _showGenericDetails(item);
                                              }
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['type'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: textColor,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  isHeader
                                                      ? "---"
                                                      : "${item['date'].toString().split(' ')[0]} ${item['note'] != null ? '(${item['note']})' : ''}",
                                                  style: TextStyle(
                                                    color: subText,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "${item['amount'].toStringAsFixed(1)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isHeader
                                                    ? textColor
                                                    : (isDebit
                                                          ? Colors.blue
                                                          : Colors.green),
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              "رصيد: ${item['runningBalance'].toStringAsFixed(1)}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: subText,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // ✅✅ هنا تظهر النقاط الثلاث للتعديل والحذف بالنسبة للدفعات فقط
                                        if (isPayment &&
                                            _canManagePayments &&
                                            !isHeader) ...[
                                          const SizedBox(width: 5),
                                          SizedBox(
                                            width: 30,
                                            child: PopupMenuButton<String>(
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                Icons.more_vert,
                                                color: subText,
                                              ),
                                              onSelected: (val) {
                                                if (val == 'edit') {
                                                  _showEditPaymentDialog(
                                                    item['rawRecord'],
                                                  );
                                                } else if (val == 'delete') {
                                                  showDialog(
                                                    context: context,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text(
                                                        "حذف السند",
                                                      ),
                                                      content: const Text(
                                                        "هل أنت متأكد؟ سيتم إعادة المديونية للعميل.",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(c),
                                                          child: const Text(
                                                            "إلغاء",
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                              ),
                                                          onPressed: () {
                                                            Navigator.pop(c);
                                                            _deletePayment(
                                                              item['id'],
                                                              (item['amount']
                                                                      as num)
                                                                  .toDouble(),
                                                            );
                                                          },
                                                          child: const Text(
                                                            "حذف",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit,
                                                        color: Colors.blue,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text("تعديل"),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text("حذف"),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else if (!isHeader) ...[
                                          const SizedBox(
                                            width: 35,
                                          ), // مسافة فارغة للحفاظ على المحاذاة
                                        ],
                                      ],
                                    ),
                                  )
                                : ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    leading: Icon(
                                      isDebit
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: isDebit
                                          ? Colors.blue
                                          : Colors.green,
                                      size: 30,
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['type'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                "${item['date'].toString().split(' ')[0]}",
                                                style: TextStyle(
                                                  color: subText,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "${item['amount'].toStringAsFixed(1)}",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDebit
                                                    ? Colors.blue
                                                    : Colors.green,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              "رصيد: ${item['runningBalance'].toStringAsFixed(1)}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: subText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        color: isDark
                                            ? Colors.black26
                                            : Colors.white,
                                        child: Column(
                                          children: [
                                            if (item['category'] ==
                                                'فواتير') ...[
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      "الإجمالي الكلي",
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${((item['rawRecord']?['totalAmount'] ?? 0) as num).toDouble().toStringAsFixed(1)} ج.م",
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (((item['rawRecord']?['discount'] ??
                                                              0)
                                                          as num)
                                                      .toDouble() >
                                                  0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 2,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        "الخصم",
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        "-${((item['rawRecord']?['discount'] ?? 0) as num).toDouble().toStringAsFixed(1)} ج.م",
                                                        style: const TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (((item['rawRecord']?['taxAmount'] ??
                                                              0)
                                                          as num)
                                                      .toDouble() >
                                                  0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 2,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        "الضريبة",
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        "+${((item['rawRecord']?['taxAmount'] ?? 0) as num).toDouble().toStringAsFixed(1)} ج.م",
                                                        style: const TextStyle(
                                                          color: Colors.orange,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              const Divider(),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      "الصافي النهائي",
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      "${item['amount'].toStringAsFixed(1)} ج.م",
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.tealAccent
                                                            : Colors.teal,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showItemsBottomSheet(
                                                        item['rawRecord'],
                                                        true,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.list,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    "عرض قائمة الأصناف والتفاصيل",
                                                  ),
                                                ),
                                              ),
                                            ] else if (item['category'] ==
                                                'مرتجعات') ...[
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showItemsBottomSheet(
                                                        item['rawRecord'],
                                                        false,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.list,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    "عرض قائمة الأصناف والمرتجعات",
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _canAddPayment
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 10),
              child: FloatingActionButton.extended(
                onPressed: () => _showAddPaymentDialog(context),
                label: const Text(
                  "تسجيل دفعة",
                  style: TextStyle(color: Colors.white),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                backgroundColor: Colors.brown,
              ),
            )
          : null,
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = "cash";
    String? selectedImagePath;
    DateTime selectedDate = DateTime.now();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final txt = isDark ? Colors.white : Colors.black;
    final border = isDark ? Colors.grey[600]! : Colors.grey;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: bg,
          title: Text("تسجيل دفعة جديدة", style: TextStyle(color: txt)),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: "المبلغ",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: isDark ? Colors.grey : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    dropdownColor: isDark
                        ? const Color(0xFF333333)
                        : Colors.white,
                    decoration: InputDecoration(
                      labelText: "طريقة الدفع",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "cash",
                        child: Text(
                          "نـقـدي (Cash)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "cheque",
                        child: Text(
                          "شـيـك (Cheque)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                      DropdownMenuItem(
                        value: "bank_transfer",
                        child: Text(
                          "تحويل بنكي (Transfer)",
                          style: TextStyle(color: txt),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setStateDialog(() => paymentMethod = val!),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (c, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: isDark
                                ? const ColorScheme.dark(
                                    primary: Colors.brown,
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF424242),
                                    onSurface: Colors.white,
                                  )
                                : const ColorScheme.light(
                                    primary: Colors.brown,
                                  ),
                            dialogTheme: DialogThemeData(
                              backgroundColor: isDark
                                  ? const Color(0xFF424242)
                                  : Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (d != null) setStateDialog(() => selectedDate = d);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "التاريخ",
                        labelStyle: TextStyle(
                          color: isDark ? Colors.grey : null,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: border),
                        ),
                        prefixIcon: Icon(
                          Icons.calendar_today,
                          color: isDark ? Colors.grey : null,
                        ),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: TextStyle(color: txt),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null)
                        setStateDialog(() => selectedImagePath = image.path);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: isDark ? Colors.grey : Colors.blueGrey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedImagePath != null
                                  ? "تم اختيار صورة ✅"
                                  : "إرفاق صورة التحويل (اختياري)",
                              style: TextStyle(
                                color: selectedImagePath != null
                                    ? Colors.green
                                    : (isDark ? Colors.grey : Colors.black54),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedImagePath != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setStateDialog(
                                () => selectedImagePath = null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: notesCtrl,
                    style: TextStyle(color: txt),
                    decoration: InputDecoration(
                      labelText: "ملاحظات / رقم الشيك",
                      labelStyle: TextStyle(color: isDark ? Colors.grey : null),
                      prefixIcon: Icon(
                        Icons.note,
                        color: isDark ? Colors.grey : null,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                double? amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount == 0) return;
                try {
                  await ref
                      .read(purchasesControllerProvider.notifier)
                      .addSupplierPayment(
                        supplierId: widget.supplier['id'],
                        amount: amount,
                        notes: notesCtrl.text,
                        date: selectedDate.toIso8601String(),
                        paymentMethod: paymentMethod,
                        imagePath: selectedImagePath,
                      );
                  Navigator.pop(ctx);
                  _loadDetails();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم تسجيل الدفعة"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 📋 عرض التفاصيل في الأسفل (Bottom Sheet)
  // ============================================================
  void _showItemsBottomSheet(Map<String, dynamic> record, bool isInvoice) {
    double total = (record['totalAmount'] ?? 0).toDouble();
    double discount = (record['discount'] ?? 0).toDouble();
    double tax = (record['taxAmount'] ?? 0).toDouble();
    double wht = (record['whtAmount'] ?? 0).toDouble();
    double net = isInvoice
        ? (record['netAmount'] ?? record['totalAmount'] ?? 0).toDouble()
        : total - discount; // Returns might not have tax/wht stored similarly

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Text(
                  isInvoice ? "تفاصيل الفاتورة" : "تفاصيل المرتجع",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              FutureBuilder<List<TransactionItemModel>>(
                future: isInvoice
                    ? ref
                          .read(purchasesControllerProvider.notifier)
                          .getPurchaseItems(record['id'])
                    : ref
                          .read(purchasesControllerProvider.notifier)
                          .getPurchaseReturnItems(record['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(child: Text("خطأ: ${snapshot.error}")),
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text("لا توجد أصناف")),
                    );
                  }
                  return Column(
                    children: items.map((item) {
                      final qty = item.quantity.toDouble();
                      final price = item.price;
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text(
                          "${qty.toInt()} x ${price.toStringAsFixed(1)}",
                        ),
                        trailing: Text(
                          "${(qty * price).toStringAsFixed(1)} ج.م",
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(),
              _buildSummaryRow("الإجمالي", total),
              if (discount > 0)
                _buildSummaryRow("الخصم", -discount, color: Colors.red),
              if (isInvoice && tax > 0)
                _buildSummaryRow("ضريبة (14%)", tax, color: Colors.orange),
              if (isInvoice && wht > 0)
                _buildSummaryRow("خصم منبع (1%)", -wht, color: Colors.purple),
              const Divider(),
              _buildSummaryRow(
                "الصافي النهائي",
                net,
                isBold: true,
                scale: 1.2,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double val, {
    Color? color,
    bool isBold = false,
    double scale = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 14 * scale,
            ),
          ),
          Text(
            "${val.toStringAsFixed(2)} ج.م",
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 14 * scale,
            ),
          ),
        ],
      ),
    );
  }
}
