import 'package:flutter/material.dart';

import '../../model/warehouse_group_model.dart';

const _kPrimary = Color(0xFF0D47A1);

class WarehouseGroupFormResult {
  final String namaGroup;
  final String? keterangan;
  final bool aktif;

  WarehouseGroupFormResult({
    required this.namaGroup,
    required this.keterangan,
    required this.aktif,
  });
}

/// Dialog tambah / edit group warehouse. Return [WarehouseGroupFormResult]
/// kalau disimpan, atau null kalau dibatalkan.
class WarehouseGroupFormDialog extends StatefulWidget {
  final WarehouseGroup? existing;

  const WarehouseGroupFormDialog({super.key, this.existing});

  @override
  State<WarehouseGroupFormDialog> createState() =>
      _WarehouseGroupFormDialogState();
}

class _WarehouseGroupFormDialogState extends State<WarehouseGroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _keterangan;
  late bool _aktif;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.existing?.namaGroup ?? '');
    _keterangan = TextEditingController(
      text: widget.existing?.keterangan ?? '',
    );
    _aktif = widget.existing?.aktif ?? true;
  }

  @override
  void dispose() {
    _nama.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      WarehouseGroupFormResult(
        namaGroup: _nama.text.trim(),
        keterangan: _keterangan.text.trim().isEmpty
            ? null
            : _keterangan.text.trim(),
        aktif: _aktif,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Group Warehouse' : 'Tambah Group Warehouse'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nama,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Group *',
                  hintText: 'mis. Site Cikarang',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama group wajib diisi'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _keterangan,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  border: OutlineInputBorder(),
                ),
                maxLength: 255,
                maxLines: 2,
              ),
              if (_isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _kPrimary,
                  title: const Text('Aktif'),
                  subtitle: const Text(
                    'Group non-aktif tidak bisa dipilih untuk warehouse baru',
                  ),
                  value: _aktif,
                  onChanged: (v) => setState(() => _aktif = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kPrimary),
          onPressed: _submit,
          child: Text(_isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }
}
