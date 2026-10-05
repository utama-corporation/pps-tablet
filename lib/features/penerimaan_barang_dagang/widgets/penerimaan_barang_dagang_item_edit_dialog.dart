// lib/features/penerimaan_barang_dagang/widgets/penerimaan_barang_dagang_item_edit_dialog.dart
//
// Dialog ubah data 1 label barang dagang. HANYA boleh dibuka selama label
// belum dicetak DAN belum dipakai — dicek di server juga (BD_ALREADY_PRINTED /
// BD_ALREADY_USED), check di [PenerimaanBarangDagangItem.canEdit] cuma supaya
// menu tidak menampilkan aksi yang pasti ditolak.
//
// Field yang bisa diubah sengaja hanya Supplier + Qty. Nama barang &
// keterangan TIDAK bisa berubah: label fisik yang sudah keluar menunjuk
// barang tertentu, jadi kalau berubah data tidak akan cocok dengan label di
// lantai produksi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/success_status_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/number_formatter.dart';
import '../../supplier/widgets/supplier_dropdown.dart';
import '../model/barang_dagang_master_item.dart';
import '../repository/penerimaan_barang_dagang_repository.dart';

const _kBorder = Color(0xFFE2E6EA);
const _kAccent = Color(0xFF00897B);

class PenerimaanBarangDagangItemEditDialog extends StatefulWidget {
  final String noPenerimaan;
  final String noBarangDagang;
  final String namaBarang;
  final int idBarangDagang;
  final int idSupplier;
  final double qty;
  final Color accentColor;

  const PenerimaanBarangDagangItemEditDialog({
    super.key,
    required this.noPenerimaan,
    required this.noBarangDagang,
    required this.namaBarang,
    required this.idBarangDagang,
    required this.idSupplier,
    required this.qty,
    this.accentColor = _kAccent,
  });

  @override
  State<PenerimaanBarangDagangItemEditDialog> createState() =>
      _PenerimaanBarangDagangItemEditDialogState();
}

