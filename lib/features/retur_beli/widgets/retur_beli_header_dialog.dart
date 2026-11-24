import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/widgets/app_date_field.dart';
import '../../../common/widgets/app_text_field.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../master_supplier/model/supplier_item.dart';
import '../../master_supplier/repository/master_supplier_repository.dart';

const _kPrimary = Color(0xFF1E6FD9);

/// Hasil dialog header Retur Beli.
class ReturBeliHeaderInput {
  final DateTime tanggal;
  final int idSupplier;
  final String keterangan;
  const ReturBeliHeaderInput({
    required this.tanggal,
    required this.idSupplier,
    required this.keterangan,
  });

  String get tanggalYmd => DateFormat('yyyy-MM-dd').format(tanggal);
}

/// Form buat/ubah header Retur Beli: tanggal, supplier, keterangan.
/// [supplierLocked] = supplier tidak bisa diganti (sudah ada item).
/// Visual mengikuti `ReturV3HeaderFormDialog`: Dialog putih berborder radius,
/// ikon bersegmen di header, form di atas kartu abu, footer BATAL / SIMPAN.
class ReturBeliHeaderDialog extends StatefulWidget {
  final DateTime? tanggal;
  final int? idSupplier;
  final String keterangan;
  final bool supplierLocked;
  final MasterSupplierRepository? supplierRepository;

  const ReturBeliHeaderDialog({
    super.key,
    this.tanggal,
    this.idSupplier,
    this.keterangan = '',
    this.supplierLocked = false,
    this.supplierRepository,
  });

  static Future<ReturBeliHeaderInput?> show(
    BuildContext context, {
    DateTime? tanggal,
    int? idSupplier,
    String keterangan = '',
    bool supplierLocked = false,
    MasterSupplierRepository? supplierRepository,
  }) {
    return showDialog<ReturBeliHeaderInput>(
      context: context,
      builder: (_) => ReturBeliHeaderDialog(
        tanggal: tanggal,
        idSupplier: idSupplier,
        keterangan: keterangan,
        supplierLocked: supplierLocked,
        supplierRepository: supplierRepository,
      ),
    );
  }

  @override
  State<ReturBeliHeaderDialog> createState() => _ReturBeliHeaderDialogState();
}

class _ReturBeliHeaderDialogState extends State<ReturBeliHeaderDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _tanggal = widget.tanggal ?? DateTime.now();
  late int? _idSupplier = widget.idSupplier;
  late final TextEditingController _tanggalCtrl;
  late final TextEditingController _ket = TextEditingController(
    text: widget.keterangan,
  );
  List<SupplierItem> _suppliers = const [];
  String _error = '';
  bool _loading = true;

  bool get _isEdit => widget.idSupplier != null;

  @override
  void initState() {
    super.initState();
    _tanggalCtrl = TextEditingController(
      text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_tanggal),
    );
    _loadSuppliers();
  }

  @override
  void dispose() {
    _tanggalCtrl.dispose();
    _ket.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    final repo =
        widget.supplierRepository ?? MasterSupplierRepository(api: ApiClient());
    try {
      final all = await repo.fetchAll(status: 'all');
      if (!mounted) return;
      setState(() {
        _suppliers = all
            .where((s) => s.enable || s.idSupplier == widget.idSupplier)
            .toList()
          ..sort((a, b) => a.namaSupplier.compareTo(b.namaSupplier));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_idSupplier == null) {
      setState(() => _error = 'Supplier wajib dipilih');
      return;
    }
    Navigator.of(context).pop(
      ReturBeliHeaderInput(
        tanggal: _tanggal,
        idSupplier: _idSupplier!,
        keterangan: _ket.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isEdit
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isEdit ? Icons.edit : Icons.add,
                    color: _isEdit
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEdit ? 'Ubah Retur Beli' : 'Tambah Retur Beli',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppDateField(
                          key: const ValueKey('rb-tanggal'),
                          controller: _tanggalCtrl,
                          label: 'Tanggal',
                          leadingIcon: Icons.calendar_month_outlined,
                          format: DateFormat('EEEE, dd MMM yyyy', 'id_ID'),
                          initialDate: _tanggal,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                              ? 'Tanggal wajib dipilih'
                              : null,
                          onChanged: (d) {
                            if (d == null) return;
                            setState(() {
                              _tanggal = d;
                              _tanggalCtrl.text = DateFormat(
                                'EEEE, dd MMM yyyy',
                                'id_ID',
                              ).format(d);
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          )
                        else if (_error.isNotEmpty)
                          Text(
                            _error,
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          )
                        else
                          DropdownButtonFormField<int>(
                            key: const ValueKey('rb-supplier'),
                            initialValue: _idSupplier,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Supplier',
                              border: const OutlineInputBorder(),
                              helperText: widget.supplierLocked
                                  ? 'Supplier tidak bisa diganti karena sudah ada item.'
                                  : null,
                            ),
                            items: [
                              for (final s in _suppliers)
                                DropdownMenuItem(
                                  value: s.idSupplier,
                                  child: Text(
                                    s.namaSupplier,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: widget.supplierLocked
                                ? null
                                : (v) => setState(() => _idSupplier = v),
                            validator: (v) => v == null
                                ? 'Supplier wajib dipilih'
                                : null,
                          ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _ket,
                          label: 'Keterangan',
                          icon: Icons.notes_outlined,
                          hintText: 'Keterangan retur (opsional)',
                          maxLines: 3,
                          maxLength: 500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BATAL'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  key: const ValueKey('rb-header-save'),
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  child: const Text('SIMPAN'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
