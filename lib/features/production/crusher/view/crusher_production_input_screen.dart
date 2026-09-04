// lib/features/production/crusher/view/crusher_production_input_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/production/crusher/view_model/crusher_production_input_view_model.dart';
import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../shared/models/broker_item.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/partial_mode_not_supported_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';
import '../../../crusher_type/model/crusher_type_model.dart';
import '../../../crusher_type/repository/crusher_type_repository.dart';
import '../../../crusher_type/view_model/crusher_type_view_model.dart';
import '../../../crusher_type/widgets/crusher_type_dropdown.dart';
import 'package:shimmer/shimmer.dart';
import '../repository/crusher_production_repository.dart';
import '../widgets/crusher_workspace_toolbar.dart';
import '../model/crusher_inputs_model.dart';
import '../model/crusher_output_model.dart';
import '../model/crusher_production_model.dart';
import '../widgets/crusher_output_tile.dart';
import '../repository/crusher_production_input_repository.dart';
import '../widgets/crusher_lookup_label_dialog.dart';
import '../widgets/crusher_lookup_label_partial_dialog.dart';
import '../widgets/crusher_production_output_form_dialog.dart';
import '../../../label/crusher/repository/crusher_repository.dart';
import '../../../../core/network/endpoints.dart';

import 'package:pps_tablet/features/production/shared/shared.dart';

const _kCrusherPrimary = Color(0xFF1E6FD9); // biru — input section (seragam)
const _kCrusherSurface = Color(0xFFF8F9FB);
const _kCrusherBorder = Color(0xFFE2E6EA);

class CrusherProductionInputScreen extends StatefulWidget {
  final String noCrusherProduksi;

  const CrusherProductionInputScreen({
    super.key,
    required this.noCrusherProduksi,
  });

  @override
  State<CrusherProductionInputScreen> createState() =>
      _CrusherProductionInputScreenState();
}

