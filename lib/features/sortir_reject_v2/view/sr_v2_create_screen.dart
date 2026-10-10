import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/scan_label_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../mst_barang_jadi/widgets/barang_jadi_dropdown.dart';
import '../../reject_type/widgets/packing_type_dropdown.dart';
import '../../warehouse/model/warehouse_model.dart';
import '../../warehouse/widgets/warehouse_dropdown.dart';
import '../model/sr_v2_label_info.dart';
import '../view_model/sr_v2_create_view_model.dart';

// â”€â”€â”€ Theme constants â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kGreen = Color(0xFF0A7349);
const _kRadius = 12.0;

// â”€â”€â”€ Shared helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_kRadius),
  border: Border.all(color: borderColor ?? _kBorder),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ],
);

Widget _sectionHeader(IconData icon, String title, {Color? iconColor}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (iconColor ?? _kPrimary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: iconColor ?? _kPrimary),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1D23),
        ),
      ),
    ],
  );
}

// â”€â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class SrV2CreateScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;

  const SrV2CreateScreen({super.key, this.onSubmitted});

  @override
  State<SrV2CreateScreen> createState() => _SrV2CreateScreenState();
}

class _SrV2CreateScreenState extends State<SrV2CreateScreen> {
  final Map<String, TextEditingController> _pcsCtls = {};
  final Map<String, TextEditingController> _beratCtls = {};
  final NumberFormat _nf = NumberFormat('#,##0', 'id_ID');

