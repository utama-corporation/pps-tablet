import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/loading_dialog.dart';
import '../../../../common/widgets/scoped_report_pdf_viewer_screen.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/services/dialog_service.dart';

/// Slug `JenisProduksi` per modul produksi — dipakai untuk membangun path
/// `/api/production/{jenisProduksi}/{noProduksi}/report/pdf`.
class ProductionJenis {
  static const String broker = 'broker';
  static const String crusher = 'crusher';
  static const String gilingan = 'gilingan';
  static const String hotStamp = 'hot-stamp';
  static const String inject = 'inject';
  static const String keyFitting = 'key-fitting';
  static const String mixer = 'mixer';
  static const String packing = 'packing';
  static const String spanner = 'spanner';
  static const String washing = 'washing';
}

/// Mengambil PDF report produksi dari server lalu membuka viewer in-app
/// dengan tombol Cetak (print native Android via `Printing.layoutPdf`).
///
/// [jenisProduksi] adalah slug modul (lihat [ProductionJenis]);
/// [noProduksi] adalah nomor produksi yang sedang dibuka.
Future<void> openProductionReportPdf(
  BuildContext context, {
  required String jenisProduksi,
  required String noProduksi,
  String? title,
}) async {
  final api = context.read<ApiClient>();
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const LoadingDialog(message: 'Menyiapkan laporan...'),
  );

  var loaderClosed = false;
  void closeLoader() {
    if (loaderClosed) return;
    loaderClosed = true;
    if (rootNavigator.mounted && rootNavigator.canPop()) {
      rootNavigator.pop();
    }
  }

  try {
    final bytes = await api.getPdfBytesForPath(
      '/api/production/$jenisProduksi/$noProduksi/report/pdf',
      timeout: const Duration(minutes: 3),
    );
    closeLoader();
    if (!context.mounted) return;
    await ScopedReportPdfViewerScreen.push(
      context: context,
      title: title ?? 'Laporan $noProduksi',
      subtitle: 'Laporan Produksi',
      pdfBytes: bytes,
    );
  } catch (e) {
    closeLoader();
    if (!context.mounted) return;
    await DialogService.instance.showError(
      title: 'Gagal Memuat Laporan',
      message: apiErrorMessage(e),
    );
  } finally {
    closeLoader();
  }
}
