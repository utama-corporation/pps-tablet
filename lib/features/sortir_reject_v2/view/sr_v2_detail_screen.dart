import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/label_print_lock_api.dart';
import '../../../core/services/label_print_sync_queue.dart';
import '../../../core/utils/pdf_print_service.dart';
import '../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../label/packing/repository/packing_repository.dart';
import '../../label/reject/repository/reject_repository.dart';
import '../model/sr_v2_label_info.dart';
import '../model/sr_v2_transaction.dart';
import '../repository/sr_v2_repository.dart';
import '../../production/shared/shared.dart';

// ─── Theme constants ───────────────────────────────────────────────────────
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

class SrV2DetailScreen extends StatefulWidget {
  final String noSortir;

  const SrV2DetailScreen({super.key, required this.noSortir});

  @override
  State<SrV2DetailScreen> createState() => _SrV2DetailScreenState();
}

class _SrV2DetailScreenState extends State<SrV2DetailScreen> {
  final SrV2Repository _repo = SrV2Repository();
  final NumberFormat _nf = NumberFormat('#,##0', 'id_ID');
  SrV2Transaction? _data;
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
      final data = await _repo.fetchDetail(widget.noSortir);
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(trx: trx),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InputsCard(inputs: trx.inputs, nf: _nf),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OutputsCard(outputs: trx.outputs, nf: _nf),
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
  final SrV2Transaction trx;

  const _HeaderCard({required this.trx});

