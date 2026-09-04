import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../features/mesin/model/mesin_model.dart';
import '../../../shift/repository/shift_repository.dart';
import '../../shared/models/crusher_stok_item.dart';
import '../../shared/models/crusher_stok_label.dart';
import '../../shared/models/washing_stok_item.dart';
import '../../shared/models/washing_stok_label.dart';
import '../../shared/repository/crusher_stok_repository.dart';
import '../../shared/repository/washing_stok_repository.dart';
import '../../shared/widgets/mesin_section_header.dart';
import '../../shared/widgets/production_mesin_card.dart';
import '../../shared/widgets/production_produksi_list.dart';
import '../../shared/widgets/production_overlay_drawer.dart';
import '../../shared/widgets/production_riwayat_header.dart';
import '../../shared/widgets/sidebar_tab_switcher.dart';
import '../../shared/widgets/stok_item_section.dart';
import '../model/broker_production_model.dart';
import '../repository/broker_production_repository.dart';
import '../view_model/broker_production_view_model.dart';
import '../widgets/broker_delete_dialog.dart';
import '../widgets/broker_production_form_dialog.dart';
import 'broker_production_input_screen.dart';

class BrokerProductionMesinScreen extends StatefulWidget {
  const BrokerProductionMesinScreen({super.key});

  @override
  State<BrokerProductionMesinScreen> createState() =>
      _BrokerProductionMesinScreenState();
}

