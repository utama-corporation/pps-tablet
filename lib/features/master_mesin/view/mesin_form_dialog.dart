import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';
import '../view_model/master_mesin_view_model.dart';

class MesinFormDialog extends StatefulWidget {
  const MesinFormDialog({super.key, required this.viewModel, this.edit});

  final MasterMesinViewModel viewModel;
  final MstMesin? edit;

  @override
  State<MesinFormDialog> createState() => _MesinFormDialogState();
}

class _MesinFormDialogState extends State<MesinFormDialog> {
  late final TextEditingController _nama;
  late final TextEditingController _kapasitas;
  late final TextEditingController _idUom;
  late int _idBagianMesin;
  late bool _enable;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _nama = TextEditingController(text: edit?.namaMesin ?? '');
    _kapasitas = TextEditingController(
      text: edit?.kapasitas == null ? '' : _fmtNum(edit!.kapasitas!),
    );
    _idUom = TextEditingController(
      text: edit?.idUom == null ? '' : '${edit!.idUom}',
    );
    _idBagianMesin = edit?.idBagianMesin ?? masterBagianMesin.first.id;
    _enable = edit?.enable ?? true;
  }

  static String _fmtNum(num v) =>
      v % 1 == 0 ? '${v.toInt()}' : v.toString();

  @override
  void dispose() {
    _nama.dispose();
    _kapasitas.dispose();
    _idUom.dispose();
    super.dispose();
  }

  num? _parseNum(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t.replaceAll(',', '.'));
  }

  int? _parseInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama mesin wajib diisi.');
      return;
    }
    final kapasitasRaw = _kapasitas.text.trim();
    final kapasitas = _parseNum(kapasitasRaw);
    if (kapasitasRaw.isNotEmpty && kapasitas == null) {
      setState(() => _error = 'Kapasitas harus berupa angka.');
      return;
    }
    final idUomRaw = _idUom.text.trim();
    final idUom = _parseInt(idUomRaw);
    if (idUomRaw.isNotEmpty && (idUom == null || idUom <= 0)) {
      setState(() => _error = 'ID UOM harus berupa angka.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.save(
        idMesin: widget.edit?.idMesin,
        namaMesin: nama,
        idBagianMesin: _idBagianMesin,
        kapasitas: kapasitas,
        idUom: idUom,
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

  InputDecoration _fieldDecoration(String label, {String? hint}) =>
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
                          ? 'Ubah Mesin ${widget.edit!.namaMesin}'
                          : 'Tambah Mesin',
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
                textCapitalization: TextCapitalization.characters,
                maxLength: 50,
                decoration: _fieldDecoration('Nama Mesin'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _idBagianMesin,
                decoration: _fieldDecoration('Bagian / Proses'),
                isExpanded: true,
                items: [
                  for (final b in masterBagianMesin)
                    DropdownMenuItem(value: b.id, child: Text(b.label)),
                ],
                onChanged: (v) => setState(() => _idBagianMesin = v ?? _idBagianMesin),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kapasitas,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _fieldDecoration(
                        'Kapasitas (opsional)',
                        hint: 'mis. 1200',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _idUom,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      decoration: _fieldDecoration('ID UOM'),
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
                  'Mesin aktif',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  _enable
                      ? 'Bisa dipilih di produksi'
                      : 'Disembunyikan dari pilihan produksi',
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
