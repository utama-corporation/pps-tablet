// lib/features/production/penerimaan_bahan_baku/view/penerimaan_bahan_baku_label_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../shared/widgets/production_inline_stat.dart';
import '../model/penerimaan_bahan_baku_model.dart';
import '../model/penerimaan_kategori.dart';
import '../repository/penerimaan_bahan_baku_repository.dart';

typedef _LabelRow = ({
  String noBahanBaku,
  int noPallet,
  String namaJenisPlastik,
  List<PenerimaanBahanBakuOutput> saks,
});

/// Layar list label bahan baku untuk satu NoPenerimaan — dibuka saat tap
/// tim yang sudah aktif / baris riwayat, MENGGANTIKAN layar
/// `PenerimaanBahanBakuInputScreen` (generate label) di alur itu. Tiap label
/// dirender sebagai kartu grid (bisa 2-3 kartu per baris), format sama
/// seperti section Label Output/Input pada `WashingProductionInputScreen`
/// (lihat `WashingOutputTile`): judul JENIS PLASTIK, subjudul
/// "NoBahanBaku-NoPallet", lalu mini-metric sak & berat. Tap kartu untuk
/// membuka dialog detail sak + berat (grid kotak per sak, format sama
/// seperti `_SakCard` di "Tambah Label", tapi read-only).
/// Dipecah jadi DUA section berdampingan dipisah garis divider: "Bahan Baku
/// Pakai" di kiri, "Bahan Baku Proses" di kanan — kategori diturunkan dari
/// prefix NoBahanBaku lewat `PenerimaanKategori.fromNoBahanBaku`. Tidak ada
/// AppBar sendiri — chrome/breadcrumb global sudah disediakan AppShell.
class PenerimaanBahanBakuLabelListScreen extends StatefulWidget {
  final String noPenerimaan;

  const PenerimaanBahanBakuLabelListScreen({
    super.key,
    required this.noPenerimaan,
  });

  @override
  State<PenerimaanBahanBakuLabelListScreen> createState() =>
      _PenerimaanBahanBakuLabelListScreenState();
}

class _PenerimaanBahanBakuLabelListScreenState
    extends State<PenerimaanBahanBakuLabelListScreen> {
  late final PenerimaanBahanBakuRepository _repo;
  late Future<PenerimaanBahanBakuDetail> _future;

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBahanBakuRepository(api: context.read<ApiClient>());
    _future = _repo.fetchDetail(widget.noPenerimaan);
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchDetail(widget.noPenerimaan);
    });
  }

  Future<void> _markComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Tandai Selesai?',
        message:
            'Yakin ingin menandai penerimaan ${widget.noPenerimaan} sebagai selesai? Setelah selesai, tim tidak bisa menambah pallet lagi.',
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

  Widget _buildHeader(PenerimaanBahanBaku header) {
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

  String _fmtKg(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<PenerimaanBahanBakuDetail>(
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
                  'Gagal memuat label\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }

          final grouped = snapshot.data!.outputsByBatchAndPallet;
          final pakaiRows = <_LabelRow>[];
          final prosesRows = <_LabelRow>[];
          for (final noBahanBaku in grouped.keys.toList()..sort()) {
            final kategori = PenerimaanKategori.fromNoBahanBaku(noBahanBaku);
            final target = kategori == PenerimaanKategori.pakai
                ? pakaiRows
                : prosesRows;
            final palletNos = grouped[noBahanBaku]!.keys.toList()..sort();
            for (final noPallet in palletNos) {
              final saks = grouped[noBahanBaku]![noPallet]!.toList()
                ..sort((a, b) => a.noSak.compareTo(b.noSak));
              final namaJenisPlastik = saks
                      .map((s) => s.namaJenisPlastik)
                      .firstWhere((n) => (n ?? '').trim().isNotEmpty, orElse: () => null) ??
                  '-';
              target.add((
                noBahanBaku: noBahanBaku,
                noPallet: noPallet,
                namaJenisPlastik: namaJenisPlastik,
                saks: saks,
              ));
            }
          }

          return Column(
            children: [
              _buildHeader(snapshot.data!.header),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildSection(
                          title: 'Bahan Baku Pakai',
                          color: const Color(0xFF00695C),
                          rows: pakaiRows,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      Expanded(
                        child: _buildSection(
                          title: 'Bahan Baku Proses',
                          color: const Color(0xFF0D47A1),
                          rows: prosesRows,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color color,
    required List<_LabelRow> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.category_outlined, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada label', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: c.maxWidth < 220 ? 1 : (c.maxWidth < 380 ? 2 : 3),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 84,
                ),
                itemCount: rows.length,
                itemBuilder: (context, i) => _buildLabelTile(rows[i], color),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabelTile(_LabelRow row, Color color) {
    final totalBerat = row.saks.fold<double>(0, (sum, s) => sum + s.berat);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _LabelSakDetailDialog(row: row, color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                row.namaJenisPlastik,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1D23)),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                '${row.noBahanBaku}-${row.noPallet}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  ProductionMiniMetric(
                    icon: Icons.inventory_2_outlined,
                    text: '${row.saks.length} sak',
                  ),
                  ProductionMiniMetric(
                    icon: Icons.scale_outlined,
                    text: '${_fmtKg(totalBerat)} kg',
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

/// Dialog detail sak + berat 1 label (NoBahanBaku-NoPallet) — format kotak
/// grid per-sak sama seperti `_SakCard` di
/// `PenerimaanBahanBakuPalletFormDialog` ("Tambah Label"), tapi read-only
/// (tanpa tombol hapus) karena hanya untuk melihat, bukan mengedit.
class _LabelSakDetailDialog extends StatelessWidget {
  final _LabelRow row;
  final Color color;

  const _LabelSakDetailDialog({required this.row, required this.color});

  String _fmtKg(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  Widget build(BuildContext context) {
    final totalBerat = row.saks.fold<double>(0, (sum, s) => sum + s.berat);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.label_outline, color: color, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.namaJenisPlastik,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${row.noBahanBaku}-${row.noPallet}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E6EA)),
            Flexible(
              child: row.saks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Belum ada sak',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (_, c) => GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: c.maxWidth < 300 ? 3 : (c.maxWidth < 400 ? 4 : 5),
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: row.saks.length,
                        itemBuilder: (_, i) => _SakDetailCard(output: row.saks[i]),
                      ),
                    ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E6EA)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              child: Text(
                'Total: ${row.saks.length} sak  ·  ${_fmtKg(totalBerat)} kg',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SakDetailCard extends StatelessWidget {
  final PenerimaanBahanBakuOutput output;

  const _SakDetailCard({required this.output});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sak ${output.noSak}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF00695C),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${output.berat.toStringAsFixed(2)} kg',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
