// lib/features/production/crusher/widgets/crusher_berat_input_dialog.dart
// Weight input dialog untuk Reject (BF.) — mengikuti GilinganBeratInputDialog.
//
// Bedanya hanya view model (Crusher) dan warna. Kalau berat yang diambil
// kurang dari berat sisa, baris otomatis ditandai partial — sama seperti
// dialog berat di gilingan.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/models/reject_item.dart';
import '../view_model/crusher_production_input_view_model.dart';

const _kCrusherBeratColor = Color(0xFF1E6FD9);

class CrusherBeratInputDialog extends StatefulWidget {
  final String noProduksi;

  const CrusherBeratInputDialog({super.key, required this.noProduksi});

  @override
  State<CrusherBeratInputDialog> createState() =>
      _CrusherBeratInputDialogState();
}

class _CrusherBeratInputDialogState extends State<CrusherBeratInputDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _ready = false;
  double? _originalBerat;
  String _labelCode = '-';
  String _namaJenis = '-';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<CrusherProductionInputViewModel>();
      if (vm.inputsOf(widget.noProduksi) == null) {
        await vm.loadInputs(widget.noProduksi);
      }

      final result = vm.lastLookup;
      if (result != null && result.typedItems.isNotEmpty) {
        final item = result.typedItems.first;
        if (item is RejectItem) {
          _labelCode = item.noReject ?? '-';
          _namaJenis = item.namaJenis ?? '-';
          _originalBerat = item.berat;
        }

        if (_originalBerat != null) {
          _ctrl.text = num2(_originalBerat!);
        }
      }

      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _inputBerat {
    return double.tryParse(_ctrl.text.replaceAll(',', '.'));
  }

  bool get _isValid {
    final v = _inputBerat;
    if (v == null || v <= 0) return false;
    if (_originalBerat != null && v > _originalBerat!) return false;
    return true;
  }

  void _commit(CrusherProductionInputViewModel vm) {
    final result = vm.lastLookup;
    if (result == null || result.data.isEmpty || !_isValid) return;

    final row = result.data.first;
    final origBerat = row['berat'];
    final origIsPartial = row['isPartial'];

    final isPartial =
        _originalBerat != null && _inputBerat! < _originalBerat!;

    row['berat'] = _inputBerat;
    row['Berat'] = _inputBerat;
    if (isPartial) {
      row['isPartial'] = true;
      row['IsPartial'] = true;
    }

    vm.clearPicks();
    vm.togglePick(row);
    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

    row['berat'] = origBerat;
    row['Berat'] = origBerat;
    row['isPartial'] = origIsPartial;
    row['IsPartial'] = origIsPartial;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.added > 0
              ? '✅ Reject ditambahkan${isPartial ? ' (partial)' : ''}'
              : 'Gagal menambahkan atau sudah ada',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CrusherProductionInputViewModel>(
      builder: (context, vm, _) {
        if (!_ready) {
          return const Dialog(
            child: SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final isOverMax = _inputBerat != null &&
            _originalBerat != null &&
            _inputBerat! > _originalBerat!;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: _kCrusherBeratColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.scale_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _labelCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _namaJenis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'REJECT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Body ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_originalBerat != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.scale_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Berat sisa',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${num2(_originalBerat!)} kg',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      Text(
                        'Berat yang diambil',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kCrusherBeratColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*[,.]?\d*'),
                                ),
                              ],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isOverMax
                                    ? Colors.red.shade700
                                    : _kCrusherBeratColor,
                              ),
                              decoration: InputDecoration(
                                suffixText: 'kg',
                                suffixStyle: TextStyle(
                                  fontSize: 14,
                                  color: _kCrusherBeratColor,
                                ),
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 24,
                                  color: Colors.grey.shade300,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: _kCrusherBeratColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isOverMax
                                        ? Colors.red
                                        : _kCrusherBeratColor,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isOverMax
                                        ? Colors.red.shade300
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_originalBerat != null) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Isi berat penuh',
                              child: InkWell(
                                onTap: () => setState(() {
                                  _ctrl.text = num2(_originalBerat!);
                                }),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE1F5FE),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _kCrusherBeratColor.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_double_arrow_up,
                                    size: 18,
                                    color: _kCrusherBeratColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (isOverMax)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Colors.red.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tidak boleh melebihi ${num2(_originalBerat!)} kg',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Footer ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            foregroundColor: Colors.grey.shade700,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isValid ? () => _commit(vm) : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kCrusherBeratColor,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Tambahkan',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
      },
    );
  }
}