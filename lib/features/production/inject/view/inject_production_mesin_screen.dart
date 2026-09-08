import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../mesin/model/mesin_model.dart';
import '../../../shift/repository/shift_repository.dart';
import '../../shared/models/furniture_wip_stok_item.dart';
import '../../shared/models/furniture_wip_stok_label.dart';
import '../../shared/models/mixer_stok_item.dart';
import '../../shared/models/mixer_stok_label.dart';
import '../../shared/repository/furniture_wip_stok_repository.dart';
import '../../shared/repository/mixer_stok_repository.dart';
import '../../shared/widgets/mesin_section_header.dart';
import '../../shared/widgets/production_mesin_card.dart';
import '../../shared/widgets/production_produksi_list.dart';
import '../../shared/widgets/production_overlay_drawer.dart';
import '../../shared/widgets/production_riwayat_header.dart';
import '../../shared/widgets/sidebar_tab_switcher.dart';
import '../../shared/widgets/stok_item_section.dart';
import '../model/inject_production_model.dart';
import '../repository/inject_production_repository.dart';
import '../view_model/inject_production_view_model.dart';
import '../widgets/inject_production_delete_dialog.dart';
import '../widgets/inject_production_form_dialog.dart';
import '../widgets/inject_qc_dialog.dart';
import 'inject_production_input_screen.dart';

class InjectProductionMesinScreen extends StatefulWidget {
  const InjectProductionMesinScreen({super.key});

  @override
  State<InjectProductionMesinScreen> createState() =>
      _InjectProductionMesinScreenState();
}

