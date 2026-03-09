import 'package:flutter/material.dart';
import 'package:al_sakr/features/store/presentations/inventory_counting_screen.dart';

class InventorySetupScreen extends StatefulWidget {
  const InventorySetupScreen({super.key});

  @override
  State<InventorySetupScreen> createState() => _InventorySetupScreenState();
}

class _InventorySetupScreenState extends State<InventorySetupScreen> {
  int _selectedScope = 0; // 0 for all, 1 for specific

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات جرد المخزون')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نطاق الجرد:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RadioListTile<int>(
              title: const Text('جرد كل المخزن'),
              value: 0,
              groupValue: _selectedScope,
              onChanged: (val) => setState(() => _selectedScope = val!),
            ),
            RadioListTile<int>(
              title: const Text('جرد صنف محدد  '),
              value: 1,
              groupValue: _selectedScope,
              onChanged: (val) => setState(() => _selectedScope = val!),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء الجرد'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          InventoryCountingScreen(scope: _selectedScope),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
