import 'package:flutter/material.dart';

import '../model/barang_dagang_label.dart';

class BarangDagangDeleteDialog extends StatefulWidget {
  final BarangDagangLabel item;

  /// Parent yang menutup dialog; widgets ini TIDAK memanggil Navigator.pop.
  final Future<void> Function() onConfirm;

  const BarangDagangDeleteDialog({
    super.key,
    required this.item,
    required this.onConfirm,
  });

  @override
  State<BarangDagangDeleteDialog> createState() =>
      _BarangDagangDeleteDialogState();
}

class _BarangDagangDeleteDialogState extends State<BarangDagangDeleteDialog> {
  bool _agree = false;
  bool _submitting = false;

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
      title: _WarningBanner(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Item summary
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  label: 'No. Barang Dagang',
                  value: widget.item.code,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Nama Barang',
                  value: widget.item.name.trim().isEmpty
                      ? '-'
                      : widget.item.name.trim(),
                ),
                const SizedBox(height: 6),
                if (widget.item.receipt.trim().isNotEmpty) ...[
                  _InfoRow(
                    label: 'Penerimaan',
                    value: widget.item.receipt.trim(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Main text
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'This action is permanent and cannot be undone.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(.75),
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Confirmation checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _agree,
            onChanged: _submitting
                ? null
                : (v) => setState(() => _agree = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'I understand and want to delete this label.',
              style: TextStyle(color: cs.onSurface.withOpacity(.9)),
            ),
          ),
        ],
      ),
      actions: [
        // Cancel
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('CANCEL'),
        ),

        // Delete (destructive)
        FilledButton.icon(
          onPressed: (!_agree || _submitting)
              ? null
              : () async {
                  setState(() => _submitting = true);
                  try {
                    await widget.onConfirm(); // parent yang menutup dialog
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
          label: const Text('DELETE'),
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            disabledBackgroundColor: cs.error.withOpacity(.4),
            disabledForegroundColor: cs.onError.withOpacity(.8),
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
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.error.withOpacity(.95), cs.error.withOpacity(.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Delete Confirmation',
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
          width: 140,
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
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
