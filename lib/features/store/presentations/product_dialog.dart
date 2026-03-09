// import 'package:al_sakr/features/auth/controllers/auth_controller.dart';
// import 'package:al_sakr/core/network/pb_helper_provider.dart';
// import 'package:al_sakr/features/notices/controllers/notices_controller.dart';
// import 'package:al_sakr/features/trash/controllers/trash_controller.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
// import 'package:al_sakr/features/purchases/controllers/purchases_controller.dart';
// import 'package:al_sakr/features/sales/controllers/sales_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:math'; // 👈 استيراد مكتبة الرياضيات للتوليد العشوائي
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 استيراد الخدمات للتحكم في المدخلات
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:image_picker/image_picker.dart';

class ProductDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product;
  const ProductDialog({super.key, this.product});

  @override
  ConsumerState<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<ProductDialog> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _minSellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _damagedStockController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _notesController = TextEditingController();

  List<String> _units = [];
  String _selectedUnit = 'قطعة';
  DateTime? _expiryDate;
  String? _selectedImagePath;
  bool _isLoading = false;

  bool _showBuyPrice = false;
  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _loadPermissions();
    if (widget.product != null) _initExistingData();
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;
    if (myId == _superAdminId) {
      if (mounted) setState(() => _showBuyPrice = true);
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
          _showBuyPrice =
              u['show_buy_price'] == 1 || u['show_buy_price'] == true;
        });
      }
    } catch (e) {
      debugPrint("Error permissions: $e");
    }
  }

  void _initExistingData() {
    final p = widget.product!;
    _nameController.text = p['name'];
    _codeController.text = p['code'] ?? '';
    _barcodeController.text = p['barcode'] ?? '';
    _buyPriceController.text = p['buyPrice'].toString();
    _sellPriceController.text = p['sellPrice'].toString();
    _minSellPriceController.text = p['minSellPrice']?.toString() ?? '0';
    _stockController.text = p['stock'].toString() == '0'
        ? ''
        : p['stock'].toString();
    _damagedStockController.text = (p['damagedStock'] ?? 0).toString() == '0'
        ? ''
        : (p['damagedStock'] ?? 0).toString();
    _reorderLevelController.text = p['reorderLevel']?.toString() == '0'
        ? ''
        : p['reorderLevel']?.toString() ?? '';
    _notesController.text = p['notes'] ?? '';
    _selectedUnit = p['unit'] ?? 'قطعة';
    if (p['expiryDate'] != null && p['expiryDate'].toString().isNotEmpty) {
      _expiryDate = DateTime.parse(p['expiryDate']);
    }
    _selectedImagePath = p['imagePath'];
  }

  Future<void> _loadUnits() async {
    final unitsData = await ref
        .read(storeControllerProvider.notifier)
        .getUnits();
    if (mounted) {
      setState(() {
        _units = unitsData;
        if (_units.isEmpty) _units = ['قطعة', 'كرتونة'];
        if (!_units.contains(_selectedUnit) && _units.isNotEmpty) {
          _selectedUnit = _units.first;
        }
      });
    }
  }

  // ✅ دالة لتوليد رقم عشوائي
  void _generateRandomCode(TextEditingController controller) {
    var rng = Random();
    // توليد رقم مكون من 12 خانة (يشبه الباركود)
    String code = '';
    for (var i = 0; i < 6; i++) {
      code += rng.nextInt(10).toString();
    }
    setState(() {
      controller.text = code;
    });
  }

  Widget _buildResponsiveRow(BuildContext context, List<Widget> children) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Column(
        children: children
            .map(
              (c) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
            )
            .toList(),
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: c,
                ),
              ),
            )
            .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidth = screenWidth > 750 ? 750 : screenWidth * 0.95;

    // تعريف الألوان المتغيرة
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.grey : Colors.grey[700];
    final fieldColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final borderColor = isDark
        ? Colors.grey.withOpacity(0.5)
        : Colors.grey.withOpacity(0.3);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              widget.product == null ? 'تسجيل صنف جديد' : 'تعديل بيانات الصنف',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // صورة الصنف
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                backgroundImage: _getImageProvider(),
                                child: _selectedImagePath == null
                                    ? Icon(
                                        Icons.camera_alt,
                                        size: 35,
                                        color: iconColor,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          if (_selectedImagePath != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImagePath = null),
                              child: const CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.red,
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // قسم 1: البيانات الأساسية
                    _buildSectionContainer(
                      context,
                      title: "البيانات الأساسية",
                      children: [
                        _buildResponsiveRow(context, [
                          _buildTextField(
                            _codeController,
                            'الكود',
                            Icons.qr_code,
                            // ✅ إضافة زر التوليد
                            onGenerate: () =>
                                _generateRandomCode(_codeController),
                          ),
                          _buildTextField(
                            _barcodeController,
                            'الباركود',
                            Icons.qr_code_scanner,
                            // ✅ إضافة زر التوليد
                            onGenerate: () =>
                                _generateRandomCode(_barcodeController),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _nameController,
                          'اسم الصنف',
                          Icons.shopping_bag,
                        ),
                        const SizedBox(height: 12),
                        // اختيار الوحدة
                        Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                            color: fieldColor,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.scale, color: iconColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _units.contains(_selectedUnit)
                                        ? _selectedUnit
                                        : null,
                                    dropdownColor: isDark
                                        ? const Color(0xFF333333)
                                        : Colors.white,
                                    style: TextStyle(color: textColor),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: textColor,
                                    ),
                                    items: _units
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(u),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedUnit = val!),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.blue,
                                ),
                                onPressed: _showAddUnitDialog,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: _showManageUnitsDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // قسم 2: التسعير والصلاحية
                    _buildSectionContainer(
                      context,
                      title: "التسعير والصلاحية",
                      children: [
                        _buildResponsiveRow(context, [
                          if (_showBuyPrice)
                            _buildTextField(
                              _buyPriceController,
                              'سعر الشراء',
                              Icons.attach_money,
                              isNumber: true,
                            ),
                          _buildTextField(
                            _sellPriceController,
                            'سعر البيع',
                            Icons.local_offer,
                            isNumber: true,
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _buildResponsiveRow(context, [
                          _buildTextField(
                            _minSellPriceController,
                            'أقل سعر بيع',
                            Icons.price_check,
                            isNumber: true,
                          ),
                          InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate:
                                    _expiryDate ??
                                    DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setState(() => _expiryDate = d);
                            },
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: fieldColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: iconColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _expiryDate != null
                                        ? "${_expiryDate!.year}-${_expiryDate!.month}-${_expiryDate!.day}"
                                        : 'تاريخ الصلاحية (اختياري)',
                                    style: TextStyle(
                                      color: _expiryDate != null
                                          ? textColor
                                          : Colors.grey[500],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_expiryDate != null)
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: iconColor,
                                      ),
                                      onPressed: () =>
                                          setState(() => _expiryDate = null),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // قسم 3: المخزون
                    _buildSectionContainer(
                      context,
                      title: "المخزون",
                      children: [
                        _buildResponsiveRow(context, [
                          _buildTextField(
                            _stockController,
                            'الرصيد',
                            Icons.inventory_2,
                            isNumber: true,
                            hintText: '0',
                          ),
                          _buildTextField(
                            _damagedStockController,
                            'التالف',
                            Icons.broken_image,
                            isNumber: true,
                            hintText: '0',
                          ),
                          _buildTextField(
                            _reorderLevelController,
                            'حد الطلب',
                            Icons.warning_amber,
                            isNumber: true,
                            hintText: '0',
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _buildTextField(
                          _notesController,
                          'ملاحظات',
                          Icons.note,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _isLoading ? null : _saveProduct,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'حفظ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.tealAccent : Colors.teal[800];
    final containerBorderColor = isDark
        ? Colors.grey.withOpacity(0.2)
        : Colors.grey.withOpacity(0.4);
    final containerBgColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.withOpacity(0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 5),
          child: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: containerBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: containerBorderColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // ✅ تم تحديث هذه الدالة لإضافة inputFormatters وزر التوليد
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    VoidCallback? onGenerate, // معامل جديد لزر التوليد
    String? hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? Colors.grey[900] : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final iconColor = isDark ? Colors.grey : Colors.grey[700];
    final borderColor = isDark
        ? Colors.grey.withOpacity(0.5)
        : Colors.grey.withOpacity(0.3);

    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        // ✅ منع إدخال أي شيء غير الأرقام والنقطة
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))]
            : null,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          // ✅ إضافة أيقونة التوليد في حالة وجودها
          suffixIcon: onGenerate != null
              ? IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: onGenerate,
                  tooltip: "توليد تلقائي",
                )
              : null,
          filled: true,
          fillColor: fieldColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.blue),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
        ),
      ),
    );
  }

  // --- دوال المنطق (Logic) ---
  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم الصنف')));
      return;
    }
    setState(() => _isLoading = true);
    Map<String, dynamic> data = {
      'name': _nameController.text,
      'code': _codeController.text,
      'barcode': _barcodeController.text,
      'unit': _selectedUnit,
      'buyPrice': double.tryParse(_buyPriceController.text) ?? 0.0,
      'sellPrice': double.tryParse(_sellPriceController.text) ?? 0.0,
      'minSellPrice': double.tryParse(_minSellPriceController.text) ?? 0.0,
      'stock': int.tryParse(_stockController.text) ?? 0,
      'reorderLevel': int.tryParse(_reorderLevelController.text) ?? 0,
      'damagedStock': int.tryParse(_damagedStockController.text) ?? 0,
      'notes': _notesController.text,
    };

    if (_expiryDate != null) {
      data['expiryDate'] = _expiryDate!.toIso8601String();
    }

    try {
      if (widget.product == null) {
        final insertedId = await ref
            .read(storeControllerProvider.notifier)
            .insertProduct(data, _selectedImagePath);
        if (mounted) {
          Navigator.pop(context, {
            'id': insertedId,
            'name': data['name'],
            'buyPrice': data['buyPrice'],
            'sellPrice': data['sellPrice'],
            'stock': data['stock'],
            'imagePath': _selectedImagePath,
          });
        }
      } else {
        String? imageToUpload;
        if (_selectedImagePath != null &&
            !_selectedImagePath!.startsWith('http')) {
          imageToUpload = _selectedImagePath;
        }
        await ref
            .read(storeControllerProvider.notifier)
            .updateProduct(widget.product!['id'], data, imageToUpload);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider? _getImageProvider() {
    if (_selectedImagePath != null && _selectedImagePath!.isNotEmpty) {
      if (_selectedImagePath!.startsWith('http'))
        return NetworkImage(_selectedImagePath!);
      return FileImage(File(_selectedImagePath!));
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImagePath = picked.path);
  }

  Future<void> _showAddUnitDialog() async {
    TextEditingController c = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('وحدة جديدة'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'أدخل اسم الوحدة'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (c.text.isNotEmpty) {
                try {
                  await ref
                      .read(storeControllerProvider.notifier)
                      .insertUnit(c.text);
                  Navigator.pop(ctx);
                  _loadUnits();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في إضافة الوحدة: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageUnitsDialog() async {
    List<String> localUnits = List.from(_units);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('حذف الوحدات'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: localUnits.isEmpty
                  ? const Center(child: Text("لا توجد وحدات"))
                  : ListView.separated(
                      itemCount: localUnits.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (c, i) {
                        final u = localUnits[i];
                        return ListTile(
                          title: Text(u),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(storeControllerProvider.notifier)
                                    .deleteUnit(u);
                                setStateDialog(() => localUnits.remove(u));
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('خطأ في حذف الوحدة: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
    await _loadUnits();
  }
}
