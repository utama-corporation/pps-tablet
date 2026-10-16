// lib/features/label/bahan_pend_support/widgets/bahan_pend_support_delete_dialog.dart

import 'package:flutter/material.dart';

import '../../../../core/utils/number_formatter.dart';
import '../model/bahan_pend_support_header_model.dart';

class BahanPendukungDeleteDialog extends StatefulWidget {
  final BahanPendukungHeader header;

  /// Parent yang menutup dialog; komponen ini tidak memanggil Navigator.pop
  /// untuk aksi konfirmasi.
  final Future<void> Function() onConfirm;

  const BahanPendukungDeleteDialog({
    super.key,
    required this.header,
    required this.onConfirm,
  });

  @override
  State<BahanPendukungDeleteDialog> createState() =>
      _BahanPendukungDeleteDialogState();
}

class _BahanPendukungDeleteDialogState
    extends State<BahanPendukungDeleteDialog> {
  bool _agree = false;
  bool _submitting = false;

  /// Backend menolak hapus kalau label sudah terpakai (penuh maupun
  /// sebagian). Kalau sudah kelihatan terpakai di tabel, lebih baik
  /// diperingatkan di depan daripada mengirim request yang pasti ditolak.
  bool get _looksUsed => !widget.header.canDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: const _WarningBanner(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'No. Label',
                  value: widget.header.noBahanPendukung,
                ),
                if ((widget.header.namaCabinetMaterial ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    label: 'Material',
                    value: widget.header.namaCabinetMaterial!.trim(),
                  ),
                ],
                if (widget.header.qty != null) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    label: 'Qty',
                    value: formatPcsQty(widget.header.qty!),
                  ),
                ],
                if (widget.header.isTerpakaiSebagian) ...[
                  const SizedBox(height: 6),
                  _InfoRow(label: 'Sisa', value: '${widget.header.sisa}'),
                ],
                if ((widget.header.noPenerimaan ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    label: 'Penerimaan',
                    value: widget.header.noPenerimaan!.trim(),
                  ),
                ],
              ],
            ),
          ),

          if (_looksUsed) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFB26A00).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFB26A00).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xFFB26A00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
child: Text(
                      widget.header.isFullyUsed
                          ? 'Label ini sudah dipakai pada proses produksi. '
                              'Server akan menolak penghapusan.'
                          : 'Qty label ini sudah terpakai sebagian. '
                              'Server akan menolak penghapusan.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF8A5200),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tindakan ini bersifat permanen dan tidak dapat dibatalkan.',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: .75),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 10),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _agree,
            onChanged: _submitting
                ? null
                : (v) => setState(() => _agree = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Saya mengerti dan ingin menghapus label ini.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: .9)),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('BATAL'),
        ),
        FilledButton.icon(
          onPressed: (!_agree || _submitting)
              ? null
              : () async {
                  setState(() => _submitting = true);
                  try {
                    await widget.onConfirm(); // parent menutup dialog
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          icon: _submitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onError,
                  ),
                )
              : const Icon(Icons.delete_outline),
          label: const Text('HAPUS'),
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            disabledBackgroundColor: cs.error.withValues(alpha: .4),
            disabledForegroundColor: cs.onError.withValues(alpha: .8),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 1,
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.error.withValues(alpha: .95),
            cs.error.withValues(alpha: .75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Konfirmasi Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: .2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}