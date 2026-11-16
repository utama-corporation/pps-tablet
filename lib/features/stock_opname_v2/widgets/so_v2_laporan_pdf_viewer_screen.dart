import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../../common/widgets/scoped_report_pdf_viewer_screen.dart';

/// Preview laporan PDF stock opname v2 — wrapper tipis di atas
/// [ScopedReportPdfViewerScreen] dengan subtitle khusus.
/// API publik dipertahankan supaya pemanggil lama tidak berubah.
class SoV2LaporanPdfViewerScreen extends StatelessWidget {
  final String title;
  final Uint8List pdfBytes;

  const SoV2LaporanPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfBytes,
  });

  static Future<void> push({
    required BuildContext context,
    required String title,
    required Uint8List pdfBytes,
  }) {
    return ScopedReportPdfViewerScreen.push(
      context: context,
      title: title,
      pdfBytes: pdfBytes,
      subtitle: 'Laporan Stock Opname',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScopedReportPdfViewerScreen(
      title: title,
      pdfBytes: pdfBytes,
      subtitle: 'Laporan Stock Opname',
    );
  }
}
