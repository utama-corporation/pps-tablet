import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../model/supplier_item.dart';
import '../view_model/master_supplier_view_model.dart';

final _phoneReg = RegExp(r'^[0-9\-.,]*$');

class SupplierFormDialog extends StatefulWidget {
  const SupplierFormDialog({super.key, required this.viewModel, this.edit});

  final MasterSupplierViewModel viewModel;
  final SupplierItem? edit;

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  late final TextEditingController _nama;
  late final TextEditingController _initial;
  late final TextEditingController _noTlp;
  late bool _enable;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.edit?.namaSupplier ?? '');
    _initial = TextEditingController(text: widget.edit?.initial ?? '');
    _noTlp = TextEditingController(text: widget.edit?.noTlp ?? '');
    _enable = widget.edit?.enable ?? true;
  }

  @override
  void dispose() {
    _nama.dispose();
    _initial.dispose();
    _noTlp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama supplier wajib diisi.');
      return;
    }
    final tlp = _noTlp.text.trim();
    if (!_phoneReg.hasMatch(tlp)) {
      setState(
        () => _error = 'No. Tlp/HP hanya boleh angka dan karakter - . ,',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.save(
        id: widget.edit?.idSupplier,
        namaSupplier: nama,
        initial: _initial.text,
        noTlp: _noTlp.text,
        enable: _enable,
      );
      if (mounted) Navigator.of(context).pop(nama);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isEdit
                          ? Colors.orange.shade50
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit : Icons.add,
                      color: _isEdit
                          ? Colors.orange.shade700
                          : Colors.teal.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEdit
                          ? 'Ubah Supplier ${widget.edit!.namaSupplier}'
                          : 'Tambah Supplier',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nama,
                autofocus: true,
                maxLength: 100,
                decoration: _decoration('Nama Supplier'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _initial,
                      maxLength: 25,
                      decoration: _decoration('Initial'),
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _noTlp,
                      maxLength: 25,
                      keyboardType: TextInputType.phone,
                      decoration: _decoration('No. Tlp/HP', hint: '0812-xxxx'),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _enable,
                onChanged: (v) => setState(() => _enable = v),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Supplier aktif',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  _enable
                      ? 'Bisa dipilih di transaksi'
                      : 'Disembunyikan dari pilihan transaksi',
                  style: const TextStyle(fontSize: 12),
                ),
                activeThumbColor: const Color(0xFF15803D),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('BATAL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEdit
                          ? const Color(0xFFF57C00)
                          : const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SIMPAN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
