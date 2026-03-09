import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:al_sakr/core/sync/sync_constants.dart';
import 'package:al_sakr/core/database/database_provider.dart';
import 'package:al_sakr/core/database/database_constants.dart';
import 'package:al_sakr/core/sync/sync_manager.dart';
import 'package:sqflite/sqflite.dart';

Future<void> showPendingSyncDetailsDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  showDialog(
    context: context,
    builder: (context) => _PendingSyncDialog(ref: ref),
  );
}

class _PendingSyncDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _PendingSyncDialog({required this.ref});

  @override
  ConsumerState<_PendingSyncDialog> createState() => _PendingSyncDialogState();
}

class _PendingSyncDialogState extends ConsumerState<_PendingSyncDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRecords = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRecords();
  }

  Future<void> _loadPendingRecords() async {
    setState(() => _isLoading = true);
    try {
      final db = await widget.ref.read(localDatabaseProvider.future);
      final List<Map<String, dynamic>> allPending = [];

      for (final table in syncTableOrder) {
        try {
          final result = await db.rawQuery(
            'SELECT * FROM $table WHERE sync_status != ?',
            ['synced'],
          );

          for (var row in result) {
            String displayName = await _getRecordDisplayName(db, table, row);
            allPending.add({
              'table': table,
              'id': row['id'],
              'status': row['sync_status'],
              'displayName': displayName,
            });
          }
        } catch (_) {
          // Table might not exist yet or other query error
        }
      }

      // --- DEBUG CODE ---
      try {
        final products = await db.query('products');
        print('====== DEBUG PRODUCTS TABLE ======');
        for (var p in products) {
          print(
            'PRODUCT: ${p['id']} | sync_status: ${p['sync_status']} | is_deleted: ${p['is_deleted']} | name: ${p['name']}',
          );
        }
        print('==================================');
      } catch (e) {
        print('Debug error: $e');
      }
      // --- END DEBUG ---

      if (mounted) {
        setState(() {
          _pendingRecords = allPending;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في جلب السجلات: $e')));
      }
    }
  }

  Future<String> _getRecordDisplayName(
    Database db,
    String table,
    Map<String, dynamic> row,
  ) async {
    try {
      if (table == 'clients' || table == 'suppliers' || table == 'products') {
        return row['name']?.toString() ?? 'بدون اسم';
      }

      if (table == 'sales') {
        final clientName = await _getClientName(db, row['client']);
        final amount = row['totalAmount']?.toString() ?? '0';
        return 'فاتورة مبيعات لـ $clientName (المبلغ: $amount)';
      }
      if (table == 'purchases') {
        final supplierName = await _getSupplierName(db, row['supplier']);
        final amount = row['totalAmount']?.toString() ?? '0';
        return 'فاتورة مشتريات من $supplierName (المبلغ: $amount)';
      }
      if (table == 'returns') {
        final clientName = await _getClientName(db, row['client']);
        final amount = row['totalAmount']?.toString() ?? '0';
        return 'مرتجع مبيعات لـ $clientName (المبلغ: $amount)';
      }
      if (table == 'purchase_returns') {
        final supplierName = await _getSupplierName(db, row['supplier']);
        final amount = row['totalAmount']?.toString() ?? '0';
        return 'مرتجع مشتريات من $supplierName (المبلغ: $amount)';
      }
      if (table == 'delivery_orders') {
        final clientName = await _getClientName(db, row['client']);
        return 'إذن تسليم لـ $clientName';
      }
      if (table == 'expenses') {
        return row['description']?.toString() ?? 'مصروف';
      }

      // Items tables
      if (table == 'sale_items' ||
          table == 'purchase_items' ||
          table == 'return_items' ||
          table == 'purchase_return_items' ||
          table == 'delivery_order_items') {
        // Try getting product name first from the row if denormalized
        String productName = row['productName']?.toString() ?? '';
        if (productName.isEmpty) {
          productName = await _getProductName(db, row['product']);
        }
        final qty = row['quantity']?.toString() ?? '';
        return 'صنف: $productName (الكمية: $qty)';
      }

      if (table == 'receipts') {
        final clientName = await _getClientName(db, row['client']);
        final amount = row['amount']?.toString() ?? '0';
        return 'سند قبض من م. $clientName ($amount)';
      }
      if (table == 'supplier_payments') {
        final supplierName = await _getSupplierName(db, row['supplier']);
        final amount = row['amount']?.toString() ?? '0';
        return 'سند صرف لـ م. $supplierName ($amount)';
      }
    } catch (_) {}
    return 'معرف: ${row['id']}';
  }

  Future<String> _getClientName(Database db, dynamic clientId) async {
    if (clientId == null || clientId.toString().isEmpty) return 'نقدي/عام';
    final res = await db.query(
      'clients',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first['name']?.toString() ?? 'معروف';
    return 'معروف';
  }

  Future<String> _getSupplierName(Database db, dynamic supplierId) async {
    if (supplierId == null || supplierId.toString().isEmpty) return 'نقدي/عام';
    final res = await db.query(
      'suppliers',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [supplierId],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first['name']?.toString() ?? 'معروف';
    return 'معروف';
  }

  Future<String> _getProductName(Database db, dynamic productId) async {
    if (productId == null || productId.toString().isEmpty)
      return 'منتج غير معروف';
    final res = await db.query(
      'products',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (res.isNotEmpty) return res.first['name']?.toString() ?? 'غير معروف';
    return 'غير معروف';
  }

  Future<void> _deleteRecord(String table, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من حذف هذا السجل المعلق؟\nلن يتم مزامنة هذا السجل مع السيرفر بعد الآن.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = await widget.ref.read(localDatabaseProvider.future);

      // Also potentially delete child records if needed to prevent further orphans,
      // but a straight delete from the table is the primary requested action.
      await db.delete(table, where: 'id = ?', whereArgs: [id]);

      // Refresh local list
      await _loadPendingRecords();

      // Update global sync provider so pending badge updates
      widget.ref
          .read(syncManagerProvider.notifier)
          .triggerSync(); // Trigger to re-read counts

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف السجل بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return 'غير معروف';
    if (status.contains('create')) return 'إضافة جديدة';
    if (status.contains('update')) return 'تعديل';
    if (status.contains('delete')) return 'مسح';
    return status;
  }

  String _formatTableName(String table) {
    switch (table) {
      case 'sales':
        return 'المبيعات';
      case 'sale_items':
        return 'أصناف المبيعات';
      case 'clients':
        return 'العملاء';
      case 'products':
        return 'المنتجات';
      case 'delivery_orders':
        return 'أذونات التسليم';
      case 'delivery_order_items':
        return 'أصناف التسليم';
      case 'purchases':
        return 'المشتريات';
      case 'purchase_items':
        return 'أصناف المشتريات';
      case 'returns':
        return 'المرتجعات';
      case 'return_items':
        return 'أصناف المرتجعات';
      case 'expenses':
        return 'المصروفات';
      default:
        return table;
    }
  }

  Future<void> _forceSyncMissing() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مزامنة شاملة لجميع البيانات'),
        content: const Text(
          'هل تريد فحص جميع الجداول (عملاء، موردين، أصناف، فواتير، مصروفات...) وإعادة رفع أي عناصر محذوفة من السيرفر بالخطأ؟\nستستغرق هذه العملية بعض الوقت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، ابدأ الفحص'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final db = await widget.ref.read(localDatabaseProvider.future);

      // Mark all synced records in all tables as pending_update.
      // The Upsync logic will try to update them:
      // If they exist -> no-op update.
      // If deleted from PB admin -> 404 fallback -> downgrades to pending_create -> inserted!
      for (final table in syncTableOrder) {
        if (table == 'users') continue; // Skip users table to avoid auth issues
        try {
          await db.update(
            table,
            {'sync_status': SyncStatus.pendingUpdate},
            where: 'sync_status = ?',
            whereArgs: [SyncStatus.synced],
          );
        } catch (_) {
          // Ignore tables that might not exist or don't have sync_status
        }
      }

      widget.ref.read(syncManagerProvider.notifier).triggerSync();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم بدء فحص ورفع كافة البيانات المفقودة...'),
          ),
        );
      }
      await _loadPendingRecords();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'تفاصيل السجلات المعلقة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'هذه السجلات لم يتم مزامنتها مع الخادم المركزي. يمكنك مسح السجلات للإلغاء.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingRecords.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد سجلات معلقة',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _pendingRecords.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final record = _pendingRecords[index];
                        final table = record['table'] as String;
                        final id = record['id'] as String;
                        final status = record['status'] as String?;
                        final displayName =
                            record['displayName'] as String? ?? id;

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(
                              Icons.sync_problem,
                              color: Colors.white,
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'جدول: ${_formatTableName(table)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color ??
                                      Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'العملية: ${_formatStatus(status)}\nالمعرف: $id',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'حذف من المزامنة',
                            onPressed: () => _deleteRecord(table, id),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync_alt, size: 18),
                  label: const Text(
                    'فحص ومزامنة شاملة لكل البيانات',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: _isLoading ? null : _forceSyncMissing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
