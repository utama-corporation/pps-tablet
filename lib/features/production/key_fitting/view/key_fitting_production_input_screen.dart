import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/production/key_fitting/view_model/key_fitting_production_input_view_model.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/success_status_dialog.dart';
import '../../../../common/widgets/scan_label_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../../furniture_wip_type/model/furniture_wip_type_model.dart';
import '../../../furniture_wip_type/repository/furniture_wip_type_repository.dart';
import '../../../furniture_wip_type/view_model/furniture_wip_type_view_model.dart';
import '../../../furniture_wip_type/widgets/furniture_wip_type_dropdown.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/widgets/add_cabinet_material_dialog.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';

import '../../hot_stamp/model/hot_stamp_output_model.dart';
import '../../hot_stamp/widgets/hot_stamp_output_tile.dart';
import '../model/key_fitting_inputs_model.dart';
import '../model/key_fitting_production_model.dart';
import '../widgets/key_fitting_production_output_form_dialog.dart';
import '../../hot_stamp/widgets/hot_stamp_reject_output_form_dialog.dart';
import 'package:shimmer/shimmer.dart';
import '../repository/key_fitting_production_repository.dart';
import '../../../label/furniture_wip/repository/furniture_wip_repository.dart';
import '../../../label/reject/repository/reject_repository.dart';
import '../../../../core/network/endpoints.dart';
import 'package:pps_tablet/features/production/shared/shared.dart';

const _kPrimary = Color(0xFF1E6FD9); // biru — input section (seragam)
const _kOutput = Color(0xFF00796B);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);

class KeyFittingProductionInputScreen extends StatefulWidget {
  final String noProduksi;

  const KeyFittingProductionInputScreen({
    super.key,
    required this.noProduksi,
  });

  @override
  State<KeyFittingProductionInputScreen> createState() =>
      _KeyFittingProductionInputScreenState();
}

