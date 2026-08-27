import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/common/widgets/scan_label_dialog.dart';
import 'package:pps_tablet/common/widgets/error_status_dialog.dart';
import 'package:pps_tablet/common/widgets/success_status_dialog.dart';
import 'package:pps_tablet/features/warehouse/widgets/warehouse_dropdown.dart';
import 'package:pps_tablet/features/warehouse/model/warehouse_model.dart';

import '../model/goods_transfer_scanned_label.dart';
import '../repository/goods_transfer_repository.dart';
import '../view_model/goods_transfer_create_view_model.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kRadius = 12.0;

final NumberFormat _nf = NumberFormat('#,##0.###', 'id_ID');

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_kRadius),
  border: Border.all(color: _kBorder),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ],
);

/// Dialog "Buat Goods Transfer". Panggil dengan:
/// `showDialog(context: context, builder: (_) => const GoodsTransferCreateDialog())`
class GoodsTransferCreateDialog extends StatelessWidget {
  const GoodsTransferCreateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GoodsTransferCreateViewModel(
        repository: GoodsTransferRepository(api: ApiClient()),
      ),
      child: const _GoodsTransferCreateView(),
    );
  }
}

class _GoodsTransferCreateView extends StatefulWidget {
  const _GoodsTransferCreateView();

  @override
  State<_GoodsTransferCreateView> createState() =>
      _GoodsTransferCreateViewState();
}

class _GoodsTransferCreateViewState extends State<_GoodsTransferCreateView> {
  final _catatanCtrl = TextEditingController();

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _openScanDialog(
    BuildContext context,
    GoodsTransferCreateViewModel vm,
  ) async {
    if (vm.idWarehouseAsal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih warehouse asal terlebih dahulu')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        onLookup: (code) => vm.lookupLabel(code),
        manualHint: 'A.0000000001',
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    GoodsTransferCreateViewModel vm,
  ) async {
    final ok = await vm.submit();
    if (!context.mounted) return;

    if (ok) {
      await showDialog(
        context: context,
        builder: (_) => SuccessStatusDialog(
          title: 'Berhasil Dibuat',
          message: 'Goods Transfer ${vm.createdNoTransfer} berhasil dibuat',
        ),
      );
      if (context.mounted) Navigator.of(context).pop();
    } else {
      showDialog(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Gagal Membuat Transfer',
          message: vm.error.isNotEmpty ? vm.error : 'Terjadi kesalahan',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GoodsTransferCreateViewModel>(
      builder: (context, vm, _) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 40,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
            decoration: const BoxDecoration(color: _kSurface),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── LEFT PANEL: Header ─────────────────────────
                        SizedBox(
                          width: 320,
                          child: _HeaderCard(
                            vm: vm,
                            catatanCtrl: _catatanCtrl,
                            onSubmit: () => _submit(context, vm),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // ── RIGHT PANEL: Label yang akan ditransfer ─────
                        Expanded(
                          child: _LabelsCard(
                            labels: vm.scannedLabels,
                            onRemove: vm.removeLabel,
                            onScan: () => _openScanDialog(context, vm),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Buat Goods Transfer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Left panel: header form ────────────────────────────────────────────────

class _HeaderCard extends StatefulWidget {
  final GoodsTransferCreateViewModel vm;
  final TextEditingController catatanCtrl;
  final VoidCallback onSubmit;

  const _HeaderCard({
    required this.vm,
    required this.catatanCtrl,
    required this.onSubmit,
  });

  @override
  State<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<_HeaderCard> {
  // Dinaikkan tiap kali user membatalkan ganti warehouse asal, supaya
  // WarehouseDropdown di-remount dan tampilannya kembali ke pilihan lama
  // (widget itu sendiri tidak punya API untuk "revert" selection).
  int _asalResetToken = 0;

  Future<void> _handleWarehouseAsalChange(
    BuildContext context,
    MstWarehouse? w,
  ) async {
    final vm = widget.vm;
    final newId = w?.idWarehouse;
    if (newId == vm.idWarehouseAsal) return;

    if (vm.scannedLabels.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ganti Warehouse Asal'),
          content: Text(
            'Warehouse asal akan diganti dan ${vm.scannedLabels.length} '
            'label yang sudah discan akan dihapus dari daftar. Lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Ya, Ganti'),
            ),
          ],
        ),
      );
      if (confirm != true) {
        if (mounted) setState(() => _asalResetToken++);
        return;
      }
    }

    vm.setWarehouseAsal(newId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final catatanCtrl = widget.catatanCtrl;
    final onSubmit = widget.onSubmit;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No. Goods Transfer',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                'Otomatis saat disimpan',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            WarehouseDropdown(
              key: ValueKey('gt-asal-${vm.idWarehouseAsal}-$_asalResetToken'),
              label: 'Warehouse Asal',
              hint: 'Pilih warehouse pengirim',
              preselectId: vm.idWarehouseAsal,
              onChanged: (w) => _handleWarehouseAsalChange(context, w),
            ),
            const SizedBox(height: 12),
            WarehouseDropdown(
              label: 'Warehouse Tujuan',
              hint: 'Pilih warehouse penerima',
              onChanged: (w) => context
                  .read<GoodsTransferCreateViewModel>()
                  .setWarehouseTujuan(w?.idWarehouse),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: catatanCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (v) =>
                  context.read<GoodsTransferCreateViewModel>().setCatatan(v),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${vm.scannedLabels.length} label siap ditransfer',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                ),
              ),
            ),
            if (vm.error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                vm.error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: vm.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Kirim Transfer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Right panel: daftar label hasil scan ────────────────────────────────────

class _LabelsCard extends StatelessWidget {
  final List<GoodsTransferScannedLabel> labels;
  final void Function(String) onRemove;
  final VoidCallback onScan;

  const _LabelsCard({
    required this.labels,
    required this.onRemove,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Label yang Ditransfer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const Spacer(),
                if (labels.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${labels.length} label',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Material(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onScan,
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 15,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Scan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: labels.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada label di-scan',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: labels.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: _kBorder,
                    ),
                    itemBuilder: (_, i) =>
                        _LabelTile(label: labels[i], onRemove: onRemove),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LabelTile extends StatelessWidget {
  final GoodsTransferScannedLabel label;
  final void Function(String) onRemove;

  const _LabelTile({required this.label, required this.onRemove});

  String get _qtyBeratText {
    if (label.isPcsUom) {
      return '${_nf.format(label.qty ?? 0)} pcs';
    }
    return '${_nf.format(label.berat ?? 0)} kg';
  }

  String get _lokasiText {
    if ((label.blok ?? '').isEmpty) return '-';
    return '${label.blok}${label.idLokasi ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label.prefix,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.namaJenis?.isNotEmpty == true
                      ? label.namaJenis!
                      : label.labelCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.labelCode,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _qtyBeratText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _lokasiText,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onRemove(label.labelCode),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
