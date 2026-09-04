import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../label/bahan_baku/repository/bahan_baku_repository.dart';
import '../../label/bahan_baku/view_model/bahan_baku_view_model.dart';
import '../../label/bonggolan/repository/bonggolan_repository.dart';
import '../../label/broker/repository/broker_repository.dart';
import '../../label/crusher/repository/crusher_repository.dart';
import '../../label/furniture_wip/repository/furniture_wip_repository.dart';
import '../../label/gilingan/repository/gilingan_repository.dart';
import '../../label/mixer/repository/mixer_repository.dart';
import '../../label/packing/repository/packing_repository.dart';
import '../../label/washing/repository/washing_repository.dart';
import '../model/bs_v2_label_info.dart';
import '../model/bs_v2_transaction.dart';
import '../repository/bs_v2_repository.dart';
import '../utils/bs_v2_category_label.dart';
import '../../production/shared/shared.dart';
import 'bs_v2_sak_detail_dialog.dart';

// ─── Theme constants (mirroring create screen) ─────────────────────────────
const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kGreen = Color(0xFF0A7349);
const _kRadius = 12.0;

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

// ─── Screen ────────────────────────────────────────────────────────────────

class BsV2DetailScreen extends StatefulWidget {
  final String noBongkarSusun;

  const BsV2DetailScreen({super.key, required this.noBongkarSusun});

  @override
  State<BsV2DetailScreen> createState() => _BsV2DetailScreenState();
}

class _BsV2DetailScreenState extends State<BsV2DetailScreen> {
  final BsV2Repository _repo = BsV2Repository();
  final NumberFormat _nf = NumberFormat('#,##0.###', 'id_ID');
  BsV2Transaction? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchDetail(widget.noBongkarSusun);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category =
        _data?.category ??
        (_data?.inputs.isNotEmpty == true
            ? _data!.inputs.first.category
            : null);

