import 'package:flutter/material.dart';

import '../../../common/widgets/search_dropdown_field.dart';
import '../../../core/network/api_error.dart';
import '../model/master_blok_lokasi_models.dart';
import '../view_model/master_blok_lokasi_view_model.dart';

class BlokFormDialog extends StatefulWidget {
  const BlokFormDialog({super.key, required this.viewModel, this.edit});

  final MasterBlokLokasiViewModel viewModel;
  final BlokRow? edit;

  @override
  State<BlokFormDialog> createState() => _BlokFormDialogState();
}

class _BlokFormDialogState extends State<BlokFormDialog> {
  late final TextEditingController _blok;
  WarehouseOption? _warehouse;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _blok = TextEditingController(text: edit?.blok ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = widget.viewModel;
      if (vm.master == null) await vm.loadMaster();
      if (!mounted) return;
      final edit = widget.edit;
      if (edit != null) {
        final list = vm.master?.warehouses ?? const <WarehouseOption>[];
        for (final w in list) {
          if (w.id == edit.idWarehouse) {
            setState(() => _warehouse = w);
            return;
          }
        }
        setState(() {
          _warehouse = WarehouseOption(edit.idWarehouse, edit.namaWarehouse);
        });
      }
    });
  }

  @override
  void dispose() {
    _blok.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final code = _blok.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{1,3}$').hasMatch(code)) {
      setState(() => _error = 'Kode blok 1-3 karakter, huruf & angka saja.');
      return;
    }
    if (_warehouse == null) {
      setState(() => _error = 'Warehouse wajib dipilih.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.saveBlok(
        editBlok: widget.edit?.blok,
        blok: code,
        idWarehouse: _warehouse!.id,
      );
      if (mounted) Navigator.of(context).pop(code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = widget.viewModel.master;
    final loading = widget.viewModel.masterLoading && master == null;
    final warehouses = master?.warehouses ?? const <WarehouseOption>[];
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
                      color: _isEdit ? Colors.orange.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit : Icons.add_location_alt_outlined,
                      color: _isEdit
                          ? Colors.orange.shade700
                          : Colors.teal.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Ubah Blok ${widget.edit!.blok}' : 'Tambah Blok',
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
                controller: _blok,
                autofocus: !_isEdit,
                enabled: !_isEdit,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                onChanged: (v) {
                  final upper = v.toUpperCase();
                  if (v != upper) {
                    _blok.value = TextEditingValue(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Kode Blok',
                  hintText: 'mis. A, B1',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SearchDropdownField<WarehouseOption>(
                items: warehouses,
                value: _warehouse,
                onChanged: (v) => setState(() => _warehouse = v),
                itemAsString: (w) => w.nama,
                compareFn: (a, b) => a.id == b.id,
                label: 'Warehouse',
                hint: 'Pilih warehouse',
                searchHint: 'Cari warehouse…',
                prefixIcon: Icons.warehouse_outlined,
                isLoading: loading,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
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
                    onPressed: _submitting ? null : () => Navigator.pop(context),
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
