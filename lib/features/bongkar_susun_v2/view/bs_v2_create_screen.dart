import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/scan_label_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../model/bs_v2_label_info.dart';
import '../utils/bs_v2_category_label.dart';
import '../view_model/bs_v2_create_view_model.dart';
import 'bs_v2_sak_detail_dialog.dart';

part 'bs_v2_create_dialogs.dart';
part 'bs_v2_create_output_panel.dart';

// ─── Theme constants ───────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kRadius = 12.0;

// ─── Shared helpers ────────────────────────────────────────────────────────

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
    mainAxisSize: MainAxisSize.min,
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
      Flexible(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D23),
          ),
        ),
      ),
    ],
  );
}

// ─── Screen ────────────────────────────────────────────────────────────────

class BsV2CreateScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;

  const BsV2CreateScreen({super.key, this.onSubmitted});

  @override
  State<BsV2CreateScreen> createState() => _BsV2CreateScreenState();
}

class _BsV2CreateScreenState extends State<BsV2CreateScreen> {
  final Map<String, TextEditingController> _beratCtls = {};
  final Map<String, TextEditingController> _sakBeratCtls = {};
  final NumberFormat _nf = NumberFormat('#,##0.###', 'id_ID');

  @override
  void dispose() {
    for (final c in _beratCtls.values) c.dispose();
    for (final c in _sakBeratCtls.values) c.dispose();
    super.dispose();
  }

  TextEditingController _beratCtl(String outputId, double current) =>
      _beratCtls.putIfAbsent(
        outputId,
        () =>
            TextEditingController(text: current > 0 ? current.toString() : ''),
      );

  TextEditingController _getSakBeratCtl(String key, double current) =>
      _sakBeratCtls.putIfAbsent(
        key,
        () =>
            TextEditingController(text: current > 0 ? current.toString() : ''),
      );

