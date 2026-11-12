import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/services/dialog_service.dart';
import '../model/barang_dagang_label.dart';
import '../view_model/barang_dagang_label_view_model.dart';

class BarangDagangEditDialog extends StatefulWidget {
  final BarangDagangLabel item;
  final BarangDagangLabelViewModel viewModel;

  const BarangDagangEditDialog({
    super.key,
    required this.item,
    required this.viewModel,
  });

  @override
  State<BarangDagangEditDialog> createState() => _BarangDagangEditDialogState();
}

class _BarangDagangEditDialogState extends State<BarangDagangEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _qtyCtrl;
  late final TextEditingController _keteranganCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: _formatQty(widget.item.qty));
    _keteranganCtrl = TextEditingController(text: widget.item.notes);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  String _formatQty(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  double? _parseQty(String raw) {
    final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final qty = _parseQty(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      await DialogService.instance.showError(
        title: 'Validasi',
        message: 'Qty harus lebih besar dari 0.',
      );
      return;
    }

    try {
      DialogService.instance.showLoading(
        message: 'Menyimpan ${widget.item.code}...',
      );
      await widget.viewModel.updateFromForm(
        code: widget.item.code,
        qty: qty,
        keterangan: _keteranganCtrl.text,
      );
      DialogService.instance.hideLoading();
      await DialogService.instance.showSuccess(
        title: 'Berhasil',
        message: 'Label Barang Dagang berhasil diupdate.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      DialogService.instance.hideLoading();
      await DialogService.instance.showError(
        title: 'Error',
        message: apiErrorMessage(e),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Header',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _readOnlyField(
                          label: 'Nomor Label',
                          icon: Icons.confirmation_number_outlined,
                          value: widget.item.code,
                        ),
                        const SizedBox(height: 12),
                        _readOnlyField(
                          label: 'Nama Barang',
                          icon: Icons.shopping_bag_outlined,
                          value: widget.item.name.trim().isEmpty
                              ? '-'
                              : widget.item.name.trim(),
                        ),
                        const SizedBox(height: 12),
                        _readOnlyField(
                          label: 'Supplier',
                          icon: Icons.local_shipping_outlined,
                          value: widget.item.supplier.trim().isEmpty
                              ? '-'
                              : widget.item.supplier.trim(),
                        ),
                        if (widget.item.receipt.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _readOnlyField(
                            label: 'Penerimaan',
                            icon: Icons.receipt_long_outlined,
                            value: widget.item.receipt.trim(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _qtyCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          style: const TextStyle(fontSize: 16),
                          validator: (value) {
                            final qty = _parseQty(value ?? '');
                            if (qty == null || qty <= 0) {
                              return 'Qty harus lebih besar dari 0';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Qty (pcs)',
                            labelStyle: const TextStyle(fontSize: 15),
                            prefixIcon: const Icon(
                              Icons.numbers_outlined,
                              size: 22,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _keteranganCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Keterangan',
                            labelStyle: const TextStyle(fontSize: 15),
                            prefixIcon: const Icon(
                              Icons.notes_outlined,
                              size: 22,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.edit, color: Colors.orange.shade700, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Edit Label Barang Dagang',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            side: BorderSide(color: Colors.grey.shade400),
          ),
          child: const Text('BATAL', style: TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF57C00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          child: const Text(
            'SIMPAN',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _readOnlyField({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 15),
        prefixIcon: Icon(icon, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
