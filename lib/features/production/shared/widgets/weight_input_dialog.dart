import 'package:flutter/material.dart';
import '../../shared/utils/format.dart';

class WeightInputDialog extends StatelessWidget {
  final double maxWeight;
  final double? currentWeight;
  final int? maxDecimalPlaces;

  const WeightInputDialog({
    super.key,
    required this.maxWeight,
    this.currentWeight,
    this.maxDecimalPlaces,
  });

  static Future<double?> show(
      BuildContext context, {
        required double maxWeight,
        double? currentWeight,
        int? maxDecimalPlaces,
      }) {
    return showDialog<double>(
      context: context,
      builder: (context) => WeightInputDialog(
        maxWeight: maxWeight,
        currentWeight: currentWeight,
        maxDecimalPlaces: maxDecimalPlaces,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(
      text: currentWeight != null ? currentWeight.toString() : '',
    );
    final formKey = GlobalKey<FormState>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ MODERN HEADER - Icon on side
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade600,
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
                          'Edit Berat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Masukkan nilai berat baru',
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

            // ✅ CONTENT - Clean & Spacious
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtle info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Batas maksimal: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${num2(maxWeight)} kg',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Input with large font
                      TextFormField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: num2(maxWeight / 2),
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
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber.shade600, width: 2),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
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

                          final normalized = value.trim().replaceAll(',', '.');
                          if (maxDecimalPlaces != null &&
                              !RegExp(r'^\d+(?:\.\d{1,' + maxDecimalPlaces.toString() + r'})?$')
                                  .hasMatch(normalized)) {
                            return 'Maksimal $maxDecimalPlaces angka di belakang koma';
                          }
                          final weight = double.tryParse(normalized);
                          if (weight == null || !weight.isFinite) {
                            return 'Format tidak valid';
                          }

                          if (weight <= 0) {
                            return 'Harus > 0';
                          }

                          if (beratLebihDari(weight, maxWeight)) {
                            return 'Melebihi batas';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ✅ FOOTER - Modern button style
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
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
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
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final weight = double.parse(controller.text.trim().replaceAll(',', '.'));
                          Navigator.pop(context, weight);
                        }
                      },
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
    );
  }
}