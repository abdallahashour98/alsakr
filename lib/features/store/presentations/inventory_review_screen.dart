import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';

class InventoryReviewScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> countedProducts;

  const InventoryReviewScreen({super.key, required this.countedProducts});

  @override
  ConsumerState<InventoryReviewScreen> createState() =>
      _InventoryReviewScreenState();
}

class _InventoryReviewScreenState extends ConsumerState<InventoryReviewScreen> {
  int _settlementOption = 0; // 0: Update only, 1: Record as expense/loss
  bool _isProcessing = false;

  void _approveInventory() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(storeControllerProvider.notifier)
          .approveInventory(widget.countedProducts, _settlementOption);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اعتماد الجرد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to StoreScreen
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء اعتماد الجرد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate differences
    final differences = widget.countedProducts.where((p) {
      int systemStock = (p['stock'] as num?)?.toInt() ?? 0;
      int actualStock = p['actual_stock'] as int;
      return systemStock != actualStock;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة وتأكيد الجرد')),
      body: differences.isEmpty
          ? const Center(
              child: Text('لا توجد فروق في الجرد، المخزون مطابق تماماً.'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: differences.length,
                    itemBuilder: (context, index) {
                      final product = differences[index];
                      int systemStock =
                          (product['stock'] as num?)?.toInt() ?? 0;
                      int actualStock = product['actual_stock'] as int;
                      int diff = actualStock - systemStock;

                      return Card(
                        child: ListTile(
                          title: Text(
                            product['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'النظام: $systemStock  |  الفعلي: $actualStock',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: diff > 0
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              diff > 0 ? '+$diff زيادة' : '$diff عجز',
                              style: TextStyle(
                                color: diff > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خيارات التسوية:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      RadioListTile<int>(
                        title: const Text('تعديل الأرقام فقط'),
                        subtitle: const Text('لا يؤثر على الحسابات المالية'),
                        value: 0,
                        groupValue: _settlementOption,
                        onChanged: (val) =>
                            setState(() => _settlementOption = val!),
                      ),
                      RadioListTile<int>(
                        title: const Text('تسجيل عجز أو زيادة مالياً'),
                        subtitle: const Text(
                          'سيتم تسجيل العجز كمصروف والزيادة كإيراد',
                        ),
                        value: 1,
                        groupValue: _settlementOption,
                        onChanged: (val) =>
                            setState(() => _settlementOption = val!),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.blue[900],
                          ),
                          onPressed: _isProcessing ? null : _approveInventory,
                          child: _isProcessing
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'اعتماد الجرد',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
