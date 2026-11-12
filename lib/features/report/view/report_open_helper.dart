// lib/features/report/view/report_open_helper.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/loading_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../model/report_item.dart';
import '../view_model/report_list_view_model.dart';
import '../widgets/report_filter_dialog.dart';
import 'report_pdf_viewer_screen.dart';
import 'report_table_screen.dart';

/// Membuka sebuah item laporan:
/// - `kind == link`  → route in-app
/// - `kind == table` → layar tabel langsung
/// - `kind == pdf`   → dialog filter → generate → PDF viewer
///
/// Dipakai oleh layar daftar laporan & layar Favorit.
Future<void> openReportItem(BuildContext context, ReportItem item) async {
  if (item.comingSoon) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Laporan ini segera tersedia.')),
    );
    return;
  }
  if (item.kind == ReportKind.link) {
    Navigator.of(context).pushNamed(item.route ?? '/');
    return;
  }
  if (item.kind == ReportKind.table) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportTableScreen(item: item),
      ),
    );
    return;
  }
  final vm = ReportListViewModel(apiClient: context.read<ApiClient>());
  // Vm direferensikan oleh closure onGenerate/onRegenerate — tidak di-dispose
  // (dieksekusi setelah dialog tutup).
  final warehouseOptions = item.isWarehouseReport
      ? await vm.loadWarehouseOptions()
      : const ['ALL'];
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReportFilterDialog(
      title: item.title,
      icon: item.icon,
      fields: item.fields,
      warehouseOptions: warehouseOptions,
      onGenerate: (values) => _generateAndShow(context, vm, item, values),
    ),
  );
}

Future<void> _generateAndShow(
  BuildContext context,
  ReportListViewModel vm,
  ReportItem item,
  Map<String, String> values,
) async {
  // showDialog memakai root navigator; LoadingDialog dan PDF viewer juga
  // memakai root navigator — jangan pop lewat shell navigator (tidak akan
  // mengubah apa pun di sana).
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const LoadingDialog(message: 'Mengunduh laporan...'),
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
    final bytes = await vm.generateReport(item: item, values: values);

    if (!context.mounted) {
      closeLoader();
      return;
    }
    closeLoader();

    final dateKeys = item.fields
        .where((f) => f.type == 'date')
        .map((f) => f.key)
        .toList();
    final isSingleDate = dateKeys.length <= 1;
    final startDate = dateKeys.isEmpty
        ? DateTime.now()
        : (DateTime.tryParse(values[dateKeys.first]!) ?? DateTime.now());
    final endDate = dateKeys.length > 1
        ? (DateTime.tryParse(values[dateKeys.last]!) ?? startDate)
        : startDate;
    final df = DateFormat('yyyy-MM-dd');

    await ReportPdfViewerScreen.push(
      context: context,
      title: item.title,
      pdfBytes: bytes,
      isSingleDate: isSingleDate,
      startDate: startDate,
      endDate: endDate,
      onRegenerate: (s, e) {
        final next = Map<String, String>.from(values);
        if (dateKeys.isNotEmpty) next[dateKeys.first] = df.format(s);
        if (dateKeys.length > 1) next[dateKeys.last] = df.format(e);
        return vm.generateReport(item: item, values: next);
      },
    );
  } catch (e) {
    closeLoader();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Gagal membuka PDF: ${apiErrorMessage(e)}'),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  } finally {
    closeLoader();
  }
}
