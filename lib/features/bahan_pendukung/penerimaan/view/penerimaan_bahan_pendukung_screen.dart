// lib/features/bahan_pendukung/penerimaan/view/penerimaan_bahan_pendukung_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../production/inject/model/inject_production_model.dart';
import '../../../production/shared/widgets/mesin_section_header.dart';
import '../../../production/shared/widgets/production_mesin_card.dart';
import '../../../production/shared/widgets/production_overlay_drawer.dart';
import '../../../production/shared/widgets/production_produksi_list.dart';
import '../../../production/shared/widgets/production_riwayat_header.dart';
import '../model/penerimaan_bahan_pendukung_model.dart';
import '../model/tim_penerimaan_model.dart';
import '../repository/penerimaan_bahan_pendukung_repository.dart';
import '../widgets/penerimaan_bahan_pendukung_header_form_dialog.dart';
import 'penerimaan_bahan_pendukung_label_list_screen.dart';

/// Layar utama modul Penerimaan Bahan Pendukung — 1:1 mengikuti pola
/// Penerimaan Bahan Baku: grid status tim (dari tabel GLOBAL
/// `dbo.MstTimPenerimaan`, bukan tabel khusus per modul) + panel Riwayat
/// yang bisa di-slide dari kanan. Tim dianggap "aktif" kalau sudah punya
/// `NoPenerimaan` untuk HARI INI. Tap tim nonaktif → dialog header ringkas
/// (Tanggal, Shift, Jam) membuat NoPenerimaan (fase 1) → LANGSUNG masuk ke
/// `PenerimaanBahanPendukungLabelListScreen` yang sama dengan tim
/// AKTIF/baris riwayat. Menambah barang (fase 2) dilakukan di layar itu
/// lewat FAB yang membuka `PenerimaanBahanPendukungAddLabelDialog` — tidak
/// ada lagi screen input penuh terpisah. Tidak ada split kategori
/// (Pakai/Proses) — satu kategori saja, jadi tidak ada tab Stok Item
/// terpisah seperti bahan baku.
class PenerimaanBahanPendukungScreen extends StatefulWidget {
  const PenerimaanBahanPendukungScreen({super.key});

  @override
  State<PenerimaanBahanPendukungScreen> createState() =>
      _PenerimaanBahanPendukungScreenState();
}

