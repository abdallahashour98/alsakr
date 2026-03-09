import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';

import 'package:al_sakr/core/services/settings_service.dart';

class InventoryPdfService {
  static Future<Uint8List> generateInventorySheetBytes(
    List<Map<String, dynamic>> products,
  ) async {
    final pdf = pw.Document();

    String address = 'Address not set';
    String phone = '---';
    String mobile = '---';
    String Website = '---';
    String email = '---';

    try {
      final companyData = await SettingsService().getCompanySettings();
      address = companyData['address'] ?? address;
      phone = companyData['phone'] ?? phone;
      mobile = companyData['mobile'] ?? mobile;
      Website = companyData['website'] ?? Website;
      email = companyData['email'] ?? email;
    } catch (_) {}

    String formattedDate = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.now());

    final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    pw.Font ttfBold = ttf;
    try {
      final fontDataBold = await rootBundle.load("assets/fonts/Amiri-Bold.ttf");
      ttfBold = pw.Font.ttf(fontDataBold);
    } catch (_) {}

    pw.MemoryImage? imageProvider;
    try {
      final logoImage = await rootBundle.load('assets/splash_logo.png');
      imageProvider = pw.MemoryImage(logoImage.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.ltr,

        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (imageProvider != null)
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.Image(imageProvider),
                      ),
                    if (imageProvider != null) pw.SizedBox(width: 10),
                    pw.Container(width: 1, height: 80, color: PdfColors.black),
                    pw.SizedBox(width: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 5),
                        pw.Text(
                          address,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Text(
                          "$phone / $mobile",
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Text(
                          Website,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Text(
                          email,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  width: 180,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "ورقة جرد المخزن",
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Divider(color: PdfColors.grey400),
                      _buildInfoRow("DATE:", formattedDate),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40), // Serial
                  1: const pw.FlexColumnWidth(3), // Name
                  2: const pw.FlexColumnWidth(1), // Actual Qty
                  3: const pw.FlexColumnWidth(2), // Notes
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _buildCell("م", isHeader: true),
                      _buildCell("اسم الصنف", isHeader: true),
                      _buildCell("الكمية الفعلية", isHeader: true),
                      _buildCell("ملاحظات", isHeader: true),
                    ],
                  ),
                  ...List.generate(products.length, (index) {
                    final p = products[index];
                    return pw.TableRow(
                      children: [
                        _buildCell((index + 1).toString()),
                        _buildCell(
                          p['name'] ?? '',
                          align: pw.Alignment.centerLeft,
                          textDirection: pw.TextDirection.ltr,
                        ),
                        _buildCell(""), // Empty for writing
                        _buildCell(""), // Empty for notes
                      ],
                    );
                  }),
                ],
              ),
            ),
            pw.Spacer(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateInventorySheet(
    List<Map<String, dynamic>> products,
  ) async {
    final bytes = await generateInventorySheetBytes(products);
    try {
      final output = await getApplicationDocumentsDirectory();
      String formattedDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File("${output.path}/Inventory_$formattedDate.pdf");
      await file.writeAsBytes(bytes);

      if (Platform.isLinux) {
        print("PDF Saved at: ${file.path}");
      } else {
        await OpenFile.open(file.path);
      }
    } catch (e) {
      print("Error opening PDF: $e");
    }
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.right,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.center,
    pw.TextDirection textDirection = pw.TextDirection.rtl,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          textDirection: textDirection,
          style: pw.TextStyle(
            fontSize: isHeader ? 12 : 10,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? PdfColors.blue900 : PdfColors.black,
          ),
        ),
      ),
    );
  }
}
