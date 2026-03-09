import 'package:al_sakr/core/network/pb_helper_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../controllers/supplier_controller.dart';
import 'package:al_sakr/features/suppliers/presentations/supplier_dialog.dart';
import 'package:al_sakr/features/suppliers/presentations/supplier_detail_screen.dart';

const _superAdminId = 'admin123';

// TODO: Move this to features/suppliers/presentations later
// Temporary import

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  double _totalPurchases = 0.0;
  double _totalPaid = 0.0;

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _canAdd = false;
  bool _canEdit = false;
  bool _canDelete = false;

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
    _loadStaticStats();
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
        });
      }
      return;
    }

    try {
      final userRecord = await globalPb.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _canAdd = userRecord.data['allow_add_clients'] ?? false;
          _canEdit =
              (userRecord.data['allow_add_clients'] ?? false) ||
              (userRecord.data['allow_edit_clients'] ?? false);
          _canDelete = userRecord.data['allow_delete_clients'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error loading permissions: $e");
    }
  }

  Future<void> _loadStaticStats() async {
    // TODO: Connect this to the new PurchasesController later
    if (mounted) {
      setState(() {
        _totalPurchases = 0.0;
        _totalPaid = 0.0;
      });
    }
  }

  void _showSupplierDialog({Map<String, dynamic>? supplier}) async {
    if (supplier == null && !_canAdd) return;
    if (supplier != null && !_canEdit) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SupplierDialog(supplier: supplier),
    );
  }

  void _deleteSupplier(String id) {
    if (!_canDelete) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف المورد"),
        content: const Text("هل تريد نقل هذا المورد إلى سلة المهملات؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(supplierControllerProvider.notifier)
                    .deleteSupplier(id);
                _loadStaticStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم نقل المورد للسلة ♻️")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                }
              }
            },
            child: const Text(
              "نقل للسلة",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey[400] : Colors.grey[600];

    final suppliersAsync = ref.watch(supplierControllerProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text('إدارة الموردين'), centerTitle: true),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("خطأ: $err")),
        data: (allSuppliers) {
          final filtered = allSuppliers.where((s) {
            if (s['is_deleted'] == true) return false;
            return _searchQuery.isEmpty ||
                (s['name'] ?? '').toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();

          double totalDebt = 0.0;
          for (var s in filtered) {
            double bal = (s['balance'] as num? ?? 0.0).toDouble();
            if (bal > 0) totalDebt += bal;
          }
          filtered.sort(
            (a, b) => ((b['balance'] as num?) ?? 0).compareTo(
              (a['balance'] as num?) ?? 0,
            ),
          );

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: isDark ? const Color(0xFF1A1A1A) : Colors.brown[50],
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 2000),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _summaryCard(
                              "إجمالي المشتريات",
                              _totalPurchases,
                              Colors.orange,
                              Icons.shopping_cart,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _summaryCard(
                              "إجمالي المدفوعات",
                              _totalPaid,
                              Colors.green,
                              Icons.payment,
                              isDark,
                            ),
                            const SizedBox(width: 8),
                            _summaryCard(
                              "المستحق للموردين",
                              totalDebt,
                              Colors.red,
                              Icons.warning,
                              isDark,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            if (_debounce?.isActive ?? false)
                              _debounce!.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) setState(() => _searchQuery = val);
                              },
                            );
                          },
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: "بحث...",
                            hintStyle: TextStyle(color: subColor),
                            prefixIcon: Icon(Icons.search, color: subColor),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2C2C2C)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 10),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final s = filtered[index];
                    double bal = (s['balance'] as num? ?? 0.0).toDouble();

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 2000),
                        child: Card(
                          color: cardColor,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: bal > 0
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                              child: Text(
                                s['name'] != null &&
                                        s['name'].toString().isNotEmpty
                                    ? s['name'][0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: bal > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                            title: Text(
                              s['name'] ?? 'بدون اسم',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              "ت: ${s['phone'] ?? '-'}",
                              style: TextStyle(color: subColor),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${bal.abs().toStringAsFixed(1)} ج.م",
                                      style: TextStyle(
                                        color: bal > 0
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      bal > 0 ? "له" : "لنا",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_canEdit || _canDelete)
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: subColor,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'edit')
                                        _showSupplierDialog(supplier: s);
                                      if (value == 'delete')
                                        _deleteSupplier(s['id']);
                                    },
                                    itemBuilder: (c) => [
                                      if (_canEdit)
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(width: 10),
                                              Text('تعديل'),
                                            ],
                                          ),
                                        ),
                                      if (_canDelete)
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 10),
                                              Text('حذف'),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SupplierDetailScreen(supplier: s),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _showSupplierDialog(),
              label: const Text(
                "مورد جديد",
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              backgroundColor: Colors.brown[700],
            )
          : null,
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              NumberFormat.compact().format(amount),
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