class _PenerimaanBarangDagangItemEditDialogState
    extends State<PenerimaanBarangDagangItemEditDialog> {
  late final PenerimaanBarangDagangRepository _repo;
  final _qtyCtrl = TextEditingController();
  int? _supplierId;
  String? _saveError;
  bool _isSaving = false;

  // Isipcs master (MstBarangDagang.PcsPerLabel) — sumber kebenaran qty label.
  double? _masterQty;

  // Qty label LAIN untuk nama barang yang sama di penerimaan ini. Dipakai
  // untuk menerapkan aturan yang sama seperti form tambah: hanya boleh ada
  // SATU label yang menyimpang dari isipcs master.
  List<double> _otherSavedQty = const [];
  bool _isLoadingPeers = false;

  // True hanya setelah user mengetik di field qty. Field ini menampilkan qty
  // tanpa angka desimal, jadi nilai 40,5 yang tersimpan akan tampil "40" —
  // tanpa penanda ini, Save tanpa menyentuh field akan menulis "40" dan
  // qty pembelian berubah diam-diam dari 40,5 jadi 40.
  bool _qtyTouched = false;

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBarangDagangRepository(api: context.read<ApiClient>());
    _supplierId = widget.idSupplier > 0 ? widget.idSupplier : null;
    _qtyCtrl.text = _fmtQtyInput(widget.qty);
    _loadMasterQty();
    _loadPeerQty();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterQty() async {
    try {
      final master = await _repo.fetchMasterBarangDagang();
      if (!mounted) return;
      final pcs = master
          .firstWhere(
            (m) => m.idBarangDagang == widget.idBarangDagang,
            orElse: () => const BarangDagangMasterItem(
              idBarangDagang: 0,
              namaBarangDagang: '',
            ),
          )
          .pcsPerLabel;
      if (pcs == null || pcs <= 0) return;
      setState(() => _masterQty = pcs.toDouble());
      _refreshQtyForLock();
    } catch (_) {
      // Master gagal dimuat = tidak ada acuan, field tetap bebas. Form tetap
      // bisa dipakai.
    }
  }

  /// Kumpulkan qty label lain untuk nama barang yang sama pada penerimaan ini.
  /// Label yang sedang diedit dikecualikan — obviously nilainya sendiri bukan
  /// "label lain".
  Future<void> _loadPeerQty() async {
    setState(() => _isLoadingPeers = true);
    try {
      final detail = await _repo.fetchDetail(widget.noPenerimaan);
      if (!mounted) return;
      setState(() {
        _otherSavedQty = detail.items
            .where(
              (i) =>
                  i.noBarangDagang != widget.noBarangDagang &&
                  i.idBarangDagang == widget.idBarangDagang &&
                  i.qty > 0,
            )
            .map((i) => i.qty)
            .toList(growable: false);
        _isLoadingPeers = false;
      });
      _refreshQtyForLock();
    } catch (_) {
      // Gagal load = tidak ada data pembanding, field tetap bebas. Server
      // tetap penjaga terakhirnya.
      if (!mounted) return;
      setState(() => _isLoadingPeers = false);
    }
  }

  static String _fmtQty(double v) => formatPcsQty(v);

  /// Field qty TIDAK boleh memakai pemisah ribuan — "1.000" akan ter-parse
  /// jadi 1.0 dan qty purchasing tersimpan 1, bukan 1000.
  static String _fmtQtyInput(double v) => formatPcsQtyInput(v);

  /// Label LAIN yang qty-nya berbeda dari isipcs master. Kosong = belum ada
  /// label lain yang menyimpang, jadi label ini masih bebas deviasi.
  List<double> get _deviatingPeers {
    final master = _masterQty;
    if (master == null) return const [];
    return _otherSavedQty
        .where((q) => (q - master).abs() > 0.000001)
        .toList(growable: false);
  }

  /// Sama seperti form tambah: terkunci hanya kalau label LAIN sudah
  /// menyimpang dari isipcs master. Kalau belum ada, label ini bebas deviasi
  /// (maksimum satu penyimpangan per nama barang).
  bool get _isQtyLocked => _deviatingPeers.isNotEmpty;

  /// Qty yang benar-benar dikirim: kalau terkunci, paksa isipcs master dan
  /// abaikan isi controller.
  double? get _effectiveQty => _isQtyLocked ? _masterQty : _qtyValue;

  /// Nilai yang dikirim ke server saat Simpan.
  ///
  /// Kalau field qty tidak pernah disentuh, kirim nilai ASLI dari server —
  /// bukan hasil parse teks field — karena teks field sengaja ditampilkan
  /// tanpa desimal (lihat [_qtyTouched]).
  double? get _saveQty {
    if (_isQtyLocked) return _masterQty;
    if (_qtyTouched) return _qtyValue;
    return widget.qty > 0 ? widget.qty : _qtyValue;
  }

  double? get _qtyValue =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));

  bool get _qtyDeviatesFromMaster {
    final master = _masterQty;
    final value = _effectiveQty;
    if (master == null || value == null) return false;
    return (master - value).abs() > 0.000001;
  }

  // Begitu master atau status kunci diketahui, paksa isi field ke isipcs
  /// master supaya angka yang tampil = angka yang akan dikirim.
  void _refreshQtyForLock() {
    if (!mounted) return;
    final master = _masterQty;
    if (master == null || !_isQtyLocked) return;
    final text = _fmtQtyInput(master);
    if (_qtyCtrl.text == text) return;
    _qtyCtrl.text = text;
  }

  Future<void> _save() async {
    if (_supplierId == null) {
      setState(() => _saveError = 'Supplier wajib dipilih.');
      return;
    }
    final qty = _saveQty;
    if (qty == null || qty <= 0) {
      setState(() => _saveError = 'Qty wajib diisi dan harus > 0.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await _repo.updateItem(
        noBarangDagang: widget.noBarangDagang,
        idSupplier: _supplierId!,
        qty: qty,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showDialog<void>(
        context: context,
        builder: (_) => const SuccessStatusDialog(
          title: 'Berhasil Menyimpan',
          message: 'Data label berhasil diubah.',
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        // friendlyMessage mengambil pesan `message` dari body JSON server,
        // jadi pesan 409 (label sudah dicetak/dipakai) terbaca utuh — bukan
        // string teknis "ApiException(409): PUT ... failed {...}".
        _saveError = e is ApiException ? e.friendlyMessage : e.toString();
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
                    _buildLockedBarangRow(),
                    const SizedBox(height: 14),
                    SupplierDropdown(
                      preselectId: _supplierId,
                      onChanged: (s) => setState(() {
                        _supplierId = s?.idSupplier;
                        _saveError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _buildQtyField(),
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
              Icons.edit_outlined,
              color: widget.accentColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Ubah Data Barang',
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

  /// Nama barang sengaja read-only — lihat catatan di header file.
  Widget _buildLockedBarangRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, size: 20, color: Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.namaBarang,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.noBarangDagang,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Nama barang tidak bisa diubah',
            child: Icon(
              Icons.lock_outline,
              size: 15,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyField() {
    final master = _masterQty;
    final locked = _isQtyLocked;
    final deviating = _deviatingPeers;

    final String? helperText;
    final Color fillColor;
    if (locked) {
      helperText =
          'Terkunci — sudah ada ${deviating.length} label '
          '(${_fmtQty(deviating.first)} PCS) yang berbeda dari isipcs master, '
          'jadi label ini wajib ${_fmtQty(master!)} PCS.';
      fillColor = Colors.grey.shade100;
    } else if (_isLoadingPeers) {
      helperText = 'Memuat data label sebelumnya...';
      fillColor = Colors.grey.shade50;
    } else if (master != null) {
      helperText =
          'Isipcs master: ${_fmtQty(master)} PCS. Bebas diisi selama semua '
          'label sama dengan master.';
      fillColor = _qtyDeviatesFromMaster ? Colors.amber.shade50 : Colors.grey.shade50;
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
        _qtyTouched = true;
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