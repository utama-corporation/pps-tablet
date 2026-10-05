// lib/features/bahan_pendukung/penerimaan/view/penerimaan_bahan_pendukung_label_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../production/shared/models/label_usage_status.dart';
import '../../../production/shared/widgets/production_filter_chip.dart';
import '../../../production/shared/widgets/production_inline_stat.dart';
import '../../../production/shared/widgets/production_output_detail_dialog.dart';
import '../../../production/shared/widgets/production_usage_badge.dart';
import '../model/penerimaan_bahan_pendukung_model.dart';
import '../repository/penerimaan_bahan_pendukung_repository.dart';
import '../widgets/penerimaan_bahan_pendukung_item_edit_dialog.dart';
import '../widgets/penerimaan_bahan_pendukung_item_form_dialog.dart';

const _kAccent = Color(0xFF00897B);

/// Filter tampilan label berdasarkan status cetak. Sengaja client-side saja:
/// satu penerimaan biasanya kecil dan seluruh item sudah terambil di
/// fetchDetail(), jadi tidak perlu round-trip ke server.
enum _PrintFilter {
  all('Semua'),
  unprinted('Belum Dicetak'),
  printed('Sudah Dicetak');

  const _PrintFilter(this.label);

  final String label;

  bool matches(PenerimaanBahanPendukungItem item) => switch (this) {
    _PrintFilter.all => true,
    _PrintFilter.unprinted => item.hasBeenPrinted <= 0,
    _PrintFilter.printed => item.hasBeenPrinted > 0,
  };

  int count(List<PenerimaanBahanPendukungItem> items) =>
      items.where(matches).length;
}

class PenerimaanBahanPendukungLabelListScreen extends StatefulWidget {
  final String noPenerimaan;

  const PenerimaanBahanPendukungLabelListScreen({
    super.key,
    required this.noPenerimaan,
  });

  @override
  State<PenerimaanBahanPendukungLabelListScreen> createState() =>
      _PenerimaanBahanPendukungLabelListScreenState();
}