    return Scaffold(backgroundColor: _kSurface, body: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade400),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Gagal memuat: $_error',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (_data == null) {
      return const Center(child: Text('Data tidak ditemukan'));
    }

    final trx = _data!;
    final category =
        trx.category ??
        (trx.inputs.isNotEmpty ? trx.inputs.first.category : null);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(trx: trx, category: category),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InputsCard(inputs: trx.inputs, nf: _nf),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OutputsCard(
                  outputs: trx.outputs,
                  nf: _nf,
                  onAfterPrint: _load,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Header Card ───────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final BsV2Transaction trx;
  final String? category;

  const _HeaderCard({required this.trx, required this.category});

  @override
  Widget build(BuildContext context) {
    final balanced = trx.balance;
    final inputCount = trx.inputLabelCount ?? trx.inputs.length;
    final outputCount = trx.outputLabelCount ?? trx.outputs.length;

    // Jenis barang yang diinput (distinct namaJenis), urut sesuai kemunculan.
    final inputJenisList = <String>[];
    for (final e in trx.inputs) {
      final j = e.namaJenis.trim();
      if (j.isNotEmpty && !inputJenisList.contains(j)) inputJenisList.add(j);
    }

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trx.noBongkarSusun,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        trx.tanggalText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                bsV2CategoryBadge(category),
              ],
            ),
          ),
          // ── Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF0F7FF),
            child: Row(
              children: [
                // Operator
                Expanded(
                  child: _StatItem(
                    icon: Icons.person_rounded,
                    label: 'Dibuat oleh',
                    value: trx.username ?? '-',
                    iconColor: _kPrimary,
                  ),
                ),
                _VertDivider(),
                // Input → Output
                Expanded(
                  child: _FlowItem(
                    inputCount: inputCount,
                    outputCount: outputCount,
                  ),
                ),
                _VertDivider(),
                // Catatan
                Expanded(
                  child: _StatItem(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Catatan',
                    value: (trx.note != null && trx.note!.isNotEmpty)
                        ? trx.note!
                        : '—',
                    iconColor: const Color(0xFF8A94A6),
                    italic: (trx.note != null && trx.note!.isNotEmpty),
                  ),
                ),
              ],
            ),
          ),
          // ── Jenis barang input
          if (inputJenisList.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F7FF),
                border: Border(top: BorderSide(color: Color(0xFFD0E4FF))),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(_kRadius),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      size: 15,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jenis Item',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A94A6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final j in inputJenisList)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _kPrimary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  j,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1D23),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFFD0E4FF),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool italic;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D23),
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FlowItem extends StatelessWidget {
  final int inputCount;
  final int outputCount;

  const _FlowItem({required this.inputCount, required this.outputCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input → Output',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF8A94A6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _Pill(count: inputCount, color: _kPrimary, label: 'Input'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: Colors.grey.shade400,
              ),
            ),
            _Pill(count: outputCount, color: _kGreen, label: 'Output'),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final int count;
  final Color color;
  final String label;

  const _Pill({required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final bool? balanced;

  const _BalanceItem({required this.balanced});

  @override
  Widget build(BuildContext context) {
    if (balanced == null) return const SizedBox.shrink();
    final ok = balanced!;
    final color = ok ? _kGreen : Colors.red.shade600;
    final bgColor = ok ? const Color(0xFFE8F5EE) : Colors.red.shade50;
    final icon = ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded;
    final text = ok ? 'Seimbang' : 'Tidak Seimbang';

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF8A94A6),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Inputs Card ───────────────────────────────────────────────────────────

class _InputsCard extends StatelessWidget {
  final List<BsV2LabelInfo> inputs;
  final NumberFormat nf;

  const _InputsCard({required this.inputs, required this.nf});

  @override
  Widget build(BuildContext context) {
    final totalPcs = inputs
        .where((e) => e.isPcsCategory)
        .fold(0.0, (s, e) => s + e.totalBerat);
    final totalBeratKg = inputs
        .where((e) => !e.isPcsCategory)
        .fold(0.0, (s, e) => s + e.totalBerat);

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                    Icons.input_rounded,
                    size: 16,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Input',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const Spacer(),
                if (inputs.isNotEmpty)
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
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (inputs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada input',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: LayoutBuilder(
                builder: (_, c) => GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: c.maxWidth < 560 ? 2 : 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: 96,
                  ),
                  children: inputs
                      .map((lbl) => _BsV2InputTile(lbl: lbl, nf: nf))
                      .toList(),
                ),
              ),
            ),
            // Total row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_kRadius),
                ),
                border: const Border(top: BorderSide(color: _kBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (totalBeratKg > 0)
                    Row(
                      children: [
                        const Text(
                          'Total Berat Input',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${nf.format(totalBeratKg)} kg',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ),
                  if (totalBeratKg > 0 && totalPcs > 0)
                    const SizedBox(height: 4),
                  if (totalPcs > 0)
                    Row(
                      children: [
                        const Text(
                          'Total Pcs Input',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${totalPcs.toInt()} pcs',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Card tile untuk satu label input — format identik dengan tile input/output
// pada layar produksi (mis. broker): jenis sebagai judul, nomor label sebagai
// sub judul, metrics (sak/berat/pcs) di baris bawah, tap untuk detail sak.
class _BsV2InputTile extends StatelessWidget {
  final BsV2LabelInfo lbl;
  final NumberFormat nf;

  const _BsV2InputTile({required this.lbl, required this.nf});

  @override
  Widget build(BuildContext context) {
    final hasSakDetail = lbl.saks.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: hasSakDetail
            ? () => showDialog<void>(
                context: context,
                builder: (_) => BsV2SakDetailDialog(lbl: lbl, nf: nf),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                lbl.namaJenis.isNotEmpty ? lbl.namaJenis : lbl.labelCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D23),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                lbl.labelCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (lbl.jumlahSak > 0)
                    ProductionMiniMetric(
                      icon: Icons.inventory_2_outlined,
                      text: '${lbl.jumlahSak} sak',
                    ),
                  ProductionMiniMetric(
                    icon: lbl.isPcsCategory
                        ? Icons.category_outlined
                        : Icons.scale_outlined,
                    text: lbl.isPcsCategory
                        ? '${lbl.totalBerat.toInt()} pcs'
                        : '${nf.format(lbl.totalBerat)} kg',
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

// ─── Outputs Card ──────────────────────────────────────────────────────────

class _OutputsCard extends StatefulWidget {
  final List<BsV2OutputLabel> outputs;
  final NumberFormat nf;

  /// Dipanggil setelah cetak batch selesai supaya parent reload detail
  /// (status print count ikut ter-update).
  final VoidCallback? onAfterPrint;

  const _OutputsCard({
    required this.outputs,
    required this.nf,
    this.onAfterPrint,
  });

  @override
  State<_OutputsCard> createState() => _OutputsCardState();
}

class _OutputsCardState extends State<_OutputsCard>
    with ProductionOutputMultiSelectMixin<_OutputsCard> {
  NumberFormat get nf => widget.nf;

  // Prefix label yang bisa dicetak (samakan dengan _printTargetFor).
  static bool _canPrintCode(String? code) {
    final c = (code ?? '').trim();
    return c.startsWith('A') ||
        c.startsWith('B') ||
        c.startsWith('D') ||
        c.startsWith('F') ||
        c.startsWith('H') ||
        c.startsWith('M') ||
        c.startsWith('V');
  }

  static String _deriveNoBahanBaku(String noPallet) {
    if (noPallet.contains('-')) {
      return noPallet.substring(0, noPallet.lastIndexOf('-'));
    }
    return noPallet;
  }

  int get _printableCount =>
      widget.outputs.where((o) => _canPrintCode(o.labelCode?.trim())).length;

  /// Bangun target cetak untuk satu label output (prefix menentukan modul).
  /// Return null bila label tidak bisa dicetak.
  ProductionOutputPrintTarget? _printTargetFor(
    BuildContext context,
    BsV2OutputLabel out,
  ) {
    final labelCode = (out.labelCode ?? '').trim();
    if (labelCode.isEmpty || !_canPrintCode(labelCode)) return null;

    final isBahanBaku = labelCode.startsWith('A');
    final isPacking = labelCode.startsWith('BA');
    final isFurnitureWip = labelCode.startsWith('BB');
    final isBroker = labelCode.startsWith('D');
    final isCrusher = labelCode.startsWith('F');
    final isMixer = labelCode.startsWith('H');
    final isBonggolan = labelCode.startsWith('M');
    final isGilingan = labelCode.startsWith('V');

    final noPallet = (out.noPallet?.trim().isNotEmpty ?? false)
        ? out.noPallet!.trim()
        : labelCode;
    final noBahanBaku = (out.noBahanBaku?.trim().isNotEmpty ?? false)
        ? out.noBahanBaku!.trim()
        : _deriveNoBahanBaku(noPallet);

    final feature = isBahanBaku
        ? 'bahan_baku'
        : isPacking
        ? 'packing'
        : isFurnitureWip
        ? 'furniture_wip'
        : isBroker
        ? 'broker'
        : isCrusher
        ? 'crusher'
        : isMixer
        ? 'mixer'
        : isBonggolan
        ? 'bonggolan'
        : isGilingan
        ? 'gilingan'
        : 'washing';

    final pdfUrl = isBahanBaku
        ? ApiConstants.bahanBakuPalletLabelPdf(noBahanBaku, noPallet)
        : isPacking
        ? ApiConstants.packingLabelPdf(labelCode)
        : isFurnitureWip
        ? ApiConstants.furnitureWipLabelPdf(labelCode)
        : isBroker
        ? ApiConstants.brokerLabelPdf(labelCode)
        : isCrusher
        ? ApiConstants.crusherLabelPdf(labelCode)
        : isMixer
        ? ApiConstants.mixerLabelPdf(labelCode)
        : isBonggolan
        ? ApiConstants.bonggolanLabelPdf(labelCode)
        : isGilingan
        ? ApiConstants.gilinganLabelPdf(labelCode)
        : ApiConstants.washingLabelPdf(labelCode);

    final code = isBahanBaku ? noPallet : labelCode;

    final bahanBakuRepo = isBahanBaku
        ? BahanBakuRepository(api: ApiClient())
        : null;
    final bahanBakuVm = isBahanBaku ? context.read<BahanBakuViewModel>() : null;
    final packingRepo = isPacking ? PackingRepository(api: ApiClient()) : null;
    final furnitureWipRepo = isFurnitureWip ? FurnitureWipRepository() : null;
    final brokerRepo = isBroker ? BrokerRepository(api: ApiClient()) : null;
    final crusherRepo = isCrusher ? CrusherRepository() : null;
    final mixerRepo = isMixer ? MixerRepository() : null;
    final bonggolanRepo = isBonggolan ? BonggolanRepository() : null;
    final gilinganRepo = isGilingan ? GilinganRepository() : null;
    final washingRepo =
        (isBahanBaku ||
            isPacking ||
            isFurnitureWip ||
            isBroker ||
            isCrusher ||
            isMixer ||
            isBonggolan ||
            isGilingan)
        ? null
        : WashingRepository();

    return ProductionOutputPrintTarget(
      code: code,
      pdfUrl: pdfUrl,
      feature: feature,
      markAsPrinted: () async {
        if (isBahanBaku) {
          final c = await bahanBakuRepo!.markAsPrinted(
            noBahanBaku: noBahanBaku,
            noPallet: noPallet,
          );
          if (c != null) {
            bahanBakuVm!.setPalletPrintedCount(noPallet: noPallet, count: c);
          }
          return c;
        }
        if (isPacking) return packingRepo!.markAsPrinted(labelCode);
        if (isFurnitureWip) return furnitureWipRepo!.markAsPrinted(labelCode);
        if (isBroker) return brokerRepo!.markAsPrinted(labelCode);
        if (isCrusher) return crusherRepo!.markAsPrinted(labelCode);
        if (isMixer) return mixerRepo!.markAsPrinted(labelCode);
        if (isBonggolan) return bonggolanRepo!.markAsPrinted(labelCode);
        if (isGilingan) return gilinganRepo!.markAsPrinted(labelCode);
        return washingRepo!.markAsPrinted(labelCode);
      },
    );
  }

  Future<void> _printSelected() async {
    final targets = <ProductionOutputPrintTarget>[];
    for (final item in selectedOutputItems) {
      final t = _printTargetFor(context, item as BsV2OutputLabel);
      if (t != null) targets.add(t);
    }
    if (targets.isEmpty) {
      cancelOutputSelection();
      return;
    }
    await runBatchPrintOutputs(targets);
    widget.onAfterPrint?.call();
  }

  void _toggleSelectAll() {
    final printable = widget.outputs
        .where((o) => _canPrintCode(o.labelCode?.trim()))
        .toList();
    if (printable.isNotEmpty && selectedOutputCount >= printable.length) {
      clearOutputSelection();
    } else {
      selectAllOutputs(printable, (o) {
        final c = (o as BsV2OutputLabel).labelCode?.trim();
        return (c != null && c.isNotEmpty) ? c : null;
      });
    }
  }

  Widget _buildOutputTile(BsV2OutputLabel out, int i) {
    final code = out.labelCode?.trim();
    final canPrint = _canPrintCode(code);
    Widget tileBuilder(VoidCallback? overrideTap) =>
        _BsV2OutputTile(out: out, nf: nf, index: i, overrideTap: overrideTap);
    if (canPrint && code != null && code.isNotEmpty) {
      return wrapOutputTile(
        code: code,
        item: out,
        accentColor: _kGreen,
        builder: tileBuilder,
      );
    }
    return tileBuilder(null);
  }

  @override
  Widget build(BuildContext context) {
    final outputs = widget.outputs;
    final totalPcs = outputs
        .where((e) => e.isPcsCategory)
        .fold(0.0, (s, e) => s + e.totalBerat);
    final totalBeratKg = outputs
        .where((e) => !e.isPcsCategory)
        .fold(0.0, (s, e) => s + e.totalBerat);

    return Container(
      decoration: _cardDecoration(borderColor: _kGreen.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.output_rounded,
                    size: 16,
                    color: _kGreen,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Output',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const Spacer(),
                if (outputs.isNotEmpty && !isSelectingOutput)
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
                      '${outputs.length} label',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (outputs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Tidak ada output',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: LayoutBuilder(
                builder: (_, c) => GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: c.maxWidth < 560 ? 2 : 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: 96,
                  ),
                  children: [
                    for (var i = 0; i < outputs.length; i++)
                      _buildOutputTile(outputs[i], i),
                  ],
                ),
              ),
            ),
            if (isSelectingOutput)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: ProductionOutputSelectionBar(
                  accentColor: _kGreen,
                  count: selectedOutputCount,
                  totalAvailable: _printableCount,
                  allSelected:
                      _printableCount > 0 &&
                      selectedOutputCount >= _printableCount,
                  onCancel: cancelOutputSelection,
                  onToggleAll: _toggleSelectAll,
                  onPrint: _printSelected,
                  // onDelete sengaja null → tombol "Hapus" tidak ditampilkan
                ),
              )
            else
              // Total row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(_kRadius),
                  ),
                  border: const Border(top: BorderSide(color: _kBorder)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (totalBeratKg > 0)
                      Row(
                        children: [
                          const Text(
                            'Total Berat Output',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kGreen,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${nf.format(totalBeratKg)} kg',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kGreen,
                            ),
                          ),
                        ],
                      ),
                    if (totalBeratKg > 0 && totalPcs > 0)
                      const SizedBox(height: 4),
                    if (totalPcs > 0)
                      Row(
                        children: [
                          const Text(
                            'Total Pcs Output',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kGreen,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${totalPcs.toInt()} pcs',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kGreen,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// Card tile untuk satu label output — format identik dengan tile output pada
// layar produksi shared: jenis sebagai judul, indikator status print count
// (×N + ikon printer) di kanan judul, nomor label sebagai sub judul, metrics
// di baris bawah. Cetak dilakukan lewat long-press multi-select.
class _BsV2OutputTile extends StatelessWidget {
  final BsV2OutputLabel out;
  final NumberFormat nf;
  final int index;

  /// Bila diisi (mode multi-select aktif), tap tile = toggle pilih, bukan
  /// buka detail sak.
  final VoidCallback? overrideTap;

  const _BsV2OutputTile({
    required this.out,
    required this.nf,
    required this.index,
    this.overrideTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelCode = out.labelCode?.trim();
    final title = out.namaJenis.isNotEmpty
        ? out.namaJenis
        : (labelCode ?? '#${index + 1}');
    final subtitle = labelCode ?? '#${index + 1}';
    final hasSakDetail = out.saks.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            overrideTap ??
            (hasSakDetail
                ? () => showDialog<void>(
                    context: context,
                    builder: (_) => BsV2SakDetailDialog(
                      nf: nf,
                      lbl: BsV2LabelInfo(
                        labelCode: out.labelCode ?? '#${index + 1}',
                        category: out.category,
                        idJenis: out.idJenis,
                        namaJenis: out.namaJenis,
                        totalBerat: out.totalBerat,
                        jumlahSak: out.jumlahSak,
                        saks: out.saks
                            .map(
                              (s) =>
                                  BsV2LabelSak(noSak: s.noSak, berat: s.berat),
                            )
                            .toList(),
                      ),
                    ),
                  )
                : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '×${out.printCount}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: out.printCount > 0
                          ? _kGreen
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.print_outlined,
                    size: 11,
                    color: out.printCount > 0 ? _kGreen : Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (out.jumlahSak > 0)
                    ProductionMiniMetric(
                      icon: Icons.inventory_2_outlined,
                      text: '${out.jumlahSak} sak',
                    ),
                  ProductionMiniMetric(
                    icon: out.isPcsCategory
                        ? Icons.category_outlined
                        : Icons.scale_outlined,
                    text: out.isPcsCategory
                        ? '${out.totalBerat.toInt()} pcs'
                        : '${nf.format(out.totalBerat)} kg',
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