class _PenerimaanBahanPendukungScreenState
    extends State<PenerimaanBahanPendukungScreen> {
  late final PenerimaanBahanPendukungRepository _repo;

  Future<List<TimPenerimaanInfo>> _timFuture = Future.value(
    <TimPenerimaanInfo>[],
  );

  final List<PenerimaanBahanPendukung> _items = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const _pageSize = 30;
  final _scrollCtl = ScrollController();
  int? _filterIdTim;
  bool _isSidebarExpanded = false;

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBahanPendukungRepository(api: context.read<ApiClient>());
    _loadTim();
    _loadPage();
    _scrollCtl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────

  Future<void> _loadTim() async {
    final future = _repo.fetchTimStatus();
    if (mounted) setState(() => _timFuture = future);
  }

  void _onScroll() {
    if (_scrollCtl.position.pixels >=
            _scrollCtl.position.maxScrollExtent - 100 &&
        !_isFetchingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadPage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final res = await _repo.fetchAll(page: 1, pageSize: _pageSize);
      if (!mounted) return;
      var newItems = res['items'] as List<PenerimaanBahanPendukung>;
      if (_filterIdTim != null) {
        newItems = newItems.where((e) => e.idTim == _filterIdTim).toList();
      }
      final totalPages = (res['totalPages'] as int?) ?? 1;
      setState(() {
        _items.addAll(newItems);
        _hasMore = 1 < totalPages;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    try {
      final nextPage = _page + 1;
      final res = await _repo.fetchAll(page: nextPage, pageSize: _pageSize);
      if (!mounted) return;
      var newItems = res['items'] as List<PenerimaanBahanPendukung>;
      if (_filterIdTim != null) {
        newItems = newItems.where((e) => e.idTim == _filterIdTim).toList();
      }
      final totalPages = (res['totalPages'] as int?) ?? 1;
      setState(() {
        _items.addAll(newItems);
        _page = nextPage;
        _hasMore = nextPage < totalPages;
        _isFetchingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _refreshAll() {
    _loadTim();
    _loadPage();
  }

  // ── Card / row data converters ───────────────────────────────────────

  /// Aktif (hijau) = punya NoPenerimaan belum selesai bertanggal HARI INI.
  /// Pending (kuning) = punya NoPenerimaan belum selesai tapi tanggalnya
  /// sudah lewat. Tidak Aktif (merah) = tidak ada NoPenerimaan berjalan.
  static MachineStatus _statusOf(TimPenerimaanInfo tim) {
    final tgl = tim.tglPenerimaan;
    if (tgl == null) return MachineStatus.inactive;
    final today = DateTime.now();
    final startDay = DateTime(tgl.year, tgl.month, tgl.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final daysSince = todayDay.difference(startDay).inDays;
    return daysSince <= 0 ? MachineStatus.active : MachineStatus.pending;
  }

  static MesinCardData _toCardData(TimPenerimaanInfo tim) {
    String? shiftTimeText;
    final tgl = tim.tglPenerimaan;
    final status = _statusOf(tim);
    if (tgl != null) {
      final today = DateTime.now();
      final startDay = DateTime(tgl.year, tgl.month, tgl.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      final daysSince = todayDay.difference(startDay).inDays;
      final tglText = DateFormat('dd MMM yyyy', 'id_ID').format(tgl);
      final daysText = daysSince <= 0 ? 'Hari ini' : 'sudah $daysSince hari';
      shiftTimeText = '$tglText • $daysText';
    }
    return MesinCardData(
      namaMesin: tim.namaTim,
      isActive: tim.isActive,
      machineStatus: status,
      shiftTimeText: shiftTimeText,
      namaOperators: tim.createBy,
      outputJenisNama: tgl != null ? '${tim.jumlahItem} label' : null,
    );
  }

  /// Warna garis status di riwayat: biru (current) = masih berlangsung
  /// (belum selesai, tanggalnya hari ini), kuning (pending) = belum selesai
  /// tapi tanggalnya sudah lewat, hijau (complete) = sudah selesai.
  static String _rowStatusOf(PenerimaanBahanPendukung row) {
    if (row.isComplete) return 'complete';
    final tgl = row.tglPenerimaan;
    if (tgl == null) return 'current';
    final today = DateTime.now();
    final startDay = DateTime(tgl.year, tgl.month, tgl.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    final daysSince = todayDay.difference(startDay).inDays;
    return daysSince <= 0 ? 'current' : 'pending';
  }

  static ProduksiRowData _toRowData(PenerimaanBahanPendukung row) {
    return ProduksiRowData(
      tglProduksi: row.tglPenerimaan,
      hourStart: null,
      hourEnd: null,
      shift: 0,
      isLocked: false,
      namaMesin: row.namaTim,
      noProduksi: row.noPenerimaan,
      produksiStatus: _rowStatusOf(row),
    );
  }

  // ── Navigation helpers ───────────────────────────────────────────────

  Future<void> _onTimTap(TimPenerimaanInfo tim) async {
    if (!mounted) return;

    if (!tim.isActive) {
      if (!tim.aktif) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tim ${tim.namaTim} sedang tidak aktif')),
        );
        return;
      }
      final headerResult =
          await showDialog<PenerimaanBahanPendukungHeaderResult>(
            context: context,
            barrierDismissible: false,
            builder: (_) => PenerimaanBahanPendukungCreateDialog(tim: tim),
          );
      if (!mounted) return;
      if (headerResult == null) return;

      // Header sudah dibuat di database begitu dialog di atas sukses
      // (fase 1) — refresh grid tim supaya kartu ini langsung berubah
      // status "aktif" walau user belum sempat menambah barang apapun.
      _refreshAll();

      await _openLabelList(headerResult.noPenerimaan);
      return;
    }

    await _openLabelList(tim.noPenerimaan!);
  }

  Future<void> _openLabelList(String noPenerimaan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PenerimaanBahanPendukungLabelListScreen(noPenerimaan: noPenerimaan),
      ),
    );
    if (!mounted) return;
    _refreshAll();
  }

  Future<void> _onRowTap(PenerimaanBahanPendukung row) async {
    await _openLabelList(row.noPenerimaan);
  }

  Future<void> _onRowDelete(PenerimaanBahanPendukung row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Penerimaan?',
        message: 'Yakin ingin menghapus penerimaan ${row.noPenerimaan}?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repo.delete(row.noPenerimaan);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => SuccessStatusDialog(
          title: 'Berhasil Menghapus',
          message: 'Penerimaan ${row.noPenerimaan} berhasil dihapus.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menghapus!', message: e.toString()),
      );
    }
    _refreshAll();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            // ── Grid tim (selalu full width) ──────────────────────────
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<List<TimPenerimaanInfo>>(
                    future: _timFuture,
                    builder: (context, snapshot) {
                      final allTim = snapshot.data ?? [];
                      final activeCount = allTim
                          .where((m) => _statusOf(m) == MachineStatus.active)
                          .length;
                      final pendingCount = allTim
                          .where((m) => _statusOf(m) == MachineStatus.pending)
                          .length;
                      final inactiveCount =
                          allTim.length - activeCount - pendingCount;
                      return MesinSectionHeader(
                        title: 'Penerimaan Bahan Pendukung',
                        activeCount: activeCount,
                        pendingCount: pendingCount,
                        alwaysShowPending: true,
                        inactiveCount: inactiveCount,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                  Expanded(
                    child: FutureBuilder<List<TimPenerimaanInfo>>(
                      future: _timFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Gagal memuat tim\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        }
                        final allTim = snapshot.data ?? [];
                        if (allTim.isEmpty) {
                          return Center(
                            child: Text(
                              'Belum ada tim penerimaan',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          );
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = (constraints.maxWidth / 150)
                                .floor()
                                .clamp(2, 6);
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisExtent: 110,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: allTim.length,
                              itemBuilder: (context, index) {
                                final tim = allTim[index];
                                return ProductionMesinCard(
                                  data: _toCardData(tim),
                                  onTap: () => _onTimTap(tim),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Overlay drawer: Riwayat Penerimaan ─────────────────────
            Positioned.fill(
              child: ProductionOverlayDrawer(
                isOpen: _isSidebarExpanded,
                onClose: () => setState(() => _isSidebarExpanded = false),
                onOpen: () => setState(() => _isSidebarExpanded = true),
                width: c.maxWidth * 0.4,
                child: _buildRiwayatContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<TimPenerimaanInfo>>(
          future: _timFuture,
          builder: (context, snapshot) {
            return ProductionRiwayatHeader(
              mesinList: (snapshot.data ?? [])
                  .map(
                    (t) =>
                        MesinFilterItem(idMesin: t.idTim, namaMesin: t.namaTim),
                  )
                  .toList(),
              selectedIdMesin: _filterIdTim,
              onFilterChanged: (id) {
                setState(() => _filterIdTim = id);
                _loadPage();
              },
            );
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPage,
            child: ProductionProduksiList<PenerimaanBahanPendukung>(
              items: _items,
              dataOf: _toRowData,
              isLoading: _isLoading,
              isFetchingMore: _isFetchingMore,
              scrollController: _scrollCtl,
              showMesin: _filterIdTim == null,
              onTap: _onRowTap,
              onEdit: (row) async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Edit belum didukung untuk data penerimaan'),
                  ),
                );
              },
              onDelete: _onRowDelete,
            ),
          ),
        ),
      ],
    );
  }
}