class _BrokerProductionMesinScreenState
    extends State<BrokerProductionMesinScreen> {
  final _prodRepo = BrokerProductionRepository();
  final _stokRepo = WashingStokRepository();
  final _crusherStokRepo = CrusherStokRepository();
  final _stokSectionController = StokItemSectionController();
  Future<List<BrokerMesinInfo>> _mesinFuture = Future.value(
    <BrokerMesinInfo>[],
  );

  final List<BrokerProduction> _produksiItems = [];
  bool _produksiLoading = false;
  bool _produksiFetchingMore = false;
  bool _produksiHasMore = true;
  int _produksiPage = 1;
  static const _pageSize = 30;
  final _produksiScrollCtl = ScrollController();
  int? _filterIdMesin;
  BrokerMesinInfo? _selectedMesinInfo;
  bool _isRiwayatExpanded = false;
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

  Future<void> _loadMesin() async {
    final future = _prodRepo.fetchBrokerMesin();
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
      final res = await _prodRepo.fetchAll(
        page: 1,
        pageSize: _pageSize,
        idMesin: _filterIdMesin,
      );
      if (!mounted) return;
      final newItems = res['items'] as List<BrokerProduction>;
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
      final res = await _prodRepo.fetchAll(
        page: nextPage,
        pageSize: _pageSize,
        idMesin: _filterIdMesin,
      );
      if (!mounted) return;
      final newItems = res['items'] as List<BrokerProduction>;
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

  static MesinCardData _toMesinCardData(BrokerMesinInfo mesin) {
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
      outputJenisNama: mesin.produksiList.isNotEmpty
          ? mesin.produksiList.first.outputJenisNama
          : null,
    );
  }

  static ProduksiRowData _toRowData(BrokerProduction row) {
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

  Future<void> _openBackdateDialog(BrokerMesinInfo mesin) async {
    if (!mounted) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final mstMesin = MstMesin(
      idMesin: mesin.idMesin,
      namaMesin: mesin.namaMesin,
      bagian: mesin.bagian,
      enable: true,
    );
    final editVm = BrokerProductionViewModel();
    try {
      final created = await showDialog<BrokerProduction>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChangeNotifierProvider.value(
          value: editVm,
          child: BrokerProductionFormDialog(
            initialMesin: mstMesin,
            initialDate: yesterday,
            isBackdateInput: true,
          ),
        ),
      );
      if (!mounted) return;
      if (created != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                BrokerProductionInputScreen(noProduksi: created.noProduksi),
          ),
        );
        if (!mounted) return;
        _refreshAll();
      }
    } finally {
      editVm.dispose();
    }
  }

  Future<void> _openCreateDialog({
    required BrokerMesinInfo mesin,
    required DateTime today,
  }) async {
    if (!mounted) return;
    final mstMesin = MstMesin(
      idMesin: mesin.idMesin,
      namaMesin: mesin.namaMesin,
      bagian: mesin.bagian,
      enable: true,
    );
    final defaultShift = await ShiftRepository.fetchCurrentShift();
    if (!mounted) return;
    final created = await showDialog<BrokerProduction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BrokerProductionFormDialog(
        initialMesin: mstMesin,
        initialDate: today,
        existingProduksiList: mesin.produksiList,
        initialShift: defaultShift?.shift,
        initialHourStart: defaultShift?.hourStart,
        initialHourEnd: defaultShift?.hourEnd,
      ),
    );
    if (!mounted) return;
    if (created != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              BrokerProductionInputScreen(noProduksi: created.noProduksi),
        ),
      );
      if (!mounted) return;
    }
    _refreshAll();
  }

  Future<void> _onMesinTap(BrokerMesinInfo mesin) async {
    if (!mounted) return;
    final item = mesin.produksiList.isNotEmpty
        ? mesin.produksiList.first
        : null;
    if (item == null) {
      await _openCreateDialog(mesin: mesin, today: DateTime.now());
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BrokerProductionInputScreen(noProduksi: item.noProduksi),
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
                  FutureBuilder<List<BrokerMesinInfo>>(
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
                        title: 'Status Mesin Broker',
                        activeCount: activeCount,
                        pendingCount: pendingCount,
                        inactiveCount: inactiveCount,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                  Expanded(
                    child: FutureBuilder<List<BrokerMesinInfo>>(
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

  // ── Stok Item: filter by chip kategori (Stok Washing / Stok Crusher) ──────

  Widget _buildStokItemContent() {
    return StokItemSection(
      controller: _stokSectionController,
      sources: [
        TypedStokItemSource<WashingStokItem, WashingStokLabel>(
          label: 'Washing',
          fetchStok: _stokRepo.fetchStok,
          fetchLabel: (item) => _stokRepo.fetchLabel(item.idWashing),
          showSakColumn: false,
          oldestDateOf: (item) => item.dateCreateTertua,
        ),
        TypedStokItemSource<CrusherStokItem, CrusherStokLabel>(
          label: 'Crusher',
          fetchStok: _crusherStokRepo.fetchStok,
          fetchLabel: (item) => _crusherStokRepo.fetchLabel(item.idCrusher),
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
        FutureBuilder<List<BrokerMesinInfo>>(
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
                child: ProductionProduksiList<BrokerProduction>(
                  items: _produksiItems,
                  dataOf: _toRowData,
                  isLoading: _produksiLoading,
                  isFetchingMore: _produksiFetchingMore,
                  scrollController: _produksiScrollCtl,
                  showMesin: _filterIdMesin == null,
                  onTap: (row) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BrokerProductionInputScreen(
                          noProduksi: row.noProduksi,
                        ),
                      ),
                    );
                    if (mounted) _refreshAll();
                  },
                  onEdit: (row) async {
                    final editVm = BrokerProductionViewModel();
                    try {
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => ChangeNotifierProvider.value(
                          value: editVm,
                          child: BrokerProductionFormDialog(header: row),
                        ),
                      );
                    } finally {
                      editVm.dispose();
                    }
                    if (mounted) _refreshAll();
                  },
                  onDelete: (row) async {
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => BrokerProductionDeleteDialog(
                        header: row,
                        onConfirm: () async {
                          final deleteVm = BrokerProductionViewModel();
                          final success = await deleteVm.deleteProduksi(
                            row.noProduksi,
                          );
                          final errMsg = deleteVm.saveError;
                          deleteVm.dispose();
                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (!mounted) return;
                          if (success) {
                            // ignore: use_build_context_synchronously
                            showDialog(
                              context: context,
                              builder: (_) => SuccessStatusDialog(
                                title: 'Berhasil Menghapus',
                                message:
                                    'No. Produksi ${row.noProduksi} berhasil dihapus.',
                              ),
                            );
                          } else {
                            // ignore: use_build_context_synchronously
                            showDialog(
                              context: context,
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
                    heroTag: 'fab_backdate_broker',
                    onPressed: () => _openBackdateDialog(_selectedMesinInfo!),
                    backgroundColor: const Color(0xFF1D4ED8),
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
