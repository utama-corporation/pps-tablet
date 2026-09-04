import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/production/gilingan/view_model/gilingan_production_input_view_model.dart';
import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/scan_label_dialog.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/partial_mode_not_supported_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';
import '../model/gilingan_inputs_model.dart';
import '../model/gilingan_output_model.dart';
import '../model/gilingan_production_model.dart';
import '../repository/gilingan_production_input_repository.dart';
import '../repository/gilingan_production_repository.dart';
import '../widgets/gilingan_sak_picker_dialog.dart';
import '../widgets/gilingan_berat_input_dialog.dart';
import '../widgets/gilingan_output_tile.dart';
import '../widgets/gilingan_production_output_form_dialog.dart';
import '../../../gilingan_type/model/gilingan_type_model.dart';
import '../../../gilingan_type/repository/gilingan_type_repository.dart';
import '../../../gilingan_type/view_model/gilingan_type_view_model.dart';
import '../../../gilingan_type/widgets/gilingan_type_dropdown.dart';
import '../../../label/gilingan/repository/gilingan_repository.dart';
import '../../../../core/network/endpoints.dart';

import 'package:pps_tablet/features/production/shared/shared.dart';

const _kGilinganPrimary = Color(0xFF1E6FD9); // biru — input section (seragam)
const _kGilinganSurface = Color(0xFFF8F9FB);
const _kGilinganBorder = Color(0xFFE2E6EA);

class GilinganProductionInputScreen extends StatefulWidget {
  final String noProduksi;

  const GilinganProductionInputScreen({super.key, required this.noProduksi});

  @override
  State<GilinganProductionInputScreen> createState() =>
      _GilinganProductionInputScreenState();
}

