import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/core/database/database_constants.dart';

import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:al_sakr/features/store/presentations/product_history_screen.dart';
import 'package:al_sakr/features/store/presentations/product_dialog.dart';
import 'package:al_sakr/features/store/presentations/inventory_setup_screen.dart';

const _superAdminId = 'admin123';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'all';
  String _searchQuery = "";
  Timer? _debounce;

  // متغيرات الصلاحيات
  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;
  bool _canSettleInventory = false;

  final String _superAdminId = "1sxo74splxbw1yh";

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final myId = globalPb.authStore.record?.id;
    if (myId == null) return;

    if (myId == _superAdminId) {
      if (mounted) {
        setState(() {
          _canAdd = true;
          _canEdit = true;
          _canDelete = true;
          _canSettleInventory = true;
        });
      }
      return;
    }

    try {
      // Try local DB first
      final db = await ref.read(localDatabaseProvider.future);
      final users = await db.query(
        'users',
        where: '${DbConstants.colId} = ?',
        whereArgs: [myId],
        limit: 1,
      );
      if (users.isNotEmpty && mounted) {
        setState(() {
          _canAdd =
              users.first['allow_add_products'] == 1 ||
              users.first['allow_add_products'] == true;
          _canEdit =
              users.first['allow_edit_products'] == 1 ||
              users.first['allow_edit_products'] == true;
          _canDelete =
              users.first['allow_delete_products'] == 1 ||
              users.first['allow_delete_products'] == true;
          _canSettleInventory =
              users.first['allow_inventory_settlement'] == 1 ||
              users.first['allow_inventory_settlement'] == true;
        });
        return;
      }
      // Fallback to PB
      final userRecord = await globalPb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAdd = userRecord.data['allow_add_products'] ?? false;
          _canEdit = userRecord.data['allow_edit_products'] ?? false;
          _canDelete = userRecord.data['allow_delete_products'] ?? false;
          _canSettleInventory =
              userRecord.data['allow_inventory_settlement'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في تحميل الصلاحيات: $e");
    }
  }

  // --- دوال مساعدة ---
  int _checkExpiryStatus(Map<String, dynamic> product) {
    if (product['expiryDate'] == null ||
        product['expiryDate'].toString().isEmpty) {
      return 0;
    }
    DateTime exp = DateTime.parse(product['expiryDate']);
    DateTime now = DateTime.now();
    DateTime expDateOnly = DateTime(exp.year, exp.month, exp.day);
    DateTime nowDateOnly = DateTime(now.year, now.month, now.day);
    int daysLeft = expDateOnly.difference(nowDateOnly).inDays;

    if (daysLeft < 0) return 1;
    if (daysLeft <= 30) return 2;
    return 0;
  }

  void _openProductDialog({Map<String, dynamic>? product}) async {
    if (product == null && !_canAdd) return;
    if (product != null && !_canEdit) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductDialog(product: product),
    );
  }

  void _deleteProduct(String id) {
    if (!_canDelete) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصنف'),
        content: const Text('هل أنت متأكد؟ سيتم الحذف نهائياً.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(storeControllerProvider.notifier)
                  .deleteProduct(id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم الحذف'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showZoomedImage(String imagePath) {
    ImageProvider imageProvider;
    if (imagePath.startsWith('http')) {
      imageProvider = NetworkImage(imagePath);
    } else {
      imageProvider = FileImage(File(imagePath));
    }
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image(image: imageProvider),
        ),
      ),
    );
  }

  // --- الفلتر ---
  void _showFilterOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "تصفية المنتجات",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _buildFilterOption(ctx, "الكل", 'all', Icons.list, Colors.blue),
              _buildFilterOption(
                ctx,
                "النواقص",
                'low_stock',
                Icons.trending_down,
                Colors.orange,
              ),
              _buildFilterOption(
                ctx,
                "التوالف",
                'damaged',
                Icons.broken_image,
                Colors.redAccent,
              ),
              _buildFilterOption(
                ctx,
                "منتهي الصلاحية",
                'expired',
                Icons.warning,
                Colors.red,
              ),
              _buildFilterOption(
                ctx,
                "قرب الانتهاء",
                'near_expiry',
                Icons.access_time,
                Colors.yellow[700]!,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    BuildContext ctx,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _filterType == value;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? color : null,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: color) : null,
      onTap: () {
        setState(() => _filterType = value);
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.watch(storeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزن والأصناف'),
        centerTitle: true,
        actions: [
          if (_canSettleInventory)
            IconButton(
              icon: const Icon(Icons.inventory_outlined),
              tooltip: 'جلسة جرد المخزون',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventorySetupScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) setState(() {});
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'بحث (اسم، كود، باركود)...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _filterType == 'all'
                        ? (isDark ? Colors.grey[800] : Colors.white)
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: _filterType == 'all'
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.white,
                    ),
                    onPressed: _showFilterOptions,
                    tooltip: 'تصفية',
                  ),
                ),
              ],
            ),
          ),

          // القائمة
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("خطأ: $e")),
              data: (allProducts) {
                final filteredList = allProducts.where((product) {
                  if (product['is_deleted'] == true ||
                      product['is_deleted'] == 1)
                    return false;
                  final keyword = _searchController.text.toLowerCase();
                  final name = (product['name'] ?? '').toString().toLowerCase();
                  final code = (product['code'] ?? '').toString().toLowerCase();
                  final barcode = (product['barcode'] ?? '')
                      .toString()
                      .toLowerCase();
                  bool matchesSearch =
                      name.contains(keyword) ||
                      code.contains(keyword) ||
                      barcode.contains(keyword);
                  if (!matchesSearch) return false;
                  if (_filterType == 'expired')
                    return _checkExpiryStatus(product) == 1;
                  if (_filterType == 'near_expiry')
                    return _checkExpiryStatus(product) == 2;
                  if (_filterType == 'low_stock') {
                    int stock = (product['stock'] as num?)?.toInt() ?? 0;
                    int reorder =
                        (product['reorderLevel'] as num?)?.toInt() ?? 0;
                    return stock <= reorder;
                  }
                  if (_filterType == 'damaged') {
                    int damaged =
                        (product['damagedStock'] as num?)?.toInt() ?? 0;
                    return damaged > 0;
                  }
                  return true;
                }).toList();

                if (filteredList.isEmpty) {
                  return const Center(child: Text('لا توجد أصناف'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    top: 5,
                    bottom: 100,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(filteredList[index], isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openProductDialog(),
              label: const Text(
                'صنف جديد',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add_box, color: Colors.white),
              backgroundColor: Colors.blue[900],
            )
          : null,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    int stock = (product['stock'] as num?)?.toInt() ?? 0;
    int reorder = (product['reorderLevel'] as num?)?.toInt() ?? 0;
    int damaged = (product['damagedStock'] as num?)?.toInt() ?? 0;
    bool isLowStock = stock <= reorder;
    int expiryStatus = _checkExpiryStatus(product);

    Color? cardColor;
    Color statusColor = Colors.grey;
    String statusText = "";

    if (expiryStatus == 1) {
      cardColor = isDark ? Colors.red.withOpacity(0.15) : Colors.red[50];
      statusColor = Colors.red;
      statusText = "منتهي!";
    } else if (expiryStatus == 2) {
      cardColor = isDark ? Colors.yellow.withOpacity(0.1) : Colors.yellow[50];
      statusColor = Colors.orange[800]!;
      statusText = "قرب الانتهاء";
    } else if (isLowStock) {
      cardColor = isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50];
      statusColor = Colors.deepOrange;
      statusText = "نواقص";
    }

    ImageProvider? listImageProvider;
    if (product['imagePath'] != null &&
        product['imagePath'].toString().isNotEmpty) {
      if (product['imagePath'].toString().startsWith('http')) {
        // ✅ 4. تطبيق الكاش لتقليل استهلاك الذاكرة
        listImageProvider = ResizeImage(
          NetworkImage(product['imagePath']),
          width: 150, // تصغير حجم الصورة في الذاكرة
          policy: ResizeImagePolicy.fit,
        );
      } else {
        listImageProvider = ResizeImage(
          FileImage(File(product['imagePath'])),
          width: 150,
        );
      }
    }

    return Card(
      color: cardColor ?? (isDark ? const Color(0xFF2C2C2C) : Colors.white),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 1. الصف العلوي: الصورة + البيانات
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصورة
                GestureDetector(
                  onTap: listImageProvider != null
                      ? () => _showZoomedImage(product['imagePath'])
                      : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusText.isNotEmpty
                          ? statusColor.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      image: listImageProvider != null
                          ? DecorationImage(
                              image: listImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: listImageProvider == null
                        ? Icon(
                            expiryStatus == 1
                                ? Icons.warning
                                : (isLowStock
                                      ? Icons.trending_down
                                      : Icons.inventory_2),
                            color: statusText.isNotEmpty
                                ? statusColor
                                : Colors.blue,
                            size: 30,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // البيانات (الاسم، الحالة، السعر، المخزون)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم والبادج
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (statusText.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // السعر والمخزون
                      Wrap(
                        spacing: 15,
                        runSpacing: 5,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sell_outlined,
                                size: 14,
                                color: isDark
                                    ? Colors.greenAccent
                                    : Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${product['sellPrice']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.greenAccent
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$stock',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (damaged > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.broken_image_outlined,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$damaged',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
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

            const SizedBox(height: 12),
            const Divider(height: 1),
            // 2. الصف السفلي: أزرار الإجراءات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.history,
                  label: "سجل",
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductHistoryScreen(product: product),
                    ),
                  ),
                ),
                if (_canEdit)
                  _buildActionButton(
                    icon: Icons.edit,
                    label: "تعديل",
                    color: Colors.blue,
                    onTap: () => _openProductDialog(product: product),
                  ),
                if (_canDelete)
                  _buildActionButton(
                    icon: Icons.delete,
                    label: "حذف",
                    color: Colors.red,
                    onTap: () => _deleteProduct(product['id']),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
