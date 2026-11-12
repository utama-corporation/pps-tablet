import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../../production/shared/widgets/production_output_detail_dialog.dart';
import '../model/barang_dagang_label.dart';
import '../repository/barang_dagang_label_repository.dart';

class BarangDagangDetailDialog extends StatelessWidget {
  const BarangDagangDetailDialog({
    super.key,
    required this.label,
    required this.repository,
    required this.onPrinted,
  });
  final BarangDagangLabel label;
  final BarangDagangLabelRepository repository;
  final VoidCallback onPrinted;
  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionViewModel>();
    if (!perm.can('label_barangdagang:read')) {
      return const AlertDialog(
        title: Text('Akses ditolak'),
        content: Text('Anda tidak memiliki akses ke Label Barang Dagang.'),
      );
    }
    return ProductionOutputDetailDialog(
      labelCode: label.code,
      namaJenis: label.name,
      printCount: label.printCount,
      accentColor: const Color(0xFF0C66E4),
      pdfUrl: ApiConstants.barangDagangLabelPdf(label.code),
      feature: 'barang_dagang',
      canPrint: perm.can('label_barangdagang:update') && label.hasStock,
      markAsPrinted: () async {
        final count = await repository.markAsPrinted(label.code);
        onPrinted();
        return count;
      },
      metrics: [
        ProductionMetric(
          label: 'Qty awal',
          icon: Icons.numbers_outlined,
          text: '${formatPcsQty(label.qty)} PCS',
        ),
        ProductionMetric(
          label: 'Qty berjalan',
          icon: Icons.inventory_2_outlined,
          text: '${formatPcsQty(label.remainingQty)} PCS',
        ),
        ProductionMetric(
          label: 'Status',
          icon: Icons.verified_outlined,
          text: label.usageStatus.label,
        ),
        if (label.supplier.isNotEmpty)
          ProductionMetric(
            label: 'Supplier',
            icon: Icons.local_shipping_outlined,
            text: label.supplier,
          ),
        if (label.receipt.isNotEmpty)
          ProductionMetric(
            label: 'Penerimaan',
            icon: Icons.receipt_long_outlined,
            text: label.receipt,
          ),
        if (label.location.isNotEmpty)
          ProductionMetric(
            label: 'Lokasi',
            icon: Icons.location_on_outlined,
            text: label.location,
          ),
        if (label.notes.isNotEmpty)
          ProductionMetric(
            label: 'Keterangan',
            icon: Icons.notes_outlined,
            text: label.notes,
          ),
      ],
    );
  }
}