  @override
  Widget build(BuildContext context) {
    final inputCount = trx.inputLabelCount ?? trx.inputs.length;
    final outputCount = trx.outputLabelCount ?? trx.outputs.length;

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.vertical(
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
                        trx.noSortir,
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
                _BalanceBadge(balance: trx.balance, category: trx.category),
              ],
            ),
          ),
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF0F7FF),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.person_rounded,
                    label: 'Dibuat oleh',
                    value: trx.username ?? '-',
                    iconColor: _kPrimary,
                  ),
                ),
                _VertDivider(),
                Expanded(
                  child: _StatItem(
                    icon: Icons.warehouse_rounded,
                    label: 'Warehouse',
                    value: trx.namaWarehouse ?? '-',
                    iconColor: const Color(0xFF7B61FF),
                  ),
                ),
                _VertDivider(),
                Expanded(
                  child: _FlowItem(
                    inputCount: inputCount,
                    outputCount: outputCount,
                    pcsIn: trx.totalPcsInput ?? 0,
                    pcsOut: trx.totalPcsOutput ?? 0,
                    beratOut: trx.totalBeratOutput,
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

class _BalanceBadge extends StatelessWidget {
  final bool? balance;
  final String? category;
  const _BalanceBadge({required this.balance, this.category});

  @override
  Widget build(BuildContext context) {
    final isBahanPendukung =
        SrV2Category.fromRaw(category) == SrV2Category.bahanPendukung;
    final isReject =
        isBahanPendukung ||
        balance == false ||
        (balance == null && category == 'reject');

    final badgeColor = isReject ? Colors.red : Colors.green;
    final icon = isReject
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline_rounded;
    final label = isReject ? 'Konversi Reject' : 'Konversi Jenis';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
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

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D23),
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
  final int pcsIn;
  final int pcsOut;
  final double? beratOut;

  const _FlowItem({
    required this.inputCount,
    required this.outputCount,
    required this.pcsIn,
    required this.pcsOut,
    this.beratOut,
  });

  @override
  Widget build(BuildContext context) {
    final berat = beratOut;
    final formattedBerat = berat == null
        ? null
        : NumberFormat('#,##0.##', 'id_ID').format(berat);
    final pcsOutText = pcsOut > 0 ? '$pcsOut pcs / ' : '';
    final outputSummary = formattedBerat != null
        ? '$pcsIn pcs -> $pcsOutText$formattedBerat kg'
        : '$pcsIn pcs -> $pcsOut pcs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input -> Output',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF8A94A6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _Pill(count: inputCount, color: _kPrimary, label: 'Label'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: Colors.grey.shade400,
              ),
            ),
            _Pill(count: outputCount, color: _kGreen, label: 'Label'),
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

// ─── Inputs Card ───────────────────────────────────────────────────────────

class _InputsCard extends StatelessWidget {
  final List<SrV2InputLabel> inputs;
  final NumberFormat nf;

  const _InputsCard({required this.inputs, required this.nf});

  @override
  Widget build(BuildContext context) {
    final totalPcs = inputs.fold(0, (s, e) => s + e.pcs);
    final totalQty = inputs.fold<double>(0, (s, e) => s + e.qty);
    // Label BP. menyimpan qty di kolom `pcs` (dari dbo.BahanPendukung.Qty)
    // yang boleh pecahan, jadi ditotalkan sebagai qty.
    final isBahanPendukung =
        inputs.isNotEmpty && inputs.every((e) => e.isBahanPendukung);
    final qtyNf = NumberFormat('#,##0.##', 'id_ID');
    final totalLabel = isBahanPendukung ? 'Total Qty Input' : 'Total Pcs Input';
    final totalText =
        isBahanPendukung ? qtyNf.format(totalQty) : '${nf.format(totalPcs)} pcs';

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
                    Icons.input_rounded,
                    size: 16,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Label Input',
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
                    crossAxisCount: c.maxWidth < 380 ? 2 : 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: 80,
                  ),
                  children: inputs
                      .map((lbl) => _SrV2InputTile(lbl: lbl, nf: nf))
                      .toList(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_kRadius),
                ),
                border: const Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    totalLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    totalText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kPrimary,
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
}

// Card tile untuk satu label input — format identik dengan tile input/output
// pada layar produksi (mis. broker) dan bs_v2_detail_screen: jenis sebagai
// judul, nomor label sebagai sub judul, metrics (pcs/operator) di baris bawah.
class _SrV2InputTile extends StatelessWidget {
  final SrV2InputLabel lbl;
  final NumberFormat nf;

  const _SrV2InputTile({required this.lbl, required this.nf});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              lbl.namaJenis.isNotEmpty ? lbl.namaJenis : lbl.noBJ,
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
              lbl.noBJ,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                ProductionMiniMetric(
                  icon: Icons.inventory_2_outlined,
                  text: lbl.isBahanPendukung
                      ? NumberFormat(
                          '#,##0.##',
                          'id_ID',
                        ).format(lbl.qty)
                      : '${nf.format(lbl.pcs)} pcs',
                ),
                if (lbl.createBy != null)
                  ProductionMiniMetric(
                    icon: Icons.person_outline_rounded,
                    text: lbl.createBy!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Outputs Card ──────────────────────────────────────────────────────────

class _OutputsCard extends StatelessWidget {
  final List<SrV2OutputLabel> outputs;
  final NumberFormat nf;

  const _OutputsCard({required this.outputs, required this.nf});

  @override
  Widget build(BuildContext context) {
    final totalPcs = outputs.fold(0, (s, e) => s + e.pcs);
    final totalBerat = outputs.fold<double>(0, (s, e) => s + (e.berat ?? 0));
    final hasBerat = totalBerat > 0;
    final totalPcsText = totalPcs > 0 ? '${nf.format(totalPcs)} pcs / ' : '';

    return Container(
      decoration: _cardDecoration(borderColor: _kGreen.withValues(alpha: 0.3)),
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
                  'Label Output',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const Spacer(),
                if (outputs.isNotEmpty)
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
                    crossAxisCount: c.maxWidth < 380 ? 2 : 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    mainAxisExtent: 80,
                  ),
                  children: [
                    for (var i = 0; i < outputs.length; i++)
                      _SrV2OutputTile(out: outputs[i], nf: nf, index: i),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(_kRadius),
                ),
                border: const Border(top: BorderSide(color: _kBorder)),
              ),
              child: Row(
                children: [
                  const Text(
                    'Total Output',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _kGreen,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    hasBerat
                        ? '$totalPcsText${nf.format(totalBerat)} kg'
                        : '${nf.format(totalPcs)} pcs',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
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
}

// Card tile untuk satu label output — format identik dengan tile input/output
// pada layar produksi (mis. broker) dan bs_v2_detail_screen: jenis sebagai
// judul, nomor label sebagai sub judul, tombol print inline.
class _SrV2OutputTile extends StatelessWidget {
  final SrV2OutputLabel out;
  final NumberFormat nf;
  final int index;

  const _SrV2OutputTile({
    required this.out,
    required this.nf,
    required this.index,
  });

  bool get _canPrint {
    final noBJ = (out.noBJ ?? '').trim();
    return noBJ.startsWith('BA') || noBJ.startsWith('BF');
  }

  Future<void> _handlePrint(BuildContext context, String noBJ) async {
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final isRejectLabel = noBJ.startsWith('BF');
    final lockApi = LabelPrintLockApi();
    final api = ApiClient();
    final packingRepo = isRejectLabel ? null : PackingRepository(api: api);
    final rejectRepo = isRejectLabel ? RejectRepository(api: api) : null;
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    final feature = isRejectLabel ? 'reject' : 'packing';
    final pdfUrl = isRejectLabel
        ? ApiConstants.rejectLabelPdf(noBJ)
        : ApiConstants.packingLabelPdf(noBJ);
    var isLockAcquired = false;
    var isPrinted = false;

    try {
      await lockApi.acquire(noBJ);
      isLockAcquired = true;

      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: Uri.parse(pdfUrl),
        title: noBJ,
        onPrinted: () {
          isPrinted = true;
          () async {
            var needsIncrement = false;
            var needsRelease = false;

            try {
              final count = isRejectLabel
                  ? await rejectRepo!.markAsPrinted(noBJ)
                  : await packingRepo!.markAsPrinted(noBJ);
              if (count != null) {
                lockVm.setPrintCount(noBJ, count);
              }
            } catch (_) {
              needsIncrement = true;
            }

            try {
              await lockApi.release(noBJ);
            } catch (_) {
              needsRelease = true;
            }

            if (needsIncrement || needsRelease) {
              await queue.enqueue(
                feature: feature,
                noLabel: noBJ,
                needsIncrement: needsIncrement,
                needsReleaseLock: needsRelease,
              );
            }
          }().ignore();
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (isLockAcquired && !isPrinted) {
        () async {
          try {
            await lockApi.release(noBJ);
          } catch (_) {
            await queue.enqueue(
              feature: feature,
              noLabel: noBJ,
              needsReleaseLock: true,
            );
          }
        }().ignore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final berat = out.berat;
    final qtyText = berat != null && berat > 0
        ? '${nf.format(berat)} kg'
        : '${nf.format(out.pcs)} pcs';
    final noBJ = out.noBJ?.trim();
    final title = out.namaJenis.isNotEmpty
        ? out.namaJenis
        : (noBJ ?? '#${index + 1}');
    final subtitle = noBJ ?? '#${index + 1}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
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
                if (noBJ != null && _canPrint) ...[
                  const SizedBox(width: 4),
                  _OutputPrintButton(
                    onPressed: () => _handlePrint(context, noBJ),
                  ),
                ],
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
            ProductionMiniMetric(
              icon: berat != null && berat > 0
                  ? Icons.scale_outlined
                  : Icons.inventory_2_outlined,
              text: qtyText,
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputPrintButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _OutputPrintButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Print',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kGreen.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.print_outlined, size: 14, color: _kGreen),
        ),
      ),
    );
  }
}