class _KeyFittingProductionInputScreenState
    extends State<KeyFittingProductionInputScreen>
    with
        ProductionOutputMultiSelectMixin<KeyFittingProductionInputScreen>,
        ProductionInputMultiSelectMixin<KeyFittingProductionInputScreen> {
  final _prodRepo = KeyFittingProductionRepository();

  /// Produksi sudah selesai / terkunci -> tidak boleh diubah maupun dicetak.
  bool get _isLockedOrComplete =>
      _header?.isLocked == true || _header?.isComplete == true;
  @override
  bool get isOutputInteractionLocked => _isLockedOrComplete;
  @override
  bool get isInputInteractionLocked => _isLockedOrComplete;
  KeyFittingProduction? _header;
  late String _cachedBreadcrumbLabel;

  String _selectedInputTab = 'fwip';
  String _selectedOutputTab = 'fwip';

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

      final vm = context.read<KeyFittingProductionInputViewModel>();
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
        (s) => BreadcrumbSegment(
          s.label,
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

  Future<bool> _onWillPop() async {
    final vm = context.read<KeyFittingProductionInputViewModel>();
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

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────
  Future<void> _handleComplete() async {
    final vm = context.read<KeyFittingProductionInputViewModel>();
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

  /// Buka kunci produksi (IsComplete → 0) supaya bisa diubah lagi.
  Future<void> _handleUncomplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmDialog(
        title: 'Buka Kunci Produksi?',
        message:
            'Produksi ${widget.noProduksi} akan dibuka kembali dan bisa '
            'diubah lagi. Lanjutkan?',
        confirmLabel: 'Buka Kunci',
        confirmIcon: Icons.lock_open_outlined,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _prodRepo.uncompleteProduksi(widget.noProduksi);
      if (!mounted) return;
      _showSnack('✅ Produksi berhasil dibuka — bisa diubah lagi',
          backgroundColor: Colors.green);
      await _loadHeader();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Gagal Membuka Kunci',
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

  Future<void> _handleSave() async {
    final vm = context.read<KeyFittingProductionInputViewModel>();
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
    final vm = context.read<KeyFittingProductionInputViewModel>();
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
    final vm = context.read<KeyFittingProductionInputViewModel>();
    final res = await vm.lookupFwipLabel(code, force: true);
    if (!mounted) return 'Halaman sudah tidak aktif';
    if (vm.lookupError != null) return 'Gagal ambil data: ${vm.lookupError}';
    if (res == null || res.found == false || res.data.isEmpty) {
      return 'Label "$code" tidak memiliki data yang tersedia.';
    }
    await _handlePcsInputFlow(vm, res);
    return null;
  }

  Future<void> _handlePcsInputFlow(
    KeyFittingProductionInputViewModel vm,
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
          primaryColor: _kPrimary,
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
      final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

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

  Future<void> _openAddMaterialDialog(
    KeyFittingProductionInputViewModel vm,
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
    KeyFittingProductionInputViewModel vm,
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

  Future<void> _openSplitDialog() async {
    if (!mounted) return;
    final vm = context.read<KeyFittingProductionInputViewModel>();
    await ProductionFlowHelpers.openSplitAndReplace<
      ({KeyFittingProductionInputScreen prod, String namaJenis})
    >(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tglProduksi,
      onMissingContext: () =>
          _showSnack('Data mesin atau tanggal tidak tersedia'),
      showSplitDialog: (idMesin, tanggal) =>
          showDialog<
            ({KeyFittingProductionInputScreen prod, String namaJenis})
          >(
            context: context,
            barrierDismissible: false,
            builder: (_) => ChangeNotifierProvider(
              create: (_) => FurnitureWipTypeViewModel(
                repository: FurnitureWipTypeRepository(api: ApiClient()),
              ),
              child:
                  ProductionGantiProduksiDialog<
                    ({KeyFittingProductionInputScreen prod, String namaJenis}),
                    FurnitureWipType
                  >(
                    tanggal: tanggal,
                    shift: _header?.shift ?? 1,
                    primaryColor: _kPrimary,
                    borderColor: _kBorder,
                    jenisRequiredMessage:
                        'Pilih jenis Furniture WIP terlebih dahulu',
                    submitLabel: 'Ganti Produksi',
                    dropdownBuilder: (selected, onChanged) =>
                        FurnitureWipTypeDropdown(
                          preselectId: selected?.idCabinetWip,
                          onChanged: onChanged,
                        ),
                    jenisNameOf: (j) => j.nama,
                    onSubmit: (hourStart, jenis) async {
                      final body = await vm.repository.splitTime(
                        idMesin: idMesin,
                        tanggal: tanggal,
                        hourStart: hourStart,
                        outputJenisId: jenis.idCabinetWip,
                      );
                      final header =
                          body['data']['header'] as Map<String, dynamic>;
                      final newProd = KeyFittingProduction.fromJson(header);
                      return (
                        prod: KeyFittingProductionInputScreen(
                          noProduksi: newProd.noProduksi,
                        ),
                        namaJenis: newProd.outputJenisNama ?? jenis.nama,
                      );
                    },
                  ),
            ),
          ),
      beforeReplace: () {
        AppShell.breadcrumb.value = _prevBreadcrumb;
      },
      replaceToResult: (splitResult) async {
        if (!mounted) return;
        await Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => splitResult.prod));
      },
    );
  }

  Future<void> _openAddOutputDialog({required VoidCallback onSuccess}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => KeyFittingProductionOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        outputJenisId: _header?.outputJenisId,
        namaJenis: _header?.outputJenisNama,
      ),
    );
    if (saved == true && mounted) onSuccess();
  }

  Future<void> _openAddRejectOutputDialog({
    required VoidCallback onSuccess,
  }) async {
    final createdNos = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HotStampRejectOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
      ),
    );
    if (!mounted || createdNos == null || createdNos.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SuccessStatusDialog(
        title: 'Berhasil Menambah Reject',
        message: createdNos.length > 1
            ? '${createdNos.length} label reject berhasil dibuat.'
            : 'Label reject berhasil dibuat.',
        extraContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: createdNos
              .map(
                (no) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    no,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (mounted) onSuccess();
  }

  String _fwipTitleKey(FurnitureWipItem e) {
    final part = (e.noFurnitureWIPPartial ?? '').trim();
    return part.isNotEmpty ? part : (e.noFurnitureWIP ?? '-');
  }

  // ── Multi-select input (long-press → Keluarkan) ───────────────────────────

  Future<void> _releaseSelectedInput(
    KeyFittingProductionInputViewModel vm,
  ) async {
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
    KeyFittingProductionInputViewModel vm,
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
    required KeyFittingProductionInputViewModel vm,
    required bool locked,
    required bool loading,
    required bool canDelete,
    required Map<String, List<FurnitureWipItem>> fwipGroups,
    required List<CabinetMaterialItem> materialAll,
    required Set<int> tempMaterialIds,
  }) {
    int fwipPcs = 0;
    for (final e in fwipGroups.values) {
      for (final i in e) fwipPcs += i.pcs ?? 0;
    }
    final materialPcs = materialAll.fold<int>(
      0,
      (s, i) => s + (i.Jumlah ?? 0).toInt(),
    );

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
                                    ? _buildFwipTab(
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
                                      _InputSummaryBar(
                                        totalLabel: fwipGroups.length,
                                        totalPcs: fwipPcs,
                                        color: _kPrimary,
                                      ),
                                      const SizedBox(height: 10),
                                      _InputGrandTotalBar(
                                        totalItem:
                                            fwipGroups.length +
                                            materialAll.length,
                                        totalPcs: fwipPcs + materialPcs,
                                        color: _kPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FloatingActionButton(
                                  heroTag: 'fab_scan_kf_input',
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
                                      _MaterialSummaryBar(
                                        items: materialAll,
                                        color: _kPrimary,
                                      ),
                                      const SizedBox(height: 10),
                                      _InputGrandTotalBar(
                                        totalItem:
                                            fwipGroups.length +
                                            materialAll.length,
                                        totalPcs: fwipPcs + materialPcs,
                                        color: _kPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FloatingActionButton(
                                  heroTag: 'fab_add_material_kf',
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

  Widget _buildFwipTab({
    required KeyFittingProductionInputViewModel vm,
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

  Widget _buildMaterialTab({
    required KeyFittingProductionInputViewModel vm,
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

  // ── Multi-select output (long-press) ──────────────────────────────────────

  String? _outputCode(Object? item) {
    if (item is! HotStampOutput) return null;
    final c = item.labelCode.trim();
    return c.isEmpty ? null : c;
  }

  ProductionOutputPrintTarget? _outputPrintTarget(Object item) {
    if (item is! HotStampOutput) return null;
    final code = item.labelCode.trim();
    if (code.isEmpty) return null;
    if (item.isReject) {
      return ProductionOutputPrintTarget(
        code: code,
        pdfUrl: ApiConstants.rejectLabelPdf(code),
        feature: 'reject',
        markAsPrinted: () =>
            RejectRepository(api: ApiClient()).markAsPrinted(code),
      );
    }
    return ProductionOutputPrintTarget(
      code: code,
      pdfUrl: ApiConstants.furnitureWipLabelPdf(code),
      feature: 'furniture_wip',
      markAsPrinted: () => FurnitureWipRepository().markAsPrinted(code),
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
      if (item is! HotStampOutput) return;
      final code = item.labelCode.trim();
      if (item.isReject) {
        await RejectRepository(api: ApiClient()).deleteReject(code);
      } else {
        await FurnitureWipRepository().deleteFurnitureWip(code);
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
    List<HotStampOutput> currentOutputs,
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
    required List<HotStampOutput> outputs,
    required bool isLoading,
    required String? error,
    required bool locked,
    required VoidCallback onRefresh,
  }) {
    final isRejectTab = _selectedOutputTab == 'reject';
    final fwipOutputs = outputs.where((o) => !o.isReject).toList();
    final rejectOutputs = outputs.where((o) => o.isReject).toList();
    final selectedOutputs = isRejectTab ? rejectOutputs : fwipOutputs;
    final totalOutputLabel = outputs.length;
    final totalFwipPcs = fwipOutputs.fold<int>(0, (s, o) => s + o.pcs);
    final totalPcs = selectedOutputs.fold<int>(0, (s, o) => s + o.pcs);
    final totalRejectBerat = selectedOutputs.fold<double>(
      0,
      (s, o) => s + o.berat,
    );
    final grandRejectBerat = rejectOutputs.fold<double>(
      0,
      (s, o) => s + o.berat,
    );

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kOutput.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.output_rounded,
                  'Output',
                  iconColor: _kOutput,
                  primaryColor: _kPrimary,
                ),
                const Spacer(),
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
                                    value: 'fwip',
                                    label: 'Furniture WIP',
                                    count: fwipOutputs.length,
                                  ),
                                  ProductionTabItem(
                                    value: 'reject',
                                    label: 'Reject',
                                    count: rejectOutputs.length,
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
                                        child: selectedOutputs.isEmpty
                                            ? Center(
                                                child: Text(
                                                  isRejectTab
                                                      ? 'Belum ada label output reject'
                                                      : 'Belum ada label output furniture WIP',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF9CA3AF),
                                                  ),
                                                ),
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
                                                children: selectedOutputs
                                                    .map(
                                                      (o) => wrapOutputTile(
                                                        code: o.labelCode.trim(),
                                                        item: o,
                                                        accentColor: _kOutput,
                                                        builder: (overrideTap) =>
                                                            HotStampOutputTile(
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
                                const SizedBox(height: 10),
                                if (isSelectingOutput)
                                  _outputSelectionBar(selectedOutputs, onRefresh)
                                else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isRejectTab)
                                            _RejectSummaryBar(
                                              totalLabel:
                                                  selectedOutputs.length,
                                              totalBerat: totalRejectBerat,
                                            )
                                          else
                                            HotStampOutputSummaryTile(
                                              totalLabel:
                                                  selectedOutputs.length,
                                              totalPcs: totalPcs,
                                            ),
                                          const SizedBox(height: 10),
                                          HotStampOutputOverallSummaryBar(
                                            totalLabel: totalOutputLabel,
                                            totalFwipPcs: totalFwipPcs,
                                            totalRejectBerat: grandRejectBerat,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton(
                                      heroTag: isRejectTab
                                          ? 'fab_add_kf_reject'
                                          : 'fab_add_kf_output',
                                      mini: true,
                                      backgroundColor: locked
                                          ? Colors.grey.shade300
                                          : _kOutput,
                                      foregroundColor: Colors.white,
                                      onPressed: locked
                                          ? null
                                          : () {
                                              if (isRejectTab) {
                                                _openAddRejectOutputDialog(
                                                  onSuccess: onRefresh,
                                                );
                                              } else {
                                                _openAddOutputDialog(
                                                  onSuccess: onRefresh,
                                                );
                                              }
                                            },
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

  @override
  Widget build(BuildContext context) {
    return Consumer<KeyFittingProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noProduksi);
        final err = vm.inputsError(widget.noProduksi);
        final inputs = vm.inputsOf(widget.noProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _isLockedOrComplete;
        final canDelete = perm.can('label_crusher:delete') && !locked;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            // ignore: use_build_context_synchronously
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
                    idMesin: _header?.idMesin,
                    namaJenis: _header?.outputJenisNama,
                    tglProduksi: _header?.tglProduksi,
                    shift: _header?.shift,
                    hourStart: _header?.hourStart,
                    hourEnd: _header?.hourEnd,
                    primaryColor: _kPrimary,
                    onGanti: locked ? null : _openSplitDialog,
                  onComplete: (_header == null || _isLockedOrComplete)
                      ? null
                      : _handleComplete,
                  onUncomplete: (_header?.isComplete == true)
                      ? _handleUncomplete
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

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<K, List<T>> _groupBy<K, T>(Iterable<T> items, K Function(T) keyFn) {
  final map = <K, List<T>>{};
  for (final item in items) {
    (map[keyFn(item)] ??= []).add(item);
  }
  return map;
}

class _RejectSummaryBar extends StatelessWidget {
  const _RejectSummaryBar({required this.totalLabel, required this.totalBerat});
  final int totalLabel;
  final double totalBerat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: _kOutput,
          ),
        ],
      ),
    );
  }
}

class _InputSummaryBar extends StatelessWidget {
  const _InputSummaryBar({
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

class _InputGrandTotalBar extends StatelessWidget {
  const _InputGrandTotalBar({
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

class _MaterialSummaryBar extends StatelessWidget {
  const _MaterialSummaryBar({required this.items, required this.color});
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
