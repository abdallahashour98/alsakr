import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:al_sakr/features/store/controllers/store_controller.dart';
import 'package:al_sakr/features/store/presentations/inventory_review_screen.dart';
import 'package:al_sakr/pdf/inventory_pdf_service.dart';
import 'package:al_sakr/pdf/pdf_preview_screen.dart';

class InventoryCountingScreen extends ConsumerStatefulWidget {
  final int scope; // 0 for all, 1 for specific

  const InventoryCountingScreen({super.key, required this.scope});

  @override
  ConsumerState<InventoryCountingScreen> createState() =>
      _InventoryCountingScreenState();
}

class _InventoryCountingScreenState
    extends ConsumerState<InventoryCountingScreen> {
  final Map<String, TextEditingController> _controllers = {};
  String _searchQuery = '';

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _reviewInventory(List<Map<String, dynamic>> products) {
    // Collect entered quantities
    List<Map<String, dynamic>> countedProducts = [];
    for (var product in products) {
      String id = product['id'];
      if (_controllers.containsKey(id) && _controllers[id]!.text.isNotEmpty) {
        int actualStock = int.tryParse(_controllers[id]!.text) ?? 0;
        countedProducts.add({...product, 'actual_stock': actualStock});
      }
    }

    if (countedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال الكمية الفعلية لصنف واحد على الأقل'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            InventoryReviewScreen(countedProducts: countedProducts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(storeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد المخزون'),
        actions: [
          if (widget.scope == 0) // Only show print for "All" scope
            productsAsync.when(
              data: (products) => IconButton(
                icon: const Icon(Icons.print),
                tooltip: 'طباعة ورقة الجرد',
                onPressed: () {
                  final validProducts = products
                      .where(
                        (p) => p['is_deleted'] != 1 && p['is_deleted'] != true,
                      )
                      .toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfPreviewScreen(
                        title: 'معاينة طباعة ورقة الجرد',
                        generatePdf: (format) =>
                            InventoryPdfService.generateInventorySheetBytes(
                              validProducts,
                            ),
                      ),
                    ),
                  );
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (products) {
          var filteredList = products.where((p) {
            if (p['is_deleted'] == 1 || p['is_deleted'] == true) return false;
            final name = (p['name'] ?? '').toString().toLowerCase();
            final code = (p['code'] ?? '').toString().toLowerCase();
            final barcode = (p['barcode'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                code.contains(_searchQuery.toLowerCase()) ||
                barcode.contains(_searchQuery.toLowerCase());
          }).toList();

          return Column(
            children: [
              if (widget.scope == 1)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'بحث عن صنف...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final product = filteredList[index];
                    final id = product['id'];

                    if (!_controllers.containsKey(id)) {
                      _controllers[id] = TextEditingController();
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _controllers[id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الكمية الفعلية',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Text(
                                product['name'],
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
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
      floatingActionButton: productsAsync.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _reviewInventory(productsAsync.value!),
              icon: const Icon(Icons.fact_check),
              label: const Text('مراجعة الجرد'),
            )
          : null,
    );
  }
}
