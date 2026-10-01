// lib/features/penerimaan_barang_dagang/widgets/penerimaan_barang_dagang_item_form_dialog.dart
//
// Dialog tambah 1 barang ("label") barang dagang — langsung menyimpan ke
// server lewat addItems(). Nama barang diambil dari master MstBarangDagang
// (dropdown, tidak di-scope per warehouse). Keterangan diisi manual.
//
// Aturan Qty — sumber kebenaran MstBarangDagang.PcsPerLabel ("isipcs master"):
//  • Field di-prefill dengan isipcs master saat nama barang dipilih.
//  • Qty BEBAS diisi kapan saja selama belum ada label tersimpan yang
//    menyimpang dari master.
//  • Begitu ada satu label dengan qty ≠ master, input berikutnya untuk nama
//    barang yang sama terkunci (readOnly) dan WAJIB memakai isipcs master.
//  • Selama qty masih deviasi, mode Multiple/Quick dinonaktifkan — kalau tidak
//    satu angka deviasi akan terduplikasi ke puluhan label sekaligus.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/auto_repeat_print_dialog.dart';
import '../../../common/widgets/print_mode_selector.dart';
import '../../../common/widgets/success_status_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../label/packing/widgets/bt_auto_print_dialog.dart';
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

  // Qty label yang sudah tersimpan per IdBarangDagang. Dipakai untuk
  // mendeteksi apakah SUDAH ADA label yang menyimpang dari isipcs master —
  // kalau ada, input berikutnya untuk nama barang itu dikunci ke master.
  Map<int, List<double>> _savedQtyByMaterial = const {};
  bool _isLoadingSavedQty = false;
  bool _qtyTouchedByUser = false;

  // ── Mode cetak ──
  PrintMode _printMode = PrintMode.single;
  late final TextEditingController _repeatCountCtrl;

  @override
  void initState() {
    super.initState();
    _repeatCountCtrl = TextEditingController(text: '1');
    _repo = PenerimaanBarangDagangRepository(api: context.read<ApiClient>());
    _loadMaterials();
    _loadSavedQty();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _keteranganCtrl.dispose();
    _repeatCountCtrl.dispose();
    super.dispose();
  }

  int get _repeatCount =>
      (int.tryParse(_repeatCountCtrl.text.trim()) ?? 1).clamp(1, 99);

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

  /// Isipcs master (MstBarangDagang.PcsPerLabel) — sumber kebenaran qty.
  /// Null = master tidak punya isipcs, jadi tidak ada yang bisa dikunci.
  double? get _masterQty {
    final pcs = _selectedMaterial?.pcsPerLabel;
    if (pcs == null || pcs <= 0) return null;
    return pcs.toDouble();
  }

  /// Qty label tersimpan untuk nama barang terpilih yang menyimpang dari
  /// isipcs master. Kosong = belum pernah menyimpang.
  List<double> get _deviatingSavedQty {
    final id = _selectedMaterial?.idBarangDagang;
    final master = _masterQty;
    if (id == null || master == null) return const [];
    return (_savedQtyByMaterial[id] ?? const <double>[])
        .where((q) => (q - master).abs() > 0.000001)
        .toList(growable: false);
  }

  /// Field bebas diisi KAPAN SAJA — terkunci hanya setelah ada label tersimpan
  /// yang qty-nya berbeda dari isipcs master. Tanpa isipcs master tidak ada
  /// acuan, jadi tidak pernah terkunci.
  bool get _isQtyLocked => _deviatingSavedQty.isNotEmpty;

  double? get _qtyValue =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));

  /// Qty yang benar-benar dikirim: kalau terkunci, paksa isipcs master dan
  /// abaikan isi controller.
  double? get _effectiveQty => _isQtyLocked ? _masterQty : _qtyValue;

  bool get _qtyDeviatesFromMaster {
    final master = _masterQty;
    final value = _qtyValue;
    if (master == null || value == null) return false;
    return (master - value).abs() > 0.000001;
  }

  PrintMode get _effectivePrintMode =>
      _qtyDeviatesFromMaster ? PrintMode.single : _printMode;

  /// Mode yang mati saat qty deviasi dari isipcs master. Kalau tidak, satu
  /// angka deviasi akan langsung diduplikasi jadi puluhan label — padahal
  /// hanya boleh ada satu label menyimpang per nama barang.
  Set<PrintMode> get _blockedPrintModes => _qtyDeviatesFromMaster
      ? const {PrintMode.multiple, PrintMode.quick}
      : const {};

  String? get _printModeBlockedReason {
    if (!_qtyDeviatesFromMaster) return null;
    final master = _masterQty!;
    final value = _qtyValue!;
    return 'Qty $value PCS berbeda dari isipcs master '
        '(${_fmtQtyInput(master)} PCS). Multiple dan Quick hanya bisa dipakai '
        'kalau qty sama dengan master, supaya hanya satu label yang boleh '
        'berbeda dari master.';
  }

  Widget _buildPrintModeNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode Multiple & Quick dinonaktifkan selama qty berbeda dari '
              'isipcs master, supaya hanya satu label yang menyimpang. '
              'Kembalikan qty ke ${_fmtQtyInput(_masterQty!)} PCS untuk '
              'mengaktifkan lagi.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtQtyInput(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return v.toString();
  }

  /// Isi field qty dari isipcs master. Nilai yang ditampilkan tetap master —
  /// bukan hasil pengisian label sebelumnya.
  void _applyQtyForMaterial(BarangDagangMasterItem? material) {
    if (material == null) {
      _qtyCtrl.clear();
      return;
    }
    final pcs = material.pcsPerLabel;
    _qtyCtrl.text = (pcs != null && pcs > 0) ? _fmtQtyInput(pcs.toDouble()) : '';
  }

  /// Kumpulkan qty label tersimpan per nama barang. Dipakai untuk
  /// mendeteksi apakah sudah ada label yang menyimpang dari isipcs master —
  /// kalau sudah ada, input berikutnya untuk barang itu wajib master.
  /// Gagal load tidak memblokir form, qty tetap bisa diisi bebas.
  Future<void> _loadSavedQty() async {
    setState(() => _isLoadingSavedQty = true);
    try {
      final detail = await _repo.fetchDetail(widget.noPenerimaan);
      if (!mounted) return;
      final map = <int, List<double>>{};
      for (final item in detail.items) {
        if (item.idBarangDagang <= 0 || item.qty <= 0) continue;
        (map[item.idBarangDagang] ??= []).add(item.qty);
      }
      setState(() {
        _savedQtyByMaterial = map;
        _isLoadingSavedQty = false;
        final material = _selectedMaterial;
        if (material == null) return;
        // Kalau sudah terkunci, master yang menang. Kalau belum, jangan
        // menimpa angka yang sudah diketik user.
        if (_isQtyLocked || !_qtyTouchedByUser) {
          _applyQtyForMaterial(material);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSavedQty = false);
    }
  }

  void _onMaterialSelected(BarangDagangMasterItem? material) {
    setState(() {
      _selectedMaterial = material;
      _saveError = null;
      _qtyTouchedByUser = false;
      _applyQtyForMaterial(material);
    });
  }

  /// Buat satu label dan kembalikan kode labelnya (mis. "BD.0000000001").
  ///
  /// Memakai data form yang sedang terisi supaya tombol "BUAT LABEL BARU
  /// (DATA SAMA)" di dialog Multiple dan loop Quick mengulang label identik.
  Future<String> _createLabel() async {
    final qty = _effectiveQty;
    if (qty == null || qty <= 0) {
      throw Exception('Qty wajib diisi dan harus > 0.');
    }
    final codes = await _repo.addItems(
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
    if (codes.isEmpty) {
      throw Exception(
        'Label berhasil dibuat tapi kode label tidak dikembalikan server.',
      );
    }
    return codes.first;
  }

  Future<void> _showAutoPrintDialog(List<String> codes) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BtAutoPrintDialog(
        headers: List<dynamic>.from(codes),
        count: codes.length,
        baseUrl: ApiConstants.baseUrl,
        pdfUrlBuilder: (code) =>
            Uri.parse(ApiConstants.barangDagangLabelPdf(code)),
        labelExtractor: (h) => h.toString(),
        onGenerateSame: () async {
          final next = await _createLabel();
          return <dynamic>[next];
        },
        markAsPrinted: (code) async {
          try {
            await _repo.markItemPrinted(code);
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _showAutoRepeatDialog(String firstCode) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AutoRepeatPrintDialog(
        totalRounds: _repeatCount,
        firstNoLabel: firstCode,
        pdfUrlBuilder: (code) =>
            Uri.parse(ApiConstants.barangDagangLabelPdf(code)),
        onCreate: _createLabel,
        markAsPrinted: (code) async {
          try {
            await _repo.markItemPrinted(code);
          } catch (_) {}
        },
      ),
    );
  }

  Widget _buildLabelCodeBox(List<String> codes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final code in codes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $code',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .2,
                ),
              ),
            ),
        ],
      ),
    );
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
    final qty = _effectiveQty;
    if (qty == null || qty <= 0) {
      setState(() => _saveError = 'Qty wajib diisi dan harus > 0.');
      return;
    }
    final materialId = _selectedMaterial!.idBarangDagang;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final codes = await _repo.addItems(
        noPenerimaan: widget.noPenerimaan,
        items: [
          PenerimaanBarangDagangItemInput(
            idSupplier: _selectedSupplierId!,
            idBarangDagang: materialId,
            qty: qty,
            keterangan: _keteranganCtrl.text,
          ),
        ],
      );

      if (!mounted) return;
      // Simpan qty ini sebagai "riwayat" supaya input berikutnya tahu kalau
      // sudah ada label yang menyimpang dari master → input setelahnya wajib
      // master. Kalau qtynya sendiri sudah sama dengan master, field tetap
      // bebas.
      setState(() {
        _isSaving = false;
        _savedQtyByMaterial = {
          ..._savedQtyByMaterial,
          materialId: [
            ...?_savedQtyByMaterial[materialId],
            qty,
          ],
        };
        _qtyCtrl.text = _fmtQtyInput(_effectiveQty ?? qty);
        _qtyTouchedByUser = false;
      });

      if (codes.isEmpty) {
        // Server tidak mengembalikan kode — label tetap tersimpan, tapi kita
        // tidak bisa menampilkan nomornya maupun membuka mode Multiple/Quick.
        await showDialog<void>(
          context: context,
          builder: (_) => const SuccessStatusDialog(
            title: 'Berhasil Menyimpan',
            message: 'Barang berhasil ditambahkan.',
          ),
        );
      } else if (_effectivePrintMode == PrintMode.quick) {
        await _showAutoRepeatDialog(codes.first);
      } else if (_effectivePrintMode == PrintMode.multiple) {
        await _showAutoPrintDialog(codes);
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => SuccessStatusDialog(
            title: 'Berhasil Menyimpan',
            message: codes.length > 1
                ? 'Label berhasil dibuat (${codes.length} label).'
                : 'Label berhasil dibuat.',
            extraContent: _buildLabelCodeBox(codes),
          ),
        );
      }

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFields(),
                    const SizedBox(height: 16),
                    PrintModeSelector(
                      value: _effectivePrintMode,
                      repeatCountCtrl: _repeatCountCtrl,
                      onChanged: (mode) => setState(() => _printMode = mode),
                      disabledModes: _blockedPrintModes,
                      disabledReason: _printModeBlockedReason,
                    ),
                    if (_printModeBlockedReason != null) ...[
                      const SizedBox(height: 8),
                      _buildPrintModeNotice(),
                    ],
                  ],
                ),
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
        _buildQtyField(),
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

  Widget _buildQtyField() {
    final locked = _isQtyLocked;
    final master = _masterQty;
    final deviating = _deviatingSavedQty;

    final String? helperText;
    final Color fillColor;
    if (locked) {
      helperText =
          'Terkunci — sudah ada ${deviating.length} label '
          '(${_fmtQtyInput(deviating.first)} PCS) yang berbeda dari isipcs '
          'master, jadi input berikutnya wajib ${_fmtQtyInput(master!)} PCS.';
      fillColor = Colors.grey.shade100;
    } else if (_isLoadingSavedQty) {
      helperText = 'Memuat data label sebelumnya...';
      fillColor = Colors.grey.shade50;
    } else if (master != null) {
      helperText =
          'Isipcs master: ${_fmtQtyInput(master)} PCS. Bebas diisi selama '
          'semua label sama dengan master.';
      fillColor = _qtyDeviatesFromMaster
          ? Colors.amber.shade50
          : Colors.grey.shade50;
    } else {
      helperText = 'Master tidak punya isipcs — isi bebas kapan saja.';
      fillColor = Colors.grey.shade50;
    }

    return TextFormField(
      controller: _qtyCtrl,
      readOnly: locked,
      keyboardType: locked
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: locked
          ? const <TextInputFormatter>[]
          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {
        _saveError = null;
        _qtyTouchedByUser = true;
      }),
      decoration: InputDecoration(
        labelText: 'Qty (PCS)',
        helperText: helperText,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          fontSize: 10.5,
          height: 1.35,
          color: locked ? Colors.grey.shade600 : Colors.grey.shade500,
        ),
        prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
        suffixIcon: locked
            ? Tooltip(
                message: 'Qty terkunci ke isipcs master, tidak bisa diubah',
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
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