class _CrusherProductionInputScreenState
    extends State<CrusherProductionInputScreen>
    with
        ProductionOutputMultiSelectMixin<CrusherProductionInputScreen>,
        ProductionInputMultiSelectMixin<CrusherProductionInputScreen> {
  final _repo = CrusherProductionInputRepository();
  final _prodRepo = CrusherProductionRepository();
  CrusherProduction? _header;

  /// Produksi sudah selesai / terkunci → tidak boleh diubah maupun dicetak.
  bool get _isLockedOrComplete =>
      _header?.isLocked == true || _header?.isComplete == true;
  @override
  bool get isOutputInteractionLocked => _isLockedOrComplete;
  @override
  bool get isInputInteractionLocked => _isLockedOrComplete;
  late String _cachedBreadcrumbLabel;

  String _selectedMode = 'full';
  String _selectedInputTab = 'bb';

  List<ProductionFormulaOutput> _formulaOutputs = [];
  Set<String>? _allowedInputKategori;

  static const _kategoriToTab = {'bahanbaku': 'bb', 'bonggolan': 'bonggolan'};

  bool _isTabAllowed(String tab) {
    final kodes = _allowedInputKategori;
    if (kodes == null) return true;
    return kodes.any((k) => _kategoriToTab[k] == tab);
  }

  String? _firstAllowedTab(Set<String> kodes) {
    for (final tab in ['bb', 'bonggolan']) {
      if (kodes.any((k) => _kategoriToTab[k] == tab)) return tab;
    }
    return null;
  }

  List<BreadcrumbSegment> _prevBreadcrumb = [];
  bool _isReplacing = false;

  String get _breadcrumbLabel {
    if (_header != null) {
      final name = _header!.namaMesin.trim();
      return name.isNotEmpty
          ? '$name (${widget.noCrusherProduksi})'
          : widget.noCrusherProduksi;
    }
    return widget.noCrusherProduksi;
  }

  @override
  void initState() {
    super.initState();
    _cachedBreadcrumbLabel = widget.noCrusherProduksi;
    _loadHeader();
    _loadFormulaInputs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
      _updateBreadcrumb();

      final vm = context.read<CrusherProductionInputViewModel>();
      if (vm.inputsOf(widget.noCrusherProduksi) == null &&
          !vm.isInputsLoading(widget.noCrusherProduksi)) {
        vm.loadInputs(widget.noCrusherProduksi);
      }
      if (vm.outputsOf(widget.noCrusherProduksi) == null &&
          !vm.isOutputsLoading(widget.noCrusherProduksi)) {
        vm.loadOutputs(widget.noCrusherProduksi);
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
      final header = await _prodRepo.fetchOne(widget.noCrusherProduksi);
      if (!mounted) return;
      setState(() {
        _header = header;
        _cachedBreadcrumbLabel = _breadcrumbLabel;
      });
      _updateBreadcrumb();
    } catch (_) {}
  }

  Future<void> _loadFormulaInputs() async {
    try {
      final result = await _repo.fetchFormulaInputs(widget.noCrusherProduksi);
      if (!mounted) return;
      setState(() {
        _formulaOutputs = result.outputs;
        _allowedInputKategori = result.kodes;
        if (!_isTabAllowed(_selectedInputTab)) {
          final first = _firstAllowedTab(result.kodes);
          if (first != null) _selectedInputTab = first;
        }
      });
    } catch (_) {
      // Gagal fetch formula: semua tab tetap ditampilkan
    }
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

  // ── Back / WillPop ─────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final vm = context.read<CrusherProductionInputViewModel>();
    if (vm.totalTempCount == 0) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UnsavedTempWarningDialog(
        totalTempCount: vm.totalTempCount,
        submitSummary: vm.getSubmitSummary(),
        onSavePressed: () {
          Navigator.of(dialogContext).pop(false);
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

  // ── Snack ──────────────────────────────────────────────────────────────────

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

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    final vm = context.read<CrusherProductionInputViewModel>();

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
      builder: (dialogContext) => ConfirmSaveTempDialog(
        totalTempCount: vm.totalTempCount,
        submitSummary: vm.getSubmitSummary(),
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await vm.submitTempItems(widget.noCrusherProduksi);
    if (!mounted) return;

    if (success) {
      _showSnack('✅ Data berhasil disimpan', backgroundColor: Colors.green);
      vm.loadOutputs(widget.noCrusherProduksi, force: true);
    } else {
      final errMsg = vm.submitError ?? 'Kesalahan tidak diketahui';
      await showDialog(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menyimpan', message: errMsg),
      );
    }
  }

  // ── Clear temp ─────────────────────────────────────────────────────────────

  void _confirmClearTemp() {
    final vm = context.read<CrusherProductionInputViewModel>();
    if (vm.totalTempCount == 0) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Semua Temp?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${vm.totalTempCount} item temp?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              vm.clearAllTempItems();
              Navigator.of(dialogContext).pop();
              _showSnack('Semua temp items dihapus');
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Scan / lookup ──────────────────────────────────────────────────────────

  String _modeLabel(String mode) {
    switch (mode) {
      case 'full':
        return 'FULL PALLET';
      case 'select':
        return 'SEBAGIAN PALLET';
      case 'partial':
        return 'PARTIAL';
      default:
        return mode.toUpperCase();
    }
  }

  Future<void> _openScanDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProductionScanLabelDialog(
        manualHint: 'X.XXXXXXXXXX',
        headerSubtitle: _modeLabel(_selectedMode),
        primaryColor: _kCrusherPrimary,
        formulaOutputs: _formulaOutputs,
        onLookup: (code) async => _onCodeReady(code),
      ),
    );
  }

  Future<String?> _onCodeReady(String code) async {
    final vm = context.read<CrusherProductionInputViewModel>();

    // Validasi prefix sebelum ke server
    final trimmed = code.trim();
    final prefix = trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : '';
    const validPrefixes = {'A.', 'M.'};
    if (prefix.isNotEmpty && !validPrefixes.contains(prefix)) {
      return 'Label "$trimmed" tidak dapat diproses.\n'
          'Proses crusher hanya menerima label Bahan Baku (A.) dan Bonggolan (M.).';
    }

    if (_selectedMode == 'partial') {
      if (prefix == 'M.') {
        await PartialModeNotSupportedDialog.show(
          context: context,
          labelType: 'Bonggolan',
          onOk: () {},
        );
        return 'Bonggolan tidak mendukung mode PARTIAL';
      }
    }

    final res = await vm.lookupLabel(code, force: true);
    if (!mounted) return 'Halaman sudah tidak aktif';

    if (vm.lookupError != null) {
      // Hindari menampilkan pesan teknis dari server langsung ke user
      return 'Label "$trimmed" tidak dapat diproses pada produksi crusher ini.';
    }

    if (res == null || res.found == false || res.data.isEmpty) {
      return 'Label "$code" tidak memiliki data yang tersedia.';
    }

    // Validasi idJenis vs InputId formula (jika formula sudah dimuat)
    if (_allowedInputKategori != null &&
        _formulaOutputs.isNotEmpty &&
        prefix.isNotEmpty) {
      final firstRow = res.data.first;
      final rawIdJenis = firstRow['idJenis'] ?? firstRow['IdJenis'];
      if (rawIdJenis != null) {
        final idJenis = (rawIdJenis as num).toInt();
        final allowedInputIds = _formulaOutputs
            .expand((o) => o.formulas)
            .where((f) => f.prefixLabel.toUpperCase() == prefix)
            .map((f) => f.inputId)
            .toSet();
        if (allowedInputIds.isNotEmpty && !allowedInputIds.contains(idJenis)) {
          final namaJenis =
              firstRow['namaJenis'] ??
              firstRow['NamaJenis'] ??
              firstRow['Jenis'] ??
              'tidak diketahui';
          return 'Jenis "$namaJenis" tidak terdaftar dalam formula produksi crusher ini.';
        }
      }
    }

    final tab = _tabForLookupResult(res);
    if (tab != null && tab != _selectedInputTab) {
      setState(() => _selectedInputTab = tab);
    }

    if (_selectedMode == 'full') {
      await _handleFullMode(vm, res);
    } else if (_selectedMode == 'partial') {
      await _handlePartialMode(vm, res);
    } else {
      await _handleSelectMode(vm, res);
    }

    return null;
  }

  String? _tabForLookupResult(ProductionLabelLookupResult res) {
    if (res.typedItems.isEmpty) return null;
    final item = res.typedItems.first;
    if (item is BbItem) return 'bb';
    if (item is BonggolanItem) return 'bonggolan';
    return null;
  }

  Future<void> _handleFullMode(
    CrusherProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    final freshCount = vm.countNewRowsInLastLookup(widget.noCrusherProduksi);
    if (freshCount == 0) {
      final labelCode = _labelCodeOfFirst(res);
      final hasTemp =
          labelCode != null && vm.hasTemporaryDataForLabel(labelCode);
      final suffix = hasTemp
          ? ' • ${vm.getTemporaryDataSummary(labelCode!)}'
          : '';
      _showSnack(
        'Semua item untuk ${labelCode ?? "label ini"} sudah ada.$suffix',
      );
      return;
    }
    vm.clearPicks();
    vm.pickAllNew(widget.noCrusherProduksi);
    final result = vm.commitPickedToTemp(noProduksi: widget.noCrusherProduksi);
    final msg = result.added > 0
        ? '✅ Auto-added ${result.added} item${result.skipped > 0 ? ' • Duplikat terlewati ${result.skipped}' : ''}'
        : 'Tidak ada item baru ditambahkan';
    _showSnack(
      msg,
      backgroundColor: result.added > 0 ? Colors.green : Colors.orange,
    );
  }

  Future<void> _handlePartialMode(
    CrusherProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CrusherLookupLabelPartialDialog(
        noProduksi: widget.noCrusherProduksi,
        selectedMode: _selectedMode,
      ),
    );
  }

  Future<void> _handleSelectMode(
    CrusherProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    final freshCount = vm.countNewRowsInLastLookup(widget.noCrusherProduksi);
    if (freshCount == 0) {
      final labelCode = _labelCodeOfFirst(res);
      final hasTemp =
          labelCode != null && vm.hasTemporaryDataForLabel(labelCode);
      final suffix = hasTemp
          ? ' • ${vm.getTemporaryDataSummary(labelCode!)}'
          : '';
      _showSnack(
        'Semua item untuk ${labelCode ?? "label ini"} sudah ada.$suffix',
      );
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CrusherLookupLabelDialog(
        noProduksi: widget.noCrusherProduksi,
        selectedMode: _selectedMode,
      ),
    );
  }

  String? _labelCodeOfFirst(ProductionLabelLookupResult res) {
    if (res.typedItems.isEmpty) return null;
    final item = res.typedItems.first;
    if (item is BbItem) {
      final noBB = (item.noBahanBaku ?? '').trim();
      final palletStr = item.noPallet == null
          ? ''
          : item.noPallet.toString().trim();
      if (noBB.isEmpty) return null;
      return palletStr.isEmpty ? noBB : '$noBB-$palletStr';
    }
    if (item is BonggolanItem) return item.noBonggolan;
    return null;
  }

  // ── Input summary helper ───────────────────────────────────────────────────

  SectionSummary _selectedInputSummary({
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
  }) {
    if (_selectedInputTab == 'bb') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final items in bbGroups.values) {
        totalSak += items.length;
        for (final i in items) totalBerat += i.berat ?? 0.0;
      }
      return SectionSummary(
        totalData: bbGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
    } else {
      int totalCount = 0;
      double totalBerat = 0.0;
      for (final items in bonggolGroups.values) {
        totalCount += items.length;
        for (final i in items) totalBerat += i.berat ?? 0.0;
      }
      return SectionSummary(
        totalData: bonggolGroups.length,
        totalSak: totalCount,
        totalBerat: totalBerat,
      );
    }
  }

  Widget _buildSelectedTabContent({
    required CrusherProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
    required bool showFooter,
  }) {
    if (_selectedInputTab == 'bb') {
      return _buildBbTab(
        vm: vm,
        canDelete: canDelete,
        bbGroups: bbGroups,
        showFooter: showFooter,
      );
    }
    return _buildBonggolTab(
      vm: vm,
      canDelete: canDelete,
      bonggolGroups: bonggolGroups,
      showFooter: showFooter,
    );
  }

  // ── Multi-select input (long-press → Keluarkan) ───────────────────────────

  Future<void> _releaseSelectedInput(CrusherProductionInputViewModel vm) async {
    final count = selectedInputCount;
    if (count == 0) return;
    if (!await confirmReleaseInputDialog(context, count) || !mounted) return;
    final success = await vm.deleteItems(
      widget.noCrusherProduksi,
      selectedInputItems,
    );
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
    CrusherProductionInputViewModel vm,
    Map<String, List<Object>> groups,
  ) {
    final total = groups.length;
    final allSelected = total > 0 && selectedInputCount >= total;
    return ProductionInputSelectionBar(
      accentColor: _kCrusherPrimary,
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

  // ── Input panel ────────────────────────────────────────────────────────────

  Widget _buildInputPanel({
    required CrusherProductionInputViewModel vm,
    required bool locked,
    required bool loading,
    required bool canDelete,
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
  }) {
    int grandLabel = bbGroups.length + bonggolGroups.length;
    int grandSak = 0;
    double grandBerat = 0.0;
    for (final items in bbGroups.values) {
      grandSak += items.length;
      for (final i in items) grandBerat += i.berat ?? 0.0;
    }
    for (final items in bonggolGroups.values) {
      grandSak += items.length;
      for (final i in items) grandBerat += i.berat ?? 0.0;
    }

    final selectedSummary = _selectedInputSummary(
      bbGroups: bbGroups,
      bonggolGroups: bonggolGroups,
    );

    return Container(
      decoration: productionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Panel header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 1, 1, 1),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.input_rounded,
                  'Input',
                  primaryColor: _kCrusherPrimary,
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
          const Divider(height: 1, color: _kCrusherBorder),

          // ── Panel body ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductionFolderTabBar(
                    selectedValue: _selectedInputTab,
                    accentColor: _kCrusherPrimary,
                    tabs: [
                      if (_isTabAllowed('bb'))
                        ProductionTabItem(
                          value: 'bb',
                          label: 'Bahan Baku',
                          count: bbGroups.length,
                        ),
                      if (_isTabAllowed('bonggolan'))
                        ProductionTabItem(
                          value: 'bonggolan',
                          label: 'Bonggolan',
                          count: bonggolGroups.length,
                        ),
                    ],
                    onChanged: (value) {
                      if (_selectedInputTab == value) return;
                      setState(() => _selectedInputTab = value);
                    },
                  ),
                  Expanded(
                    child: ProductionInputCategoryBlock(
                      color: _kCrusherPrimary,
                      isLoading: loading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) => SizedBox(
                                width: constraints.maxWidth,
                                child: _buildSelectedTabContent(
                                  vm: vm,
                                  canDelete: canDelete,
                                  bbGroups: bbGroups,
                                  bonggolGroups: bonggolGroups,
                                  showFooter: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isSelectingInput)
                            _inputSelectionBar(
                              vm,
                              _selectedInputTab == 'bonggolan'
                                  ? bonggolGroups
                                  : bbGroups,
                            )
                          else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProductionCategorySummaryTile(
                                      summary: selectedSummary,
                                      accentColor: _kCrusherPrimary,
                                      // Bonggolan hanya pakai UOM berat, tidak ada pcs
                                      showSak: _selectedInputTab != 'bonggolan',
                                    ),
                                    const SizedBox(height: 10),
                                    ProductionInputGrandTotalBar(
                                      totalLabel: grandLabel,
                                      totalSak: grandSak,
                                      totalBerat: grandBerat,
                                      color: _kCrusherPrimary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              FloatingActionButton(
                                heroTag: 'fab_scan_crusher',
                                mini: true,
                                backgroundColor: locked
                                    ? Colors.grey.shade300
                                    : _kCrusherPrimary,
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

  // ── BB tab ─────────────────────────────────────────────────────────────────

  Widget _buildBbTab({
    required CrusherProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BbItem>> bbGroups,
    required bool showFooter,
  }) {
    int totalSak = 0;
    double totalBerat = 0.0;
    for (final entry in bbGroups.entries) {
      for (final item in entry.value) {
        totalSak++;
        totalBerat += item.berat ?? 0.0;
      }
    }

    final footer = showFooter
        ? ProductionCategorySummaryTile(
            summary: SectionSummary(
              totalData: bbGroups.length,
              totalSak: totalSak,
              totalBerat: totalBerat,
            ),
            accentColor: _kCrusherPrimary,
          )
        : const SizedBox.shrink();

    final grid = bbGroups.isEmpty
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
              children: bbGroups.entries.map((entry) {
                final hasPartial = entry.value.any((x) => x.isPartialRow);
                // Selalu tampilkan noBahanBaku[-noPallet] (nomor label asli),
                // bukan noBBPartial — grouping key (entry.key) tetap dipakai
                // untuk matching/delete temp item.
                final displaySubtitle = hasPartial
                    ? _bbPairLabel(
                        entry.value.firstWhere((x) => x.isPartialRow),
                      )
                    : entry.key;
                return ProductionInputGroupTile(
                  title:
                      (entry.value.isNotEmpty
                          ? entry.value.first.namaJenis
                          : '-') ??
                      '-',
                  headerSubtitle: displaySubtitle,
                  tileMetrics: [
                    (Icons.inventory_2_outlined, '${entry.value.length} sak'),
                    (
                      Icons.scale_outlined,
                      '${num2(entry.value.fold<double>(0.0, (s, i) => s + (i.berat ?? 0.0)))} kg',
                    ),
                  ],
                  color: _kCrusherPrimary,
                  isTemp: vm.hasTemporaryDataForLabel(entry.key),
                  expandable: !hasPartial,
                  isPartialGroup: hasPartial,
                  isSelected: isInputGroupSelected(entry.key),
                  onTap: isSelectingInput
                      ? () => toggleInputGroup(entry.key, entry.value)
                      : null,
                  onLongPress: isSelectingInput
                      ? null
                      : () => startSelectingInput(entry.key, entry.value),
                  partialReference: hasPartial
                      ? _bbPairLabel(
                          entry.value.firstWhere((x) => x.isPartialRow),
                        )
                      : null,
                  detailsBuilder: () => [],
                  chipItemsBuilder: () {
                    final currentInputs = vm.inputsOf(widget.noCrusherProduksi);
                    final dbItems = currentInputs == null
                        ? <BbItem>[]
                        : currentInputs.bb.where(
                            (x) => _bbTitleKey(x) == entry.key,
                          );
                    final tempFull = vm.tempBb.where(
                      (x) => _bbTitleKey(x) == entry.key,
                    );
                    final tempPart = vm.tempBbPartial.where(
                      (x) => _bbTitleKey(x) == entry.key,
                    );
                    final items = [...tempPart, ...dbItems, ...tempFull];
                    return items.map((item) {
                      final isTemp =
                          vm.tempBb.contains(item) ||
                          vm.tempBbPartial.contains(item);
                      return ProductionSakChip(
                        label: 'Sak ${item.noSak ?? '-'}',
                        berat: item.berat,
                        isTemp: isTemp,
                        isPartial: item.isPartialRow,
                        onDelete: isTemp
                            ? () => vm.deleteTempBbItem(item)
                            : null,
                      );
                    }).toList();
                  },
                );
              }).toList(),
            ),
          );

    return ProductionOutputCategoryContent(footer: footer, child: grid);
  }

  // ── Bonggolan tab ───────────────────────────────────────────────────────────

  Widget _buildBonggolTab({
    required CrusherProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BonggolanItem>> bonggolGroups,
    required bool showFooter,
  }) {
    int totalCount = 0;
    double totalBerat = 0.0;
    for (final entry in bonggolGroups.entries) {
      for (final item in entry.value) {
        totalCount++;
        totalBerat += item.berat ?? 0.0;
      }
    }

    final footer = showFooter
        ? ProductionCategorySummaryTile(
            summary: SectionSummary(
              totalData: bonggolGroups.length,
              totalSak: totalCount,
              totalBerat: totalBerat,
            ),
            accentColor: _kCrusherPrimary,
            // Bonggolan hanya pakai UOM berat, tidak ada pcs
            showSak: false,
          )
        : const SizedBox.shrink();

    final grid = bonggolGroups.isEmpty
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
              children: bonggolGroups.entries.map((entry) {
                final namaJenis =
                    (entry.value.isNotEmpty
                        ? entry.value.first.namaJenis
                        : null) ??
                    '-';
                return ProductionInputGroupTile(
                  title: namaJenis,
                  headerSubtitle: entry.key,
                  tileMetrics: [
                    // Bonggolan hanya pakai UOM berat, tidak ada pcs
                    (
                      Icons.scale_outlined,
                      '${num2(entry.value.fold<double>(0.0, (s, i) => s + (i.berat ?? 0.0)))} kg',
                    ),
                  ],
                  color: _kCrusherPrimary,
                  isTemp: vm.hasTemporaryDataForLabel(entry.key),
                  expandable: true,
                  isSelected: isInputGroupSelected(entry.key),
                  onTap: isSelectingInput
                      ? () => toggleInputGroup(entry.key, entry.value)
                      : null,
                  onLongPress: isSelectingInput
                      ? null
                      : () => startSelectingInput(entry.key, entry.value),
                  detailsBuilder: () => [],
                  chipItemsBuilder: () {
                    final currentInputs = vm.inputsOf(widget.noCrusherProduksi);
                    final dbItems = currentInputs == null
                        ? <BonggolanItem>[]
                        : currentInputs.bonggolan.where(
                            (x) => (x.noBonggolan ?? '-') == entry.key,
                          );
                    final tempItems = vm.tempBonggolan.where(
                      (x) => (x.noBonggolan ?? '-') == entry.key,
                    );
                    final items = [...dbItems, ...tempItems];
                    return items.map((item) {
                      final isTemp = vm.tempBonggolan.contains(item);
                      return ProductionSakChip(
                        label: '${num2(item.berat)} kg',
                        berat: item.berat,
                        isTemp: isTemp,
                        onDelete: isTemp
                            ? () => vm.deleteTempBonggolanItem(item)
                            : null,
                      );
                    }).toList();
                  },
                );
              }).toList(),
            ),
          );

    return ProductionOutputCategoryContent(footer: footer, child: grid);
  }

  // ── Add output dialog ──────────────────────────────────────────────────────

  Future<void> _openAddOutputDialog() async {
    if (_header?.outputJenisId == null) {
      _showSnack(
        'Jenis output belum dikonfigurasi pada produksi ini.',
        backgroundColor: Colors.orange,
      );
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CrusherProductionOutputFormDialog(
        noProduksi: widget.noCrusherProduksi,
        idJenis: _header!.outputJenisId!,
        namaJenis: _header?.outputJenisNama ?? '',
        tglProduksi: _header?.tanggal,
        repository: _repo,
      ),
    );
    if (result == true && mounted) {
      context.read<CrusherProductionInputViewModel>().loadOutputs(
        widget.noCrusherProduksi,
        force: true,
      );
    }
  }

  // ── Split / Ganti produksi ─────────────────────────────────────────────────

  Future<void> _openSplitDialog() async {
    if (!mounted) return;
    await ProductionFlowHelpers.openSplitAndReplace<
      ({CrusherProduction prod, String namaJenis})
    >(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tanggal,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      showSplitDialog: (idMesin, tgl) {
        return showDialog<({CrusherProduction prod, String namaJenis})>(
          context: context,
          barrierDismissible: true,
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                CrusherTypeViewModel(repository: CrusherTypeRepository()),
            child:
                ProductionGantiProduksiDialog<
                  ({CrusherProduction prod, String namaJenis}),
                  CrusherType
                >(
                  tanggal: tgl,
                  shift: _header?.shift ?? 1,
                  primaryColor: _kCrusherPrimary,
                  borderColor: _kCrusherBorder,
                  jenisRequiredMessage: 'Pilih jenis crusher terlebih dahulu',
                  submitLabel: 'Ganti Produksi',
                  dropdownBuilder: (selected, onChanged) => CrusherTypeDropdown(
                    preselectId: selected?.idCrusher,
                    onChanged: onChanged,
                  ),
                  jenisNameOf: (j) => j.namaCrusher,
                  onSubmit: (hourStart, jenis) async {
                    final body = await _repo.splitTime(
                      idMesin: idMesin,
                      tanggal: tgl,
                      hourStart: hourStart,
                      outputJenisId: jenis.idCrusher,
                    );
                    final data = body['data'] as Map<String, dynamic>? ?? {};
                    final header =
                        data['header'] as Map<String, dynamic>? ?? {};
                    final prod = CrusherProduction.fromJson(header);
                    return (prod: prod, namaJenis: jenis.namaCrusher);
                  },
                ),
          ),
        );
      },
      beforeReplace: () {
        _isReplacing = true;
        AppShell.breadcrumb.value = _prevBreadcrumb;
      },
      replaceToResult: (splitResult) async {
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CrusherProductionInputScreen(
              noCrusherProduksi: splitResult.prod.noCrusherProduksi,
            ),
          ),
        );
      },
    );
  }

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────

  Future<void> _handleComplete() async {
    final vm = context.read<CrusherProductionInputViewModel>();
    if (vm.totalTempCount > 0) {
      _showSnack(
        'Masih ada ${vm.totalTempCount} data temp yang belum disimpan. '
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
            'Yakin ingin menyelesaikan produksi ${widget.noCrusherProduksi}?\n'
            'Setelah selesai, produksi akan dikunci dan tidak dapat diubah.',
        confirmLabel: 'Selesaikan',
        confirmIcon: Icons.check_circle_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _prodRepo.completeProduksi(widget.noCrusherProduksi);
      if (!mounted) return;
      _showSnack(
        '✅ Produksi berhasil diselesaikan',
        backgroundColor: Colors.green,
      );
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

  // ── Riwayat / timeline ────────────────────────────────────────────────────

  Future<void> _openTimelineDialog() async {
    if (!mounted) return;
    await ProductionFlowHelpers.openTimeline(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tanggal,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      dialogBuilder: (idMesin, tgl) => buildProductionShiftTimelineDialog(
        namaMesin: _header?.outputJenisNama,
        tanggal: tgl,
        shift: _header?.shift ?? 1,
        currentNoProduksi: widget.noCrusherProduksi,
        primaryColor: _kCrusherPrimary,
        borderColor: _kCrusherBorder,
        emptyMessage: 'Belum ada riwayat produksi pada shift ini.',
        loadTimeline: () async {
          final list = await CrusherProductionRepository()
              .fetchByMesinTanggalShift(
                idMesin: idMesin,
                tanggal: tgl,
                shift: _header?.shift ?? 1,
              );
          return list
              .map(
                (e) => ProductionShiftTimelineEntry(
                  noProduksi: e.noCrusherProduksi,
                  hourStart: e.hourStart,
                  hourEnd: e.hourEnd,
                  isLocked: e.isLocked,
                  subtitle: e.outputJenisNama,
                ),
              )
              .toList();
        },
      ),
    );
  }

  // ── Output panel ────────────────────────────────────────────────────────────

  static const _kCrusherOutput = Color(0xFF00796B);

  // ── Multi-select output (long-press) ──────────────────────────────────────

  String? _outputCode(Object? item) {
    if (item is! CrusherOutput) return null;
    final c = item.noCrusher.trim();
    return c.isEmpty ? null : c;
  }

  ProductionOutputPrintTarget? _outputPrintTarget(Object item) {
    if (item is! CrusherOutput) return null;
    final code = item.noCrusher.trim();
    if (code.isEmpty) return null;
    return ProductionOutputPrintTarget(
      code: code,
      pdfUrl: ApiConstants.crusherLabelPdf(code),
      feature: 'crusher',
      markAsPrinted: () => CrusherRepository().markAsPrinted(code),
    );
  }

  Future<void> _printSelectedOutputs() async {
    final targets = selectedOutputItems
        .map(_outputPrintTarget)
        .whereType<ProductionOutputPrintTarget>()
        .toList();
    await runBatchPrintOutputs(targets);
  }

  Future<void> _deleteSelectedOutputs() async {
    final count = selectedOutputCount;
    if (count == 0) return;
    if (!await confirmDeleteOutputsDialog(context, count) || !mounted) return;
    final r = await deleteSelectedOutputs((item) async {
      if (item is CrusherOutput) {
        await CrusherRepository().deleteCrusher(item.noCrusher.trim());
      }
    });
    if (!mounted) return;
    context.read<CrusherProductionInputViewModel>().loadOutputs(
      widget.noCrusherProduksi,
      force: true,
    );
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

  Widget _outputSelectionBar(List<CrusherOutput> currentOutputs) {
    final total = currentOutputs.where((o) => _outputCode(o) != null).length;
    final allSelected = total > 0 && selectedOutputCount >= total;
    return ProductionOutputSelectionBar(
      accentColor: _kCrusherOutput,
      count: selectedOutputCount,
      totalAvailable: total,
      allSelected: allSelected,
      onCancel: cancelOutputSelection,
      onToggleAll: allSelected
          ? clearOutputSelection
          : () => selectAllOutputs(currentOutputs, _outputCode),
      onPrint: _isLockedOrComplete ? null : _printSelectedOutputs,
      onDelete: _isLockedOrComplete ? null : _deleteSelectedOutputs,
    );
  }

  Widget _buildOutputSection({
    required List<CrusherOutput> outputs,
    required bool isLoading,
    required String? error,
    required double grandInputBerat,
  }) {
    final totalBerat = outputs.fold<double>(0.0, (s, o) => s + o.berat);

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kCrusherOutput.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.output_rounded,
                  'Output',
                  iconColor: _kCrusherOutput,
                  primaryColor: _kCrusherPrimary,
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: _kCrusherBorder),

          // ── Body ────────────────────────────────────────────────────
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
                        // ── Tab bar ─────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: ProductionFolderTabBar(
                                selectedValue: 'crusher',
                                accentColor: _kCrusherOutput,
                                tabs: [
                                  ProductionTabItem(
                                    value: 'crusher',
                                    label: 'Crusher',
                                    count: outputs.length,
                                  ),
                                ],
                                onChanged: (_) {},
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ProductionInputCategoryBlock(
                            color: _kCrusherOutput,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Output grid
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) => SizedBox(
                                      width: constraints.maxWidth,
                                      child: ProductionOutputCategoryContent(
                                        footer: const SizedBox.shrink(),
                                        child: outputs.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'Belum ada output crusher',
                                                  style: TextStyle(
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
                                                children: outputs
                                                    .map(
                                                      (o) => wrapOutputTile(
                                                        code: o.noCrusher.trim(),
                                                        item: o,
                                                        accentColor:
                                                            _kCrusherOutput,
                                                        builder: (overrideTap) =>
                                                            CrusherOutputTile(
                                                              output: o,
                                                              onTap: overrideTap,
                                                              canPrint:
                                                                  !_isLockedOrComplete,
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
                                  _outputSelectionBar(outputs)
                                else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CrusherOutputSummaryTile(
                                            totalLabel: outputs.length,
                                            totalBerat: totalBerat,
                                          ),
                                          const SizedBox(height: 10),
                                          CrusherOutputGrandTotalBar(
                                            totalLabel: outputs.length,
                                            totalBerat: totalBerat,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton(
                                      heroTag: 'fab_add_crusher_output',
                                      mini: true,
                                      backgroundColor:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? Colors.grey.shade300
                                          : _kCrusherOutput,
                                      foregroundColor: Colors.white,
                                      onPressed:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? null
                                          : _openAddOutputDialog,
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

  // ── Title key helpers ──────────────────────────────────────────────────────

  String _bbTitleKey(BbItem item) {
    final partial = (item.noBBPartial ?? '').trim();
    if (partial.isNotEmpty) return partial;
    final nb = (item.noBahanBaku ?? '').trim();
    final np = item.noPallet;
    final hasNb = nb.isNotEmpty;
    final hasNp = np != null && np > 0;
    if (!hasNb && !hasNp) return '-';
    if (hasNb && hasNp) return '$nb-$np';
    if (hasNb) return nb;
    return 'Pallet $np';
  }

  String _bbPairLabel(BbItem item) {
    final nb = item.noBahanBaku ?? '-';
    final np = item.noPallet ?? 0;
    return np > 0 ? '$nb-$np' : nb;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<CrusherProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noCrusherProduksi);
        final err = vm.inputsError(widget.noCrusherProduksi);
        final inputs = vm.inputsOf(widget.noCrusherProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _isLockedOrComplete;

        final canDelete = perm.can('label_washing:delete') && !locked;

        final outputs = vm.outputsOf(widget.noCrusherProduksi) ?? [];
        final outputLoading = vm.isOutputsLoading(widget.noCrusherProduksi);
        final outputErr = vm.outputsError(widget.noCrusherProduksi);

        final bbAll = loading
            ? <BbItem>[]
            : [
                ...vm.tempBb.reversed,
                ...vm.tempBbPartial.reversed,
                ...?inputs?.bb,
              ];
        final bonggolAll = loading
            ? <BonggolanItem>[]
            : [...vm.tempBonggolan, ...?inputs?.bonggolan];

        final bbGroups = groupBy(bbAll, _bbTitleKey);
        final bonggolGroups = groupBy(
          bonggolAll,
          (BonggolanItem e) => e.noBonggolan ?? '-',
        );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(
              this.context,
            ); // ignore: use_build_context_synchronously
            final canPop = await _onWillPop();
            if (canPop && mounted) nav.pop();
          },
          child: Scaffold(
            backgroundColor: _kCrusherSurface,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                if (_header == null)
                  _buildToolbarSkeleton()
                else
                  CrusherWorkspaceToolbar(
                    isLocked: locked,
                    idMesin: _header?.idMesin,
                    namaJenis: _header?.outputJenisNama,
                    tglProduksi: _header?.tanggal,
                    shift: _header?.shift,
                    hourStart: _header?.hourStart,
                    hourEnd: _header?.hourEnd,
                    onRefresh: () {
                      vm.loadInputs(widget.noCrusherProduksi, force: true);
                      _showSnack('Data di-refresh');
                    },
                    onGanti: locked ? null : _openSplitDialog,
                    onRiwayat: _openTimelineDialog,
                    showGantiRiwayat:
                        _header?.tanggal != null &&
                        _header!.tanggal!.year == DateTime.now().year &&
                        _header!.tanggal!.month == DateTime.now().month &&
                        _header!.tanggal!.day == DateTime.now().day,
                    produksiStatus: _header?.produksiStatus,
                    onComplete: (_header?.isComplete == true)
                        ? null
                        : _handleComplete,
                    completeDisabledReason: (_header?.isComplete == true)
                        ? 'Produksi sudah selesai'
                        : null,
                  ),
                Expanded(
                  child: Builder(
                    builder: (_) {
                      if (err != null) {
                        return Center(
                          child: Text('Gagal memuat inputs:\n$err'),
                        );
                      }

                      double grandInputBerat = 0.0;
                      for (final i in bbAll) grandInputBerat += i.berat ?? 0.0;
                      for (final i in bonggolAll)
                        grandInputBerat += i.berat ?? 0.0;

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
                                bbGroups: bbGroups,
                                bonggolGroups: bonggolGroups,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildOutputSection(
                                outputs: outputs,
                                isLoading: outputLoading,
                                error: outputErr,
                                grandInputBerat: grandInputBerat,
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
