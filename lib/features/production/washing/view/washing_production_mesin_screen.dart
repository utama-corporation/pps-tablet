import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../features/mesin/model/mesin_model.dart';
import '../../../shift/repository/shift_repository.dart';
import '../../shared/models/bahan_baku_proses_label.dart';
import '../../shared/models/stok_bahan_baku_item.dart';
import '../../shared/repository/stok_bahan_baku_repository.dart';
import '../../shared/widgets/mesin_section_header.dart';
import '../../shared/widgets/production_mesin_card.dart';
import '../../shared/widgets/production_produksi_list.dart';
import '../../shared/widgets/production_overlay_drawer.dart';
import '../../shared/widgets/production_riwayat_header.dart';
import '../../shared/widgets/sidebar_tab_switcher.dart';
import '../../shared/widgets/stok_item_section.dart';
import '../model/washing_production_model.dart';
import '../repository/washing_production_repository.dart';
import '../view_model/washing_production_view_model.dart';
import '../widgets/washing_delete_dialog.dart';
import '../widgets/washing_production_form_dialog.dart';
import 'washing_production_input_screen.dart';

class WashingProductionMesinScreen extends StatefulWidget {
  const WashingProductionMesinScreen({super.key});

  @override
  State<WashingProductionMesinScreen> createState() =>
      _WashingProductionMesinScreenState();
}

