// lib/features/production/shared/widgets/pcs_weight_input_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/utils/format.dart';

class PcsWeightInputDialog {
  /// Returns Map with 'pcs' (int) and 'weight' (double)
  static Future<Map<String, num>?> show(
      BuildContext context, {
        required int maxPcs,
        required double maxWeight,
        int? currentPcs,
        double? currentWeight,
      }) async {
    return showDialog<Map<String, num>>(
      context: context,
      builder: (ctx) => _PcsWeightInputDialogContent(
        maxPcs: maxPcs,
        maxWeight: maxWeight,
        currentPcs: currentPcs,
        currentWeight: currentWeight,
      ),
    );
  }
}

class _PcsWeightInputDialogContent extends StatefulWidget {
  final int maxPcs;
  final double maxWeight;
  final int? currentPcs;
  final double? currentWeight;

  const _PcsWeightInputDialogContent({
    required this.maxPcs,
    required this.maxWeight,
    this.currentPcs,
    this.currentWeight,
  });

  @override
  State<_PcsWeightInputDialogContent> createState() =>
      _PcsWeightInputDialogContentState();
}

class _PcsWeightInputDialogContentState
    extends State<_PcsWeightInputDialogContent> {
  late final TextEditingController _pcsController;
  late final TextEditingController _weightController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _pcsController = TextEditingController(
      text: widget.currentPcs?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.currentWeight?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _pcsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final pcs = int.parse(_pcsController.text.trim());
      final weight = double.parse(_weightController.text.trim());

      Navigator.pop(context, <String, num>{
        'pcs': pcs,
        'weight': weight,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ MODERN HEADER
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit PCS & Berat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Masukkan nilai baru',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ CONTENT
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Batas maksimal:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PCS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${widget.maxPcs}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BERAT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${num2(widget.maxWeight)} kg',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // PCS Input
                      Text(
                        'Jumlah PCS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _pcsController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '${widget.maxPcs ~/ 2}',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                          suffixText: 'pcs',
                          suffixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 16,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.purple.shade600,
                              width: 2,
                            ),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          focusedErrorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          errorStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Wajib diisi';
                          }

                          final pcs = int.tryParse(value.trim());
                          if (pcs == null) {
                            return 'Format tidak valid';
                          }

                          if (pcs <= 0) {
                            return 'Harus > 0';
                          }

                          if (pcs > widget.maxPcs) {
                            return 'Melebihi batas (${widget.maxPcs})';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),

                      const SizedBox(height: 24),

                      // Weight Input
                      Text(
                        'Berat (kg)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: num2(widget.maxWeight / 2),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                          suffixText: 'kg',
                          suffixStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 16,
                          ),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.purple.shade600,
                              width: 2,
                            ),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          focusedErrorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                          errorStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Wajib diisi';
                          }

                          final weight = double.tryParse(value.trim());
                          if (weight == null) {
                            return 'Format tidak valid';
                          }

                          if (weight <= 0) {
                            return 'Harus > 0';
                          }

                          if (beratLebihDari(weight, widget.maxWeight)) {
                            return 'Melebihi batas (${num2(widget.maxWeight)} kg)';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ✅ FOOTER
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _submit,
                        child: const Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}