class _PenerimaanBahanPendukungLabelListScreenState
    extends State<PenerimaanBahanPendukungLabelListScreen> {
  late final PenerimaanBahanPendukungRepository _repo;
  late Future<PenerimaanBahanPendukungDetail> _future;

  bool _selectionMode = false;
  final Set<String> _selectedCodes = {};

  _PrintFilter _printFilter = _PrintFilter.all;

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBahanPendukungRepository(api: context.read<ApiClient>());
    _future = _repo.fetchDetail(widget.noPenerimaan);
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchDetail(widget.noPenerimaan);
    });
  }

  // ── Selection mode (bulk delete / bulk print) ───────────────────────────

  void _enterSelectionMode(String noBahanPendukung) {
    setState(() {
      _selectionMode = true;
      _selectedCodes
        ..clear()
        ..add(noBahanPendukung);
    });
  }

  void _toggleSelection(String noBahanPendukung) {
    setState(() {
      if (_selectedCodes.contains(noBahanPendukung)) {
        _selectedCodes.remove(noBahanPendukung);
        if (_selectedCodes.isEmpty) _selectionMode = false;
      } else {
        _selectedCodes.add(noBahanPendukung);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedCodes.clear();
    });
  }

  /// Ganti filter cetak. Selection mode ikut direset supaya bulk delete/print
  /// tidak ikut menyasar label yang sedang tersembunyi di balik filter.
  void _setPrintFilter(_PrintFilter filter) {
    if (_printFilter == filter) return;
    setState(() {
      _printFilter = filter;
      _selectionMode = false;
      _selectedCodes.clear();
    });
  }

  Widget _buildFilterBar(List<PenerimaanBahanPendukungItem> allItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          for (final filter in _PrintFilter.values) ...[
            if (filter != _PrintFilter.values.first) const SizedBox(width: 6),
            ProductionFilterChip(
              label: '${filter.label} (${filter.count(allItems)})',
              selected: _printFilter == filter,
              selectedColor: _kAccent,
              onTap: () => _setPrintFilter(filter),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(List<PenerimaanBahanPendukungItem> allItems) {
    if (allItems.isEmpty) {
      return Center(
        child: Text(
          'Belum ada barang',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Tidak ada label "${_printFilter.label}"',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Future<void> _bulkDelete() async {
    if (_selectedCodes.isEmpty) return;

    // Status pemakaian diambil ulang dari server: label bisa saja sudah
    // terpakai di perangkat lain sejak list ini terakhir dimuat.
    List<PenerimaanBahanPendukungItem> items;
    try {
      items = (await _repo.fetchDetail(widget.noPenerimaan)).items;
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Memuat', message: e.toString()),
      );
      return;
    }
    if (!mounted) return;

    final deletable = <String>[];
    var blocked = 0;
    for (final item in items) {
      if (!_selectedCodes.contains(item.noBahanPendukung)) continue;
      if (item.canDelete) {
        deletable.add(item.noBahanPendukung);
      } else {
        blocked++;
      }
    }

    if (deletable.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (_) => const ErrorStatusDialog(
          title: 'Tidak Bisa Dihapus',
          message:
              'Semua label yang dipilih sudah terpakai atau habis. Label yang sudah dipakai tidak bisa dihapus karena riwayatnya masih tercatat di proses produksi.',
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Hapus ${deletable.length} Barang?',
        message: blocked > 0
            ? '$blocked label sudah terpakai atau habis dan akan dilewati. Yakin ingin menghapus ${deletable.length} barang yang dipilih?'
            : 'Yakin ingin menghapus ${deletable.length} barang yang dipilih?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    var failed = 0;
    for (final code in deletable) {
      try {
        await _repo.deleteItem(code);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelectionMode();
    _reload();
    if (failed > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failed barang gagal dihapus')));
    }
  }

  Future<void> _bulkPrint() async {
    final codes = _selectedCodes.toList();
    if (codes.isEmpty) return;

    final pdfUrls = codes
        .map((c) => Uri.parse(ApiConstants.bahanPendukungLabelPdf(c)))
        .toList();

    await PdfPrintService(defaultSystem: 'pps').previewMultipleFromUrls(
      context: context,
      pdfUrls: pdfUrls,
      title: '${codes.length} Label',
      onPrintedCallbacks: codes
          .map<VoidCallback?>(
            (code) => () {
              () async {
                try {
                  await _repo.markItemPrinted(code);
                } catch (_) {}
              }().ignore();
            },
          )
          .toList(),
    );

    if (!mounted) return;
    _exitSelectionMode();
    _reload();
  }

  Future<void> _openAddLabelDialog() async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PenerimaanBahanPendukungItemFormDialog(
        noPenerimaan: widget.noPenerimaan,
      ),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _openEditDialog(PenerimaanBahanPendukungItem item) async {
    // Status label bisa berubah di perangkat lain di antara dialog detail dibuka
    // dan tombol ditekan. Biarkan server yang menolak (409) — dialog edit
    // sudah menampilkan pesan error-nya sendiri.
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PenerimaanBahanPendukungItemEditDialog(
        noPenerimaan: widget.noPenerimaan,
        noBahanPendukung: item.noBahanPendukung,
        namaBarang: item.namaBarang,
        idCabinetMaterial: item.idCabinetMaterial,
        idSupplier: item.idSupplier,
        qty: item.qty,
        accentColor: _kAccent,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _openDetailDialog(PenerimaanBahanPendukungItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProductionOutputDetailDialog(
        labelCode: item.noBahanPendukung,
        namaJenis: item.namaBarang,
        printCount: item.hasBeenPrinted,
        accentColor: _kAccent,
        pdfUrl: ApiConstants.bahanPendukungLabelPdf(item.noBahanPendukung),
        feature: 'bahan_pendukung',
        markAsPrinted: () async {
          final count = await _repo.markItemPrinted(item.noBahanPendukung);
          if (mounted) _reload();
          return count;
        },
        onEdit: item.canEdit ? () => _openEditDialog(item) : null,
        // Label terpakai/habis tidak bisa dihapus — tombol disembunyikan,
        // bukan hanya dinonaktifkan, supaya tidak ada jalan buntu di UI.
        onDelete: item.canDelete ? () => _deleteItem(item) : null,
        metrics: [
          ProductionMetric(
            label: 'Qty',
            icon: Icons.numbers_outlined,
            text: '${_fmtQty(item.qty)} PCS',
          ),
          // Sisa hanya relevan kalau label sudah dipotong oleh konsumsi
          // parsial — kalau masih utuh, angka ini cuma mengulang Qty.
          if (item.usageStatus == LabelUsageStatus.terpakai)
            ProductionMetric(
              label: 'Sisa',
              icon: Icons.inventory_2_outlined,
              text: '${_fmtQty(item.qtySisa)} PCS',
            ),
          ProductionMetric(
            label: 'Status',
            icon: Icons.verified_outlined,
            text: item.usageStatus.label,
          ),
          if (item.namaSupplier.isNotEmpty)
            ProductionMetric(
              label: 'Supplier',
              icon: Icons.local_shipping_outlined,
              text: item.namaSupplier,
            ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(PenerimaanBahanPendukungItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Barang?',
        message:
            'Yakin ingin menghapus ${item.namaBarang} (${item.noBahanPendukung})?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repo.deleteItem(item.noBahanPendukung);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menghapus', message: e.toString()),
      );
    }
  }

  Future<void> _markComplete(PenerimaanBahanPendukungDetail detail) async {
    final belumDiprint = detail.items
        .where((i) => i.hasBeenPrinted <= 0)
        .length;
    if (belumDiprint > 0) {
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Label Belum Dicetak',
          message:
              'Masih ada $belumDiprint label yang belum diprint. Harap print $belumDiprint label lagi untuk menyelesaikan penerimaan ini.',
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Tandai Selesai?',
        message:
            'Yakin ingin menandai penerimaan ${widget.noPenerimaan} sebagai selesai? Setelah selesai, tim tidak bisa menambah barang lagi.',
        confirmLabel: 'Selesai',
        confirmIcon: Icons.check_circle_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repo.markComplete(widget.noPenerimaan);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => const SuccessStatusDialog(
          title: 'Berhasil',
          message: 'Penerimaan berhasil ditandai selesai.',
        ),
      );
      if (mounted) {
        _reload();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal', message: e.toString()),
      );
    }
  }

  Widget _buildHeader(PenerimaanBahanPendukungDetail detail) {
    final header = detail.header;
    final belumDiprint = detail.items
        .where((i) => i.hasBeenPrinted <= 0)
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${header.namaTim} • ${header.tglPenerimaanTextShort}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  header.noPenerimaan,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (belumDiprint > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$belumDiprint label belum diprint',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (header.isComplete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Selesai',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _markComplete(detail),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text(
                'Selesai',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _exitSelectionMode,
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
            tooltip: 'Batal',
          ),
          Text(
            '${_selectedCodes.length} dipilih',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _selectedCodes.isEmpty ? null : _bulkDelete,
            icon: const Icon(Icons.delete_outline),
            color: const Color(0xFFDC2626),
            disabledColor: Colors.grey.shade300,
            tooltip: 'Hapus yang dipilih',
          ),
          IconButton(
            onPressed: _selectedCodes.isEmpty ? null : _bulkPrint,
            icon: const Icon(Icons.print_outlined),
            color: _kAccent,
            disabledColor: Colors.grey.shade300,
            tooltip: 'Print yang dipilih',
          ),
        ],
      ),
    );
  }

  String _fmtQty(double v) => formatPcsQty(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: _selectionMode
          ? null
          : FutureBuilder<PenerimaanBahanPendukungDetail>(
              future: _future,
              builder: (context, snapshot) {
                final isComplete = snapshot.data?.header.isComplete ?? false;
                if (isComplete) return const SizedBox.shrink();
                return FloatingActionButton(
                  onPressed: _openAddLabelDialog,
                  backgroundColor: _kAccent,
                  child: const Icon(Icons.add, color: Colors.white),
                );
              },
            ),
      body: FutureBuilder<PenerimaanBahanPendukungDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Gagal memuat barang\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final allItems = detail.items;
          final items = allItems.where(_printFilter.matches).toList();

          return Column(
            children: [
              _selectionMode ? _buildSelectionBar() : _buildHeader(detail),
              if (!_selectionMode) _buildFilterBar(allItems),
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyState(allItems)
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (_, c) => GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: c.maxWidth < 380
                                      ? 2
                                      : (c.maxWidth < 640 ? 3 : 4),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  // 104 pas untuk isi tanpa badge status
                                  // pemakaian. Badge menambah ~19px, jadi
                                  // dinaikkan supaya Column di dalam tile
                                  // tidak overflow.
                                  mainAxisExtent: 120,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, i) =>
                                _buildItemTile(items[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemTile(PenerimaanBahanPendukungItem item) {
    final isSelected = _selectedCodes.contains(item.noBahanPendukung);
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? _kAccent.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? _kAccent : Colors.grey.shade300,
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (_selectionMode) {
                _toggleSelection(item.noBahanPendukung);
              } else {
                _openDetailDialog(item);
              }
            },
            onLongPress: () {
              if (!_selectionMode) _enterSelectionMode(item.noBahanPendukung);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Title row: nama barang + print count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.namaBarang,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1D23),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.print_outlined,
                        size: 11,
                        color: item.hasBeenPrinted > 0
                            ? _kAccent
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'x${item.hasBeenPrinted}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: item.hasBeenPrinted > 0
                              ? _kAccent
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  // Nomor label subtitle
                  Text(
                    item.noBahanPendukung,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  // Qty — teks pendek, aman di Wrap.
                  ProductionMiniMetric(
                    icon: Icons.numbers_outlined,
                    text: '${_fmtQty(item.qty)} PCS',
                  ),
                  // Supplier — teks bebas dari server, bisa jauh lebih lebar
                  // dari tile. ProductionMiniMetric tidak bisa dipakai di sini
                  // karena Wrap memberi lebar tak terbatas ke child-nya, jadi
                  // teks panjang meluber keluar kartu. Baris sendiri +
                  // Expanded supaya memotong dengan ellipsis.
                  if (item.namaSupplier.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Tooltip(
                            message: item.namaSupplier,
                            child: Text(
                              item.namaSupplier,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Status pemakaian (terpakai sebagian / habis). Disembunyikan
                  // untuk label yang belum dipakai supaya tile tidak ramai.
                  if (item.usageStatus != LabelUsageStatus.belumDipakai) ...[
                    const SizedBox(height: 3),
                    ProductionUsageBadge(
                      status: item.usageStatus,
                      sisaQty: item.qtySisa,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_selectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: isSelected ? _kAccent : Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
}
