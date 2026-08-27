// lib/features/penerimaan_barang_dagang/widgets/penerimaan_barang_dagang_item_form_dialog.dart
//
// Dialog tambah 1 barang ("label") barang dagang — langsung menyimpan ke
// server lewat addItems(). Nama barang diambil dari master MstBarangDagang
// (dropdown, tidak di-scope per warehouse). Supplier + Qty + Keterangan
// diisi manual.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/success_status_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../supplier/widgets/supplier_dropdown.dart';
import '../model/barang_dagang_master_item.dart';
import '../repository/penerimaan_barang_dagang_repository.dart';

const _kBorder = Color(0xFFE2E6EA);
const _kAccent = Color(0xFF00897B);

class PenerimaanBarangDagangItemFormDialog extends StatefulWidget {
  final String noPenerimaan;
  final Color accentColor;

  const PenerimaanBarangDagangItemFormDialog({
    super.key,
    required this.noPenerimaan,
    this.accentColor = _kAccent,
  });

  @override
  State<PenerimaanBarangDagangItemFormDialog> createState() =>
      _PenerimaanBarangDagangItemFormDialogState();
}

class _PenerimaanBarangDagangItemFormDialogState
    extends State<PenerimaanBarangDagangItemFormDialog> {
  late final PenerimaanBarangDagangRepository _repo;
  int? _selectedSupplierId;
  BarangDagangMasterItem? _selectedMaterial;
  final _qtyCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  String? _saveError;
  bool _isSaving = false;

  bool _isLoadingMaterials = false;
  String? _loadMaterialsError;
  List<BarangDagangMasterItem> _materials = const [];

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBarangDagangRepository(api: context.read<ApiClient>());
    _loadMaterials();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoadingMaterials = true;
      _loadMaterialsError = null;
    });
    try {
      final items = await _repo.fetchMasterBarangDagang();
      if (!mounted) return;
      final sorted = [...items]
        ..sort((a, b) => a.namaBarangDagang.compareTo(b.namaBarangDagang));
      setState(() {
        _materials = sorted;
        _isLoadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadMaterialsError = e.toString();
        _isLoadingMaterials = false;
      });
    }
  }

  void _onMaterialSelected(BarangDagangMasterItem? material) {
    setState(() {
      _selectedMaterial = material;
      _saveError = null;
    });
  }

  Future<void> _save() async {
    if (_selectedSupplierId == null) {
      setState(() => _saveError = 'Supplier wajib dipilih.');
      return;
    }
    if (_selectedMaterial == null) {
      setState(() => _saveError = 'Nama barang wajib dipilih dari daftar.');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _saveError = 'Qty wajib diisi dan harus > 0.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await _repo.addItems(
        noPenerimaan: widget.noPenerimaan,
        items: [
          PenerimaanBarangDagangItemInput(
            idSupplier: _selectedSupplierId!,
            idBarangDagang: _selectedMaterial!.idBarangDagang,
            qty: qty,
            keterangan: _keteranganCtrl.text,
          ),
        ],
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => const SuccessStatusDialog(
          title: 'Berhasil Menyimpan',
          message: 'Barang berhasil ditambahkan.',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _kBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _buildFields(),
              ),
            ),
            if (_saveError != null) _buildErrorBanner(),
            const Divider(height: 1, color: _kBorder),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: widget.accentColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tambah Barang',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SupplierDropdown(
          onChanged: (s) => setState(() {
            _selectedSupplierId = s?.idSupplier;
            _saveError = null;
          }),
        ),
        const SizedBox(height: 12),
        _buildMaterialDropdown(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: (_) => setState(() => _saveError = null),
          decoration: InputDecoration(
            labelText: 'Qty (PCS)',
            prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _keteranganCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Keterangan',
            hintText: 'Opsional',
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialDropdown() {
    if (_isLoadingMaterials) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Nama Barang',
          prefixIcon: const Icon(Icons.category_outlined, size: 20),
          isDense: true,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        child: const SizedBox(
          height: 20,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_loadMaterialsError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gagal memuat data barang',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),
            IconButton(
              onPressed: _loadMaterials,
              icon: Icon(Icons.refresh, size: 16, color: Colors.red.shade600),
              tooltip: 'Coba lagi',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedMaterial?.idBarangDagang,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Nama Barang',
        hintText: 'Pilih barang',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      items: _materials.map((m) {
        final code = (m.itemCode ?? '').trim();
        return DropdownMenuItem<int>(
          value: m.idBarangDagang,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  m.namaBarangDagang,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) {
          _onMaterialSelected(null);
          return;
        }
        final picked = _materials.firstWhere(
          (x) => x.idBarangDagang == value,
          orElse: () => _materials.first,
        );
        _onMaterialSelected(picked);
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 15, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _saveError!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
            child: const Text('Batal', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 15),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
