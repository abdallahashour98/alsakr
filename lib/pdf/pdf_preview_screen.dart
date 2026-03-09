import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// شاشة معاينة المستند (PDF Preview)
/// قابلة لإعادة الاستخدام مع أي نوع PDF (فواتير، أذونات تسليم، مرتجعات...)
class PdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function(PdfPageFormat) generatePdf;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.generatePdf,
    this.title = 'معاينة المستند',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: PdfPreview(
        build: generatePdf,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'preview.pdf',
      ),
    );
  }
}