class _InjectProductionMesinScreenState
    extends State<InjectProductionMesinScreen> {
  final _prodRepo = InjectProductionRepository();
  final _furnitureWipStokRepo = FurnitureWipStokRepository();
  final _mixerStokRepo = MixerStokRepository();
  final _stokSectionController = StokItemSectionController();
  Future<List<InjectMesinInfo>> _mesinFuture = Future.value(
    <InjectMesinInfo>[],
  );

  final List<InjectProduction> _produksiItems = [];
  bool _produksiLoading = false;
  bool _produksiFetchingMore = false;
  bool _produksiHasMore = true;
  int _produksiPage = 1;
  static const _pageSize = 30;
  final _produksiScrollCtl = ScrollController();
  int? _filterIdMesin;
  InjectMesinInfo? _selectedMesinInfo;
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
    final future = _prodRepo.fetchInjectMesin();
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
      final newItems = res['items'] as List<InjectProduction>;
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
      final newItems = res['items'] as List<InjectProduction>;
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

  Future<void> _openInputScreen(String noProduksi) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InjectProductionInputScreen(noProduksi: noProduksi),
      ),
    );
  }

  Future<void> _openCreateDialog({
    required InjectMesinInfo mesin,
    bool isBackdateInput = false,
  }) async {
    if (!mounted) return;
    final defaultShift = await ShiftRepository.fetchInjectCurrentShift();
    if (!mounted) return;
    final mstMesin = MstMesin(
      idMesin: mesin.idMesin,
      namaMesin: mesin.namaMesin,
      bagian: mesin.bagian,
      enable: true,
    );
    final vm = InjectProductionViewModel(repository: _prodRepo);
    try {
      final created = await showDialog<InjectProduction>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChangeNotifierProvider<InjectProductionViewModel>.value(
          value: vm,
          child: InjectProductionFormDialog(
            initialMesin: mstMesin,
            initialDate: ShiftRepository.effectiveDateForShift(defaultShift),
            initialShift: defaultShift?.shift,
            initialHourStart: defaultShift?.hourStart,
            initialHourEnd: defaultShift?.hourEnd,
            isBackdateInput: isBackdateInput,
          ),
        ),
      );
      if (!mounted) return;
      if (created != null) {
        await _openInputScreen(created.noProduksi);
        if (!mounted) return;
        _refreshAll();
      }
    } finally {
      vm.dispose();
    }
  }

  Future<void> _onMesinTap(InjectMesinInfo mesin) async {
    if (!mounted) return;
    if (!mesin.hasProduction) {
      await _openCreateDialog(mesin: mesin);
      return;
    }
    final noProduksi = mesin.produksiList.first.noProduksi;
    await _openInputScreen(noProduksi);
    if (mounted) _refreshAll();
  }

  Future<void> _onMesinLongPress(InjectMesinInfo mesin) async {
    if (!mounted || !mesin.hasProduction) return;
    await _openQcDialog(mesin);
  }

  // ── helpers ──────────────────────────────────────────────────────

  static InjectProduksiItem? _currentItem(InjectMesinInfo mesin) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    TimeOfDay? parse(String? s) {
      if (s == null || s.isEmpty) return null;
      final parts = s.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return TimeOfDay(hour: h, minute: m);
    }

    for (final p in mesin.produksiList) {
      final start = parse(p.hourStart);
      final end = parse(p.hourEnd);
      if (start == null || end == null) continue;
      final s = start.hour * 60 + start.minute;
      final e = end.hour * 60 + end.minute;
      final inRange = s <= e
          ? nowMin >= s && nowMin < e
          : nowMin >= s || nowMin < e;
      if (inRange) return p;
    }
    return mesin.produksiList.isNotEmpty ? mesin.produksiList.first : null;
  }

  static MesinCardData _toMesinCardData(
    InjectMesinInfo mesin, {
    VoidCallback? onQcTap,
  }) {
    final current = mesin.hasProduction ? _currentItem(mesin) : null;
    String? shiftTimeText;
    if (current != null) {
      final parts = <String>[];
      if (current.shift != null) parts.add('Shift ${current.shift}');
      parts.add(
        '${current.hourStart ?? '--:--'} – ${current.hourEnd ?? '--:--'}',
      );
      shiftTimeText = parts.join('  |  ');
    }
    return MesinCardData(
      namaMesin: mesin.namaMesin,
      isActive: mesin.isActive,
      machineStatus: mesin.machineStatus,
      shiftTimeText: shiftTimeText,
      namaRegu: current?.namaRegu,
      outputJenisNama: current?.outputs.isNotEmpty == true
          ? current!.outputs.map((o) => o.namaJenis).join(', ')
          : null,
      onQcTap: onQcTap,
    );
  }

  Future<void> _openQcDialog(InjectMesinInfo mesin) async {
    if (!mounted) return;
    final item = mesin.produksiList.isNotEmpty
        ? mesin.produksiList.first
        : null;
    if (item == null || item.hourStart == null || item.hourEnd == null) return;

    String trimHour(String? s) {
      final v = (s ?? '').trim();
      return v.length >= 5 ? v.substring(0, 5) : v;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InjectQcDialog(
        noProduksi: item.noProduksi,
        shift: item.shift,
        namaMesin: mesin.namaMesin,
        idMesin: mesin.idMesin,
        outputJenisList: item.outputs.isNotEmpty
            ? item.outputs.map((output) => output.namaJenis).toList()
            : [
                if ((item.outputCategory ?? '').trim().isNotEmpty)
                  item.outputCategory!.trim(),
              ],
        hourStart: trimHour(item.hourStart),
        hourEnd: trimHour(item.hourEnd),
        tglProduksi: item.tglProduksi,
      ),
    );
  }

  static ProduksiRowData _toRowData(InjectProduction row) {
    return ProduksiRowData(
      tglProduksi: row.tglProduksi,
      hourStart: row.hourStart,
      hourEnd: row.hourEnd,
      shift: row.shift,
      isLocked: row.isLocked,
      namaMesin: row.namaMesin,
      namaCetakan: row.namaCetakan,
      namaWarna: row.namaWarna,
      namaFurnitureMaterial: row.namaFurnitureMaterial,
      noProduksi: row.noProduksi,
      produksiStatus: row.produksiStatus,
    );
  }

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
                  FutureBuilder<List<InjectMesinInfo>>(
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
                        title: 'Status Mesin Inject',
                        activeCount: activeCount,
                        pendingCount: pendingCount,
                        inactiveCount: inactiveCount,
                        isLoading:
                            snapshot.connectionState == ConnectionState.waiting,
                      );
                    },
                  ),
                  Expanded(
                    child: FutureBuilder<List<InjectMesinInfo>>(
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
                                  onLongPress: mesin.hasProduction
                                      ? () => _onMesinLongPress(mesin)
                                      : null,
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
        TypedStokItemSource<MixerStokItem, MixerStokLabel>(
          label: 'Mixer',
          fetchStok: _mixerStokRepo.fetchStok,
          fetchLabel: (item) => _mixerStokRepo.fetchLabel(item.idMixer),
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
        FutureBuilder<List<InjectMesinInfo>>(
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
                child: ProductionProduksiList<InjectProduction>(
                  items: _produksiItems,
                  dataOf: _toRowData,
                  isLoading: _produksiLoading,
                  isFetchingMore: _produksiFetchingMore,
                  scrollController: _produksiScrollCtl,
                  showMesin: _filterIdMesin == null,
                  onTap: (row) async {
                    await _openInputScreen(row.noProduksi);
                    if (mounted) _refreshAll();
                  },
                  onEdit: (row) async {
                    final vm = InjectProductionViewModel(repository: _prodRepo);
                    InjectProduction? savedResult;
                    String? saveError;
                    try {
                      await showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            ChangeNotifierProvider<
                              InjectProductionViewModel
                            >.value(
                              value: vm,
                              child: InjectProductionFormDialog(
                                header: row,
                                onSave: (r) => savedResult = r,
                              ),
                            ),
                      );
                      saveError = vm.saveError;
                    } finally {
                      vm.dispose();
                    }
                    if (!mounted) return;
                    if (savedResult != null) {
                      // ignore: use_build_context_synchronously
                      await showDialog<void>(
                        context: context,
                        builder: (_) => SuccessStatusDialog(
                          title: 'Berhasil Diperbarui',
                          message:
                              'No. Produksi ${row.noProduksi} berhasil diperbarui.',
                        ),
                      );
                    } else if (saveError != null) {
                      // ignore: use_build_context_synchronously
                      await showDialog<void>(
                        context: context,
                        builder: (_) => ErrorStatusDialog(
                          title: 'Gagal Memperbarui',
                          message: saveError!,
                        ),
                      );
                    }
                    if (mounted) _refreshAll();
                  },
                  onDelete: (row) async {
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => InjectProductionDeleteDialog(
                        header: row,
                        onConfirm: () async {
                          final vm = InjectProductionViewModel(
                            repository: _prodRepo,
                          );
                          final success = await vm.deleteProduksi(
                            row.noProduksi,
                          );
                          final errMsg = vm.saveError;
                          vm.dispose();
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
                    heroTag: 'fab_backdate_inject',
                    onPressed: () => _openCreateDialog(
                      mesin: _selectedMesinInfo!,
                      isBackdateInput: true,
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
