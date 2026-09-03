// lib/features/bahan_pendukung/penerimaan/view/penerimaan_bahan_pendukung_label_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../production/shared/widgets/production_inline_stat.dart';
import '../../../production/shared/widgets/production_output_detail_dialog.dart';
import '../model/penerimaan_bahan_pendukung_model.dart';
import '../repository/penerimaan_bahan_pendukung_repository.dart';
import '../widgets/penerimaan_bahan_pendukung_item_form_dialog.dart';

const _kAccent = Color(0xFF00897B);

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

  Future<void> _bulkDelete() async {
    final codes = _selectedCodes.toList();
    if (codes.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Hapus ${codes.length} Barang?',
        message: 'Yakin ingin menghapus ${codes.length} barang yang dipilih?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    var failed = 0;
    for (final code in codes) {
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
        onDelete: () => _deleteItem(item),
        metrics: [
          ProductionMetric(
            label: 'Qty',
            icon: Icons.numbers_outlined,
            text: '${_fmtQty(item.qty)} PCS',
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

  Future<void> _markComplete() async {
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

  Widget _buildHeader(PenerimaanBahanPendukung header) {
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
              onPressed: _markComplete,
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

  String _fmtQty(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

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
          final items = detail.items;

          return Column(
            children: [
              _selectionMode
                  ? _buildSelectionBar()
                  : _buildHeader(detail.header),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Belum ada barang',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
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
                                  mainAxisExtent: 104,
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
                  // Metrics
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      ProductionMiniMetric(
                        icon: Icons.numbers_outlined,
                        text: '${_fmtQty(item.qty)} PCS',
                      ),
                      if (item.namaSupplier.isNotEmpty)
                        ProductionMiniMetric(
                          icon: Icons.local_shipping_outlined,
                          text: item.namaSupplier,
                        ),
                    ],
                  ),
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
