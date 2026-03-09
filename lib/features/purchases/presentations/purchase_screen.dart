import 'package:al_sakr/features/suppliers/controllers/supplier_controller.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/models/transaction_item_model.dart';
import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:al_sakr/features/store/presentations/product_dialog.dart';
import 'package:al_sakr/features/suppliers/presentations/supplier_dialog.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';

const _superAdminId = 'admin123';

class PurchaseScreen extends ConsumerStatefulWidget {
  // ✅ متغيرات استقبال بيانات التعديل
  final Map<String, dynamic>? oldPurchaseData;
  final List<TransactionItemModel>? initialItems;

  const PurchaseScreen({super.key, this.oldPurchaseData, this.initialItems});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  // --- المتغيرات ---
  List<String> _units = [];
  final List<Map<String, dynamic>> _cart = [];

  String? _selectedSupplierId;
  String? _selectedProductId;

  final TextEditingController _supplierSearchController =
      TextEditingController();
  final TextEditingController _productSearchController =
      TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _refNumController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );

  DateTime _invoiceDate = DateTime.now();
  bool _isTaxEnabled = false;
  bool _isWhtEnabled = false;
  String _paymentType = 'cash';

  bool _canAddPurchase = false;
  bool _canAddSupplier = false;
  bool _canAddProduct = false;
  bool _isSaving = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadUnits();

    // ✅✅ منطق التعبئة في حالة التعديل ✅✅
    if (widget.oldPurchaseData != null) {
      final old = widget.oldPurchaseData!;

      // تعبئة المورد
      _selectedSupplierId = old['supplier'] ?? old['supplierId'];
      _supplierSearchController.text = old['supplierName'] ?? '';

      // تعبئة التاريخ والرقم
      if (old['date'] != null)
        _invoiceDate = DateTime.parse(old['date']).toLocal();
      _refNumController.text = old['referenceNumber'] ?? '';

      // تعبئة نوع الدفع
      _paymentType = old['paymentType'] ?? 'cash';

      // تفعيل الضرائب تلقائياً
      double tax = (old['taxAmount'] ?? 0).toDouble();
      double wht = (old['whtAmount'] ?? 0).toDouble();
      _isTaxEnabled = tax > 0;
      _isWhtEnabled = wht > 0;

      // تعبئة الخصم
      _discountController.text = (old['discount'] ?? 0).toString();
    }

    // ✅✅ تعبئة الأصناف في السلة ✅✅
    if (widget.initialItems != null) {
      for (var item in widget.initialItems!) {
        _cart.add({
          'productId': item.productId,
          'name': item.productName,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'imagePath': '', // يمكن تحسين جلب الصورة هنا لو متاحة
        });
      }
    }
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) {
        setState(() {
          _canAddPurchase = true;
          _canAddSupplier = true;
          _paymentType = 'cash';
        });
      }
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
          _canAddPurchase =
              u['allow_add_purchases'] == 1 || u['allow_add_purchases'] == true;
          _canAddSupplier =
              u['allow_add_clients'] == 1 || u['allow_add_clients'] == true;
          _canAddProduct =
              u['allow_add_products'] == 1 || u['allow_add_products'] == true;
        });
      }
    } catch (e) {
      debugPrint("Error loading perms: $e");
    }
  }

  Future<void> _loadUnits() async {
    if (mounted) {
      setState(() {
        if (_units.isEmpty) _units = ['قطعة', 'كرتونة'];
      });
    }
  }

  // --- الحسابات ---
  double get _subTotal {
    double sum = 0;
    for (var item in _cart) {
      sum += (item['total'] as num).toDouble();
    }
    return sum;
  }

  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _taxableAmount => _subTotal - _discount;
  double get _taxAmount => _isTaxEnabled ? _taxableAmount * 0.14 : 0.0;
  double get _whtAmount => _isWhtEnabled ? _taxableAmount * 0.01 : 0.0;
  double get _grandTotal => _taxableAmount + _taxAmount - _whtAmount;

  // --- الديالوجات ---
  Future<void> _openAddSupplierDialog() async {
    if (!_canAddSupplier) return;
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const SupplierDialog(),
    );
    if (result != null && result is Map) {
      setState(() {
        _selectedSupplierId = result['id'];
        _supplierSearchController.text = result['name'];
      });
    }
  }

  Future<void> _openAddProductDialog() async {
    if (!_canAddProduct) return;
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ProductDialog(),
    );
    if (result != null && result is Map) {
      setState(() {
        _selectedProductId = result['id'];
        _productSearchController.text = result['name'];
        _costPriceController.text = (result['buyPrice'] ?? 0).toString();
      });
    }
  }

  // ✅✅ تم تحسين دالة البحث: الآن تستدعي كلاس منفصل للأداء الأفضل
  void _showSearchDialog({required bool isSupplier}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SearchDialog(isSupplier: isSupplier),
    );

    if (result != null) {
      setState(() {
        if (isSupplier) {
          _selectedSupplierId = result['id'];
          _supplierSearchController.text = result['name'];
        } else {
          _selectedProductId = result['id'];
          _productSearchController.text = result['name'];
          _costPriceController.text = result['buyPrice'].toString();
        }
      });
    }
  }

  void _addToCart() {
    if (_selectedProductId == null ||
        _qtyController.text.isEmpty ||
        _costPriceController.text.isEmpty)
      return;
    int qty = int.tryParse(_qtyController.text) ?? 0;
    double cost = double.tryParse(_costPriceController.text) ?? 0.0;
    if (qty <= 0) return;

    String prodName = _productSearchController.text;

    setState(() {
      _cart.add({
        'productId': _selectedProductId!,
        'name': prodName,
        'price': cost,
        'quantity': qty,
        'total': (qty * cost).toDouble(),
      });
      _selectedProductId = null;
      _productSearchController.clear();
      _qtyController.clear();
      _costPriceController.clear();
    });
  }

  // ✅✅ دالة الحفظ المعدلة للتعامل مع التعديل ✅✅
  void _submitPurchase() async {
    if (_isSaving) return;
    if (!_canAddPurchase) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية')));
      return;
    }
    if (_selectedSupplierId == null || _cart.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('البيانات ناقصة')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. إذا كان تعديل، نحذف الفاتورة القديمة أولاً
      if (widget.oldPurchaseData != null) {
        await ref
            .read(purchasesControllerProvider.notifier)
            .deletePurchase(widget.oldPurchaseData!['id']);
      }

      // 2. إنشاء الفاتورة الجديدة
      await ref
          .read(purchasesControllerProvider.notifier)
          .createPurchase(
            supplierId: _selectedSupplierId!,
            totalAmount: _grandTotal,
            items: _cart,
            refNumber: _refNumController.text,
            customDate: DateTime(
              _invoiceDate.year,
              _invoiceDate.month,
              _invoiceDate.day,
              12,
            ).toUtc().toIso8601String(),
            taxAmount: _taxAmount,
            whtAmount: _whtAmount,
            discount: _discount,
            paymentType: _paymentType,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // 3. التوجيه بعد الحفظ
      if (widget.oldPurchaseData != null) {
        Navigator.pop(context); // العودة للسجل في حالة التعديل
      } else {
        // تصفير الشاشة في حالة الإضافة الجديدة
        setState(() {
          _cart.clear();
          _selectedSupplierId = null;
          _supplierSearchController.clear();
          _refNumController.clear();
          _discountController.text = '0';
        });
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'لم يتم حفظ الفاتورة',
              style: TextStyle(color: Colors.red),
            ),
            content: Text(
              'حدث خطأ أثناء حفظ الفاتورة في قاعدة البيانات المحلية: $e\n\nتم التراجع عن الفاتورة لتجنب الأخطاء والمضاعفات في الرصيد.\nيرجى إعادة المحاولة من جديد.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسنًا، سأحاول مجدداً'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editItem(int index) {
    final item = _cart[index];
    setState(() {
      // 1. إرجاع البيانات للحقول
      _productSearchController.text = item['name'];
      _costPriceController.text = item['price'].toString();
      _qtyController.text = item['quantity'].toString();

      // 2. تحديد الايدي عشان الحفظ يشتغل
      _selectedProductId = item['productId'];

      // 3. حذف من القائمة
      _cart.removeAt(index);
    });
  }

  // ✅✅ تم تحسين دالة الصور (Image Caching Optimization)
  Widget _buildProductImage(String? imagePath, {double size = 45}) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            // 🚀 تحسين: تحديد أبعاد الكاش لتقليل استهلاك الذاكرة
            cacheWidth: (size * 2).toInt(),
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        );
      } else if (File(imagePath).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            // 🚀 تحسين محلي
            cacheWidth: (size * 2).toInt(),
          ),
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/splash_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.brown[300]! : Colors.brown[700]!;
    final blueColor = Colors.blue[800]!;
    bool isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مشتريات'), centerTitle: true),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. الجزء العلوي (البيانات)
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _supplierSearchController,
                              readOnly: true,
                              onTap: () => _showSearchDialog(isSupplier: true),
                              decoration: InputDecoration(
                                labelText: 'المورد',
                                prefixIcon: const Icon(Icons.local_shipping),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: _canAddSupplier
                                    ? IconButton(
                                        icon: const Icon(Icons.add_circle),
                                        onPressed: _openAddSupplierDialog,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _invoiceDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) setState(() => _invoiceDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'التاريخ',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: Text(
                                  "${_invoiceDate.year}-${_invoiceDate.month}-${_invoiceDate.day}",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _refNumController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الفاتورة',
                          prefixIcon: Icon(Icons.receipt),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // حقول إضافة المنتج
                      if (!isWide)
                        Column(
                          children: [
                            TextField(
                              controller: _productSearchController,
                              readOnly: true,
                              onTap: () => _showSearchDialog(isSupplier: false),
                              decoration: InputDecoration(
                                labelText: 'الصنف',
                                prefixIcon: const Icon(Icons.category),
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: _canAddProduct
                                    ? IconButton(
                                        icon: const Icon(Icons.add_box),
                                        onPressed: _openAddProductDialog,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _costPriceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*'),
                                      ),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'سعر',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: TextField(
                                    controller: _qtyController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'كمية',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                IconButton.filled(
                                  onPressed: _addToCart,
                                  icon: const Icon(Icons.add),
                                  style: IconButton.styleFrom(
                                    backgroundColor: accentColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _productSearchController,
                                readOnly: true,
                                onTap: () =>
                                    _showSearchDialog(isSupplier: false),
                                decoration: InputDecoration(
                                  labelText: 'الصنف',
                                  prefixIcon: const Icon(Icons.category),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: _canAddProduct
                                      ? IconButton(
                                          icon: const Icon(Icons.add_box),
                                          onPressed: _openAddProductDialog,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextField(
                                controller: _costPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'سعر',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: TextField(
                                controller: _qtyController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'كمية',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            IconButton.filled(
                              onPressed: _addToCart,
                              icon: const Icon(Icons.add),
                              style: IconButton.styleFrom(
                                backgroundColor: accentColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. الجزء الأوسط (القائمة)
            SliverToBoxAdapter(
              child: _cart.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'السلة فارغة',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _cart.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 5),
                      itemBuilder: (c, i) => Card(
                        child: ListTile(
                          leading: _buildProductImage(_cart[i]['imagePath']),
                          title: Text(
                            _cart[i]['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${_cart[i]['quantity']} x ${_cart[i]['price']} ج.م",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${(_cart[i]['total'] as num).toDouble().toStringAsFixed(1)} ج.م",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _editItem(i),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _cart.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // 3. الجزء السفلي (لوحة التحكم)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // لوحة التحكم (متجاوبة)
                        if (!isWide)
                          Column(
                            children: [
                              _buildSegmentedPaymentToggle(isDark),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(child: _buildDiscountField(isDark)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildTaxToggle(
                                      "14%",
                                      _isTaxEnabled,
                                      (v) => setState(() => _isTaxEnabled = v),
                                      Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: _buildTaxToggle(
                                      "1%",
                                      _isWhtEnabled,
                                      (v) => setState(() => _isWhtEnabled = v),
                                      Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildSegmentedPaymentToggle(isDark),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                flex: 2,
                                child: _buildDiscountField(isDark),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTaxToggle(
                                        "ضريبة 14%",
                                        _isTaxEnabled,
                                        (v) =>
                                            setState(() => _isTaxEnabled = v),
                                        Colors.orange,
                                        fullWidth: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTaxToggle(
                                        "خصم 1%",
                                        _isWhtEnabled,
                                        (v) =>
                                            setState(() => _isWhtEnabled = v),
                                        Colors.red,
                                        fullWidth: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),
                        const Divider(),

                        _buildSummaryLine("Total Befor Add Tax", _subTotal),
                        if (_isTaxEnabled)
                          _buildSummaryLine(
                            "Value Added Tax 14%",
                            _taxAmount,
                            color: Colors.orange,
                          ),
                        if (_isWhtEnabled)
                          _buildSummaryLine(
                            "discount tax 1%",
                            _whtAmount,
                            color: Colors.red,
                          ),
                        if (_discount > 0)
                          _buildSummaryLine(
                            "خصم إضافي",
                            _discount,
                            color: Colors.green,
                          ),

                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: _submitPurchase,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _canAddPurchase
                                    ? [blueColor, Colors.blueAccent]
                                    : [Colors.grey, Colors.grey.shade400],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: blueColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isSaving
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _canAddPurchase
                                            ? "حفظ الفاتورة"
                                            : "غير مسموح",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                const SizedBox(width: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${_grandTotal.toStringAsFixed(2)} ج.م",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- الدوال المساعدة ---
  Widget _buildSegmentedPaymentToggle(bool isDark) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPaymentOption(
            title: "كاش",
            value: 'cash',
            activeColor: Colors.green,
            isDark: isDark,
          ),
          _buildPaymentOption(
            title: "آجل",
            value: 'credit',
            activeColor: Colors.redAccent,
            isDark: isDark,
          ),
          _buildPaymentOption(
            title: "شيك",
            value: 'cheque',
            activeColor: Colors.orange,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String value,
    required Color activeColor,
    required bool isDark,
  }) {
    bool isSelected = _paymentType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey : Colors.black54),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountField(bool isDark) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: _discountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          labelText: 'خصم إضافي',
          labelStyle: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey : Colors.grey[700],
          ),
          prefixIcon: const Icon(Icons.discount_outlined, size: 18),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  Widget _buildTaxToggle(
    String label,
    bool value,
    Function(bool) onChanged,
    Color activeColor, {
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: value ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? activeColor : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: value ? activeColor : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, double val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(
            val.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ScrollingText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  const ScrollingText({required this.text, this.style, super.key});
  @override
  ConsumerState<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends ConsumerState<ScrollingText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      _animation =
          Tween<double>(
            begin: 0,
            end: _scrollController.position.maxScrollExtent,
          ).animate(
            CurvedAnimation(parent: _animationController, curve: Curves.linear),
          );
      _animation.addListener(() {
        if (_scrollController.hasClients)
          _scrollController.jumpTo(_animation.value);
      });
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style),
    );
  }
}

// ✅✅✅ الكلاس الجديد للبحث المحسن (Performance Optimization) ✅✅✅
class _SearchDialog extends ConsumerStatefulWidget {
  final bool isSupplier;
  const _SearchDialog({required this.isSupplier});

  @override
  ConsumerState<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<_SearchDialog> {
  String _query = '';

  Widget _buildProductImage(String? imagePath, {double size = 30}) {
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 2).toInt(),
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        );
      } else if (File(imagePath).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 2).toInt(),
          ),
        );
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/splash_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildStockIndicator(dynamic stockVal) {
    int stock = (stockVal is int)
        ? stockVal
        : int.tryParse(stockVal?.toString() ?? '0') ?? 0;
    bool inStock = stock > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: inStock
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: inStock
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 12,
            color: inStock ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            "$stock",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: inStock ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ Read from the local-first Riverpod providers
    final asyncData = widget.isSupplier
        ? ref.watch(supplierControllerProvider)
        : ref.watch(storeControllerProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.isSupplier ? 'بحث عن مورد' : 'اختر صنفاً',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'اكتب للبحث...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: asyncData.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('خطأ: $e')),
                data: (allItems) {
                  final filteredList = allItems.where((item) {
                    final q = _query.toLowerCase();
                    final name = (item['name'] ?? '').toString().toLowerCase();
                    if (widget.isSupplier) {
                      return name.contains(q);
                    } else {
                      final code = (item['code'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(q) || code.contains(q);
                    }
                  }).toList();

                  if (filteredList.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "لا توجد نتائج",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredList.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                ),
                                child: widget.isSupplier
                                    ? const Icon(
                                        Icons.local_shipping,
                                        size: 25,
                                        color: Colors.grey,
                                      )
                                    : _buildProductImage(
                                        item['imagePath'],
                                        size: 40,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      child: ScrollingText(
                                        text: item['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (!widget.isSupplier)
                                      Row(
                                        children: [
                                          _buildStockIndicator(item['stock']),
                                          const SizedBox(width: 12),
                                          Text(
                                            "شراء: ${item['buyPrice']}",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.brown[400],
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        item['phone'] ?? 'لا يوجد رقم',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("إلغاء"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