class _GilinganProductionInputScreenState
    extends State<GilinganProductionInputScreen>
    with
        ProductionOutputMultiSelectMixin<GilinganProductionInputScreen>,
        ProductionInputMultiSelectMixin<GilinganProductionInputScreen> {
  final _repo = GilinganProductionInputRepository();
  final _prodRepo = GilinganProductionRepository();
  bool _isReplacing = false;

  /// Produksi sudah selesai / terkunci → tidak boleh diubah maupun dicetak.
  bool get _isLockedOrComplete =>
      _header?.isLocked == true || _header?.isComplete == true;
  @override
  bool get isOutputInteractionLocked => _isLockedOrComplete;
  @override
  bool get isInputInteractionLocked => _isLockedOrComplete;

  String _selectedMode = 'full';
  String _selectedInputTab = 'broker';

  List<BreadcrumbSegment> _prevBreadcrumb = [];

  GilinganProduction? _header;
  late String _cachedBreadcrumbLabel;

  String get _breadcrumbLabel {
    final m = (_header?.namaMesin ?? '').trim();
    return m.isNotEmpty ? '$m (${widget.noProduksi})' : widget.noProduksi;
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

      final vm = context.read<GilinganProductionInputViewModel>();
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

  @override
  void dispose() {
    if (!_isReplacing) {
      final prev = _prevBreadcrumb;
      final label = _cachedBreadcrumbLabel;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = AppShell.breadcrumb.value;
        if (current.isNotEmpty && current.last.label == label) {
          AppShell.breadcrumb.value = prev;
        }
      });
    }
    super.dispose();
  }

  // ── Back / WillPop ─────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final vm = context.read<GilinganProductionInputViewModel>();
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
    final vm = context.read<GilinganProductionInputViewModel>();

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

  // ── Clear temp ─────────────────────────────────────────────────────────────

  void _confirmClearTemp() {
    final vm = context.read<GilinganProductionInputViewModel>();
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
      builder: (_) => ScanLabelDialog(
        manualHint: 'X.XXXXXXXXXX',
        headerSubtitle: _modeLabel(_selectedMode),
        acceptedLabels: const [
          (prefix: 'D', label: 'Broker'),
          (prefix: 'M', label: 'Bonggolan'),
          (prefix: 'F', label: 'Crusher'),
          (prefix: 'BF', label: 'Reject'),
        ],
        onLookup: (code) async => _onCodeReady(code),
      ),
    );
  }

  Future<String?> _onCodeReady(String code) async {
    final vm = context.read<GilinganProductionInputViewModel>();

    if (_selectedMode == 'partial') {
      final c = code.trim().toUpperCase();
      final prefix2 = c.length >= 2 ? c.substring(0, 2) : c;
      if (prefix2 == 'M.' || prefix2 == 'F.') {
        final labelType = prefix2 == 'M.' ? 'Bonggolan' : 'Crusher';
        await PartialModeNotSupportedDialog.show(
          context: context,
          labelType: labelType,
          onOk: () {},
        );
        return '$labelType tidak mendukung mode PARTIAL';
      }
    }

    final res = await vm.lookupLabel(code, force: true);
    if (!mounted) return 'Halaman sudah tidak aktif';

    if (vm.lookupError != null) return 'Gagal ambil data: ${vm.lookupError}';

    if (res == null || res.found == false || res.data.isEmpty) {
      return 'Label "$code" tidak memiliki data yang tersedia.';
    }

    const allowedPrefixes = {
      PrefixType.broker,
      PrefixType.bonggolan,
      PrefixType.crusher,
      PrefixType.reject,
    };
    if (!allowedPrefixes.contains(res.prefixType)) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => ErrorStatusDialog(
            title: 'Label Tidak Diizinkan',
            message:
                'Label "${res.prefix}" tidak dapat digunakan di proses Gilingan.\n\n'
                'Prefix yang diperbolehkan: D (Broker), M (Bonggolan), F (Crusher), BF (Reject).',
          ),
        );
      }
      return 'Prefix ${res.prefix} tidak diperbolehkan untuk proses Gilingan';
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
    if (item is BrokerItem) return 'broker';
    if (item is BonggolanItem) return 'bonggolan';
    if (item is CrusherItem) return 'crusher';
    if (item is RejectItem) return 'reject';
    return null;
  }

  void _autoCommit(
    GilinganProductionInputViewModel vm,
    ProductionLabelLookupResult res,
    String categoryLabel,
  ) {
    if (res.data.isEmpty) return;
    final row = res.data.first;
    vm.clearPicks();
    vm.togglePick(row);
    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.added > 0
              ? '✅ $categoryLabel ditambahkan'
              : 'Gagal menambahkan atau sudah ada',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleFullMode(
    GilinganProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    if (res.prefixType == PrefixType.broker) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => GilinganSakPickerDialog(noProduksi: widget.noProduksi),
      );
    } else if (res.prefixType.isFullOnlyInput) {
      _autoCommit(vm, res, res.prefixType.displayName);
    } else {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => GilinganBeratInputDialog(noProduksi: widget.noProduksi),
      );
    }
  }

  Future<void> _handlePartialMode(
    GilinganProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    if (res.prefixType == PrefixType.broker) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => GilinganSakPickerDialog(
          noProduksi: widget.noProduksi,
          isPartialMode: true,
        ),
      );
    } else {
      // bonggolan/crusher sudah diblok di _onCodeReady; reject pakai dialog berat
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => GilinganBeratInputDialog(noProduksi: widget.noProduksi),
      );
    }
  }

  Future<void> _handleSelectMode(
    GilinganProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    if (res.prefixType == PrefixType.broker) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => GilinganSakPickerDialog(noProduksi: widget.noProduksi),
      );
    } else if (res.prefixType.isFullOnlyInput) {
      _autoCommit(vm, res, res.prefixType.displayName);
    } else {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => GilinganBeratInputDialog(noProduksi: widget.noProduksi),
      );
    }
  }

  // ── Summary helper ─────────────────────────────────────────────────────────

  SectionSummary _selectedTabSummary({
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<RejectItem>> rejectGroups,
  }) {
    Map<String, List<dynamic>> groups;
    switch (_selectedInputTab) {
      case 'broker':
        groups = brokerGroups;
        break;
      case 'bonggolan':
        groups = bonggolGroups;
        break;
      case 'crusher':
        groups = crusherGroups;
        break;
      default:
        groups = rejectGroups;
    }
    int totalSak = 0;
    double totalBerat = 0.0;
    for (final items in groups.values) {
      totalSak += items.length;
      for (final i in items) {
        if (i is BrokerItem) totalBerat += i.berat ?? 0.0;
        if (i is BonggolanItem) totalBerat += i.berat ?? 0.0;
        if (i is CrusherItem) totalBerat += i.berat ?? 0.0;
        if (i is RejectItem) totalBerat += i.berat ?? 0.0;
      }
    }
    return SectionSummary(
      totalData: groups.length,
      totalSak: totalSak,
      totalBerat: totalBerat,
    );
  }

  // ── Input panel ────────────────────────────────────────────────────────────

  // ── Multi-select input (long-press → Keluarkan) ───────────────────────────

  Future<void> _releaseSelectedInput(GilinganProductionInputViewModel vm) async {
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
    GilinganProductionInputViewModel vm,
    Map<String, List<Object>> groups,
  ) {
    final total = groups.length;
    final allSelected = total > 0 && selectedInputCount >= total;
    return ProductionInputSelectionBar(
      accentColor: _kGilinganPrimary,
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

  Map<String, List<Object>> _activeInputGroups({
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<RejectItem>> rejectGroups,
  }) {
    switch (_selectedInputTab) {
      case 'bonggolan':
        return {for (final e in bonggolGroups.entries) e.key: e.value};
      case 'crusher':
        return {for (final e in crusherGroups.entries) e.key: e.value};
      case 'reject':
        return {for (final e in rejectGroups.entries) e.key: e.value};
      default:
        return {for (final e in brokerGroups.entries) e.key: e.value};
    }
  }

  Widget _buildInputPanel({
    required GilinganProductionInputViewModel vm,
    required bool locked,
    required bool loading,
    required bool canDelete,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<RejectItem>> rejectGroups,
    required GilinganInputs? inputs,
  }) {
    int grandLabel =
        brokerGroups.length +
        bonggolGroups.length +
        crusherGroups.length +
        rejectGroups.length;
    int grandSak = 0;
    double grandBerat = 0.0;
    for (final items in brokerGroups.values) {
      grandSak += items.length;
      for (final i in items) grandBerat += i.berat ?? 0.0;
    }
    for (final items in bonggolGroups.values) {
      grandSak += items.length;
      for (final i in items) grandBerat += i.berat ?? 0.0;
    }
    for (final items in crusherGroups.values) {
      grandSak += items.length;
      for (final i in items) grandBerat += i.berat ?? 0.0;
    }
    for (final items in rejectGroups.values) {
      grandSak += items.length;
      for (final i in items) grandBerat += i.berat ?? 0.0;
    }

    final selectedSummary = _selectedTabSummary(
      brokerGroups: brokerGroups,
      bonggolGroups: bonggolGroups,
      crusherGroups: crusherGroups,
      rejectGroups: rejectGroups,
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
                  primaryColor: _kGilinganPrimary,
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
          const Divider(height: 1, color: _kGilinganBorder),

          // ── Panel body ────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductionFolderTabBar(
                    selectedValue: _selectedInputTab,
                    accentColor: _kGilinganPrimary,
                    tabs: [
                      ProductionTabItem(
                        value: 'broker',
                        label: 'Broker',
                        count: brokerGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'bonggolan',
                        label: 'Bonggolan',
                        count: bonggolGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'crusher',
                        label: 'Crusher',
                        count: crusherGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'reject',
                        label: 'Reject',
                        count: rejectGroups.length,
                      ),
                    ],
                    onChanged: (value) {
                      if (_selectedInputTab == value) return;
                      setState(() => _selectedInputTab = value);
                    },
                  ),
                  Expanded(
                    child: ProductionInputCategoryBlock(
                      color: _kGilinganPrimary,
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
                                  brokerGroups: brokerGroups,
                                  bonggolGroups: bonggolGroups,
                                  crusherGroups: crusherGroups,
                                  rejectGroups: rejectGroups,
                                  inputs: inputs,
                                  maxWidth: constraints.maxWidth,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isSelectingInput)
                            _inputSelectionBar(
                              vm,
                              _activeInputGroups(
                                brokerGroups: brokerGroups,
                                bonggolGroups: bonggolGroups,
                                crusherGroups: crusherGroups,
                                rejectGroups: rejectGroups,
                              ),
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
                                      accentColor: _kGilinganPrimary,
                                    ),
                                    const SizedBox(height: 10),
                                    ProductionInputGrandTotalBar(
                                      totalLabel: grandLabel,
                                      totalSak: grandSak,
                                      totalBerat: grandBerat,
                                      color: _kGilinganPrimary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              FloatingActionButton(
                                heroTag: 'fab_scan_gilingan',
                                mini: true,
                                backgroundColor: locked
                                    ? Colors.grey.shade300
                                    : _kGilinganPrimary,
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

  Widget _buildSelectedTabContent({
    required GilinganProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<BonggolanItem>> bonggolGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<RejectItem>> rejectGroups,
    required GilinganInputs? inputs,
    required double maxWidth,
  }) {
    final crossAxisCount = maxWidth < 380 ? 2 : 3;
    switch (_selectedInputTab) {
      case 'broker':
        return _buildBrokerTab(
          vm: vm,
          canDelete: canDelete,
          groups: brokerGroups,
          inputs: inputs,
          crossAxisCount: crossAxisCount,
        );
      case 'bonggolan':
        return _buildBonggolTab(
          vm: vm,
          canDelete: canDelete,
          groups: bonggolGroups,
          inputs: inputs,
          crossAxisCount: crossAxisCount,
        );
      case 'crusher':
        return _buildCrusherTab(
          vm: vm,
          canDelete: canDelete,
          groups: crusherGroups,
          inputs: inputs,
          crossAxisCount: crossAxisCount,
        );
      default:
        return _buildRejectTab(
          vm: vm,
          canDelete: canDelete,
          groups: rejectGroups,
          inputs: inputs,
          crossAxisCount: crossAxisCount,
        );
    }
  }

  // ── Broker tab ─────────────────────────────────────────────────────────────

  Widget _buildBrokerTab({
    required GilinganProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BrokerItem>> groups,
    required GilinganInputs? inputs,
    required int crossAxisCount,
  }) {
    final grid = groups.isEmpty
        ? const Center(
            child: Text('Tidak ada data', style: TextStyle(fontSize: 11)),
          )
        : GridView(
            padding: const EdgeInsets.all(6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: 72,
            ),
            children: groups.entries.map((entry) {
              final hasPartial = entry.value.any((x) => x.isPartialRow);
              // Selalu tampilkan noBroker (nomor label asli), bukan
              // noBrokerPartial — grouping key (entry.key) tetap pakai
              // noBrokerPartial untuk item partial supaya matching/delete
              // temp item tidak berubah.
              final displaySubtitle = entry.value.isNotEmpty
                  ? ((entry.value.first.noBroker ?? '').trim().isNotEmpty
                        ? entry.value.first.noBroker!.trim()
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
                  (Icons.inventory_2_outlined, '${entry.value.length} sak'),
                  (
                    Icons.scale_outlined,
                    '${num2(entry.value.fold<double>(0.0, (s, i) => s + (i.berat ?? 0.0)))} kg',
                  ),
                ],
                color: _kGilinganPrimary,
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
                detailsBuilder: () => [],
                chipItemsBuilder: () {
                  final dbItems = inputs == null
                      ? <BrokerItem>[]
                      : inputs.broker.where(
                          (x) => brokerTitleKey(x) == entry.key,
                        );
                  final tempFull = vm.tempBroker.where(
                    (x) => brokerTitleKey(x) == entry.key,
                  );
                  final tempPart = vm.tempBrokerPartial.where(
                    (x) => brokerTitleKey(x) == entry.key,
                  );
                  final items = [...tempPart, ...dbItems, ...tempFull];
                  return items.map((item) {
                    final isTemp =
                        vm.tempBroker.contains(item) ||
                        vm.tempBrokerPartial.contains(item);
                    return ProductionSakChip(
                      label: 'Sak ${item.noSak ?? '-'}',
                      berat: item.berat,
                      isTemp: isTemp,
                      isPartial: item.isPartialRow,
                      onDelete: isTemp
                          ? () => vm.deleteTempBrokerItem(item)
                          : null,
                    );
                  }).toList();
                },
              );
            }).toList(),
          );
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: grid,
    );
  }

  // ── Bonggolan tab ──────────────────────────────────────────────────────────

  Widget _buildBonggolTab({
    required GilinganProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BonggolanItem>> groups,
    required GilinganInputs? inputs,
    required int crossAxisCount,
  }) {
    final grid = groups.isEmpty
        ? const Center(
            child: Text('Tidak ada data', style: TextStyle(fontSize: 11)),
          )
        : GridView(
            padding: const EdgeInsets.all(6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: 72,
            ),
            children: groups.entries.map((entry) {
              return ProductionInputGroupTile(
                title: entry.key,
                headerSubtitle: 'Bonggolan',
                tileMetrics: [
                  (Icons.category_outlined, '${entry.value.length} item'),
                  (
                    Icons.scale_outlined,
                    '${num2(entry.value.fold<double>(0.0, (s, i) => s + (i.berat ?? 0.0)))} kg',
                  ),
                ],
                color: _kGilinganPrimary,
                isTemp: vm.hasTemporaryDataForLabel(entry.key),
                isSelected: isInputGroupSelected(entry.key),
                onTap: isSelectingInput
                    ? () => toggleInputGroup(entry.key, entry.value)
                    : null,
                onLongPress: isSelectingInput
                    ? null
                    : () => startSelectingInput(entry.key, entry.value),
                expandable: true,
                detailsBuilder: () => [],
                chipItemsBuilder: () {
                  final dbItems = inputs == null
                      ? <BonggolanItem>[]
                      : inputs.bonggolan.where(
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
          );
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: grid,
    );
  }

  // ── Crusher tab ────────────────────────────────────────────────────────────

  Widget _buildCrusherTab({
    required GilinganProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<CrusherItem>> groups,
    required GilinganInputs? inputs,
    required int crossAxisCount,
  }) {
    final grid = groups.isEmpty
        ? const Center(
            child: Text('Tidak ada data', style: TextStyle(fontSize: 11)),
          )
        : GridView(
            padding: const EdgeInsets.all(6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: 72,
            ),
            children: groups.entries.map((entry) {
              return ProductionInputGroupTile(
                title:
                    (entry.value.isNotEmpty
                        ? entry.value.first.namaJenis
                        : '-') ??
                    '-',
                headerSubtitle: entry.key,
                tileMetrics: [
                  (Icons.category_outlined, '${entry.value.length} item'),
                  (
                    Icons.scale_outlined,
                    '${num2(entry.value.fold<double>(0.0, (s, i) => s + (i.berat ?? 0.0)))} kg',
                  ),
                ],
                color: _kGilinganPrimary,
                isTemp: vm.hasTemporaryDataForLabel(entry.key),
                isSelected: isInputGroupSelected(entry.key),
                onTap: isSelectingInput
                    ? () => toggleInputGroup(entry.key, entry.value)
                    : null,
                onLongPress: isSelectingInput
                    ? null
                    : () => startSelectingInput(entry.key, entry.value),
                expandable: true,
                detailsBuilder: () => [],
                chipItemsBuilder: () {
                  final dbItems = inputs == null
                      ? <CrusherItem>[]
                      : inputs.crusher.where(
                          (x) => (x.noCrusher ?? '-') == entry.key,
                        );
                  final tempItems = vm.tempCrusher.where(
                    (x) => (x.noCrusher ?? '-') == entry.key,
                  );
                  final items = [...dbItems, ...tempItems];
                  return items.map((item) {
                    final isTemp = vm.tempCrusher.contains(item);
                    return ProductionSakChip(
                      label: '${num2(item.berat)} kg',
                      berat: item.berat,
                      isTemp: isTemp,
                      onDelete: isTemp
                          ? () => vm.deleteTempCrusherItem(item)
                          : null,
                    );
                  }).toList();
                },
              );
            }).toList(),
          );
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: grid,
    );
  }

  // ── Reject tab ─────────────────────────────────────────────────────────────

  Widget _buildRejectTab({
    required GilinganProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<RejectItem>> groups,
    required GilinganInputs? inputs,
    required int crossAxisCount,
  }) {
    final grid = groups.isEmpty
        ? const Center(
            child: Text('Tidak ada data', style: TextStyle(fontSize: 11)),
          )
        : GridView(
            padding: const EdgeInsets.all(6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: 72,
            ),
            children: groups.entries.map((entry) {
              final hasPartial = entry.value.any((x) => x.isPartialRow);
              // Selalu tampilkan noReject (nomor label asli), bukan
              // noRejectPartial — grouping key (entry.key) tetap dipakai
              // untuk matching/delete temp item.
              final displaySubtitle = entry.value.isNotEmpty
                  ? ((entry.value.first.noReject ?? '').trim().isNotEmpty
                        ? entry.value.first.noReject!.trim()
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
                  (Icons.inventory_2_outlined, '${entry.value.length} item'),
                  (
                    Icons.scale_outlined,
                    '${num2(entry.value.fold<double>(0.0, (s, i) => s + (i.berat ?? 0.0)))} kg',
                  ),
                ],
                color: _kGilinganPrimary,
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
                detailsBuilder: () => [],
                chipItemsBuilder: () {
                  final dbItems = inputs == null
                      ? <RejectItem>[]
                      : inputs.reject.where(
                          (x) => rejectTitleKey(x) == entry.key,
                        );
                  final tempFull = vm.tempReject.where(
                    (x) => rejectTitleKey(x) == entry.key,
                  );
                  final tempPart = vm.tempRejectPartial.where(
                    (x) => rejectTitleKey(x) == entry.key,
                  );
                  final items = [...tempPart, ...dbItems, ...tempFull];
                  return items.map((item) {
                    final isTemp =
                        vm.tempReject.contains(item) ||
                        vm.tempRejectPartial.contains(item);
                    return ProductionSakChip(
                      label: '${num2(item.berat)} kg',
                      berat: item.berat,
                      isTemp: isTemp,
                      isPartial: item.isPartialRow,
                      onDelete: isTemp
                          ? () => vm.deleteTempRejectItem(item)
                          : null,
                    );
                  }).toList();
                },
              );
            }).toList(),
          );
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: grid,
    );
  }

  // ── Split / Ganti jenis ────────────────────────────────────────────────────

  Future<void> _openSplitDialog() async {
    if (!mounted) return;
    await ProductionFlowHelpers.openSplitAndReplace<
      ({GilinganProduction prod, String namaJenis})
    >(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tglProduksi,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      showSplitDialog: (idMesin, tgl) {
        return showDialog<({GilinganProduction prod, String namaJenis})>(
          context: context,
          barrierDismissible: true,
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                GilinganTypeViewModel(repository: GilinganTypeRepository()),
            child:
                ProductionGantiProduksiDialog<
                  ({GilinganProduction prod, String namaJenis}),
                  GilinganType
                >(
                  tanggal: tgl,
                  shift: _header?.shift ?? 1,
                  primaryColor: _kGilinganPrimary,
                  borderColor: _kGilinganBorder,
                  jenisRequiredMessage: 'Pilih jenis gilingan terlebih dahulu',
                  submitLabel: 'Ganti Produksi',
                  dropdownBuilder: (selected, onChanged) =>
                      GilinganTypeDropdown(
                        preselectId: selected?.idGilingan,
                        onChanged: onChanged,
                      ),
                  jenisNameOf: (j) => j.namaGilingan,
                  onSubmit: (hourStart, jenis) async {
                    final body = await _repo.splitTime(
                      idMesin: idMesin,
                      tanggal: tgl,
                      hourStart: hourStart,
                      outputJenisId: jenis.idGilingan,
                    );
                    final data = body['data'] as Map<String, dynamic>? ?? {};
                    final header =
                        data['header'] as Map<String, dynamic>? ?? {};
                    final prod = GilinganProduction.fromJson(header);
                    return (prod: prod, namaJenis: jenis.namaGilingan);
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
        final newProd = splitResult.prod;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                GilinganProductionInputScreen(noProduksi: newProd.noProduksi),
          ),
        );
      },
    );
  }

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────

  Future<void> _handleComplete() async {
    final vm = context.read<GilinganProductionInputViewModel>();
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
            'Yakin ingin menyelesaikan produksi ${widget.noProduksi}?\n'
            'Setelah selesai, produksi akan dikunci dan tidak dapat diubah.',
        confirmLabel: 'Selesaikan',
        confirmIcon: Icons.check_circle_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _prodRepo.completeProduksi(widget.noProduksi);
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
      tanggal: _header?.tglProduksi,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      dialogBuilder: (idMesin, tgl) => buildProductionShiftTimelineDialog(
        namaMesin: _header?.outputJenisNama,
        tanggal: tgl,
        shift: _header?.shift ?? 1,
        currentNoProduksi: widget.noProduksi,
        primaryColor: _kGilinganPrimary,
        borderColor: _kGilinganBorder,
        emptyMessage: 'Belum ada riwayat produksi pada shift ini.',
        loadTimeline: () async {
          final list = await GilinganProductionRepository()
              .fetchByMesinTanggalShift(
                idMesin: idMesin,
                tanggal: tgl,
                shift: _header?.shift ?? 1,
              );
          return list
              .map(
                (e) => ProductionShiftTimelineEntry(
                  noProduksi: e.noProduksi,
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

  // ── Add output dialog ──────────────────────────────────────────────────────

  Future<void> _openAddOutputDialog(
    int? outputJenisId,
    String? namaJenis,
  ) async {
    if (outputJenisId == null) {
      _showSnack(
        'Jenis output belum dikonfigurasi pada produksi ini.',
        backgroundColor: Colors.orange,
      );
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GilinganProductionOutputFormDialog(
        noProduksi: widget.noProduksi,
        idJenis: outputJenisId,
        namaJenis: namaJenis ?? '',
        tglProduksi: _header?.tglProduksi,
        repository: _repo,
      ),
    );
    if (result == true && mounted) {
      context.read<GilinganProductionInputViewModel>().loadOutputs(
        widget.noProduksi,
        force: true,
      );
    }
  }

  // ── Output section ─────────────────────────────────────────────────────────

  static const _kGilinganOutputColor = Color(0xFF00796B);

  // ── Multi-select output (long-press) ──────────────────────────────────────

  String? _outputCode(Object? item) {
    if (item is! GilinganOutput) return null;
    final c = item.noGilingan.trim();
    return c.isEmpty ? null : c;
  }

  ProductionOutputPrintTarget? _outputPrintTarget(Object item) {
    if (item is! GilinganOutput) return null;
    final code = item.noGilingan.trim();
    if (code.isEmpty) return null;
    return ProductionOutputPrintTarget(
      code: code,
      pdfUrl: ApiConstants.gilinganLabelPdf(code),
      feature: 'gilingan',
      markAsPrinted: () => GilinganRepository().markAsPrinted(code),
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
      if (item is GilinganOutput) {
        await GilinganRepository().deleteGilingan(item.noGilingan.trim());
      }
    });
    if (!mounted) return;
    context.read<GilinganProductionInputViewModel>().loadOutputs(
      widget.noProduksi,
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

  Widget _outputSelectionBar(List<GilinganOutput> currentOutputs) {
    final total = currentOutputs.where((o) => _outputCode(o) != null).length;
    final allSelected = total > 0 && selectedOutputCount >= total;
    return ProductionOutputSelectionBar(
      accentColor: _kGilinganOutputColor,
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
    required List<GilinganOutput> outputs,
    required bool isLoading,
    required String? error,
    required int? outputJenisId,
    required String? namaJenis,
  }) {
    final totalBerat = outputs.fold<double>(0.0, (s, o) => s + o.berat);

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kGilinganOutputColor.withValues(alpha: 0.3),
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
                  iconColor: _kGilinganOutputColor,
                  primaryColor: _kGilinganPrimary,
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: _kGilinganBorder),
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
                                selectedValue: 'gilingan',
                                accentColor: _kGilinganOutputColor,
                                tabs: [
                                  ProductionTabItem(
                                    value: 'gilingan',
                                    label: 'Gilingan',
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
                            color: _kGilinganOutputColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) =>
                                        ProductionOutputCategoryContent(
                                          footer: const SizedBox.shrink(),
                                          child: outputs.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'Belum ada output gilingan',
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
                                                            constraints
                                                                    .maxWidth <
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
                                                          code: o.noGilingan
                                                              .trim(),
                                                          item: o,
                                                          accentColor:
                                                              _kGilinganOutputColor,
                                                          builder:
                                                              (overrideTap) =>
                                                                  GilinganOutputTile(
                                                                    output: o,
                                                                    onTap:
                                                                        overrideTap,
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
                                          GilinganOutputSummaryTile(
                                            totalLabel: outputs.length,
                                            totalBerat: totalBerat,
                                          ),
                                          const SizedBox(height: 10),
                                          GilinganOutputGrandTotalBar(
                                            totalLabel: outputs.length,
                                            totalBerat: totalBerat,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton(
                                      heroTag: 'fab_add_gilingan_output',
                                      mini: true,
                                      backgroundColor:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? Colors.grey.shade300
                                          : _kGilinganOutputColor,
                                      foregroundColor: Colors.white,
                                      onPressed:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? null
                                          : () => _openAddOutputDialog(
                                              outputJenisId,
                                              namaJenis,
                                            ),
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

  // ── Skeleton toolbar ───────────────────────────────────────────────────────

  Widget _buildToolbarSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(color: Colors.grey.shade300, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _skeletonBox(w: 72, h: 20, r: 20),
              const SizedBox(width: 16),
              _skeletonBox(w: 140, h: 14, r: 4),
              const SizedBox(width: 10),
              _skeletonBox(w: 100, h: 14, r: 4),
              const Spacer(),
              _skeletonBox(w: 64, h: 24, r: 6),
              const SizedBox(width: 6),
              _skeletonBox(w: 64, h: 24, r: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox({required double w, required double h, double r = 4}) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<GilinganProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noProduksi);
        final err = vm.inputsError(widget.noProduksi);
        final inputs = vm.inputsOf(widget.noProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _isLockedOrComplete;

        final canDelete = perm.can('label_washing:delete') && !locked;

        final outputs = vm.outputsOf(widget.noProduksi) ?? [];
        final outputLoading = vm.isOutputsLoading(widget.noProduksi);
        final outputErr = vm.outputsError(widget.noProduksi);

        final brokerAll = loading
            ? <BrokerItem>[]
            : [
                ...vm.tempBroker.reversed,
                ...vm.tempBrokerPartial.reversed,
                ...?inputs?.broker,
              ];
        final bonggolAll = loading
            ? <BonggolanItem>[]
            : [...vm.tempBonggolan, ...?inputs?.bonggolan];
        final crusherAll = loading
            ? <CrusherItem>[]
            : [...vm.tempCrusher, ...?inputs?.crusher];
        final rejectAll = loading
            ? <RejectItem>[]
            : [
                ...vm.tempReject.reversed,
                ...vm.tempRejectPartial.reversed,
                ...?inputs?.reject,
              ];

        final brokerGroups = groupBy(brokerAll, brokerTitleKey);
        final bonggolGroups = groupBy(
          bonggolAll,
          (BonggolanItem e) => e.noBonggolan ?? '-',
        );
        final crusherGroups = groupBy(
          crusherAll,
          (CrusherItem e) => e.noCrusher ?? '-',
        );
        final rejectGroups = groupBy(rejectAll, rejectTitleKey);

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
            backgroundColor: _kGilinganSurface,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                if (_header == null)
                  _buildToolbarSkeleton()
                else
                  ProductionWorkspaceToolbar(
                    isLocked: locked,
                    primaryColor: _kGilinganPrimary,
                    idMesin: _header?.idMesin,
                    tglProduksi: _header?.tglProduksi,
                    shift: _header?.shift,
                    namaJenis: _header?.outputJenisNama,
                    hourStart: _header?.hourStart,
                    hourEnd: _header?.hourEnd,
                    onRefresh: () {
                      vm.loadInputs(widget.noProduksi, force: true);
                      _showSnack('Data di-refresh');
                    },
                    onGanti: locked ? null : _openSplitDialog,
                    onRiwayat: _openTimelineDialog,
                    showGantiRiwayat:
                        _header?.tglProduksi != null &&
                        _header!.tglProduksi!.year == DateTime.now().year &&
                        _header!.tglProduksi!.month == DateTime.now().month &&
                        _header!.tglProduksi!.day == DateTime.now().day,
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
                                brokerGroups: brokerGroups,
                                bonggolGroups: bonggolGroups,
                                crusherGroups: crusherGroups,
                                rejectGroups: rejectGroups,
                                inputs: inputs,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildOutputSection(
                                outputs: outputs,
                                isLoading: outputLoading,
                                error: outputErr,
                                outputJenisId:
                                    _header?.outputJenisId ??
                                    (outputs.isNotEmpty
                                        ? outputs.first.idJenis
                                        : null),
                                namaJenis:
                                    _header?.outputJenisNama ??
                                    (outputs.isNotEmpty
                                        ? outputs.first.namaJenis
                                        : null),
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
