import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:al_sakr/pdf/PdfService.dart';
import 'package:al_sakr/pdf/pdf_preview_screen.dart';
import 'package:al_sakr/features/store/presentations/product_search_dialog.dart';
import 'dart:async';

// ✅ Enum لنوع الفلتر
enum OrderFilter { monthly, yearly }

class DeliveryOrdersScreen extends ConsumerStatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  ConsumerState<DeliveryOrdersScreen> createState() =>
      _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends ConsumerState<DeliveryOrdersScreen> {
  // ✅ متغيرات الفلتر
  OrderFilter _filterType = OrderFilter.monthly;
  DateTime _selectedDate = DateTime.now();

  List<dynamic> _allOrdersFlat = [];
  Map<String, List<dynamic>> _groupedOrders = {};

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _products = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  bool _canAdd = false;
  bool _canDelete = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted)
        setState(() {
          _canAdd = true;
          _canDelete = true;
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
          _canAdd =
              u['allow_add_delivery'] == 1 || u['allow_add_delivery'] == true;
          _canDelete =
              u['allow_delete_delivery'] == 1 ||
              u['allow_delete_delivery'] == true;
        });
      }
    } catch (e) {
      //
    }
  }

  // ✅ تغيير التاريخ
  void _changeDate(int offset) {
    setState(() {
      if (_filterType == OrderFilter.monthly) {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + offset,
          1,
        );
      } else {
        _selectedDate = DateTime(_selectedDate.year + offset, 1, 1);
      }
      _isLoading = true;
    });
    _loadData();
  }

  // ✅ تحميل البيانات مع الفلتر
  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    try {
      // 1. تحديد بداية ونهاية الفترة
      DateTime startDate, endDate;
      if (_filterType == OrderFilter.monthly) {
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
          23,
          59,
          59,
        );
      } else {
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
      }

      // 2. جلب الكل ثم الفلترة محلياً
      final rawOrders = await ref
          .read(salesControllerProvider.notifier)
          .getAllDeliveryOrders();

      // فلترة القائمة حسب التاريخ المختار
      final filteredOrders = rawOrders.where((order) {
        if (order['is_deleted'] == true) return false;
        if (order['date'] == null) return false;
        DateTime orderDate = DateTime.parse(order['date']);
        return orderDate.isAfter(
              startDate.subtract(const Duration(seconds: 1)),
            ) &&
            orderDate.isBefore(endDate.add(const Duration(seconds: 1)));
      }).toList();

      // تحميل البيانات المساعدة (عملاء ومنتجات) من قاعدة البيانات المحلية
      if (_clients.isEmpty || _products.isEmpty) {
        try {
          if (_clients.isEmpty) {
            final db = await ref.read(localDatabaseProvider.future);
            final clientRows = await db.query(
              'clients',
              where: 'is_deleted = ? OR is_deleted IS NULL',
              whereArgs: [0],
              orderBy: 'name ASC',
            );
            _clients = clientRows
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
          }

          if (_products.isEmpty) {
            final db = await ref.read(localDatabaseProvider.future);
            final productRows = await db.query(
              'products',
              where: 'is_deleted = ? OR is_deleted IS NULL',
              whereArgs: [0],
              orderBy: 'created DESC',
            );
            List<Map<String, dynamic>> tempProducts = [];
            for (var r in productRows) {
              var data = Map<String, dynamic>.from(r);
              // Try to get supplier name from local DB
              if (data['supplier'] != null &&
                  data['supplier'].toString().isNotEmpty) {
                try {
                  final suppRow = await db.query(
                    'suppliers',
                    columns: ['name'],
                    where: '${DbConstants.colId} = ?',
                    whereArgs: [data['supplier']],
                    limit: 1,
                  );
                  if (suppRow.isNotEmpty)
                    data['supplierName'] = suppRow.first['name'];
                } catch (_) {}
              }
              tempProducts.add(data);
            }
            _products = tempProducts;
          }

          if (mounted) setState(() {});
        } catch (e) {
          // تجاهل - البيانات المساعدة ستكون فارغة في وضع أوفلاين
        }
      }

      List<dynamic> enrichedOrders = [];

      // معالجة البيانات (تجميع أرقام أوامر التوريد)
      for (var order in filteredOrders) {
        List<dynamic> items = [];
        try {
          items = await ref
              .read(salesControllerProvider.notifier)
              .getDeliveryOrderItems(order['id']);
        } catch (_) {}
        Set<String> allNumbers = {};

        if (order['supplyOrderNumber'] != null &&
            order['supplyOrderNumber'].toString().isNotEmpty) {
          allNumbers.add(order['supplyOrderNumber'].toString());
        }

        for (var item in items) {
          if (item['relatedSupplyOrder'] != null &&
              item['relatedSupplyOrder'].toString().isNotEmpty) {
            allNumbers.add(item['relatedSupplyOrder'].toString());
          }
        }

        Map<String, dynamic> newOrder = Map.from(order);
        newOrder['displaySupplyOrders'] = allNumbers.join(' - ');

        // ✅ ضمان جلب اسم العميل من قائمة العملاء المحلية لو كان مفقوداً
        if ((newOrder['clientName'] == null ||
                newOrder['clientName'].toString().isEmpty) &&
            newOrder['client'] != null) {
          try {
            final c = _clients.firstWhere(
              (element) => element['id'] == newOrder['client'],
            );
            newOrder['clientName'] = c['name'];
          } catch (_) {
            newOrder['clientName'] = 'عميل غير معروف';
          }
        } else if (newOrder['clientName'] == null) {
          newOrder['clientName'] = 'عميل غير معروف';
        }

        enrichedOrders.add(newOrder);
      }

      // ترتيب تنازلي حسب تاريخ الإنشاء
      enrichedOrders.sort((a, b) {
        String dateA = a['created'] ?? '';
        String dateB = b['created'] ?? '';
        return dateB.compareTo(dateA);
      });

      _allOrdersFlat = enrichedOrders;
      _groupOrders(_allOrdersFlat);
    } catch (e) {
      // في وضع أوفلاين - عرض رسالة بسيطة بدل الكراش
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ لا يوجد اتصال - يتم عرض البيانات المحفوظة'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _groupOrders(List<dynamic> ordersList) {
    Map<String, List<dynamic>> tempGrouped = {};

    for (var order in ordersList) {
      String clientName = order['clientName'] ?? 'عميل غير معروف';
      if (!tempGrouped.containsKey(clientName)) {
        tempGrouped[clientName] = [];
      }
      tempGrouped[clientName]!.add(order);
    }

    if (mounted) {
      setState(() {
        _groupedOrders = tempGrouped;
      });
    }
  }

  void _filterOrders(String query) {
    if (query.isEmpty) {
      _groupOrders(_allOrdersFlat);
      return;
    }

    final filtered = _allOrdersFlat.where((order) {
      final client = (order['clientName'] ?? '').toString().toLowerCase();
      final manualNo = order['manualNo']?.toString().toLowerCase() ?? '';
      final allSupplyNums =
          order['displaySupplyOrders']?.toString().toLowerCase() ?? '';
      final q = query.toLowerCase();
      return client.contains(q) ||
          manualNo.contains(q) ||
          allSupplyNums.contains(q);
    }).toList();

    _groupOrders(filtered);
  }

  String _formatDateForSerial(DateTime date) {
    String day = date.day.toString().padLeft(2, '0');
    String month = date.month.toString().padLeft(2, '0');
    String year = date.year.toString();
    return "$day$month$year";
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

  // --- دوال الديالوج والعمليات (كما هي تماماً) ---

  void _showOrderDialog({
    Map<String, dynamic>? existingOrder,
    List<dynamic>? existingItems,
  }) {
    if (existingOrder == null && !_canAdd) return;
    if (existingOrder != null && !_canAdd) return;

    final isEditing = existingOrder != null;
    DateTime selectedDate = isEditing && existingOrder['date'] != null
        ? DateTime.parse(existingOrder['date'])
        : DateTime.now();
    String initialManualNo = isEditing
        ? (existingOrder['manualNo'] ?? '')
        : _formatDateForSerial(selectedDate);

    final manualNoController = TextEditingController(text: initialManualNo);
    final addressController = TextEditingController(
      text: isEditing ? existingOrder['address'] : '',
    );
    final notesController = TextEditingController(
      text: isEditing ? existingOrder['notes'] : '',
    );
    final supplyOrderNumber = TextEditingController(
      text: isEditing ? existingOrder['supplyOrderNumber'] : '',
    );

    String? selectedClientId;
    if (isEditing) {
      selectedClientId = existingOrder['client'];
      if (selectedClientId == null && existingOrder['clientName'] != null) {
        try {
          final c = _clients.firstWhere(
            (c) => c['name'] == existingOrder['clientName'],
          );
          selectedClientId = c['id'];
        } catch (e) {}
      }
    }

    List<dynamic> tempItems = isEditing ? List.from(existingItems!) : [];
    Set<String> sectionsSet = {''};
    if (isEditing) {
      for (var item in tempItems) {
        if (item['relatedSupplyOrder'] != null &&
            item['relatedSupplyOrder'].toString().isNotEmpty) {
          sectionsSet.add(item['relatedSupplyOrder']);
        }
      }
    }
    List<String> activeSections = sectionsSet.toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          bool isDark = Theme.of(context).brightness == Brightness.dark;
          Color cardColor = isDark ? Colors.grey[850]! : Colors.white;
          Color mainHeaderColor = isDark
              ? Colors.blue.withOpacity(0.2)
              : Colors.blue[50]!;
          Color subHeaderColor = isDark
              ? Colors.orange.withOpacity(0.2)
              : Colors.orange[50]!;
          Color textColor = isDark ? Colors.white : Colors.black87;

          void addItemToSection(String sectionOrderNumber) {
            String? prodName;
            String? prodId;
            String? prodUnit;
            final nameController = TextEditingController();
            final qtyCtrl = TextEditingController(text: '1');
            final descCtrl = TextEditingController();

            showDialog(
              context: context,
              builder: (innerCtx) => AlertDialog(
                title: Text(
                  sectionOrderNumber.isEmpty
                      ? 'إضافة صنف'
                      : 'إضافة لـ ($sectionOrderNumber)',
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 2000),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: "اختر الصنف",
                              hintText: "اضغط للبحث...",
                              suffixIcon: Icon(Icons.arrow_drop_down),
                              border: OutlineInputBorder(),
                            ),
                            onTap: () async {
                              final selectedProduct =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (ctx) => ProductSearchDialog(
                                      allProducts: _products,
                                    ),
                                  );
                              if (selectedProduct != null) {
                                prodName = selectedProduct['name'];
                                prodId = selectedProduct['id'];
                                prodUnit = selectedProduct['unit'];
                                nameController.text = prodName!;
                                descCtrl.text = "${selectedProduct['name']} ";
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'العدد',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: descCtrl,
                            minLines: 1,
                            maxLines: 10,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              labelText: 'الوصف',
                              hintText: 'اكتب كل سيريال في سطر جديد...',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(innerCtx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (prodName != null) {
                        setStateSB(() {
                          tempItems.add({
                            'productId': prodId,
                            'productName': prodName,
                            'quantity': int.tryParse(qtyCtrl.text) ?? 1,
                            'unit': prodUnit ?? 'قطعة',
                            'description': descCtrl.text,
                            'relatedSupplyOrder': sectionOrderNumber.isEmpty
                                ? null
                                : sectionOrderNumber,
                          });
                        });
                        Navigator.pop(innerCtx);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('برجاء اختيار صنف')),
                        );
                      }
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            );
          }

          void addSection() {
            final sectionCtrl = TextEditingController();
            showDialog(
              context: context,
              builder: (innerCtx) => AlertDialog(
                title: const Text('إضافة أمر توريد فرعي'),
                content: TextField(
                  controller: sectionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الأمر',
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(innerCtx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (sectionCtrl.text.isNotEmpty &&
                          !activeSections.contains(sectionCtrl.text)) {
                        setStateSB(() => activeSections.add(sectionCtrl.text));
                        Navigator.pop(innerCtx);
                      }
                    },
                    child: const Text('إضافة'),
                  ),
                ],
              ),
            );
          }

          void deleteSection(String sectionName) {
            setStateSB(() {
              activeSections.remove(sectionName);
              tempItems.removeWhere(
                (item) => (item['relatedSupplyOrder'] ?? '') == sectionName,
              );
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: 2000,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                children: [
                  Text(
                    isEditing ? 'تعديل الإذن' : 'إذن تسليم جديد',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedClientId,
                            decoration: const InputDecoration(
                              labelText: 'العميل',
                              border: OutlineInputBorder(),
                            ),
                            items: _clients
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'] as String,
                                    child: Text(c['name']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              selectedClientId = val;
                              final c = _clients.firstWhere(
                                (e) => e['id'] == val,
                              );
                              addressController.text = c['address'] ?? '';
                            },
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: manualNoController,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الإذن',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: supplyOrderNumber,
                                  decoration: const InputDecoration(
                                    labelText: 'أمر توريد رئيسي',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setStateSB(() {
                                  selectedDate = d;
                                  manualNoController.text =
                                      _formatDateForSerial(d);
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'تاريخ التسليم',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}",
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: addressController,
                            decoration: const InputDecoration(
                              labelText: 'العنوان',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "الأصناف",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: addSection,
                                icon: const Icon(Icons.add),
                                label: const Text("فرعي جديد"),
                              ),
                            ],
                          ),
                          ...activeSections.map((sectionName) {
                            List<dynamic> sectionItems = tempItems.where((
                              item,
                            ) {
                              String itemSection =
                                  item['relatedSupplyOrder'] ?? '';
                              return itemSection == sectionName;
                            }).toList();
                            bool isMain = sectionName.isEmpty;
                            String displayTitle = isMain
                                ? "عام / الرئيسي"
                                : "أمر توريد: $sectionName";
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: cardColor,
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMain
                                          ? mainHeaderColor
                                          : subHeaderColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          displayTitle,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle,
                                                color: Colors.green,
                                              ),
                                              onPressed: () =>
                                                  addItemToSection(sectionName),
                                            ),
                                            if (!isMain)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    deleteSection(sectionName),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (sectionItems.isNotEmpty)
                                    ...sectionItems.map((item) {
                                      final realIdx = tempItems.indexOf(item);
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          item['productName'],
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => setStateSB(
                                            () => tempItems.removeAt(realIdx),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                      const SizedBox(width: 10),
                      // زر المعاينة
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('معاينة'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(color: Colors.deepOrange),
                        ),
                        onPressed: () {
                          if (selectedClientId == null || tempItems.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'برجاء اختيار عميل وإضافة أصناف أولاً',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          final clientRow = _clients.firstWhere(
                            (c) => c['id'] == selectedClientId,
                            orElse: () => {'name': ''},
                          );
                          final tempOrder = {
                            'id': isEditing
                                ? existingOrder['id']
                                : 'preview_${DateTime.now().millisecondsSinceEpoch}',
                            'client': selectedClientId,
                            'clientName': clientRow['name'] ?? '',
                            'supplyOrderNumber': supplyOrderNumber.text,
                            'manualNo': manualNoController.text,
                            'address': addressController.text,
                            'date': selectedDate.toIso8601String(),
                            'notes': notesController.text,
                          };
                          final previewItems = tempItems
                              .cast<Map<String, dynamic>>()
                              .toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfPreviewScreen(
                                title: 'معاينة إذن التسليم',
                                generatePdf: (format) =>
                                    PdfService.generateDeliveryOrderBytes(
                                      tempOrder,
                                      previewItems,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: Icon(isEditing ? Icons.edit : Icons.save),
                        label: Text(isEditing ? 'تعديل وحفظ' : 'حفظ جديد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Future<void> submitOrder() async {
                            if (selectedClientId != null &&
                                supplyOrderNumber.text.isNotEmpty &&
                                tempItems.isNotEmpty) {
                              if (isEditing) {
                                await ref
                                    .read(salesControllerProvider.notifier)
                                    .updateDeliveryOrder(
                                      existingOrder['id'],
                                      selectedClientId!,
                                      supplyOrderNumber.text,
                                      manualNoController.text,
                                      addressController.text,
                                      selectedDate.toIso8601String(),
                                      notesController.text,
                                      tempItems.cast<Map<String, dynamic>>(),
                                    );
                              } else {
                                await ref
                                    .read(salesControllerProvider.notifier)
                                    .createDeliveryOrder(
                                      selectedClientId!,
                                      supplyOrderNumber.text,
                                      manualNoController.text,
                                      addressController.text,
                                      selectedDate.toIso8601String(),
                                      notesController.text,
                                      tempItems.cast<Map<String, dynamic>>(),
                                    );
                              }
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'تم التعديل بنجاح ✅'
                                        : 'تم الحفظ بنجاح ✅',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // ✅ تحديث قائمة العرض محلياً لتظهر الداتا فوراً
                              _loadData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('برجاء استكمال البيانات'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }

                          if (tempItems.length > 7) {
                            showDialog(
                              context: context,
                              builder: (alertCtx) => AlertDialog(
                                title: const Text("تنبيه: عدد الأصناف كبير"),
                                content: Text(
                                  "عدد الأصناف الحالي (${tempItems.length}) قد يتجاوز مساحة الصفحة الواحدة في ملف PDF.\n\nهل تريد المتابعة والحفظ؟",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(alertCtx),
                                    child: const Text("مراجعة"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(alertCtx);
                                      submitOrder();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                    ),
                                    child: const Text(
                                      "حفظ على أي حال",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            submitOrder();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _deleteOrder(String id, bool isLocked) {
    if (!_canDelete) return;

    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ هذا الإذن موقع ومقفل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف الإذن"),
        content: const Text(
          "هل تريد نقل هذا الإذن إلى سلة المهملات؟",
        ), // ✅ تغيير الرسالة
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // ✅ استدعاء دالة النقل للسلة بدلاً من الحذف النهائي
              await ref
                  .read(salesControllerProvider.notifier)
                  .softDeleteDeliveryOrder(id);

              // (ملاحظة: بما إنك عامل subscribe في initState، القائمة هتتحدث لوحدها وتخفي العنصر)
            },
            child: const Text("نقل للسلة", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleLock(String id, bool currentStatus) async {
    if (!_canAdd) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية التعديل')));
      return;
    }

    if (currentStatus) {
      await ref
          .read(salesControllerProvider.notifier)
          .toggleOrderLock(id, false);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("تأكيد القفل"),
          content: const Text("هل تريد إرفاق صورة الإذن الموقع من العميل؟"),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(salesControllerProvider.notifier)
                    .toggleOrderLock(id, true);
              },
              child: const Text("لا (قفل فقط)"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("نعم (إرفاق صورة)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  await ref
                      .read(salesControllerProvider.notifier)
                      .toggleOrderLock(
                        id,
                        true,
                        // imagePath: image.path,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم رفع الصورة وقفل الإذن ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      );
    }
  }

  void _manageImage(String orderId, String imagePath) {
    if (!_canAdd) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "خيارات صورة الإذن",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text("عرض الصورة"),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: Image.network(imagePath, fit: BoxFit.contain),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text("تغيير الصورة"),
              onTap: () async {
                Navigator.pop(ctx);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  await ref
                      .read(salesControllerProvider.notifier)
                      .updateOrderImage(orderId, image.path);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير الصورة بنجاح ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("حذف الصورة"),
              onTap: () async {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (alertCtx) => AlertDialog(
                    title: const Text("حذف الصورة"),
                    content: const Text("هل أنت متأكد من حذف صورة الإذن؟"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(alertCtx),
                        child: const Text("إلغاء"),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(salesControllerProvider.notifier)
                              .updateOrderImage(orderId, null);
                          Navigator.pop(alertCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف الصورة 🗑️'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: const Text(
                          "حذف",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-reload when the sales provider is invalidated (e.g. after sync)
    ref.listen(salesControllerProvider, (_, __) {
      _loadData(showLoading: false);
    });
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String filterTitle = _filterType == OrderFilter.monthly
        ? "${_getMonthName(_selectedDate.month)} ${_selectedDate.year}"
        : "${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('أذونات التسليم'),
        centerTitle: true,
        actions: [
          // ✅ زر رفع الأوفلاين (Sync)
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: 'مزامنة أوامر التسليم المحفوظة',
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await ref
                    .read(salesControllerProvider.notifier)
                    .syncOfflineDeliveryOrders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت المزامنة بنجاح ✅')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في المزامنة: $e ❌')),
                  );
                }
              }
              _loadData();
            },
          ),
          // ✅ زر اختيار الفلتر
          PopupMenuButton<OrderFilter>(
            icon: const Icon(Icons.filter_alt_outlined),
            onSelected: (OrderFilter result) {
              setState(() {
                _filterType = result;
                _selectedDate = DateTime.now();
                _isLoading = true;
              });
              _loadData();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: OrderFilter.monthly,
                child: Text('عرض شهري'),
              ),
              const PopupMenuItem(
                value: OrderFilter.yearly,
                child: Text('عرض سنوي'),
              ),
            ],
          ),
        ],
        // ✅ شريط التنقل (الأسهم)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: isDark ? const Color(0xFF2C2C2C) : Colors.blue[50],
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
                        _filterType == OrderFilter.monthly
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 2000),
                child: Column(
                  children: [
                    // شريط البحث
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'بحث (اسم العميل / رقم الإذن)...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterOrders('');
                            },
                          ),
                        ),
                        onChanged: _filterOrders,
                      ),
                    ),
                    Expanded(
                      child: _groupedOrders.isEmpty
                          ? const Center(
                              child: Text("لا توجد أذونات في هذه الفترة"),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                left: 10,
                                right: 10,
                                bottom: 100,
                              ),
                              itemCount: _groupedOrders.length,
                              itemBuilder: (context, index) {
                                String clientName = _groupedOrders.keys
                                    .elementAt(index);
                                List<dynamic> clientOrders =
                                    _groupedOrders[clientName]!;
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.blue.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: ExpansionTile(
                                    initiallyExpanded: true,
                                    shape: const Border(),
                                    title: Text(
                                      clientName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.blue[200]
                                            : Colors.blue[900],
                                      ),
                                    ),
                                    leading: const Icon(
                                      Icons.business,
                                      color: Colors.orange,
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.grey[850]
                                        : Colors.blue[50]?.withOpacity(0.3),
                                    childrenPadding: const EdgeInsets.all(5),
                                    children: clientOrders.map((order) {
                                      bool isLocked = order['isLocked'] == true;
                                      bool hasImage =
                                          order['signedImagePath'] != null &&
                                          order['signedImagePath']
                                              .toString()
                                              .isNotEmpty;
                                      Color tileColor = isLocked
                                          ? (isDark
                                                ? Colors.green.withOpacity(0.15)
                                                : Colors.green[50]!)
                                          : Theme.of(context).cardColor;
                                      return Card(
                                        elevation: 2,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                          left: 5,
                                          right: 5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        color: tileColor,
                                        child: ExpansionTile(
                                          leading: CircleAvatar(
                                            backgroundColor: isLocked
                                                ? Colors.green
                                                : Colors.blue,
                                            child: Icon(
                                              isLocked
                                                  ? Icons.check
                                                  : Icons.description,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Text(
                                                "رقم الإذن: ${order['manualNo'] ?? '---'}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (order['isOffline'] ==
                                                  true) ...[
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.cloud_off,
                                                  color: Colors.red,
                                                  size: 16,
                                                ),
                                              ],
                                            ],
                                          ),
                                          subtitle: Text(
                                            "أوامر توريد: ${order['displaySupplyOrders']}",
                                            style: TextStyle(
                                              color: isLocked
                                                  ? Colors.green
                                                  : Colors.blue,
                                              fontSize: 12,
                                            ),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                15.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "التاريخ: ${order['date'].toString().split(' ')[0]}",
                                                  ),
                                                  const Divider(),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Switch(
                                                            value: isLocked,
                                                            activeThumbColor:
                                                                Colors.green,
                                                            onChanged: (val) =>
                                                                _toggleLock(
                                                                  order['id'],
                                                                  isLocked,
                                                                ),
                                                          ),
                                                          Text(
                                                            isLocked
                                                                ? "مغلق"
                                                                : "تعديل",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: isLocked
                                                                  ? Colors.green
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                          if (hasImage)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    right: 8.0,
                                                                  ),
                                                              child: IconButton(
                                                                icon: const Icon(
                                                                  Icons.image,
                                                                  color: Colors
                                                                      .purple,
                                                                ),
                                                                tooltip:
                                                                    "عرض الصورة",
                                                                onPressed: () {
                                                                  if (isLocked) {
                                                                    showDialog(
                                                                      context:
                                                                          context,
                                                                      builder: (_) => Dialog(
                                                                        child: Image.network(
                                                                          order['signedImagePath'],
                                                                          fit: BoxFit
                                                                              .contain,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    _manageImage(
                                                                      order['id'],
                                                                      order['signedImagePath'],
                                                                    );
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          if (_canDelete)
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.delete,
                                                                color: isLocked
                                                                    ? Colors
                                                                          .grey
                                                                    : Colors
                                                                          .red,
                                                              ),
                                                              onPressed: () =>
                                                                  _deleteOrder(
                                                                    order['id'],
                                                                    isLocked,
                                                                  ),
                                                            ),
                                                          if (_canAdd)
                                                            IconButton(
                                                              icon: Icon(
                                                                Icons.edit,
                                                                color: isLocked
                                                                    ? Colors
                                                                          .grey
                                                                    : Colors
                                                                          .orange,
                                                              ),
                                                              onPressed:
                                                                  isLocked
                                                                  ? null
                                                                  : () async {
                                                                      List<
                                                                        Map<
                                                                          String,
                                                                          dynamic
                                                                        >
                                                                      >
                                                                      orderItems = await ref
                                                                          .read(
                                                                            salesControllerProvider.notifier,
                                                                          )
                                                                          .getDeliveryOrderItems(
                                                                            order['id'],
                                                                          );
                                                                      _showOrderDialog(
                                                                        existingOrder:
                                                                            order,
                                                                        existingItems:
                                                                            orderItems,
                                                                      );
                                                                    },
                                                            ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.print,
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                            onPressed: () async {
                                                              List<
                                                                Map<
                                                                  String,
                                                                  dynamic
                                                                >
                                                              >
                                                              orderItems = await ref
                                                                  .read(
                                                                    salesControllerProvider
                                                                        .notifier,
                                                                  )
                                                                  .getDeliveryOrderItems(
                                                                    order['id'],
                                                                  );
                                                              await PdfService.generateDeliveryOrderPdf(
                                                                order,
                                                                orderItems,
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: _canAdd
          ? FloatingActionButton(
              onPressed: () => _showOrderDialog(),
              backgroundColor: Colors.blue[800],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