  void _cleanupCtls(BsV2CreateViewModel vm) {
    final validOutputIds = vm.outputs.map((o) => o.id).toSet();
    _beratCtls.removeWhere((k, v) {
      if (!validOutputIds.contains(k)) {
        v.dispose();
        return true;
      }
      return false;
    });
    final validSakKeys = <String>{};
    for (final o in vm.outputs) {
      for (final s in o.saks) validSakKeys.add('${o.id}_${s.id}');
    }
    _sakBeratCtls.removeWhere((k, v) {
      if (!validSakKeys.contains(k)) {
        v.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> _openScanDialog(
    BuildContext context,
    BsV2CreateViewModel vm,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        onLookup: (code) async {
          await vm.lookupLabel(code);
          return vm.lookupError;
        },
        manualHint: 'B.0000000001',
        acceptedLabels: const [
          (prefix: 'A', label: 'Bahan Baku'),
          (prefix: 'B', label: 'Washing'),
          (prefix: 'D', label: 'Broker'),
          (prefix: 'M', label: 'Bonggolan'),
          (prefix: 'V', label: 'Gilingan'),
          (prefix: 'F', label: 'Crusher'),
          (prefix: 'BB', label: 'Furniture WIP'),
          (prefix: 'BA', label: 'Barang Jadi'),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, BsV2CreateViewModel vm) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
    if (note == null || !context.mounted) return;
    vm.setNote(note);
    final result = await vm.submit();
    if (!context.mounted) return;

    if (result != null) {
      widget.onSubmitted?.call();
      await showDialog(
        context: context,
        builder: (_) => SuccessStatusDialog(
          title: 'Berhasil Submit',
          message: 'Data berhasil dibuat dengan nomor ${result.noBongkarSusun}',
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
    return Consumer<BsV2CreateViewModel>(
      builder: (context, vm, _) {
        _cleanupCtls(vm);
        final rightPanel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.inputBeratByJenis.isNotEmpty) ...[
              _BeratSummaryCard(
                inputByJenis: vm.inputBeratByJenis,
                remainingByJenis: vm.remainingByJenis,
                jenisNames: {
                  for (final j in vm.jenisOptions) j.idJenis: j.namaJenis,
                },
                nf: _nf,
                unit: vm.quantityUnit,
              ),
              const SizedBox(height: 12),
            ],
            _SubmitCard(
              isSubmitting: vm.isSubmitting,
              isBalanced: vm.isBalanced,
              allOutputsValid: vm.allOutputsValid,
              inputCount: vm.inputs.length,
              outputCount: vm.outputs.length,
              onSubmit: () => _submit(context, vm),
            ),
          ],
        );

        return Scaffold(
          backgroundColor: _kSurface,
          resizeToAvoidBottomInset: false,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                // Breakpoint: di bawah ~840px ruang tidak cukup untuk 3 kolom,
                // panel kanan (Alokasi + Submit) dipindah ke bawah.
                final stackRight = w < 840;
                final leftW = w < 720
                    ? 200.0
                    : w < 1000
                    ? 260.0
                    : 320.0;
                final rightW = w < 1000 ? 260.0 : 300.0;

                final inputCard = _InputsCard(
                  inputs: vm.inputs,
                  onRemove: vm.removeInput,
                  onScan: () => _openScanDialog(context, vm),
                  nf: _nf,
                );
                final outputPanel = _OutputsPanel(
                  vm: vm,
                  nf: _nf,
                  beratCtlOf: _beratCtl,
                  sakBeratCtlOf: _getSakBeratCtl,
                );

                if (stackRight) {
                  // Input | Output berdampingan, panel kanan di bawah (scroll).
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: leftW, child: inputCard),
                            const SizedBox(width: 12),
                            Expanded(child: outputPanel),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(child: rightPanel),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── LEFT: Label Input ──────────────────────────────────
                    SizedBox(width: leftW, child: inputCard),
                    const SizedBox(width: 16),
                    // ── CENTER: Label Output ───────────────────────────────
                    Expanded(child: outputPanel),
                    const SizedBox(width: 16),
                    // ── RIGHT: Alokasi Berat + Submit ──────────────────────
                    SizedBox(
                      width: rightW,
                      child: SingleChildScrollView(child: rightPanel),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Inputs Card ───────────────────────────────────────────────────────────

class _InputsCard extends StatelessWidget {
  final List<BsV2LabelInfo> inputs;
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
                _sectionHeader(Icons.input_rounded, 'Input'),
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
  final BsV2LabelInfo lbl;
  final NumberFormat nf;
  final void Function(String) onRemove;

  const _InputLabelTile({
    required this.lbl,
    required this.nf,
    required this.onRemove,
  });

  void _showSakDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => BsV2SakDetailDialog(lbl: lbl, nf: nf),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSaks = lbl.saks.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (hasSaks) ...[
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
                          '${lbl.jumlahSak} sak  •  ${nf.format(lbl.totalBerat)} kg',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showSakDetail(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.list_alt_rounded,
                                size: 11,
                                color: _kPrimary,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Detail',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _kPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!hasSaks)
            Text(
              '${lbl.isPcsCategory ? lbl.totalBerat.toInt() : nf.format(lbl.totalBerat)} ${lbl.isPcsCategory ? 'pcs' : 'kg'}',
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

// ─── Berat Summary ─────────────────────────────────────────────────────────

class _BeratSummaryCard extends StatelessWidget {
  final Map<int, double> inputByJenis;
  final Map<int, double> remainingByJenis;
  final Map<int, String> jenisNames;
  final NumberFormat nf;
  final String unit;

  const _BeratSummaryCard({
    required this.inputByJenis,
    required this.remainingByJenis,
    required this.jenisNames,
    required this.nf,
    this.unit = 'kg',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.balance_rounded,
            unit == 'pcs' ? 'Alokasi Pcs' : 'Alokasi Berat',
            iconColor: const Color(0xFF0A7349),
          ),
          const SizedBox(height: 12),
          ...inputByJenis.entries.map((e) {
            final rem = remainingByJenis[e.key] ?? e.value;
            final balanced = rem.abs() < 0.001;
            final over = rem < -0.001;
            final progress = e.value > 0
                ? ((e.value - rem.clamp(0.0, e.value)) / e.value).clamp(
                    0.0,
                    1.0,
                  )
                : 0.0;
            final barColor = over
                ? Colors.red
                : (balanced ? const Color(0xFF0A7349) : _kPrimary);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          jenisNames[e.key] ?? 'Jenis ${e.key}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1D23),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        balanced
                            ? '✓ Seimbang'
                            : over
                            ? '⚠ Lebih ${nf.format(-rem)} $unit'
                            : 'Sisa ${nf.format(rem)} $unit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: balanced
                              ? const Color(0xFF0A7349)
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
                    'Total input: ${nf.format(e.value)} $unit',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Submit Card ───────────────────────────────────────────────────────────

class _SubmitCard extends StatelessWidget {
  final bool isSubmitting;
  final bool isBalanced;
  final bool allOutputsValid;
  final int inputCount;
  final int outputCount;
  final VoidCallback onSubmit;

  const _SubmitCard({
    required this.isSubmitting,
    required this.isBalanced,
    required this.allOutputsValid,
    required this.inputCount,
    required this.outputCount,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final canSubmit = isBalanced && !isSubmitting;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats row
          Row(
            children: [
              _stat(
                Icons.input_rounded,
                '$inputCount',
                'Input',
                const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              _stat(
                Icons.output_rounded,
                '$outputCount',
                'Output',
                const Color(0xFF0A7349),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Submit button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: canSubmit ? const Color(0xFF0A7349) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(_kRadius),
              boxShadow: canSubmit
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0A7349).withValues(alpha: 0.3),
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
                      if (isSubmitting)
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
                        isSubmitting ? 'Menyimpan...' : 'Submit Transaksi',
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
          if (!isBalanced && inputCount > 0) ...[
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
                      !allOutputsValid
                          ? 'Setiap output wajib memiliki minimal 1 sak dengan berat > 0'
                          : 'Berat output belum seimbang dengan input',
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
