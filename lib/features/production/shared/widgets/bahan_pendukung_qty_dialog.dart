// lib/features/production/shared/widgets/bahan_pendukung_qty_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bahan_pendukung_item.dart' as bp;

/// Dialog input jumlah Bahan Pendukung (BP.) saat scan label.
///
/// Mendukung input PARSIAL: operator boleh mengisi qty kurang dari sisa label
/// ([BahanPendukungItem.quantity]). Mengembalikan [BahanPendukungQtyResult],
/// atau `null` jika dibatalkan.
class BahanPendukungQtyResult {
  final num qty;
  final num maxQty;
  final bool isPartial;

  const BahanPendukungQtyResult({
    required this.qty,
    required this.maxQty,
    required this.isPartial,
  });
}

class BahanPendukungQtyDialog extends StatefulWidget {
  final bp.BahanPendukungItem item;
  final Color primaryColor;

  const BahanPendukungQtyDialog({
    super.key,
    required this.item,
    this.primaryColor = const Color(0xFF1E6FD9),
  });

  @override
  State<BahanPendukungQtyDialog> createState() =>
      _BahanPendukungQtyDialogState();
}

class _BahanPendukungQtyDialogState extends State<BahanPendukungQtyDialog> {
  late final TextEditingController _ctrl;
  late final num _maxQty;
  String? _error;

  @override
  void initState() {
    super.initState();
    _maxQty = widget.item.quantity;
    _ctrl = TextEditingController(text: '${_maxQty.toInt()}');
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = int.tryParse(_ctrl.text.trim());
    if (val == null || val <= 0) {
      setState(() => _error = 'Masukkan angka yang valid');
      return;
    }
    if (val > _maxQty) {
      setState(() => _error = 'Maksimal ${_maxQty.toInt()}');
      return;
    }
    Navigator.of(context).pop(
      BahanPendukungQtyResult(
        qty: val,
        maxQty: _maxQty,
        isPartial: val < _maxQty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor;
    final labelCode = widget.item.noBahanPendukung ?? '-';
    final namaJenis = widget.item.namaJenis ?? 'Bahan Pendukung';
    final uom = widget.item.namaUom ?? '';

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labelCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          namaJenis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Input field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan jumlah yang akan diinput',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      suffixText: uom.isNotEmpty
                          ? '/ ${_maxQty.toInt()} $uom'
                          : '/ ${_maxQty.toInt()}',
                      suffixStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                      errorText: _error,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Tambah'),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}