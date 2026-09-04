import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pps_tablet/core/view/app_shell.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/scan_label_dialog.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../shared/widgets/add_cabinet_material_dialog.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../model/packing_output_model.dart';
import '../view_model/packing_production_input_view_model.dart';
import '../model/packing_production_inputs_model.dart';
import '../model/packing_production_model.dart';
import '../repository/packing_production_repository.dart';
import '../widgets/packing_production_output_form_dialog.dart';
import '../../../label/packing/repository/packing_repository.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import 'package:pps_tablet/features/production/shared/shared.dart';
import 'package:shimmer/shimmer.dart';
import '../../../packing_type/model/packing_type_model.dart';
import '../../../packing_type/widgets/packing_type_dropdown.dart';

// ── Colour palette ──────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1E6FD9); // biru — input section (seragam)
const _kOutput = Color(0xFF0F766E); // teal — output
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);

class PackingProductionInputScreen extends StatefulWidget {
  final String noProduksi;

  const PackingProductionInputScreen({super.key, required this.noProduksi});

  @override
  State<PackingProductionInputScreen> createState() =>
      _PackingProductionInputScreenState();
}

class _PackingProductionInputScreenState
    extends State<PackingProductionInputScreen>
    with
        ProductionOutputMultiSelectMixin<PackingProductionInputScreen>,
        ProductionInputMultiSelectMixin<PackingProductionInputScreen> {
  final _prodRepo = PackingProductionRepository();

  /// Produksi sudah selesai / terkunci -> tidak boleh diubah maupun dicetak.
  bool get _isLockedOrComplete =>
      _header?.isLocked == true || _header?.isComplete == true;
  @override
  bool get isOutputInteractionLocked => _isLockedOrComplete;
  @override
  bool get isInputInteractionLocked => _isLockedOrComplete;
  PackingProduction? _header;
  late String _cachedBreadcrumbLabel;
  String _selectedInputTab = 'fwip';
  String _selectedOutputTab = 'bj';
  List<BreadcrumbSegment> _prevBreadcrumb = [];
  bool _isReplacing = false;

  String get _breadcrumbLabel {
    final mesin = (_header?.namaMesin ?? '').trim();
    if (mesin.isNotEmpty) return '$mesin (${widget.noProduksi})';
    return widget.noProduksi;
  }

  @override
  void initState() {
    super.initState();
    _cachedBreadcrumbLabel = widget.noProduksi;
    _loadHeader();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
      _updateBreadcrumb();
      final vm = context.read<PackingProductionInputViewModel>();
      if (vm.inputsOf(widget.noProduksi) == null &&
          !vm.isInputsLoading(widget.noProduksi)) {
        vm.loadInputs(widget.noProduksi);
      }
      if (vm.outputsOf(widget.noProduksi) == null &&
          !vm.isOutputsLoading(widget.noProduksi)) {
        vm.loadOutputs(widget.noProduksi);
      }
    });
  }

  @override
  void dispose() {
    if (!_isReplacing) {
      final label = _cachedBreadcrumbLabel;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = AppShell.breadcrumb.value;
        if (current.isNotEmpty && current.last.label == label) {
          AppShell.breadcrumb.value = _prevBreadcrumb;
        }
      });
    }
    super.dispose();
  }

  Future<void> _loadHeader() async {
    try {
      final header = await _prodRepo.fetchOne(widget.noProduksi);
      if (!mounted) return;
      setState(() {
        _header = header;
        _cachedBreadcrumbLabel = _breadcrumbLabel;
      });
      _updateBreadcrumb();
    } catch (_) {}
  }

  void _updateBreadcrumb() {
    if (!mounted) return;
    AppShell.breadcrumb.value = [
      ..._prevBreadcrumb.map(
        (segment) => BreadcrumbSegment(
          segment.label,
          onTap: () {
            AppShell.breadcrumb.value = _prevBreadcrumb;
            AppShell.shellNavigatorKey.currentState?.pop();
          },
        ),
      ),
      BreadcrumbSegment(_breadcrumbLabel),
    ];
  }

  Widget _buildToolbarSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(height: 56, color: Colors.white),
    );
  }

  // ── Back ──────────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final vm = context.read<PackingProductionInputViewModel>();
    if (vm.totalTempCount == 0) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UnsavedTempWarningDialog(
        totalTempCount: vm.totalTempCount,
        submitSummary: vm.getSubmitSummary(),
        onSavePressed: () {
          Navigator.of(ctx).pop(false);
          _handleSave();
        },
      ),
    );

    if (shouldPop == true) {
      vm.clearAllTempItems();
      return true;
    }
    return false;
  }

  // ── Split / Ganti produksi ─────────────────────────────────────────────────

  Future<void> _openSplitDialog() async {
    if (!mounted) return;
    await ProductionFlowHelpers.openSplitAndReplace<
      ({PackingProduction prod, String namaJenis})
    >(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tglProduksi,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      showSplitDialog: (idMesin, tgl) {
        return showDialog<({PackingProduction prod, String namaJenis})>(
          context: context,
          barrierDismissible: true,
          builder: (_) =>
              ProductionGantiProduksiDialog<
                ({PackingProduction prod, String namaJenis}),
                PackingType
              >(
                tanggal: tgl,
                shift: _header?.shift ?? 1,
                primaryColor: _kPrimary,
                borderColor: _kBorder,
                jenisRequiredMessage: 'Pilih jenis barang jadi terlebih dahulu',
                submitLabel: 'Ganti Produksi',
                dropdownBuilder: (selected, onChanged) => PackingTypeDropdown(
                  preselectId: selected?.idBj,
                  onChanged: onChanged,
                ),
                jenisNameOf: (j) => j.namaBj,
                onSubmit: (hourStart, jenis) async {
                  final body = await _prodRepo.splitTime(
                    idMesin: idMesin,
                    tanggal: tgl,
                    hourStart: '${hourStart.trim()}:00',
                    outputJenisId: jenis.idBj,
                  );
                  final data = body['data'];
                  final headerMap = data is Map && data['header'] is Map
                      ? data['header'] as Map<String, dynamic>
                      : (data is Map<String, dynamic>
                            ? data
                            : <String, dynamic>{});
                  return (
                    prod: PackingProduction.fromJson(headerMap),
                    namaJenis: jenis.namaBj,
                  );
                },
              ),
        );
      },
      beforeReplace: () {
        _isReplacing = true;
        AppShell.breadcrumb.value = _prevBreadcrumb;
      },
      replaceToResult: (result) async {
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                PackingProductionInputScreen(noProduksi: result.prod.noPacking),
          ),
        );
      },
    );
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────
  Future<void> _handleComplete() async {
    final vm = context.read<PackingProductionInputViewModel>();
    if (vm.totalTempCount > 0) {
      _showSnack(
        'Masih ada ${vm.totalTempCount} data belum disimpan. '
        'Simpan atau hapus dulu sebelum menyelesaikan.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Selesaikan Produksi?',
        message:
            'Yakin ingin menyelesaikan produksi ${widget.noProduksi}? '
            'Setelah selesai, produksi akan dikunci dan tidak dapat diubah.',
        confirmLabel: 'Selesaikan',
        confirmIcon: Icons.check_circle_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _prodRepo.completeProduksi(widget.noProduksi);
      if (!mounted) return;
      _showSnack('✅ Produksi berhasil diselesaikan',
          backgroundColor: Colors.green);
      await _loadHeader();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Gagal Menyelesaikan',
          message: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _showSnack(String msg, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    final vm = context.read<PackingProductionInputViewModel>();
    if (vm.totalTempCount == 0) {
      _showSnack(
        'Tidak ada data untuk disimpan',
        backgroundColor: Colors.orange,
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConfirmSaveTempDialog(
        totalTempCount: vm.totalTempCount,
        submitSummary: vm.getSubmitSummary(),
      ),
    );
    if (confirm != true || !mounted) return;

    final success = await vm.submitTempItems(widget.noProduksi);
    if (!mounted) return;

    if (success) {
      _showSnack('✅ Data berhasil disimpan', backgroundColor: Colors.green);
      vm.loadOutputs(widget.noProduksi, force: true);
    } else {
      final errMsg = vm.submitError ?? 'Kesalahan tidak diketahui';
      await showDialog(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menyimpan', message: errMsg),
      );
    }
  }

  void _confirmClearTemp() {
    final vm = context.read<PackingProductionInputViewModel>();
    if (vm.totalTempCount == 0) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Semua Temp?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${vm.totalTempCount} item temp?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              vm.clearAllTempItems();
              Navigator.of(ctx).pop();
              _showSnack('Semua temp items dihapus');
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Scan / lookup ─────────────────────────────────────────────────────────

  Future<void> _openScanDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        manualHint: 'F.XXXXXXXXXX',
        acceptedLabels: const [(prefix: 'F', label: 'Furniture WIP')],
        onLookup: _onCodeReady,
      ),
    );
  }

  Future<String?> _onCodeReady(String code) async {
    final vm = context.read<PackingProductionInputViewModel>();
    final res = await vm.lookupLabel(code, force: true);
    if (!mounted) return 'Halaman sudah tidak aktif';
    if (vm.lookupError != null) return 'Gagal ambil data: ${vm.lookupError}';
    if (res == null || res.found == false || res.data.isEmpty) {
      return 'Label "$code" tidak memiliki data yang tersedia.';
    }
    await _handlePcsInputFlow(vm, res);
    return null;
  }

  Future<void> _handlePcsInputFlow(
    PackingProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    int totalAdded = 0;
    int totalSkipped = 0;

    for (int i = 0; i < res.typedItems.length; i++) {
      final item = res.typedItems[i];
      if (item is! FurnitureWipItem) continue;

      final rawRow = res.data[i];
      final simpleKey = res.simpleKey(rawRow);

      if (vm.isInTempKeys(simpleKey)) {
        totalSkipped++;
        continue;
      }

      if (!mounted) break;

      final result = await showDialog<ProductionPcsInputResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProductionPcsInputDialog(
          item: item,
          itemIndex: i,
          totalItems: res.typedItems.length,
        ),
      );

      if (result == null) continue;

      final originalPcs = rawRow['pcs'] ?? rawRow['Pcs'];
      final originalIsPartial = rawRow['isPartial'];

      if (result.isPartial) {
        rawRow['pcs'] = result.pcs;
        rawRow['Pcs'] = result.pcs;
        rawRow['isPartial'] = true;
        rawRow['IsPartial'] = true;
      }

      vm.clearPicks();
      vm.togglePick(rawRow);
      final r = vm.commitPickedToTemp(noPacking: widget.noProduksi);

      rawRow['pcs'] = originalPcs;
      rawRow['Pcs'] = originalPcs;
      rawRow['isPartial'] = originalIsPartial;
      rawRow['IsPartial'] = originalIsPartial;

      totalAdded += r.added;
      totalSkipped += r.skipped;
    }

    if (!mounted) return;
    final msg = totalAdded > 0
        ? '✅ Ditambahkan $totalAdded item${totalSkipped > 0 ? ' • $totalSkipped terlewati' : ''}'
        : 'Tidak ada item yang ditambahkan';
    _showSnack(
      msg,
      backgroundColor: totalAdded > 0 ? Colors.green : Colors.orange,
    );
  }

  // ── Cabinet Material helpers ───────────────────────────────────────────────

  Future<void> _openAddMaterialDialog(
    PackingProductionInputViewModel vm,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AddCabinetMaterialDialog(
        idWarehouse: 5,
        loadMaterials: ({required idWarehouse, bool force = false}) => vm
            .loadMasterCabinetMaterials(idWarehouse: idWarehouse, force: force),
        isAlreadyInTemp: (id) => vm.hasCabinetMaterialInTemp(id),
        onAddTemp: ({required masterItem, required jumlah}) =>
            vm.addTempCabinetMaterialFromMaster(
              masterItem: masterItem,
              Jumlah: jumlah,
            ),
      ),
    );
  }

  Future<void> _deleteExistingMaterial(
    PackingProductionInputViewModel vm,
    CabinetMaterialItem item,
  ) async {
    final name = item.Nama ?? 'Material';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Material?'),
        content: Text('Yakin ingin menghapus $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await vm.deleteItems(widget.noProduksi, [item]);
    if (!mounted) return;
    _showSnack(
      success ? '✅ Material berhasil dihapus' : (vm.deleteError ?? 'Gagal'),
      backgroundColor: success ? Colors.green : Colors.red,
    );
  }

  // ── FWIP title key ─────────────────────────────────────────────────────────

  String _fwipTitleKey(FurnitureWipItem e) {
    final part = (e.noFurnitureWIPPartial ?? '').trim();
    return part.isNotEmpty ? part : (e.noFurnitureWIP ?? '-');
  }

  // ── Input panel ────────────────────────────────────────────────────────────

  // ── Multi-select input (long-press → Keluarkan) ───────────────────────────

  Future<void> _releaseSelectedInput(PackingProductionInputViewModel vm) async {
    final count = selectedInputCount;
    if (count == 0) return;
    if (!await confirmReleaseInputDialog(context, count) || !mounted) return;
    final success = await vm.deleteItems(widget.noProduksi, selectedInputItems);
    if (!mounted) return;
    cancelInputSelection();
    _showSnack(
      success
          ? '✅ $count label berhasil dikeluarkan dari proses'
          : (vm.deleteError ?? 'Gagal mengeluarkan label'),
      backgroundColor: success ? Colors.green : Colors.red,
    );
  }

  Widget _inputSelectionBar(
    PackingProductionInputViewModel vm,
    Map<String, List<Object>> groups,
  ) {
    final total = groups.length;
    final allSelected = total > 0 && selectedInputCount >= total;
    return ProductionInputSelectionBar(
      accentColor: _kPrimary,
      count: selectedInputCount,
      totalAvailable: total,
      allSelected: allSelected,
      isBusy: vm.isDeleting,
      onCancel: cancelInputSelection,
      onToggleAll: allSelected
          ? clearInputSelection
          : () => selectAllInputGroups(groups),
      onRelease: _isLockedOrComplete ? null : () => _releaseSelectedInput(vm),
    );
  }

  Widget _buildInputPanel({
    required PackingProductionInputViewModel vm,
    required bool locked,
    required bool loading,
    required bool canDelete,
    required Map<String, List<FurnitureWipItem>> fwipGroups,
    required List<CabinetMaterialItem> materialAll,
    required Set<int> tempMaterialIds,
  }) {
    int fwipPcs = 0;
    for (final e in fwipGroups.values) {
      for (final i in e) {
        fwipPcs += i.pcs ?? 0;
      }
    }
    final fwipLabelCount = fwipGroups.length;
    final materialPcs = materialAll.fold<int>(
      0,
      (s, i) => s + (i.Jumlah ?? 0).toInt(),
    );
    final totalInputLabel = fwipLabelCount + materialAll.length;
    final totalInputPcs = fwipPcs + materialPcs;

    return Container(
      decoration: productionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 1, 1, 1),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.input_rounded,
                  'Input',
                  primaryColor: _kPrimary,
                ),
                const Spacer(),
                SaveButtonWithBadge(
                  count: vm.totalTempCount,
                  isLoading: vm.isSubmitting,
                  onPressed: _handleSave,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Hapus Semua Temp',
                  onPressed: vm.totalTempCount > 0 ? _confirmClearTemp : null,
                  icon: Icon(
                    Icons.delete_sweep,
                    size: 20,
                    color: vm.totalTempCount > 0
                        ? Colors.red.shade700
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductionFolderTabBar(
                    selectedValue: _selectedInputTab,
                    accentColor: _kPrimary,
                    tabs: [
                      ProductionTabItem(
                        value: 'fwip',
                        label: 'Furniture WIP',
                        count: fwipGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'material',
                        label: 'Material Kabinet',
                        count: materialAll.length,
                      ),
                    ],
                    onChanged: (v) {
                      if (_selectedInputTab != v) {
                        setState(() => _selectedInputTab = v);
                      }
                    },
                  ),
                  Expanded(
                    child: ProductionInputCategoryBlock(
                      color: _kPrimary,
                      isLoading: loading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (ctx, c) => SizedBox(
                                width: c.maxWidth,
                                child: _selectedInputTab == 'fwip'
                                    ? _buildFwipInputTab(
                                        vm: vm,
                                        fwipGroups: fwipGroups,
                                      )
                                    : _buildMaterialTab(
                                        vm: vm,
                                        locked: locked,
                                        canDelete: canDelete,
                                        materialAll: materialAll,
                                        tempMaterialIds: tempMaterialIds,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isSelectingInput && _selectedInputTab == 'fwip')
                            _inputSelectionBar(vm, fwipGroups)
                          else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_selectedInputTab == 'fwip') ...[
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _PackingInputSummaryBar(
                                        totalLabel: fwipLabelCount,
                                        totalPcs: fwipPcs,
                                        color: _kPrimary,
                                      ),
                                      const SizedBox(height: 10),
                                      _PackingGrandTotalBar(
                                        totalItem: totalInputLabel,
                                        totalPcs: totalInputPcs,
                                        color: _kPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FloatingActionButton(
                                  heroTag: 'fab_scan_packing_input',
                                  mini: true,
                                  backgroundColor: locked
                                      ? Colors.grey.shade300
                                      : _kPrimary,
                                  foregroundColor: Colors.white,
                                  onPressed: locked || vm.isLookupLoading
                                      ? null
                                      : _openScanDialog,
                                  child: vm.isLookupLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.qr_code_scanner),
                                ),
                              ] else ...[
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _PackingMaterialSummaryBar(
                                        items: materialAll,
                                        color: _kPrimary,
                                      ),
                                      const SizedBox(height: 10),
                                      _PackingGrandTotalBar(
                                        totalItem: totalInputLabel,
                                        totalPcs: totalInputPcs,
                                        color: _kPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FloatingActionButton(
                                  heroTag: 'fab_add_material_packing',
                                  mini: true,
                                  backgroundColor: locked
                                      ? Colors.grey.shade300
                                      : _kPrimary,
                                  foregroundColor: Colors.white,
                                  onPressed: locked
                                      ? null
                                      : () => _openAddMaterialDialog(vm),
                                  child: const Icon(Icons.add),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FWIP input tab ─────────────────────────────────────────────────────────

  Widget _buildFwipInputTab({
    required PackingProductionInputViewModel vm,
    required Map<String, List<FurnitureWipItem>> fwipGroups,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: fwipGroups.isEmpty
          ? const Center(
              child: Text('Tidak ada data', style: TextStyle(fontSize: 11)),
            )
          : LayoutBuilder(
              builder: (_, c) => GridView(
                padding: const EdgeInsets.all(6),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: c.maxWidth < 380 ? 2 : 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  mainAxisExtent: 72,
                ),
                children: fwipGroups.entries.map((entry) {
                  final hasPartial = entry.value.any((x) => x.isPartialRow);
                  // Selalu tampilkan noFurnitureWIP (nomor label asli),
                  // bukan noFurnitureWIPPartial — grouping key (entry.key)
                  // tetap dipakai untuk matching/delete temp item.
                  final displaySubtitle = entry.value.isNotEmpty
                      ? ((entry.value.first.noFurnitureWIP ?? '')
                                .trim()
                                .isNotEmpty
                            ? entry.value.first.noFurnitureWIP!.trim()
                            : entry.key)
                      : entry.key;
                  return ProductionInputGroupTile(
                    title:
                        (entry.value.isNotEmpty
                            ? entry.value.first.namaJenis
                            : '-') ??
                        '-',
                    headerSubtitle: displaySubtitle,
                    tileMetrics: [
                      (
                        Icons.inventory_2_outlined,
                        '${entry.value.fold<int>(0, (s, i) => s + (i.pcs ?? 0))} pcs',
                      ),
                    ],
                    color: _kPrimary,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : () => startSelectingInput(entry.key, entry.value),
                    expandable: !hasPartial,
                    isPartialGroup: hasPartial,
                    partialReference: hasPartial
                        ? (entry.value
                                  .firstWhere((x) => x.isPartialRow)
                                  .noFurnitureWIP ??
                              '-')
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final dbItems =
                          vm
                              .inputsOf(widget.noProduksi)
                              ?.furnitureWip
                              .where((x) => _fwipTitleKey(x) == entry.key) ??
                          const [];
                      final items = [
                        ...vm.tempFurnitureWipPartial.where(
                          (x) => _fwipTitleKey(x) == entry.key,
                        ),
                        ...dbItems,
                        ...vm.tempFurnitureWip.where(
                          (x) => _fwipTitleKey(x) == entry.key,
                        ),
                      ];
                      return items.map((item) {
                        final isTemp =
                            vm.tempFurnitureWip.contains(item) ||
                            vm.tempFurnitureWipPartial.contains(item);
                        return ProductionSakChip(
                          label: item.noFurnitureWIP ?? '-',
                          berat: item.berat,
                          isTemp: isTemp,
                          isPartial: item.isPartialRow,
                          onDelete: isTemp
                              ? () => vm.deleteTempFurnitureWipItem(item)
                              : null,
                        );
                      }).toList();
                    },
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ── Material tab ───────────────────────────────────────────────────────────

  Widget _buildMaterialTab({
    required PackingProductionInputViewModel vm,
    required bool locked,
    required bool canDelete,
    required List<CabinetMaterialItem> materialAll,
    required Set<int> tempMaterialIds,
  }) {
    if (materialAll.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada material kabinet.\nTambah dengan tombol + di bawah.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: materialAll.length,
      itemBuilder: (context, index) {
        final item = materialAll[index];
        final id = item.IdCabinetMaterial ?? 0;
        final isTemp = id == 0 || tempMaterialIds.contains(id);
        return _MaterialListTile(
          item: item,
          isTemp: isTemp,
          onDeleteTemp: isTemp
              ? () {
                  vm.deleteTempCabinetMaterialItem(item);
                  _showSnack(
                    '✅ Material TEMP dihapus',
                    backgroundColor: Colors.green,
                  );
                }
              : null,
          onDeleteExisting: (!isTemp && canDelete)
              ? () => _deleteExistingMaterial(vm, item)
              : null,
        );
      },
    );
  }

  // ── Output panel ───────────────────────────────────────────────────────────

  Future<void> _openAddOutputDialog(VoidCallback onRefresh) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PackingProductionOutputFormDialog(
        noPacking: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        outputJenisId: _header?.outputJenisId,
        namaJenis: _header?.outputJenisNama,
      ),
    );
    if (result == true) {
      onRefresh();
    }
  }

  // ── Multi-select output (long-press) ──────────────────────────────────────

  String? _outputCode(Object? item) {
    if (item is! PackingOutput) return null;
    final c = item.labelCode.trim();
    return c.isEmpty ? null : c;
  }

  ProductionOutputPrintTarget? _outputPrintTarget(Object item) {
    if (item is! PackingOutput) return null;
    final code = item.labelCode.trim();
    if (code.isEmpty) return null;
    return ProductionOutputPrintTarget(
      code: code,
      pdfUrl: ApiConstants.packingLabelPdf(code),
      feature: 'packing',
      markAsPrinted: () =>
          PackingRepository(api: ApiClient()).markAsPrinted(code),
    );
  }

  Future<void> _printSelectedOutputs() async {
    final targets = selectedOutputItems
        .map(_outputPrintTarget)
        .whereType<ProductionOutputPrintTarget>()
        .toList();
    await runBatchPrintOutputs(targets);
  }

  Future<void> _deleteSelectedOutputs(VoidCallback onRefresh) async {
    final count = selectedOutputCount;
    if (count == 0) return;
    if (!await confirmDeleteOutputsDialog(context, count) || !mounted) return;
    final r = await deleteSelectedOutputs((item) async {
      if (item is PackingOutput) {
        await PackingRepository(
          api: ApiClient(),
        ).deletePacking(item.labelCode.trim());
      }
    });
    if (!mounted) return;
    onRefresh();
    if (r.failed == 0) {
      _showSnack(
        '✅ ${r.deleted} label output berhasil dihapus',
        backgroundColor: Colors.green,
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Gagal Menghapus Label',
          message: [
            if (r.deleted > 0)
              '${r.deleted} label berhasil dihapus, ${r.failed} gagal.',
            ...r.errors,
          ].join('\n\n'),
        ),
      );
    }
  }

  Widget _outputSelectionBar(
    List<PackingOutput> currentOutputs,
    VoidCallback onRefresh,
  ) {
    final total = currentOutputs.where((o) => _outputCode(o) != null).length;
    final allSelected = total > 0 && selectedOutputCount >= total;
    return ProductionOutputSelectionBar(
      accentColor: _kOutput,
      count: selectedOutputCount,
      totalAvailable: total,
      allSelected: allSelected,
      onCancel: cancelOutputSelection,
      onToggleAll: allSelected
          ? clearOutputSelection
          : () => selectAllOutputs(currentOutputs, _outputCode),
      onPrint: _isLockedOrComplete ? null : _printSelectedOutputs,
      onDelete: _isLockedOrComplete ? null : () => _deleteSelectedOutputs(onRefresh),
    );
  }

  Widget _buildOutputPanel({
    required List<PackingOutput> outputs,
    required bool isLoading,
    required String? error,
    required bool locked,
    required VoidCallback onRefresh,
  }) {
    final totalPcs = outputs.fold<int>(0, (s, o) => s + o.pcs);
    final totalJenis = outputs.map((o) => o.idJenis).toSet().length;

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kOutput.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 1, 1, 1),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.output_rounded,
                  'Output',
                  iconColor: _kOutput,
                  primaryColor: _kPrimary,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh output',
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (error != null) ...[
                          ProductionOutputErrorBanner(message: error),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ProductionFolderTabBar(
                                selectedValue: _selectedOutputTab,
                                accentColor: _kOutput,
                                tabs: [
                                  ProductionTabItem(
                                    value: 'bj',
                                    label: 'Barang Jadi',
                                    count: outputs.length,
                                  ),
                                ],
                                onChanged: (v) {
                                  if (_selectedOutputTab == v) return;
                                  setState(() => _selectedOutputTab = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ProductionInputCategoryBlock(
                            color: _kOutput,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (ctx, constraints) => SizedBox(
                                      width: constraints.maxWidth,
                                      child: ProductionOutputCategoryContent(
                                        footer: const SizedBox.shrink(),
                                        child: outputs.isEmpty
                                            ? const Center(
                                                child: SizedBox.shrink(),
                                              )
                                            : GridView(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount:
                                                          constraints.maxWidth <
                                                              380
                                                          ? 2
                                                          : 3,
                                                      crossAxisSpacing: 6,
                                                      mainAxisSpacing: 6,
                                                      mainAxisExtent: 78,
                                                    ),
                                                children: outputs
                                                    .map(
                                                      (o) => wrapOutputTile(
                                                        code: o.labelCode.trim(),
                                                        item: o,
                                                        accentColor: _kOutput,
                                                        builder: (overrideTap) =>
                                                            _PackingOutputTile(
                                                              output: o,
                                                              onTap: overrideTap,
                                                            ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (outputs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16),
                                    child: Center(
                                      child: Text(
                                        'Belum ada label output barang jadi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                if (isSelectingOutput)
                                  _outputSelectionBar(outputs, onRefresh)
                                else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _PackingOutputSummaryBar(
                                            totalLabel: outputs.length,
                                            totalPcs: totalPcs,
                                            totalJenis: totalJenis,
                                          ),
                                          const SizedBox(height: 10),
                                          _PackingOutputOverallBar(
                                            totalLabel: outputs.length,
                                            totalPcs: totalPcs,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton(
                                      heroTag: 'fab_add_packing_output',
                                      mini: true,
                                      backgroundColor: locked
                                          ? Colors.grey.shade300
                                          : _kOutput,
                                      foregroundColor: Colors.white,
                                      onPressed: locked
                                          ? null
                                          : () =>
                                                _openAddOutputDialog(onRefresh),
                                      child: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<PackingProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noProduksi);
        final err = vm.inputsError(widget.noProduksi);
        final inputs = vm.inputsOf(widget.noProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _isLockedOrComplete;
        final canDelete = perm.can('label_packing:delete') && !locked;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(this.context);
            final canPop = await _onWillPop();
            if (canPop && mounted) nav.pop();
          },
          child: Scaffold(
            backgroundColor: _kSurface,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                if (_header == null)
                  _buildToolbarSkeleton()
                else
                  ProductionWorkspaceToolbar(
                    isLocked: locked,
                    primaryColor: _kPrimary,
                    idMesin: _header?.idMesin,
                    shift: _header?.shift,
                    tglProduksi: _header?.tglProduksi,
                    hourStart: _header?.hourStart,
                    hourEnd: _header?.hourEnd,
                    namaJenis: _header?.outputJenisNama,
                    onGanti: locked ? null : _openSplitDialog,
                  onComplete: (_header == null || _isLockedOrComplete)
                      ? null
                      : _handleComplete,
                  completeDisabledReason: (_header?.isComplete == true)
                      ? 'Produksi sudah selesai'
                      : null,
                    onRefresh: () {
                      _loadHeader();
                      vm.loadInputs(widget.noProduksi, force: true);
                      vm.loadOutputs(widget.noProduksi, force: true);
                      _showSnack('Data di-refresh');
                    },
                  ),
                Expanded(
                  child: Builder(
                    builder: (_) {
                      if (err != null) {
                        return Center(
                          child: Text('Gagal memuat inputs:\n$err'),
                        );
                      }

                      final fwipAll = loading
                          ? <FurnitureWipItem>[]
                          : [
                              ...vm.tempFurnitureWip.reversed,
                              ...vm.tempFurnitureWipPartial.reversed,
                              ...?inputs?.furnitureWip,
                            ];

                      final tempMat = vm.tempCabinetMaterial;
                      final dbMat =
                          inputs?.cabinetMaterial ??
                          const <CabinetMaterialItem>[];
                      final materialAll = <CabinetMaterialItem>[
                        ...tempMat,
                        ...dbMat,
                      ];
                      final tempMaterialIds = tempMat
                          .map((x) => x.IdCabinetMaterial ?? 0)
                          .where((id) => id > 0)
                          .toSet();
                      final fwipGroups = _groupBy(fwipAll, _fwipTitleKey);

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildInputPanel(
                                vm: vm,
                                locked: locked,
                                loading: loading,
                                canDelete: canDelete,
                                fwipGroups: fwipGroups,
                                materialAll: materialAll,
                                tempMaterialIds: tempMaterialIds,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildOutputPanel(
                                outputs: vm.outputsOf(widget.noProduksi) ?? [],
                                isLoading: vm.isOutputsLoading(
                                  widget.noProduksi,
                                ),
                                error: vm.outputsError(widget.noProduksi),
                                locked: locked,
                                onRefresh: () => vm.loadOutputs(
                                  widget.noProduksi,
                                  force: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Map<K, List<T>> _groupBy<K, T>(Iterable<T> items, K Function(T) keyFn) {
  final map = <K, List<T>>{};
  for (final item in items) {
    (map[keyFn(item)] ??= []).add(item);
  }
  return map;
}

// ── Output tile ────────────────────────────────────────────────────────────────

class _PackingOutputTile extends StatelessWidget {
  final PackingOutput output;
  final VoidCallback? onTap;

  const _PackingOutputTile({required this.output, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            onTap ??
            () => showDialog<void>(
              context: context,
              builder: (_) => _PackingOutputDetailDialog(output: output),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      output.namaJenis.isNotEmpty
                          ? output.namaJenis
                          : output.labelCode,
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
                    color: output.isPrinted ? _kOutput : Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                output.labelCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              ProductionMiniMetric(
                icon: Icons.inventory_2_outlined,
                text: '${output.pcs} pcs',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackingOutputDetailDialog extends StatelessWidget {
  final PackingOutput output;

  const _PackingOutputDetailDialog({required this.output});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _kOutput,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          output.namaJenis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          output.labelCode,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.print_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          output.isPrinted ? 'Printed' : 'Belum Print',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      label: 'No Barang Jadi',
                      value: output.labelCode,
                    ),
                  ),
                  Expanded(
                    child: _InfoCell(label: 'PCS', value: '${output.pcs} pcs'),
                  ),
                  Expanded(
                    child: _InfoCell(
                      label: 'Status Print',
                      value: output.hasBeenPrinted == 0
                          ? 'Belum'
                          : output.hasBeenPrinted == 1
                          ? 'Sudah'
                          : 'Reprint (${output.hasBeenPrinted}x)',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ── Summary bars ───────────────────────────────────────────────────────────────

class _PackingInputSummaryBar extends StatelessWidget {
  const _PackingInputSummaryBar({
    required this.totalLabel,
    required this.totalPcs,
    required this.color,
  });

  final int totalLabel;
  final int totalPcs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: color,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(label: 'PCS', value: '$totalPcs', color: color),
        ],
      ),
    );
  }
}

class _PackingGrandTotalBar extends StatelessWidget {
  const _PackingGrandTotalBar({
    required this.totalItem,
    required this.totalPcs,
    required this.color,
  });

  final int totalItem;
  final int totalPcs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Icon(Icons.summarize_outlined, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Item',
                value: '$totalItem',
                color: color,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'PCS',
                value: '$totalPcs',
                color: color,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PackingMaterialSummaryBar extends StatelessWidget {
  const _PackingMaterialSummaryBar({required this.items, required this.color});

  final List<CabinetMaterialItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final totalPcs = items.fold<num>(0, (s, i) => s + (i.Jumlah ?? 0));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Material',
            value: '${items.length}',
            color: color,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(label: 'PCS', value: '$totalPcs', color: color),
        ],
      ),
    );
  }
}

class _PackingOutputSummaryBar extends StatelessWidget {
  const _PackingOutputSummaryBar({
    required this.totalLabel,
    required this.totalPcs,
    required this.totalJenis,
  });

  final int totalLabel;
  final int totalPcs;
  final int totalJenis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'BJ',
            value: '$totalLabel',
            color: _kOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'PCS',
            value: '$totalPcs',
            color: _kOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Jenis',
            value: '$totalJenis',
            color: _kOutput,
          ),
        ],
      ),
    );
  }
}

class _PackingOutputOverallBar extends StatelessWidget {
  const _PackingOutputOverallBar({
    required this.totalLabel,
    required this.totalPcs,
  });

  final int totalLabel;
  final int totalPcs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.summarize_outlined, size: 13, color: _kOutput),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: _kOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'PCS',
                value: '$totalPcs',
                color: _kOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Material list tile ─────────────────────────────────────────────────────────

class _MaterialListTile extends StatelessWidget {
  const _MaterialListTile({
    required this.item,
    required this.isTemp,
    this.onDeleteTemp,
    this.onDeleteExisting,
  });

  final CabinetMaterialItem item;
  final bool isTemp;
  final VoidCallback? onDeleteTemp;
  final VoidCallback? onDeleteExisting;

  @override
  Widget build(BuildContext context) {
    final borderColor = isTemp
        ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
        : const Color(0xFFE2E6EA);
    final bgColor = isTemp ? const Color(0xFFFFFBEB) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.category_outlined,
              size: 16,
              color: Colors.deepPurple.shade400,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.Nama ?? '-',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.Jumlah ?? 0} ${item.namaUom ?? 'unit'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (onDeleteTemp != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
              tooltip: 'Hapus temp',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDeleteTemp,
            )
          else if (onDeleteExisting != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.grey.shade400,
              ),
              tooltip: 'Hapus material',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: onDeleteExisting,
            ),
        ],
      ),
    );
  }
}