  @override
  void dispose() {
    for (final c in _pcsCtls.values) {
      c.dispose();
    }
    for (final c in _beratCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _pcsCtl(String outputId, int current) =>
      _pcsCtls.putIfAbsent(
        outputId,
        () =>
            TextEditingController(text: current > 0 ? current.toString() : ''),
      );

  TextEditingController _beratCtl(String outputId, double current) =>
      _beratCtls.putIfAbsent(
        outputId,
        () => TextEditingController(text: current > 0 ? '$current' : ''),
      );

  void _cleanupCtls(SrV2CreateViewModel vm) {
    final validIds = vm.outputs.map((o) => o.id).toSet();
    _pcsCtls.removeWhere((k, v) {
      if (!validIds.contains(k)) {
        v.dispose();
        return true;
      }
      return false;
    });
    _beratCtls.removeWhere((k, v) {
      if (!validIds.contains(k)) {
        v.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> _openScanDialog(
    BuildContext context,
    SrV2CreateViewModel vm,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        onLookup: (code) async {
          await vm.lookupLabel(code);
          return vm.lookupError;
        },
        manualHint: 'BA / BB / BP / BF.0000000001',
        acceptedLabels: const [
          (prefix: 'BB', label: 'Furniture WIP'),
          (prefix: 'BA', label: 'Barang Jadi'),
          (prefix: 'BP', label: 'Bahan Pendukung'),
        ],
      ),
    );
  }

  Future<void> _addOutput(BuildContext context, SrV2CreateViewModel vm) async {
    var type = vm.nextOutputType;
    type ??= await showDialog<SrV2OutputType>(
      context: context,
      builder: (_) => const _OutputTypeDialog(),
    );
    if (type == null) return;
    vm.addOutput(type: type, idJenis: 0, namaJenis: '');
  }

  Future<void> _clearOutputMode(
    BuildContext context,
    SrV2CreateViewModel vm,
  ) async {
    if (!vm.canChangeOutputMode) return;
    if (vm.outputs.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _ClearOutputModeConfirmDialog(),
      );
      if (confirmed != true) return;
    }
    vm.clearOutputMode();
  }

  Future<void> _submit(BuildContext context, SrV2CreateViewModel vm) async {
    final picked = await showDialog<MstWarehouse>(
      context: context,
      builder: (_) => const _WarehousePickerDialog(),
    );
    if (picked == null || !context.mounted) return;
    vm.setWarehouse(picked);

    final result = await vm.submit();
    if (!context.mounted) return;
    if (result != null) {
      widget.onSubmitted?.call();
      await showDialog(
        context: context,
        builder: (_) => SuccessStatusDialog(
          title: 'Berhasil Submit',
          message: 'Data berhasil dibuat dengan nomor ${result.noSortir}',
        ),
      );
      if (context.mounted) Navigator.of(context).pop();
    } else {
      showDialog(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Gagal Submit',
          message: vm.submitError ?? 'Terjadi kesalahan',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SrV2CreateViewModel>(
      builder: (context, vm, _) {
        _cleanupCtls(vm);
        return Scaffold(
          backgroundColor: _kSurface,
          resizeToAvoidBottomInset: false,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ LEFT PANEL: Label Input â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SizedBox(
                  width: 320,
                  child: _InputsCard(
                    inputs: vm.inputs,
                    onRemove: vm.removeInput,
                    onScan: () => _openScanDialog(context, vm),
                    nf: _nf,
                  ),
                ),
                const SizedBox(width: 16),
                // Output panel
                Expanded(
                  child: _OutputsPanel(
                    vm: vm,
                    nf: _nf,
                    pcsCtlOf: _pcsCtl,
                    beratCtlOf: _beratCtl,
                    onAddOutput: () => _addOutput(context, vm),
                    onClearMode: () => _clearOutputMode(context, vm),
                  ),
                ),
                const SizedBox(width: 16),
                // â”€â”€ RIGHT PANEL: Summary + Submit â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SizedBox(
                  width: 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.inputs.isNotEmpty || vm.outputs.isNotEmpty) ...[
                        _PcsSummaryCard(vm: vm, nf: _nf),
                        const SizedBox(height: 12),
                      ],
                      _SubmitCard(vm: vm, onSubmit: () => _submit(context, vm)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// â”€â”€â”€ Inputs Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InputsCard extends StatelessWidget {
  final List<SrV2LabelInfo> inputs;
  final void Function(String) onRemove;
  final VoidCallback onScan;
  final NumberFormat nf;

  const _InputsCard({
    required this.inputs,
    required this.onRemove,
    required this.onScan,
    required this.nf,
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
                _sectionHeader(Icons.input_rounded, 'Label Input'),
                const Spacer(),
                if (inputs.isNotEmpty) ...[
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
                      '${inputs.length} label',
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
            child: inputs.isEmpty
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
                    itemCount: inputs.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: _kBorder,
                    ),
                    itemBuilder: (_, i) => _InputLabelTile(
                      lbl: inputs[i],
                      nf: nf,
                      onRemove: onRemove,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InputLabelTile extends StatelessWidget {
  final SrV2LabelInfo lbl;
  final NumberFormat nf;
  final void Function(String) onRemove;

  const _InputLabelTile({
    required this.lbl,
    required this.nf,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Bahan pendukung memakai qty dari dbo.BahanPendukung.Qty yang bisa
    // pecahan, jadi ditampilkan apa adanya; label lain tetap pcs bulat.
    final qtyText = lbl.isBahanPendukung
        ? NumberFormat('#,##0.##', 'id_ID').format(lbl.qty)
        : nf.format(lbl.pcs);
    final unit = lbl.isBahanPendukung ? '' : ' pcs';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lbl.labelCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lbl.namaJenis,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$qtyText$unit',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D23),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => onRemove(lbl.labelCode),
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

// â”€â”€â”€ Outputs Panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _OutputsPanel extends StatelessWidget {
  final SrV2CreateViewModel vm;
  final NumberFormat nf;
  final TextEditingController Function(String outputId, int current) pcsCtlOf;
  final TextEditingController Function(String outputId, double current)
  beratCtlOf;
  final VoidCallback onAddOutput;
  final VoidCallback onClearMode;

  const _OutputsPanel({
    required this.vm,
    required this.nf,
    required this.pcsCtlOf,
    required this.beratCtlOf,
    required this.onAddOutput,
    required this.onClearMode,
  });

  String _modeLabel(SrV2OutputType type) {
    switch (type) {
      case SrV2OutputType.barangJadi:
        return 'Barang Jadi';
      case SrV2OutputType.reject:
        return 'Reject';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(borderColor: _kGreen.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                _sectionHeader(
                  Icons.output_rounded,
                  'Label Output',
                  iconColor: _kGreen,
                ),
                const Spacer(),
                if (vm.outputs.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${vm.outputs.length} label',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Material(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onAddOutput,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Tambah',
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
                if (vm.outputMode != null && vm.canChangeOutputMode) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: onClearMode,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.clear_rounded,
                              size: 15,
                              color: Colors.red.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: Builder(
              builder: (context) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                if (vm.outputs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_box_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tekan "Tambah Output" untuk mulai',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: vm.outputs.length,
                    itemBuilder: (context, i) {
                      final out = vm.outputs[i];
                      return _OutputCard(
                        key: ValueKey(out.id),
                        entry: out,
                        index: i,
                        vm: vm,
                        nf: nf,
                        pcsCtlOf: pcsCtlOf,
                        beratCtlOf: beratCtlOf,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final SrV2OutputEntry entry;
  final int index;
  final SrV2CreateViewModel vm;
  final NumberFormat nf;
  final TextEditingController Function(String, int) pcsCtlOf;
  final TextEditingController Function(String, double) beratCtlOf;

  const _OutputCard({
    super.key,
    required this.entry,
    required this.index,
    required this.vm,
    required this.nf,
    required this.pcsCtlOf,
    required this.beratCtlOf,
  });

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kGreen, width: 1.5),
    ),
    filled: true,
    fillColor: _kSurface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );

  @override
  Widget build(BuildContext context) {
    final isValid =
        entry.idJenis > 0 && (entry.isReject ? entry.berat > 0 : entry.pcs > 0);
    final pcsCtl = pcsCtlOf(entry.id, entry.pcs);
    final beratCtl = beratCtlOf(entry.id, entry.berat);
    final typeLabel = entry.isReject ? 'Reject' : 'Barang Jadi';
    final beratText = NumberFormat('#,##0.##', 'id_ID').format(entry.berat);
    final qtyLabel = entry.isReject
        ? (entry.berat > 0 ? '$beratText kg' : '')
        : (entry.pcs > 0 ? '${nf.format(entry.pcs)} pcs' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(
        borderColor: isValid ? _kBorder : Colors.red.shade300,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isValid ? const Color(0xFFF0FDF4) : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kRadius),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isValid
                      ? const Color(0xFFD1FAE5)
                      : Colors.red.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isValid ? _kGreen : Colors.red.shade400,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$typeLabel #${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (qtyLabel.isNotEmpty)
                  Text(
                    qtyLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isValid ? _kGreen : Colors.red.shade700,
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => vm.removeOutput(entry.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Card body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.isReject)
                  RejectTypeDropdown(
                    preselectId: entry.idJenis > 0 ? entry.idJenis : null,
                    onChanged: (val) {
                      if (val != null) {
                        vm.updateOutputJenis(
                          entry.id,
                          val.idReject,
                          val.namaReject,
                        );
                      }
                    },
                  )
                else
                  BarangJadiDropdown(
                    preselectId: entry.idJenis > 0 ? entry.idJenis : null,
                    onChanged: (val) {
                      if (val != null) {
                        vm.updateOutputJenis(
                          entry.id,
                          val.idJenis,
                          val.namaJenis,
                        );
                      }
                    },
                    fieldHeight: 44,
                  ),
                const SizedBox(height: 12),
                if (entry.isReject)
                  TextField(
                    controller: beratCtl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                    ],
                    decoration: _fieldDecoration(
                      'Berat',
                    ).copyWith(suffixText: 'kg'),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (context.mounted) {
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: 1.0,
                          );
                        }
                      });
                    },
                    onChanged: (v) {
                      final d = double.tryParse(v.trim().replaceAll(',', '.'));
                      vm.updateOutputBerat(entry.id, d ?? 0);
                    },
                  )
                else
                  TextField(
                    controller: pcsCtl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _fieldDecoration('Pcs').copyWith(
                      suffixIcon: vm.remainingPcs > 0
                          ? _MaxButton(
                              onTap: () {
                                final max = vm.remainingPcs + entry.pcs;
                                pcsCtl.text = max.toString();
                                vm.updateOutputPcs(entry.id, max);
                              },
                            )
                          : null,
                    ),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (context.mounted) {
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            alignment: 1.0,
                          );
                        }
                      });
                    },
                    onChanged: (v) {
                      final d = int.tryParse(v);
                      if (d != null) vm.updateOutputPcs(entry.id, d);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaxButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MaxButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _kGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Max',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kGreen,
            height: 3,
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€ WIP Info Panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _OutputTypeDialog extends StatelessWidget {
  final String title;

  const _OutputTypeDialog({this.title = 'Pilih Output'});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: _kGreen,
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
                      Icons.output_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: _OutputTypeOption(
                      icon: Icons.inventory_2_outlined,
                      title: 'Barang Jadi',
                      subtitle: 'Jenis barang jadi dan pcs',
                      color: _kGreen,
                      onTap: () =>
                          Navigator.of(context).pop(SrV2OutputType.barangJadi),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OutputTypeOption(
                      icon: Icons.report_problem_outlined,
                      title: 'Reject',
                      subtitle: 'Jenis reject dan berat',
                      color: Colors.red.shade500,
                      onTap: () =>
                          Navigator.of(context).pop(SrV2OutputType.reject),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearOutputModeConfirmDialog extends StatelessWidget {
  const _ClearOutputModeConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 96, vertical: 140),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Clear pilihan output?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Mode output dan semua output yang sudah dibuat akan dihapus. Setelah itu pilih Barang Jadi atau Reject lagi saat tambah output.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutputTypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OutputTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 126,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: color),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PcsSummaryCard extends StatelessWidget {
  final SrV2CreateViewModel vm;
  final NumberFormat nf;

  const _PcsSummaryCard({required this.vm, required this.nf});

  @override
  Widget build(BuildContext context) {
    final hasReject = vm.hasRejectOutput;
    final remaining = vm.remainingPcs;
    final balanced = hasReject || remaining == 0;
    final over = remaining < 0;
    final progress = hasReject
        ? 1.0
        : vm.totalPcsInput > 0
        ? ((vm.totalPcsInput - remaining.clamp(0, vm.totalPcsInput)) /
                  vm.totalPcsInput)
              .clamp(0.0, 1.0)
        : 0.0;
    final barColor = over ? Colors.red : (balanced ? _kGreen : _kPrimary);
    // Bahan pendukung: output selalu reject (berat), input diukur qty dari
    // label BP.-modul lain tetap pcs.
    final isBahanPendukung = vm.isBahanPendukungInput;
    final qtyNf = NumberFormat('#,##0.##', 'id_ID');
    final inputText = isBahanPendukung
        ? qtyNf.format(vm.totalQtyInput)
        : nf.format(vm.totalPcsInput);
    final inputUnit = isBahanPendukung ? '' : ' pcs';
    final rejectKgText = qtyNf.format(vm.totalBeratReject);

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.balance_rounded,
            hasReject ? 'Konversi ke Reject' : 'Alokasi Pcs',
            iconColor: _kGreen,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasReject ? 'Input -> Reject' : 'Barang Jadi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D23),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hasReject
                    ? '$inputText$inputUnit -> $rejectKgText kg'
                    : balanced
                    ? 'Seimbang'
                    : over
                    ? 'Lebih ${nf.format(-remaining)} pcs'
                    : 'Sisa ${nf.format(remaining)} pcs',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: balanced
                      ? _kGreen
                      : (over ? Colors.red : Colors.orange.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hasReject
                ? 'Input: $inputText$inputUnit  -  Reject: $rejectKgText kg'
                : 'Input: ${nf.format(vm.totalPcsInput)} pcs  -  Output: ${nf.format(vm.totalPcsOutput)} pcs',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _SubmitCard extends StatelessWidget {
  final SrV2CreateViewModel vm;
  final VoidCallback onSubmit;

  const _SubmitCard({required this.vm, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final canSubmit = vm.isBalanced && !vm.isSubmitting;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _stat(
                Icons.input_rounded,
                '${vm.inputs.length}',
                'Input',
                const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              _stat(
                Icons.output_rounded,
                '${vm.outputs.length}',
                'Output',
                _kGreen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: canSubmit ? _kGreen : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(_kRadius),
              boxShadow: canSubmit
                  ? [
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(_kRadius),
              child: InkWell(
                onTap: canSubmit ? onSubmit : null,
                borderRadius: BorderRadius.circular(_kRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (vm.isSubmitting)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: canSubmit
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        vm.isSubmitting ? 'Menyimpan...' : 'Submit Transaksi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: canSubmit
                              ? Colors.white
                              : Colors.grey.shade400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!vm.isBalanced &&
              (vm.inputs.isNotEmpty || vm.outputs.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      !vm.allOutputsValid
                          ? 'Setiap output wajib memiliki jenis dan qty > 0'
                          : 'Total pcs output belum seimbang dengan input',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€ Warehouse Picker Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _WarehousePickerDialog extends StatefulWidget {
  const _WarehousePickerDialog();

  @override
  State<_WarehousePickerDialog> createState() => _WarehousePickerDialogState();
}

class _WarehousePickerDialogState extends State<_WarehousePickerDialog> {
  MstWarehouse? _selected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 100),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                      Icons.warehouse_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Pilih Warehouse',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WarehouseDropdown(
                    onChanged: (val) => setState(() => _selected = val),
                    label: 'Warehouse',
                    hint: 'PILIH WAREHOUSE',
                    fieldHeight: 48,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _selected != null
                          ? () => Navigator.of(context).pop(_selected)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Konfirmasi & Submit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selected != null
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
