import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Panggil ini dari mana saja:
/// await showInputLabelStockOpnameBottomSheet(
///   context: context,
///   label: 'A.123.456',
///   onSave: (sak, berat) { /* ... */ },
/// );
Future<void> showInputLabelStockOpnameBottomSheet({
  required BuildContext context,
  required String label,
  required void Function(int jmlhSak, double berat) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => InputLabelStockOpnameSheet(label: label, onSave: onSave),
  );
}

class InputLabelStockOpnameSheet extends StatefulWidget {
  final String label;
  final Function(int jmlhSak, double berat) onSave;

  const InputLabelStockOpnameSheet({
    Key? key,
    required this.label,
    required this.onSave,
  }) : super(key: key);

  @override
  State<InputLabelStockOpnameSheet> createState() => _InputLabelStockOpnameSheetState();
}

class _InputLabelStockOpnameSheetState extends State<InputLabelStockOpnameSheet> {
  final TextEditingController _sakController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _sakController.dispose();
    _beratController.dispose();
    super.dispose();
  }

  double? _parseBerat(String v) {
    if (v.trim().isEmpty) return null;
    // terima koma/dot (id-ID)
    final normalized = v.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final jmlhSak = int.parse(_sakController.text.trim());
    final berat = _parseBerat(_beratController.text.trim())!;

    setState(() => _saving = true);
    // kalau ada proses async, taruh di sini. Sekarang langsung callback:
    widget.onSave(jmlhSak, berat);
    Navigator.of(context).pop(); // tutup sheet
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // header
          Row(
            children: const [
              SizedBox(width: 16),
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit Detail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),

          // content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _LabelInfo(title: 'Label', value: widget.label),
                  const SizedBox(height: 16),

                  // Pcs (sak)
                  TextFormField(
                    controller: _sakController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Pcs',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Pcs tidak boleh kosong';
                      final n = int.tryParse(t);
                      if (n == null || n <= 0) return 'Pcs harus angka lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Berat (kg)
                  TextFormField(
                    controller: _beratController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    inputFormatters: [
                      // izinkan angka, koma, titik
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Berat (kg)',
                      prefixIcon: Icon(Icons.scale),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Berat tidak boleh kosong';
                      final d = _parseBerat(t);
                      if (d == null || d <= 0) return 'Berat harus angka lebih dari 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Simpan Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelInfo extends StatelessWidget {
  final String title;
  final String value;
  const _LabelInfo({required this.title, required this.value, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.qr_code_2, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
