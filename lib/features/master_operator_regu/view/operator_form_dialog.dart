import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/search_dropdown_field.dart';
import '../../../core/network/api_error.dart';
import '../../operator/model/operator_model.dart';
import '../view_model/master_operator_regu_view_model.dart';

class OperatorFormDialog extends StatefulWidget {
  const OperatorFormDialog({super.key, required this.viewModel, this.edit});

  final MasterOperatorReguViewModel viewModel;
  final MstOperator? edit;

  @override
  State<OperatorFormDialog> createState() => _OperatorFormDialogState();
}

class _OperatorFormDialogState extends State<OperatorFormDialog> {
  late final TextEditingController _nama;
  late bool _enable;
  OperatorBagian? _bagian;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.edit?.namaOperator ?? '');
    _enable = widget.edit?.enable ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = widget.viewModel;
      if (vm.bagianOptions == null) await vm.loadBagianOptions();
      if (!mounted) return;
      final edit = widget.edit;
      if (edit != null && _bagian == null) {
        final match = _findBagian(vm.bagianOptions, edit.idBagian);
        setState(() {
          _bagian = match ??
              (edit.idBagian > 0
                  ? OperatorBagian(
                      idBagianMesin: edit.idBagian,
                      namaBagianMesin: edit.namaBagianMesin.trim().isEmpty
                          ? 'Bagian ${edit.idBagian}'
                          : edit.namaBagianMesin,
                    )
                  : null);
        });
      }
    });
  }

  OperatorBagian? _findBagian(List<OperatorBagian>? options, int id) {
    if (options == null) return null;
    for (final o in options) {
      if (o.idBagianMesin == id) return o;
    }
    return null;
  }

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama operator wajib diisi.');
      return;
    }
    final bagian = _bagian;
    if (bagian == null) {
      setState(() => _error = 'Bagian operator wajib dipilih.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.saveOperator(
        idOperator: widget.edit?.idOperator,
        namaOperator: nama,
        idBagian: bagian.idBagianMesin,
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
                      _isEdit ? Icons.edit : Icons.person_add_alt_outlined,
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
                          ? 'Ubah Operator ${widget.edit!.namaOperator}'
                          : 'Tambah Operator',
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
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: 'Nama Operator',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Consumer<MasterOperatorReguViewModel>(
                builder: (context, vm, _) => SearchDropdownField<OperatorBagian>(
                  items: vm.bagianOptions ?? const [],
                  value: _bagian,
                  onChanged: (v) => setState(() => _bagian = v),
                  itemAsString: (b) => b.namaBagianMesin,
                  compareFn: (a, b) => a.idBagianMesin == b.idBagianMesin,
                  label: 'Bagian',
                  hint: 'Pilih bagian',
                  searchHint: 'Cari bagian…',
                  prefixIcon: Icons.precision_manufacturing_outlined,
                  isLoading: vm.bagianLoading && vm.bagianOptions == null,
                  fetchError:
                      vm.bagianError.isNotEmpty && vm.bagianOptions == null,
                  fetchErrorText:
                      vm.bagianError.isNotEmpty ? vm.bagianError : null,
                  onRetry: () => vm.loadBagianOptions(force: true),
                ),
              ),
              SwitchListTile(
                value: _enable,
                onChanged: (v) => setState(() => _enable = v),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Operator aktif',
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
