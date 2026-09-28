import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../model/broker_header_model.dart';
import '../repository/broker_repository.dart';

class BrokerActionDialog extends StatefulWidget {
  final BrokerHeader header;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAuditHistory;
  final VoidCallback onQc;

  const BrokerActionDialog({
    super.key,
    required this.header,
    required this.onEdit,
    required this.onDelete,
    required this.onAuditHistory,
    required this.onQc,
  });

  @override
  State<BrokerActionDialog> createState() => _BrokerActionDialogState();
}

class _BrokerActionDialogState extends State<BrokerActionDialog> {
  static const _copyFeedbackDuration = Duration(milliseconds: 1200);
  bool _copied = false;
  Timer? _copiedResetTimer;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _closeAndRun(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  Future<void> _copyNoBroker() async {
    await Clipboard.setData(ClipboardData(text: widget.header.noBroker));
    if (!mounted) return;
    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(_copyFeedbackDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _printLabel(BuildContext ctx) async {
    final rootCtx = Navigator.of(ctx, rootNavigator: true).context;
    final noBroker = widget.header.noBroker;
    final lockApi = LabelPrintLockApi();
    final repo = BrokerRepository(api: ApiClient());
    final lockVm = ctx.read<LabelPrintLockSocketManager>();
    final queue = ctx.read<LabelPrintSyncQueue>();
    var isLockAcquired = false;
    var isPrinted = false;

    _close();

    try {
      await lockApi.acquire(noBroker);
      isLockAcquired = true;

      // ignore: use_build_context_synchronously
      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: Uri.parse(ApiConstants.brokerLabelPdf(noBroker)),
        title: noBroker,
        onPrinted: () {
          isPrinted = true;
          () async {
            var needsIncrement = false;
            var needsRelease = false;

            try {
              final count = await repo.markAsPrinted(noBroker);
              if (count != null) lockVm.setPrintCount(noBroker, count);
            } catch (_) {
              needsIncrement = true;
            }

            try {
              await lockApi.release(noBroker);
            } catch (_) {
              needsRelease = true;
            }

            if (needsIncrement || needsRelease) {
              await queue.enqueue(
                feature: 'broker',
                noLabel: noBroker,
                needsIncrement: needsIncrement,
                needsReleaseLock: needsRelease,
              );
            }
          }().ignore();
        },
      );
    } catch (e) {
      if (!rootCtx.mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(rootCtx).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (isLockAcquired && !isPrinted) {
        () async {
          try {
            await lockApi.release(noBroker);
          } catch (_) {
            await queue.enqueue(
              feature: 'broker',
              noLabel: noBroker,
              needsReleaseLock: true,
            );
          }
        }().ignore();
      }
    }
  }

  Future<void> _printQc(BuildContext ctx) async {
    final rootCtx = Navigator.of(ctx, rootNavigator: true).context;
    final noBroker = widget.header.noBroker;

    _close();

    try {
      // ignore: use_build_context_synchronously
      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: Uri.parse(ApiConstants.brokerQcPdf(noBroker)),
        title: '$noBroker – QC',
      );
    } catch (e) {
      if (!rootCtx.mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(rootCtx).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionViewModel>();
    final canEdit = perm.can('label_broker:update');
    final canDelete = perm.can('label_broker:delete');
    final canQC = perm.can('qc_label:update');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 540),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Panel kiri: QC data ──────────────────────────
                  Expanded(child: _buildQcPanel(canQC)),

                  Container(width: 1, color: Colors.grey.shade200),

                  // ── Panel kanan: menu aksi ───────────────────────
                  SizedBox(
                    width: 220,
                    child: _buildActionPanel(canEdit, canDelete),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2FF),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.label_rounded,
              color: Color(0xFF1565C0),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.header.noBroker,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF172B4D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.header.namaJenisPlastik,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF44546F),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _copied ? 'Tersalin!' : 'Salin nomor',
            onPressed: _copyNoBroker,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                key: ValueKey(_copied),
                size: 18,
                color: const Color(0xFF1565C0),
              ),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panel kiri: QC data ───────────────────────────────────────────────────

  Widget _buildQcPanel(bool canQC) {
    final qcDate = formatDateToShortId(widget.header.dateQc);
    final qcBy = (widget.header.qcBy ?? '').trim();
    final hasQcDate = qcDate.isNotEmpty && qcDate != widget.header.dateQc;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionLabel('Quality Control', Icons.science_outlined),
                      const Spacer(),
                      if (hasQcDate)
                        Text(
                          qcBy.isEmpty ? qcDate : '$qcDate • $qcBy',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B778C),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _qcCell(
                              'Density 1',
                              widget.header.density,
                              'g/cm³',
                            ),
                            const SizedBox(width: 6),
                            _qcCell(
                              'Density 2',
                              widget.header.density2,
                              'g/cm³',
                            ),
                            const SizedBox(width: 6),
                            _qcCell(
                              'Density 3',
                              widget.header.density3,
                              'g/cm³',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _qcCell('Moisture 1', widget.header.moisture, '%'),
                            const SizedBox(width: 6),
                            _qcCell('Moisture 2', widget.header.moisture2, '%'),
                            const SizedBox(width: 6),
                            _qcCell('Moisture 3', widget.header.moisture3, '%'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _qcCell(
                              'Max Melt Temp',
                              widget.header.maxMeltTemp,
                              '°C',
                            ),
                            const SizedBox(width: 6),
                            _qcCell(
                              'Min Melt Temp',
                              widget.header.minMeltTemp,
                              '°C',
                            ),
                            const SizedBox(width: 6),
                            _qcCell('MFI', widget.header.mfi, null),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sectionLabel('Visual Note', Icons.sticky_note_2_outlined),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 80),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      (widget.header.visualNote ?? '').trim().isEmpty
                          ? '—'
                          : widget.header.visualNote!.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: canQC ? '' : 'Tidak punya izin update QC',
                  child: OutlinedButton.icon(
                    onPressed: canQC ? () => _closeAndRun(widget.onQc) : null,
                    icon: const Icon(Icons.science_outlined, size: 16),
                    label: const Text('Input QC'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade300),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _printQc(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Print QC'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    foregroundColor: Colors.deepPurple,
                    side: BorderSide(color: Colors.deepPurple.shade200),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF44546F)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF44546F),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _qcCell(String label, double? value, String? unit) {
    final hasValue = value != null;
    final displayValue = hasValue
        ? '${value.toStringAsFixed(2)}${unit != null ? ' $unit' : ''}'
        : '—';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B778C),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              displayValue,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: hasValue
                    ? const Color(0xFF172B4D)
                    : Colors.grey.shade400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Panel kanan: menu aksi ────────────────────────────────────────────────

  Widget _buildActionPanel(bool canEdit, bool canDelete) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            'Aksi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        _actionTile(
          icon: Icons.history_rounded,
          label: 'History',
          color: const Color(0xFF0C66E4),
          onTap: () => _closeAndRun(widget.onAuditHistory),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        _actionTile(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: Colors.orange.shade700,
          enabled: canEdit,
          tooltip: 'Tidak punya izin edit',
          onTap: () => _closeAndRun(widget.onEdit),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        _actionTile(
          icon: Icons.print_outlined,
          label: 'Print Label',
          color: const Color(0xFF0C66E4),
          onTap: () => _printLabel(context),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        _actionTile(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          color: Colors.red.shade700,
          enabled: canDelete,
          tooltip: 'Tidak punya izin hapus',
          onTap: () => _closeAndRun(widget.onDelete),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
    String? tooltip,
  }) {
    final effectiveColor = enabled ? color : Colors.grey.shade400;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashColor: effectiveColor.withValues(alpha: 0.08),
        highlightColor: effectiveColor.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: effectiveColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? (label == 'Delete'
                              ? Colors.red.shade700
                              : const Color(0xFF172B4D))
                        : Colors.grey.shade400,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: enabled ? Colors.grey.shade400 : Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );

    if (!enabled && (tooltip?.isNotEmpty ?? false)) {
      return Tooltip(
        message: tooltip!,
        child: Opacity(opacity: 0.6, child: tile),
      );
    }
    return tile;
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _close,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(color: Colors.grey.shade300),
              foregroundColor: const Color(0xFF44546F),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
