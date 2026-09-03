import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../shared/models/furniture_wip_stok_item.dart';
import '../../shared/models/furniture_wip_stok_label.dart';
import '../../shared/repository/furniture_wip_stok_repository.dart';
import '../../shared/widgets/mesin_section_header.dart';
import '../../shared/widgets/production_mesin_card.dart';
import '../../shared/widgets/production_produksi_list.dart';
import '../../shared/widgets/production_overlay_drawer.dart';
import '../../shared/widgets/production_riwayat_header.dart';
import '../../shared/widgets/sidebar_tab_switcher.dart';
import '../../shared/widgets/stok_item_section.dart';
import '../../../mesin/model/mesin_model.dart';
import '../../../shift/repository/shift_repository.dart';
import '../model/packing_production_model.dart';
import '../repository/packing_production_repository.dart';
import '../view_model/packing_production_view_model.dart';
import '../widgets/packing_production_delete_dialog.dart';
import '../widgets/packing_production_form_dialog.dart';
import 'packing_production_input_screen.dart';

class PackingProductionMesinScreen extends StatefulWidget {
  const PackingProductionMesinScreen({super.key});

  @override
  State<PackingProductionMesinScreen> createState() =>
      _PackingProductionMesinScreenState();
}

class _PackingProductionMesinScreenState
    extends State<PackingProductionMesinScreen> {
  final _repo = PackingProductionRepository();
  final _furnitureWipStokRepo = FurnitureWipStokRepository();
  final _stokSectionController = StokItemSectionController();
  late final PackingProductionViewModel _editVmPool;

  Future<List<PackingMesinInfo>> _mesinFuture = Future.value(
    <PackingMesinInfo>[],
  );

  final List<PackingProduction> _produksiItems = [];
  bool _produksiLoading = false;
  bool _produksiFetchingMore = false;
  bool _produksiHasMore = true;
  int _produksiPage = 1;
  static const _pageSize = 30;
  final _produksiScrollCtl = ScrollController();
  int? _filterIdMesin;
  PackingMesinInfo? _selectedMesinInfo;
  bool _isRiwayatExpanded = false;
  int _sidebarTab = 0; // 0 = Riwayat Produksi, 1 = Stok Item

  @override
  void initState() {
    super.initState();
    _editVmPool = PackingProductionViewModel(repository: _repo);
    _loadMesin();
    _loadProduksiPage();
    _produksiScrollCtl.addListener(_onProduksiScroll);
  }

  @override
  void dispose() {
    _produksiScrollCtl.dispose();
    _editVmPool.dispose();
    super.dispose();
  }

  Future<void> _loadMesin() async {
    final future = _repo.fetchPackingMesin();
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
      final newItems = res['items'] as List<PackingProduction>;
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
      final newItems = res['items'] as List<PackingProduction>;
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

  static MesinCardData _toMesinCardData(PackingMesinInfo mesin) {
    String? shiftTimeText;
    if (mesin.isActive) {
      final parts = <String>[];
      if (mesin.shift != null) parts.add('Shift ${mesin.shift}');
      parts.add('${mesin.hourStart ?? '--:--'} – ${mesin.hourEnd ?? '--:--'}');
      shiftTimeText = parts.join('  |  ');
    }
    return MesinCardData(
      namaMesin: mesin.namaMesin,
      isActive: mesin.isActive,
      shiftTimeText: shiftTimeText,
      namaRegu: mesin.namaRegu,
      outputJenisNama: mesin.outputJenisNama,
    );
  }

  static ProduksiRowData _toRowData(PackingProduction row) {
    return ProduksiRowData(
      tglProduksi: row.tglProduksi,
      hourStart: row.hourStart,
      hourEnd: row.hourEnd,
      shift: row.shift,
      isLocked: row.isLocked,
      namaMesin: row.namaMesin,
      namaRegu: row.namaOperator,
      outputJenisNama: row.outputJenisNama,
      noProduksi: row.noPacking,
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  Future<void> _openCreateDialog({
    PackingMesinInfo? mesin,
    bool isBackdate = false,
  }) async {
    if (!mounted) return;
    final initialMesin = mesin == null
        ? null
        : MstMesin(
            idMesin: mesin.idMesin,
            namaMesin: mesin.namaMesin,
            bagian: mesin.bagian ?? '',
            enable: true,
          );

    // Fetch current shift hanya saat realtime (isBackdate=false, dari klik kartu mesin)
    ActiveShift? activeShift;
    if (!isBackdate && mesin != null) {
      activeShift = await ShiftRepository.fetchCurrentShift();
      if (!mounted) return;
    }

    final editVm = PackingProductionViewModel(repository: _repo);
    try {
      final created = await showDialog<PackingProduction>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChangeNotifierProvider.value(
          value: editVm,
          child: PackingProductionFormDialog(
            initialMesin: initialMesin,
            initialDate: !isBackdate ? DateTime.now() : null,
            initialShift: activeShift?.shift,
            initialHourStart: activeShift?.hourStart,
            initialHourEnd: activeShift?.hourEnd,
            isBackdateInput: isBackdate,
          ),
        ),
      );
      if (!mounted) return;
      if (created != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PackingProductionInputScreen(noProduksi: created.noPacking),
          ),
        );
        if (!mounted) return;
      }
    } finally {
      editVm.dispose();
    }
    _refreshAll();
  }

  Future<void> _onMesinTap(PackingMesinInfo mesin) async {
    if (!mounted) return;

    if (!mesin.isActive) {
      await _openCreateDialog(mesin: mesin, isBackdate: false);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PackingProductionInputScreen(noProduksi: mesin.noProduksi!),
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
                  FutureBuilder<List<PackingMesinInfo>>(
                    future: _mesinFuture,
                    builder: (context, snapshot) {
                      final allMesin = snapshot.data ?? [];
                      final activeCount = allMesin
                          .where((m) => m.isActive)
                          .length;
                      final inactiveCount = allMesin.length - activeCount;
                      return MesinSectionHeader(
                        title: 'Status Mesin Packing',
                        activeCount: activeCount,
                        inactiveCount: inactiveCount,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                  Expanded(
                    child: FutureBuilder<List<PackingMesinInfo>>(
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
                            final cols = (constraints.maxWidth / 165)
                                .floor()
                                .clamp(2, 6);
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisExtent: 130,
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
                isOpen: _isRiwayatExpanded,
                onClose: () => setState(() => _isRiwayatExpanded = false),
                onOpen: () => setState(() => _isRiwayatExpanded = true),
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

  // ── Stok Item: chip kategori (Furniture WIP) ────────────────────────────────

  Widget _buildStokItemContent() {
    return StokItemSection(
      controller: _stokSectionController,
      sources: [
        TypedStokItemSource<FurnitureWipStokItem, FurnitureWipStokLabel>(
          label: 'Furniture WIP',
          fetchStok: _furnitureWipStokRepo.fetchStok,
          fetchLabel: (item) =>
              _furnitureWipStokRepo.fetchLabel(item.idCabinetWip),
          sakColumnLabel: 'PCS',
          showBeratColumn: false,
          oldestDateOf: (item) => item.dateCreateTertua,
        ),
      ],
    );
  }

  Widget _buildRiwayatContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<PackingMesinInfo>>(
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
                child: ProductionProduksiList<PackingProduction>(
                  items: _produksiItems,
                  dataOf: _toRowData,
                  isLoading: _produksiLoading,
                  isFetchingMore: _produksiFetchingMore,
                  scrollController: _produksiScrollCtl,
                  showMesin: _filterIdMesin == null,
                  onTap: (row) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PackingProductionInputScreen(
                          noProduksi: row.noPacking,
                        ),
                      ),
                    );
                    if (mounted) _refreshAll();
                  },
                  onEdit: (row) async {
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ChangeNotifierProvider.value(
                        value: _editVmPool,
                        child: PackingProductionFormDialog(header: row),
                      ),
                    );
                    if (mounted) _refreshAll();
                  },
                  onDelete: (row) async {
                    final screenCtx = context;
                    await showDialog<void>(
                      context: screenCtx,
                      barrierDismissible: false,
                      builder: (ctx) => PackingProductionDeleteDialog(
                        header: row,
                        onConfirm: () async {
                          final success = await _editVmPool.deleteProduksi(
                            row.noPacking,
                          );
                          final errMsg = _editVmPool.saveError;
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (!screenCtx.mounted) return;
                          if (success) {
                            showDialog(
                              context: screenCtx,
                              builder: (_) => SuccessStatusDialog(
                                title: 'Berhasil Menghapus',
                                message:
                                    'No. Packing ${row.noPacking} berhasil dihapus.',
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
                    heroTag: 'fab_add_packing',
                    onPressed: () => _openCreateDialog(
                      mesin: _selectedMesinInfo,
                      isBackdate: true,
                    ),
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    tooltip: 'Tambah Produksi',
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
