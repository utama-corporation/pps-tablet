import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/confirm_dialog.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';
import '../model/uom_option.dart';
import '../view_model/master_mesin_view_model.dart';

/// Hasil dialog Tambah/Ubah Mesin.
enum MesinFormOutcome { saved, deactivated }

class MesinFormResult {
  const MesinFormResult.saved(this.name) : outcome = MesinFormOutcome.saved;
  const MesinFormResult.deactivated(this.name)
    : outcome = MesinFormOutcome.deactivated;

  final MesinFormOutcome outcome;
  final String name;
}

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
  late final TextEditingController _shortWeightPs;
  late final TextEditingController _klemLebar;
  late final TextEditingController _klemTinggi;
  late int _idBagianMesin;
  late bool _enable;
  int? _selectedUom;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;
  bool _canDelete = false;

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
    _selectedUom = edit?.idUom;
    _shortWeightPs = TextEditingController(
      text: edit?.shotWeightPs == null ? '' : _fmtNum(edit!.shotWeightPs!),
    );
    _klemLebar = TextEditingController(
      text: edit?.klemLebar == null ? '' : _fmtNum(edit!.klemLebar!),
    );
    _klemTinggi = TextEditingController(
      text: edit?.klemPanjang == null ? '' : _fmtNum(edit!.klemPanjang!),
    );
    _canDelete = context.read<PermissionViewModel>().can('datamastermesin:delete');
  }

  /// Opsi dropdown; edit dengan idUom di luar opsi (data lama / UOM
  /// dinonaktifkan) tetap ditampilkan supaya tidak hilang dari form.
  List<UomOption> get _effectiveUomOptions {
    final options = widget.viewModel.uomOptions;
    final selected = widget.edit?.idUom;
    if (selected != null && options.every((o) => o.idUom != selected)) {
      return [...options, UomOption(idUom: selected, namaUom: '#$selected')];
    }
    return options;
  }

  static String _fmtNum(num v) =>
      v % 1 == 0 ? '${v.toInt()}' : v.toString();

  @override
  void dispose() {
    _nama.dispose();
    _kapasitas.dispose();
    _idUom.dispose();
    _shortWeightPs.dispose();
    _klemLebar.dispose();
    _klemTinggi.dispose();
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
    if (kapasitasRaw.isEmpty) {
      setState(() => _error = 'Kapasitas wajib diisi.');
      return;
    }
    if (kapasitas == null || kapasitas < 0) {
      setState(() => _error = 'Kapasitas harus berupa angka (≥ 0).');
      return;
    }
    final isInject = _idBagianMesin == 4;
    num? parseOptional(String raw, String label) {
      final t = raw.trim();
      if (t.isEmpty) return 0;
      final n = _parseNum(t);
      if (n == null || n < 0) {
        throw FormatException('$label harus berupa angka (≥ 0).');
      }
      return n;
    }

    num? shortWeightPs, klemLebar, klemTinggi;
    if (isInject) {
      try {
        shortWeightPs = parseOptional(_shortWeightPs.text, 'Shot Weight PS');
        klemLebar = parseOptional(_klemLebar.text, 'Klem Lebar');
        klemTinggi = parseOptional(_klemTinggi.text, 'Klem Tinggi');
      } on FormatException catch (e) {
        setState(() => _error = e.message);
        return;
      }
    }
    final idUomRaw = _idUom.text.trim();
    final useDropdown = widget.viewModel.uomOptions.isNotEmpty;
    int? idUom;
    if (useDropdown) {
      if (_selectedUom == null) {
        setState(() => _error = 'UOM wajib dipilih.');
        return;
      }
      idUom = _selectedUom;
    } else {
      idUom = _parseInt(idUomRaw);
      if (idUomRaw.isEmpty) {
        setState(() => _error = 'ID UOM wajib diisi.');
        return;
      }
      if (idUom == null || idUom <= 0) {
        setState(() => _error = 'ID UOM harus berupa angka.');
        return;
      }
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
        shortWeightPs: shortWeightPs,
        klemLebar: klemLebar,
        klemTinggi: klemTinggi,
      );
      if (mounted) Navigator.of(context).pop(MesinFormResult.saved(nama));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deactivate() async {
    if (_submitting) return;
    final edit = widget.edit;
    if (edit == null) return;
    final idBagianMesin = edit.idBagianMesin;
    if (idBagianMesin == null) {
      setState(() => _error = 'Bagian mesin tidak diketahui.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Nonaktifkan Mesin',
        message:
            'Nonaktifkan mesin ${edit.namaMesin}? Mesin tidak dihapus permanen; bisa diaktifkan kembali lewat ubah.',
        confirmLabel: 'Nonaktifkan',
        confirmIcon: Icons.visibility_off_outlined,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.delete(edit.idMesin, idBagianMesin: idBagianMesin);
      if (!mounted) return;
      Navigator.of(context).pop(MesinFormResult.deactivated(edit.namaMesin));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _injectField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        maxLength: 10,
        decoration: _fieldDecoration(label),
        textInputAction: TextInputAction.next,
      );

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
                        'Kapasitas',
                        hint: 'mis. 1200',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: widget.viewModel.uomOptions.isNotEmpty
                        ? DropdownButtonFormField<int>(
                            initialValue: _selectedUom,
                            decoration: _fieldDecoration('UOM'),
                            isExpanded: true,
                            hint: const Text('Pilih UOM'),
                            items: [
                              for (final o in _effectiveUomOptions)
                                DropdownMenuItem(
                                  value: o.idUom,
                                  child: Text(o.namaUom),
                                ),
                            ],
                            onChanged: (v) => setState(() => _selectedUom = v),
                          )
                        : TextField(
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
              if (_idBagianMesin == 4) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _injectField(_shortWeightPs, 'Shot Weight PS'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _injectField(_klemLebar, 'Klem Lebar'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _injectField(_klemTinggi, 'Klem Tinggi'),
                    ),
                  ],
                ),
              ],
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
                children: [
                  if (_isEdit && _canDelete)
                    TextButton(
                      onPressed: _submitting ? null : _deactivate,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'NONAKTIFKAN',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
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
                        horizontal: 18,
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
