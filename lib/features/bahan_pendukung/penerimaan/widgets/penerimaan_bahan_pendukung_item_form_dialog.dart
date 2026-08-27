// lib/features/bahan_pendukung/penerimaan/widgets/penerimaan_bahan_pendukung_item_form_dialog.dart
//
// Dialog tambah 1 barang ("label") bahan pendukung — langsung menyimpan
// ke server lewat addItems(). Nama barang diambil dari master cabinet
// material (dropdown). Supplier + Qty + Keterangan diisi manual.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../production/shared/models/cabinet_material_item.dart';
import '../../../supplier/widgets/supplier_dropdown.dart';
import '../repository/penerimaan_bahan_pendukung_repository.dart';

const _kBorder = Color(0xFFE2E6EA);
const _kAccent = Color(0xFF00897B);
const int _kDefaultWarehouse = 5;

class PenerimaanBahanPendukungItemFormDialog extends StatefulWidget {
  final String noPenerimaan;
  final Color accentColor;

  const PenerimaanBahanPendukungItemFormDialog({
    super.key,
    required this.noPenerimaan,
    this.accentColor = _kAccent,
  });

  @override
  State<PenerimaanBahanPendukungItemFormDialog> createState() =>
      _PenerimaanBahanPendukungItemFormDialogState();
}

class _PenerimaanBahanPendukungItemFormDialogState
    extends State<PenerimaanBahanPendukungItemFormDialog> {
  late final PenerimaanBahanPendukungRepository _repo;
  int? _selectedSupplierId;
  CabinetMaterialItem? _selectedMaterial;
  final _qtyCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  String? _saveError;
  bool _isSaving = false;

  bool _isLoadingMaterials = false;
  String? _loadMaterialsError;
  List<CabinetMaterialItem> _materials = const [];

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBahanPendukungRepository(api: context.read<ApiClient>());
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
      final items = await _repo.fetchMasterCabinetMaterials(
        idWarehouse: _kDefaultWarehouse,
      );
      if (!mounted) return;
      items.sort((a, b) => (a.Nama ?? '').compareTo(b.Nama ?? ''));
      setState(() {
        _materials = items;
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

  void _onMaterialSelected(CabinetMaterialItem? material) {
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
          PenerimaanBahanPendukungItemInput(
            idSupplier: _selectedSupplierId!,
            idCabinetMaterial: _selectedMaterial!.IdCabinetMaterial ?? 0,
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
            child: Icon(Icons.inventory_2_outlined, color: widget.accentColor, size: 17),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tambah Barang',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        child: const SizedBox(
          height: 20,
          child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
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
      value: _selectedMaterial?.IdCabinetMaterial,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Nama Barang',
        hintText: 'Pilih barang',
        prefixIcon: const Icon(Icons.category_outlined, size: 20),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: _materials.map((m) {
        final stock = m.SaldoAkhir ?? 0;
        final uom = m.NamaUOM ?? 'unit';
        final name = m.Nama ?? 'Material ${m.IdCabinetMaterial ?? 0}';
        return DropdownMenuItem<int>(
          value: m.IdCabinetMaterial,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: stock > 0 ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  '$stock $uom',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
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
          (x) => x.IdCabinetMaterial == value,
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
            child: Text(_saveError!, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
