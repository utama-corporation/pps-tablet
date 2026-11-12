import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../model/master_barang_models.dart';
import '../view_model/master_barang_view_model.dart';

/// Form dinamis — field dirender dari meta backend
/// (`GET /api/mst-barang/meta` → `types[].fields[]`).
class MasterBarangFormDialog extends StatefulWidget {
  const MasterBarangFormDialog({
    super.key,
    required this.viewModel,
    required this.type,
    this.edit,
  });

  final MasterBarangViewModel viewModel;
  final MasterBarangTypeMeta type;
  final MasterBarangItem? edit;

  @override
  State<MasterBarangFormDialog> createState() => _MasterBarangFormDialogState();
}

class _MasterBarangFormDialogState extends State<MasterBarangFormDialog> {
  late final TextEditingController _nama;
  final Map<String, TextEditingController> _texts = {};
  final Map<String, bool> _bools = {};
  final Map<String, int?> _selects = {};
  late bool _enable;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _nama = TextEditingController(text: edit?.nama ?? '');
    _enable = edit?.enable ?? true;
    for (final field in widget.type.fields) {
      switch (field.kind) {
        case 'bool':
          _bools[field.key] = edit != null
              ? edit.fieldBool(field.key)
              : field.defaultValue == true;
        case 'select':
          _selects[field.key] = edit?.field(field.key) == null
              ? null
              : num.tryParse(edit!.field(field.key).toString())?.toInt();
        default:
          final rawValue = edit?.field(field.key);
          var initial = rawValue?.toString() ?? '';
          if (field.kind != 'text' && rawValue != null) {
            final parsed = num.tryParse(rawValue.toString());
            initial = parsed == null
                ? rawValue.toString()
                : MasterBarangItem.fmtNum(parsed);
          }
          _texts[field.key] = TextEditingController(text: initial);
      }
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  num? _parseNum(String raw, String fieldLabel, {required bool integer}) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final n = num.tryParse(t.replaceAll(',', '.'));
    if (n == null || n < 0) {
      throw FormatException('$fieldLabel harus angka tidak negatif.');
    }
    if (integer && n % 1 != 0) {
      throw FormatException('$fieldLabel harus bilangan bulat.');
    }
    return n;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = '${widget.type.nameLabel} wajib diisi.');
      return;
    }

    final values = <String, dynamic>{};
    try {
      for (final field in widget.type.fields) {
        switch (field.kind) {
          case 'bool':
            values[field.key] = _bools[field.key] ?? false;
          case 'int':
            values[field.key] = _parseNum(
              _texts[field.key]!.text,
              field.label,
              integer: true,
            );
          case 'decimal':
            values[field.key] = _parseNum(
              _texts[field.key]!.text,
              field.label,
              integer: false,
            );
          case 'select':
            final v = _selects[field.key];
            if (field.required && v == null) {
              throw FormatException('${field.label} wajib dipilih.');
            }
            values[field.key] = v;
          default:
            values[field.key] = _texts[field.key]!.text.trim();
        }
      }
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.save(
        id: widget.edit?.id,
        nama: nama,
        values: values,
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

  InputDecoration _decoration(String label, {bool required = false}) =>
      InputDecoration(
        labelText: required ? '$label *' : label,
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

  Widget _buildField(MasterBarangFieldMeta field) {
    final meta = widget.viewModel.meta!;
    switch (field.kind) {
      case 'bool':
        return SwitchListTile(
          value: _bools[field.key] ?? false,
          onChanged: (v) => setState(() => _bools[field.key] = v),
          contentPadding: EdgeInsets.zero,
          title: Text(field.label, style: const TextStyle(fontSize: 14)),
          activeThumbColor: const Color(0xFF15803D),
        );
      case 'select':
        final dependsOnValue = field.dependsOn == null
            ? null
            : _selects[field.dependsOn!];
        final options = meta.optionsFor(
          field.source ?? '',
          parentId: field.dependsOn == null ? null : dependsOnValue,
        );
        final current = _selects[field.key];
        final items = <DropdownMenuItem<int?>>[
          DropdownMenuItem<int?>(
            value: null,
            child: Text(field.required ? '— Pilih —' : 'Tidak'),
          ),
          for (final o in options)
            DropdownMenuItem<int?>(value: o.id, child: Text(o.label)),
          if (current != null && !options.any((o) => o.id == current))
            DropdownMenuItem<int?>(value: current, child: Text('ID $current')),
        ];
        return DropdownButtonFormField<int?>(
          key: ValueKey('mb-field-${field.key}'),
          initialValue: current,
          decoration: _decoration(field.label, required: field.required),
          isExpanded: true,
          items: items,
          onChanged: (v) => setState(() => _selects[field.key] = v),
        );
      case 'int':
      case 'decimal':
        final isInt = field.kind == 'int';
        return TextField(
          controller: _texts[field.key]!,
          keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
          decoration: _decoration(field.label, required: field.required),
          textInputAction: TextInputAction.next,
        );
      default:
        final isItemCode = field.key == 'itemCode';
        return TextField(
          controller: _texts[field.key]!,
          maxLength: field.maxLength ?? 50,
          textCapitalization: isItemCode
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          decoration: _decoration(field.label, required: field.required),
          textInputAction: TextInputAction.next,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                          ? 'Ubah ${widget.type.label} ${widget.edit!.nama}'
                          : 'Tambah ${widget.type.label}',
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nama,
                        autofocus: true,
                        maxLength: 200,
                        decoration: _decoration(
                          widget.type.nameLabel,
                          required: true,
                        ),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      for (final field in widget.type.fields) ...[
                        _buildField(field),
                        const SizedBox(height: 12),
                      ],
                      SwitchListTile(
                        value: _enable,
                        onChanged: (v) => setState(() => _enable = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Aktif',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Item nonaktif disembunyikan dari pilihan',
                          style: TextStyle(fontSize: 12),
                        ),
                        activeThumbColor: const Color(0xFF15803D),
                      ),
                    ],
                  ),
                ),
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
