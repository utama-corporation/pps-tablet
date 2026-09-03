import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';

/// Satu baris metrik pada [ProductionOutputDetailDialog].
///
/// [label] opsional — kalau diisi, tampil sebagai "label : value" (field
/// berlabel). Kalau null, [icon] dipakai sebagai penanda di kolom label.
class ProductionMetric {
  const ProductionMetric({required this.icon, required this.text, this.label});

  final IconData icon;
  final String text;
  final String? label;
}

class ProductionOutputDetailDialog extends StatefulWidget {
  const ProductionOutputDetailDialog({
    super.key,
    required this.labelCode,
    required this.namaJenis,
    required this.printCount,
    required this.metrics,
    required this.accentColor,
    required this.pdfUrl,
    required this.feature,
    this.markAsPrinted,
    this.onDelete,
  });

  final String labelCode;
  final String namaJenis;
  final int printCount;

  /// Daftar metrik tambahan (di luar Nomor & Jenis) yang tampil di body.
  final List<ProductionMetric> metrics;
  final Color accentColor;

  /// Full PDF URL string (from ApiConstants.*LabelPdf)
  final String pdfUrl;

  /// Feature key for LabelPrintSyncQueue e.g. 'furniture_wip', 'reject', 'bonggolan'
  final String feature;

  /// Called after print confirmed — returns new print count from server, or null on failure.
  final Future<int?> Function()? markAsPrinted;

  /// When provided, a delete button is shown. Caller is responsible for confirm dialog + API call.
  final VoidCallback? onDelete;

  @override
  State<ProductionOutputDetailDialog> createState() =>
      _ProductionOutputDetailDialogState();
}

class _ProductionOutputDetailDialogState
    extends State<ProductionOutputDetailDialog> {
  bool _isPrinting = false;

  Future<void> _handlePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    final lockApi = LabelPrintLockApi();
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final markAsPrinted = widget.markAsPrinted;
    final labelCode = widget.labelCode;
    final feature = widget.feature;
    final pdfUrl = Uri.parse(widget.pdfUrl);

    var isLockAcquired = false;
    var isPrinted = false;

    try {
      await lockApi.acquire(labelCode);
      isLockAcquired = true;

      if (!mounted) return;
      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: pdfUrl,
        title: labelCode,
        onPrinted: () {
          isPrinted = true;
          () async {
            var needsIncrement = false;
            var needsRelease = false;

            try {
              final count = markAsPrinted != null
                  ? await markAsPrinted()
                  : null;
              if (count != null) {
                lockVm.setPrintCount(labelCode, count);
              }
            } catch (_) {
              needsIncrement = true;
            }

            try {
              await lockApi.release(labelCode);
            } catch (_) {
              needsRelease = true;
            }

            if (needsIncrement || needsRelease) {
              await queue.enqueue(
                feature: feature,
                noLabel: labelCode,
                needsIncrement: needsIncrement,
                needsReleaseLock: needsRelease,
              );
            }
          }().ignore();
        },
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (isLockAcquired && !isPrinted) {
        () async {
          try {
            await lockApi.release(labelCode);
          } catch (_) {
            await queue.enqueue(
              feature: feature,
              noLabel: labelCode,
              needsReleaseLock: true,
            );
          }
        }().ignore();
      }
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.label_outline,
                      color: widget.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Detail Label',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E6EA)),

            // ── Detail fields ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'Nomor', value: widget.labelCode),
                  const SizedBox(height: 9),
                  _DetailRow(label: 'Jenis', value: widget.namaJenis),
                  for (final m in widget.metrics) ...[
                    const SizedBox(height: 9),
                    _DetailRow(
                      label: m.label,
                      icon: m.label == null ? m.icon : null,
                      value: m.text,
                      accentColor: widget.accentColor,
                    ),
                  ],
                ],
              ),
            ),

            // ── Print count ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(
                    widget.printCount > 0
                        ? Icons.print
                        : Icons.print_disabled_outlined,
                    size: 15,
                    color: widget.printCount > 0
                        ? widget.accentColor
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.printCount > 0
                        ? 'Sudah dicetak ${widget.printCount} kali'
                        : 'Belum pernah dicetak',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.printCount > 0
                          ? widget.accentColor
                          : Colors.grey.shade400,
                      fontWeight: widget.printCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // ── Print button ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                widget.onDelete != null ? 8 : 16,
              ),
              child: FilledButton.icon(
                onPressed: _isPrinting ? null : _handlePrint,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isPrinting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print, size: 16),
                label: Text(
                  _isPrinting
                      ? 'Memproses...'
                      : widget.printCount > 0
                      ? 'Cetak Ulang'
                      : 'Cetak Label',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // ── Delete button ───────────────────────────────────────
            if (widget.onDelete != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: OutlinedButton.icon(
                  onPressed: _isPrinting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text(
                    'Hapus Label',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    this.label,
    this.icon,
    required this.value,
    this.accentColor,
  });

  final String? label;
  final IconData? icon;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 66,
          child: label != null
              ? Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    icon ?? Icons.chevron_right,
                    size: 14,
                    color: accentColor ?? const Color(0xFF9CA3AF),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }
}