class _WashingProductionMesinScreenState
    extends State<WashingProductionMesinScreen> {
  final _repo = WashingProductionRepository();
  final _stokRepo = StokBahanBakuRepository();
  final _stokSectionController = StokItemSectionController();

  Future<List<WashingMesinInfo>> _mesinFuture = Future.value(
    <WashingMesinInfo>[],
  );

  final List<WashingProduction> _produksiItems = [];
  bool _produksiLoading = false;
  bool _produksiFetchingMore = false;
  bool _produksiHasMore = true;
  int _produksiPage = 1;
  static const _pageSize = 30;
  final _produksiScrollCtl = ScrollController();
  int? _filterIdMesin;
  WashingMesinInfo? _selectedMesinInfo;
  bool _isSidebarExpanded = false;
  int _sidebarTab = 0; // 0 = Riwayat Produksi, 1 = Stok Item

  @override
  void initState() {
    super.initState();
    _loadMesin();
    _loadProduksiPage();
    _produksiScrollCtl.addListener(_onProduksiScroll);
  }

  @override
  void dispose() {
    _produksiScrollCtl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadMesin() async {
    final future = _repo.fetchWashingMesin().then((r) => r.mesinList);
    if (mounted) setState(() => _mesinFuture = future);
  }

  void _onProduksiScroll() {
    if (_produksiScrollCtl.position.pixels >=
            _produksiScrollCtl.position.maxScrollExtent - 100 &&
        !_produksiFetchingMore &&
        _produksiHasMore) {
      _loadMoreProduksi();
    }
  }

  Future<void> _loadProduksiPage() async {
    if (!mounted) return;
    setState(() {
      _produksiLoading = true;
      _produksiItems.clear();
      _produksiPage = 1;
      _produksiHasMore = true;
    });
    try {
      final res = await _repo.fetchAll(
        page: 1,
        pageSize: _pageSize,
        idMesin: _filterIdMesin,
      );
      if (!mounted) return;
      final newItems = res['items'] as List<WashingProduction>;
      final totalPages = (res['totalPages'] as int?) ?? 1;
      setState(() {
        _produksiItems.addAll(newItems);
        _produksiHasMore = 1 < totalPages;
        _produksiLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _produksiLoading = false);
    }
  }

  Future<void> _loadMoreProduksi() async {
    if (!mounted || _produksiFetchingMore || !_produksiHasMore) return;
    setState(() => _produksiFetchingMore = true);
    try {
      final nextPage = _produksiPage + 1;
      final res = await _repo.fetchAll(
        page: nextPage,
        pageSize: _pageSize,
        idMesin: _filterIdMesin,
      );
      if (!mounted) return;
      final newItems = res['items'] as List<WashingProduction>;
      final totalPages = (res['totalPages'] as int?) ?? 1;
      setState(() {
        _produksiItems.addAll(newItems);
        _produksiPage = nextPage;
        _produksiHasMore = nextPage < totalPages;
        _produksiFetchingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _produksiFetchingMore = false);
    }
  }

  void _refreshAll() {
    _loadMesin();
    _loadProduksiPage();
    _stokSectionController.refreshAll();
  }

  // ── Card / row data converters ────────────────────────────────────────────

  static MesinCardData _toMesinCardData(WashingMesinInfo mesin) {
    String? shiftTimeText;
    if (mesin.hasProduction) {
      final parts = <String>[];
      if (mesin.shift != null) parts.add('Shift ${mesin.shift}');
      parts.add('${mesin.hourStart ?? '--:--'} – ${mesin.hourEnd ?? '--:--'}');
      shiftTimeText = parts.join('  |  ');
    }
    return MesinCardData(
      namaMesin: mesin.namaMesin,
      isActive: mesin.isActive,
      machineStatus: mesin.machineStatus,
      shiftTimeText: shiftTimeText,
      namaRegu: mesin.namaRegu,
      outputJenisNama: mesin.outputJenisNama,
    );
  }

  static ProduksiRowData _toRowData(WashingProduction row) {
    return ProduksiRowData(
      tglProduksi: row.tglProduksi,
      hourStart: row.hourStart,
      hourEnd: row.hourEnd,
      shift: row.shift,
      isLocked: row.isLocked,
      namaMesin: row.namaMesin,
      namaRegu: row.namaRegu,
      outputJenisNama: row.outputJenisNama,
      noProduksi: row.noProduksi,
      produksiStatus: row.produksiStatus,
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  Future<void> _openCreateDialog({required WashingMesinInfo mesin}) async {
    if (!mounted) return;

    final mstMesin = MstMesin(
      idMesin: mesin.idMesin,
      namaMesin: mesin.namaMesin,
      bagian: mesin.bagian ?? '',
      enable: true,
    );

    final defaultShift = await ShiftRepository.fetchCurrentShift();
    if (!mounted) return;

    final created = await showDialog<WashingProduction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WashingProductionFormDialog(
        initialMesin: mstMesin,
        initialDate: DateTime.now(),
        initialShift: defaultShift?.shift,
        initialHourStart: defaultShift?.hourStart,
        initialHourEnd: defaultShift?.hourEnd,
        lockShiftFields: defaultShift != null,
        onSave: (p) => Navigator.of(context).pop(p),
      ),
    );

    if (!mounted) return;
    if (created != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              WashingProductionInputScreen(noProduksi: created.noProduksi),
        ),
      );
      if (!mounted) return;
    }
    _refreshAll();
  }

  Future<void> _openBackdateDialog(WashingMesinInfo mesin) async {
    if (!mounted) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final mstMesin = MstMesin(
      idMesin: mesin.idMesin,
      namaMesin: mesin.namaMesin,
      bagian: mesin.bagian ?? '',
      enable: true,
    );
    final created = await showDialog<WashingProduction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WashingProductionFormDialog(
        initialMesin: mstMesin,
        initialDate: yesterday,
        lockShiftFields: false,
        isDateEditable: true,
        onSave: (p) => Navigator.of(context).pop(p),
      ),
    );
    if (!mounted) return;
    if (created != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              WashingProductionInputScreen(noProduksi: created.noProduksi),
        ),
      );
      if (!mounted) return;
    }
    _refreshAll();
  }

  Future<void> _onMesinTap(WashingMesinInfo mesin) async {
    if (!mounted) return;

    if (!mesin.hasProduction) {
      await _openCreateDialog(mesin: mesin);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WashingProductionInputScreen(noProduksi: mesin.noProduksi!),
      ),
    );
    if (!mounted) return;
    _refreshAll();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (_, c) => Stack(
          children: [
            // ── Mesin grid (selalu full width) ──────────────────────
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<List<WashingMesinInfo>>(
                    future: _mesinFuture,
                    builder: (context, snapshot) {
                      final allMesin = snapshot.data ?? [];
                      final activeCount = allMesin
                          .where((m) => m.isActive)
                          .length;
                      final pendingCount = allMesin
                          .where((m) => m.isPending)
                          .length;
                      final inactiveCount = allMesin
                          .where((m) => !m.hasProduction)
                          .length;
                      return MesinSectionHeader(
                        title: 'Status Mesin Washing',
                        activeCount: activeCount,
                        pendingCount: pendingCount,
                        inactiveCount: inactiveCount,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                  Expanded(
                    child: FutureBuilder<List<WashingMesinInfo>>(
                      future: _mesinFuture,
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
                                'Gagal memuat mesin\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        }
                        final allMesin = snapshot.data ?? [];
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
                              itemCount: allMesin.length,
                              itemBuilder: (context, index) {
                                final mesin = allMesin[index];
                                return ProductionMesinCard(
                                  data: _toMesinCardData(mesin),
                                  onTap: () => _onMesinTap(mesin),
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

            // ── Overlay drawer: Riwayat Produksi / Stok Item ────────
            Positioned.fill(
              child: ProductionOverlayDrawer(
                isOpen: _isSidebarExpanded,
                onClose: () => setState(() => _isSidebarExpanded = false),
                onOpen: () => setState(() => _isSidebarExpanded = true),
                width: c.maxWidth * 0.4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SidebarTabSwitcher(
                      tabs: const [
                        SidebarTabItem(
                          label: 'Riwayat Produksi',
                          icon: Icons.history_rounded,
                        ),
                        SidebarTabItem(
                          label: 'Stok Item',
                          icon: Icons.inventory_2_rounded,
                        ),
                      ],
                      selectedIndex: _sidebarTab,
                      onSelected: (i) => setState(() => _sidebarTab = i),
                    ),
                    Expanded(
                      child: _sidebarTab == 0
                          ? _buildRiwayatContent()
                          : _buildStokItemContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stok Item: chip kategori (Bahan Baku Proses) ───────────────────────────

  Widget _buildStokItemContent() {
    return StokItemSection(
      controller: _stokSectionController,
      sources: [
        TypedStokItemSource<StokBahanBakuItem, BahanBakuProsesLabel>(
          label: 'Bahan Baku Proses',
          fetchStok: _stokRepo.fetchStok,
          fetchLabel: (item) => _stokRepo.fetchLabel(item.idBB),
          showSakColumn: false,
          oldestDateOf: (item) => item.dateCreateTertua,
        ),
      ],
    );
  }

  Widget _buildRiwayatContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<WashingMesinInfo>>(
          future: _mesinFuture,
          builder: (context, snapshot) {
            return ProductionRiwayatHeader(
              showTitle: false,
              mesinList: (snapshot.data ?? [])
                  .map(
                    (m) => MesinFilterItem(
                      idMesin: m.idMesin,
                      namaMesin: m.namaMesin,
                    ),
                  )
                  .toList(),
              selectedIdMesin: _filterIdMesin,
              onFilterChanged: (id) {
                final mesinData = snapshot.data ?? [];
                setState(() {
                  _filterIdMesin = id;
                  _selectedMesinInfo = id == null
                      ? null
                      : mesinData.where((m) => m.idMesin == id).firstOrNull;
                });
                _loadProduksiPage();
              },
            );
          },
        ),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _loadProduksiPage,
                child: ProductionProduksiList<WashingProduction>(
                  items: _produksiItems,
                  dataOf: _toRowData,
                  isLoading: _produksiLoading,
                  isFetchingMore: _produksiFetchingMore,
                  scrollController: _produksiScrollCtl,
                  showMesin: _filterIdMesin == null,
                  onTap: (row) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WashingProductionInputScreen(
                          noProduksi: row.noProduksi,
                        ),
                      ),
                    );
                    if (mounted) _refreshAll();
                  },
                  onEdit: (row) async {
                    final editVm = WashingProductionViewModel(
                      repository: _repo,
                    );
                    try {
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ChangeNotifierProvider.value(
                          value: editVm,
                          child: WashingProductionFormDialog(header: row),
                        ),
                      );
                    } finally {
                      editVm.dispose();
                    }
                    if (mounted) _refreshAll();
                  },
                  onDelete: (row) async {
                    final screenCtx = context;
                    await showDialog<void>(
                      context: screenCtx,
                      barrierDismissible: false,
                      builder: (ctx) => WashingProductionDeleteDialog(
                        header: row,
                        onConfirm: () async {
                          bool success = false;
                          String? errMsg;
                          try {
                            await _repo.deleteProduksi(row.noProduksi);
                            success = true;
                          } catch (e) {
                            errMsg = e.toString();
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (!screenCtx.mounted) return;
                          if (success) {
                            showDialog(
                              context: screenCtx,
                              builder: (_) => SuccessStatusDialog(
                                title: 'Berhasil Menghapus',
                                message:
                                    'No. Produksi ${row.noProduksi} berhasil dihapus.',
                              ),
                            );
                          } else {
                            showDialog(
                              context: screenCtx,
                              builder: (_) => ErrorStatusDialog(
                                title: 'Gagal Menghapus!',
                                message: errMsg ?? 'Gagal menghapus data',
                              ),
                            );
                          }
                          _refreshAll();
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_selectedMesinInfo != null)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'fab_backdate_washing',
                    onPressed: () => _openBackdateDialog(_selectedMesinInfo!),
                    backgroundColor: const Color(0xFF0277BD),
                    foregroundColor: Colors.white,
                    tooltip: 'Tambah Backdate',
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
