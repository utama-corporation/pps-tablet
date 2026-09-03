import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/production/mixer/view_model/mixer_production_input_view_model.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../common/widgets/scan_label_dialog.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/partial_mode_not_supported_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';
import '../../shared/models/bb_item.dart';
import '../../shared/models/broker_item.dart';
import '../../shared/models/washing_item.dart';
import '../../shared/models/gilingan_item.dart';
import '../../shared/models/mixer_item.dart';
import '../model/mixer_output_model.dart';
import '../repository/mixer_production_input_repository.dart';
import '../repository/mixer_production_repository.dart';
import '../model/mixer_production_model.dart';
import 'package:pps_tablet/features/mixer_type/model/mixer_type_model.dart';
import 'package:pps_tablet/features/mixer_type/repository/mixer_type_repository.dart';
import 'package:pps_tablet/features/mixer_type/view_model/mixer_type_view_model.dart';
import 'package:pps_tablet/features/mixer_type/widgets/mixer_type_dropdown.dart';
import '../widgets/mixer_input_group_popover.dart';
import '../widgets/mixer_output_tile.dart';
import '../widgets/mixer_sak_picker_dialog.dart';
import '../widgets/mixer_gilingan_weight_dialog.dart';
import '../widgets/mixer_production_output_form_dialog.dart';
import '../../../label/mixer/repository/mixer_repository.dart';
import '../../../../core/network/endpoints.dart';
import 'package:pps_tablet/features/production/shared/shared.dart';

// ── Mixer colour palette ──────────────────────────────────────────────────────
const _kMixerPrimary = Color(0xFF1565C0);
const _kMixerSurface = Color(0xFFF8F9FB);
const _kMixerBorder = Color(0xFFE2E6EA);

// ── Screen ────────────────────────────────────────────────────────────────────

class MixerProductionInputScreen extends StatefulWidget {
  final String noProduksi;

  const MixerProductionInputScreen({super.key, required this.noProduksi});

  @override
  State<MixerProductionInputScreen> createState() =>
      _MixerProductionInputScreenState();
}

class _MixerProductionInputScreenState
    extends State<MixerProductionInputScreen>
    with
        ProductionOutputMultiSelectMixin<MixerProductionInputScreen>,
        ProductionInputMultiSelectMixin<MixerProductionInputScreen> {
  final _repo = MixerProductionInputRepository();
  final _prodRepo = MixerProductionRepository();

  /// Produksi sudah selesai / terkunci → tidak boleh diubah maupun dicetak.
  bool get _isLockedOrComplete =>
      _header?.isLocked == true || _header?.isComplete == true;
  @override
  bool get isOutputInteractionLocked => _isLockedOrComplete;
  @override
  bool get isInputInteractionLocked => _isLockedOrComplete;

  String _selectedMode = 'full';
  String _selectedTab = 'bb';

  List<BreadcrumbSegment> _prevBreadcrumb = [];
  bool _isReplacing = false;

  MixerProduction? _header;
  late String _cachedBreadcrumbLabel;

  String get _breadcrumbLabel {
    final m = (_header?.namaMesin ?? '').trim();
    return m.isNotEmpty ? '$m (${widget.noProduksi})' : widget.noProduksi;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cachedBreadcrumbLabel = widget.noProduksi;
    _loadHeader();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
      _updateBreadcrumb();

      final vm = context.read<MixerProductionInputViewModel>();
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

  // ── Title key helpers ──────────────────────────────────────────────────────

  String _bbTitleKey(BbItem item) {
    final partial = (item.noBBPartial ?? '').trim();
    if (partial.isNotEmpty) return partial;
    final nb = (item.noBahanBaku ?? '').trim();
    final np = item.noPallet;
    if (nb.isEmpty && (np == null || np == 0)) return '-';
    if (nb.isNotEmpty && np != null && np > 0) return '$nb-$np';
    return nb.isNotEmpty ? nb : 'Pallet $np';
  }

  String _bbPairLabel(BbItem item) {
    final nb = item.noBahanBaku ?? '-';
    final np = item.noPallet ?? 0;
    return np > 0 ? '$nb-$np' : nb;
  }

  String _washingTitleKey(WashingItem item) => item.noWashing ?? '-';

  String _brokerTitleKey(BrokerItem item) {
    final p = (item.noBrokerPartial ?? '').trim();
    return p.isNotEmpty ? p : (item.noBroker ?? '-');
  }

  String _gilinganTitleKey(GilinganItem item) {
    final p = (item.noGilinganPartial ?? '').trim();
    return p.isNotEmpty ? p : (item.noGilingan ?? '-');
  }

  String _mixerTitleKey(MixerItem item) {
    final p = (item.noMixerPartial ?? '').trim();
    return p.isNotEmpty ? p : (item.noMixer ?? '-');
  }

  // ── Back ───────────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final vm = context.read<MixerProductionInputViewModel>();
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
    final vm = context.read<MixerProductionInputViewModel>();
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
    final vm = context.read<MixerProductionInputViewModel>();
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
          (prefix: 'A / AB', label: 'Bahan Baku'),
          (prefix: 'B', label: 'Washing'),
          (prefix: 'D', label: 'Broker'),
          (prefix: 'V', label: 'Gilingan'),
          (prefix: 'I', label: 'Mixer'),
        ],
        onLookup: _onCodeReady,
      ),
    );
  }

  Future<String?> _onCodeReady(String code) async {
    final vm = context.read<MixerProductionInputViewModel>();

    if (_selectedMode == 'partial') {
      final normalized = code.trim().toUpperCase();
      final prefix = normalized.length >= 2 ? normalized.substring(0, 2) : '';
      if (prefix == 'B.' || prefix == 'F.') {
        final labelType = prefix == 'B.' ? 'Washing' : 'Crusher';
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

    final tab = _tabForLookup(res);
    if (tab != null && tab != _selectedTab) {
      setState(() => _selectedTab = tab);
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

  String? _tabForLookup(ProductionLabelLookupResult res) {
    if (res.typedItems.isEmpty) return null;
    final item = res.typedItems.first;
    if (item is BbItem) return 'bb';
    if (item is BrokerItem) return 'broker';
    if (item is WashingItem) return 'washing';
    if (item is GilinganItem) return 'gilingan';
    if (item is MixerItem) return 'mixer';
    return null;
  }

  bool _usesChipPicker(ProductionLabelLookupResult res) {
    return res.prefixType == PrefixType.bb ||
        res.prefixType == PrefixType.washing ||
        res.prefixType == PrefixType.broker ||
        res.prefixType == PrefixType.mixer;
  }

  Future<void> _handleFullMode(
    MixerProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    if (res.prefixType == PrefixType.gilingan) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            MixerGilinganWeightDialog(noProduksi: widget.noProduksi),
      );
    } else if (_usesChipPicker(res)) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => MixerSakPickerDialog(noProduksi: widget.noProduksi),
      );
    }
  }

  Future<void> _handlePartialMode(
    MixerProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    if (res.prefixType == PrefixType.gilingan) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            MixerGilinganWeightDialog(noProduksi: widget.noProduksi),
      );
    } else if (_usesChipPicker(res)) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => MixerSakPickerDialog(
          noProduksi: widget.noProduksi,
          isPartialMode: true,
        ),
      );
    }
  }

  Future<void> _handleSelectMode(
    MixerProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    if (res.prefixType == PrefixType.gilingan) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            MixerGilinganWeightDialog(noProduksi: widget.noProduksi),
      );
    } else if (_usesChipPicker(res)) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => MixerSakPickerDialog(noProduksi: widget.noProduksi),
      );
    }
  }

  // ── Output helpers ─────────────────────────────────────────────────────────

  Future<void> _openAddOutputDialog(double grandInputBerat) async {
    if (!mounted) return;
    final vm = context.read<MixerProductionInputViewModel>();

    // Output tidak wajib menunggu input — boleh diisi kapan saja.

    if (_header?.outputJenisId == null) {
      _showSnack(
        'Jenis output belum dikonfigurasi pada produksi ini.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MixerProductionOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        idJenis: _header!.outputJenisId!,
        namaJenis: _header?.outputJenisNama ?? '',
        namaMesin: _header?.namaMesin,
        repository: _repo,
      ),
    );

    if (result != null && mounted) {
      vm.loadOutputs(widget.noProduksi, force: true);
    }
  }

  // ── Riwayat / Timeline ────────────────────────────────────────────────────

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
        namaMesin: _header?.namaMesin,
        tanggal: tgl,
        shift: _header?.shift ?? 1,
        currentNoProduksi: widget.noProduksi,
        primaryColor: _kMixerPrimary,
        borderColor: _kMixerBorder,
        emptyMessage: 'Belum ada riwayat produksi pada shift ini.',
        loadTimeline: () async {
          final list = await _prodRepo.fetchByMesinTanggalShift(
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

  // ── Split / Ganti produksi ─────────────────────────────────────────────────

  Future<void> _openSplitDialog() async {
    if (!mounted) return;
    await ProductionFlowHelpers.openSplitAndReplace<
      ({MixerProduction prod, String namaJenis})
    >(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tglProduksi,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      showSplitDialog: (idMesin, tgl) {
        return showDialog<({MixerProduction prod, String namaJenis})>(
          context: context,
          barrierDismissible: true,
          builder: (_) => ChangeNotifierProvider(
            create: (_) =>
                MixerTypeViewModel(repository: MixerTypeRepository()),
            child:
                ProductionGantiProduksiDialog<
                  ({MixerProduction prod, String namaJenis}),
                  MixerType
                >(
                  tanggal: tgl,
                  shift: _header?.shift ?? 1,
                  primaryColor: _kMixerPrimary,
                  borderColor: _kMixerBorder,
                  jenisRequiredMessage: 'Pilih jenis mixer terlebih dahulu',
                  submitLabel: 'Ganti Produksi',
                  dropdownBuilder: (selected, onChanged) => MixerTypeDropdown(
                    preselectId: selected?.idMixer,
                    onChanged: onChanged,
                  ),
                  jenisNameOf: (j) => j.jenis,
                  onSubmit: (hourStart, jenis) async {
                    final body = await _prodRepo.splitTime(
                      idMesin: idMesin,
                      tanggal: tgl,
                      hourStart: hourStart,
                      outputJenisId: jenis.idMixer,
                    );
                    final data = body['data'] as Map<String, dynamic>? ?? {};
                    final header =
                        data['header'] as Map<String, dynamic>? ?? {};
                    final prod = MixerProduction.fromJson(header);
                    return (prod: prod, namaJenis: jenis.jenis);
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
                MixerProductionInputScreen(noProduksi: newProd.noProduksi),
          ),
        );
      },
    );
  }

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────

  Future<void> _handleComplete() async {
    final vm = context.read<MixerProductionInputViewModel>();
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

  // ── Output panel ───────────────────────────────────────────────────────────

  static const _kMixerOutputColor = Color(0xFF00796B); // teal — output

  // ── Multi-select output (long-press) ──────────────────────────────────────

  String? _outputCode(Object? item) {
    if (item is! MixerOutput) return null;
    final c = item.noMixer.trim();
    return c.isEmpty || c == '-' ? null : c;
  }

  ProductionOutputPrintTarget? _outputPrintTarget(Object item) {
    if (item is! MixerOutput) return null;
    final code = item.noMixer.trim();
    if (code.isEmpty || code == '-') return null;
    return ProductionOutputPrintTarget(
      code: code,
      pdfUrl: ApiConstants.mixerLabelPdf(code),
      feature: 'mixer',
      markAsPrinted: () => MixerRepository().markAsPrinted(code),
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
      if (item is MixerOutput) {
        await MixerRepository().deleteMixer(item.noMixer.trim());
      }
    });
    if (!mounted) return;
    context.read<MixerProductionInputViewModel>().loadOutputs(
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

  Widget _outputSelectionBar(List<MixerOutput> currentOutputs) {
    final total = currentOutputs.where((o) => _outputCode(o) != null).length;
    final allSelected = total > 0 && selectedOutputCount >= total;
    return ProductionOutputSelectionBar(
      accentColor: _kMixerOutputColor,
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
    required List<MixerOutput> outputs,
    required bool isLoading,
    required String? error,
    double grandInputBerat = 0,
  }) {
    int totalSak = 0;
    double totalBerat = 0.0;
    for (final o in outputs) {
      totalSak += o.totalSak;
      totalBerat += o.totalBerat;
    }

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kMixerOutputColor.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.output_rounded,
                  'Label Output',
                  iconColor: _kMixerOutputColor,
                  primaryColor: _kMixerPrimary,
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: _kMixerBorder),

          // Body
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
                        ProductionFolderTabBar(
                          selectedValue: 'mixer_output',
                          accentColor: _kMixerOutputColor,
                          tabs: [
                            ProductionTabItem(
                              value: 'mixer_output',
                              label: 'Mixer',
                              count: outputs.length,
                            ),
                          ],
                          onChanged: (_) {},
                        ),
                        Expanded(
                          child: ProductionInputCategoryBlock(
                            color: _kMixerOutputColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (ctx, c) =>
                                        ProductionOutputCategoryContent(
                                          footer: const SizedBox.shrink(),
                                          child: outputs.isEmpty
                                              ? const Center(
                                                  child: Text(
                                                    'Belum ada output mixer',
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
                                                            c.maxWidth < 380
                                                            ? 2
                                                            : 3,
                                                        crossAxisSpacing: 6,
                                                        mainAxisSpacing: 6,
                                                        mainAxisExtent: 78,
                                                      ),
                                                  children: outputs
                                                      .map(
                                                        (o) => wrapOutputTile(
                                                          code: o.noMixer.trim(),
                                                          item: o,
                                                          accentColor:
                                                              _kMixerOutputColor,
                                                          builder:
                                                              (overrideTap) =>
                                                                  MixerOutputTile(
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
                                          MixerOutputSummaryTile(
                                            totalLabel: outputs.length,
                                            totalSak: totalSak,
                                            totalBerat: totalBerat,
                                          ),
                                          const SizedBox(height: 6),
                                          MixerOutputGrandTotalBar(
                                            totalLabel: outputs.length,
                                            totalSak: totalSak,
                                            totalBerat: totalBerat,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton(
                                      heroTag: 'fab_add_mixer_output',
                                      mini: true,
                                      backgroundColor:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? Colors.grey.shade300
                                          : _kMixerOutputColor,
                                      foregroundColor: Colors.white,
                                      onPressed:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? null
                                          : () => _openAddOutputDialog(
                                              grandInputBerat,
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

  // ── Multi-select input (long-press → Keluarkan) ───────────────────────────

  Future<void> _releaseSelectedInput(MixerProductionInputViewModel vm) async {
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
    MixerProductionInputViewModel vm,
    Map<String, List<Object>> groups,
  ) {
    final total = groups.length;
    final allSelected = total > 0 && selectedInputCount >= total;
    return ProductionInputSelectionBar(
      accentColor: _kMixerPrimary,
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
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
  }) {
    switch (_selectedTab) {
      case 'broker':
        return {for (final e in brokerGroups.entries) e.key: e.value};
      case 'washing':
        return {for (final e in washingGroups.entries) e.key: e.value};
      case 'gilingan':
        return {for (final e in gilinganGroups.entries) e.key: e.value};
      case 'mixer':
        return {for (final e in mixerGroups.entries) e.key: e.value};
      default:
        return {for (final e in bbGroups.entries) e.key: e.value};
    }
  }

  // ── Input panel ────────────────────────────────────────────────────────────

  Widget _buildInputPanel({
    required MixerProductionInputViewModel vm,
    required bool locked,
    required bool loading,
    required bool canDelete,
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
  }) {
    int grandSak = 0;
    double grandBerat = 0.0;
    for (final e in bbGroups.values) {
      for (final i in e) {
        grandSak++;
        grandBerat += i.berat ?? 0;
      }
    }
    for (final e in brokerGroups.values) {
      for (final i in e) {
        grandSak++;
        grandBerat += i.berat ?? 0;
      }
    }
    for (final e in washingGroups.values) {
      for (final i in e) {
        grandSak++;
        grandBerat += i.berat ?? 0;
      }
    }
    for (final e in gilinganGroups.values) {
      for (final i in e) {
        grandSak++;
        grandBerat += i.berat ?? 0;
      }
    }
    for (final e in mixerGroups.values) {
      for (final i in e) {
        grandSak++;
        grandBerat += i.berat ?? 0;
      }
    }
    final totalLabel =
        bbGroups.length +
        brokerGroups.length +
        washingGroups.length +
        gilinganGroups.length +
        mixerGroups.length;
    final selSummary = _selectedTabSummary(
      bbGroups: bbGroups,
      brokerGroups: brokerGroups,
      washingGroups: washingGroups,
      gilinganGroups: gilinganGroups,
      mixerGroups: mixerGroups,
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
                  'Label Input',
                  primaryColor: _kMixerPrimary,
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
          const Divider(height: 1, color: _kMixerBorder),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductionFolderTabBar(
                    selectedValue: _selectedTab,
                    accentColor: _kMixerPrimary,
                    tabs: [
                      ProductionTabItem(
                        value: 'bb',
                        label: 'Bahan Baku',
                        count: bbGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'broker',
                        label: 'Broker',
                        count: brokerGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'washing',
                        label: 'Washing',
                        count: washingGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'gilingan',
                        label: 'Gilingan',
                        count: gilinganGroups.length,
                      ),
                      ProductionTabItem(
                        value: 'mixer',
                        label: 'Mixer',
                        count: mixerGroups.length,
                      ),
                    ],
                    onChanged: (v) {
                      if (_selectedTab != v) setState(() => _selectedTab = v);
                    },
                  ),
                  Expanded(
                    child: ProductionInputCategoryBlock(
                      color: _kMixerPrimary,
                      isLoading: loading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (ctx, c) => SizedBox(
                                width: c.maxWidth,
                                child: _buildTabContent(
                                  vm: vm,
                                  canDelete: canDelete,
                                  bbGroups: bbGroups,
                                  brokerGroups: brokerGroups,
                                  washingGroups: washingGroups,
                                  gilinganGroups: gilinganGroups,
                                  mixerGroups: mixerGroups,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (isSelectingInput)
                            _inputSelectionBar(
                              vm,
                              _activeInputGroups(
                                bbGroups: bbGroups,
                                brokerGroups: brokerGroups,
                                washingGroups: washingGroups,
                                gilinganGroups: gilinganGroups,
                                mixerGroups: mixerGroups,
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
                                      summary: selSummary,
                                      accentColor: _kMixerPrimary,
                                    ),
                                    const SizedBox(height: 10),
                                    ProductionInputGrandTotalBar(
                                      totalLabel: totalLabel,
                                      totalSak: grandSak,
                                      totalBerat: grandBerat,
                                      color: _kMixerPrimary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              FloatingActionButton(
                                heroTag: 'fab_scan_mixer_input',
                                mini: true,
                                backgroundColor: locked
                                    ? Colors.grey.shade300
                                    : _kMixerPrimary,
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

  // ── Tab routing ────────────────────────────────────────────────────────────

  Widget _buildTabContent({
    required MixerProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
  }) {
    switch (_selectedTab) {
      case 'bb':
        return _buildBbTab(vm: vm, canDelete: canDelete, bbGroups: bbGroups);
      case 'broker':
        return _buildBrokerTab(
          vm: vm,
          canDelete: canDelete,
          brokerGroups: brokerGroups,
        );
      case 'washing':
        return _buildWashingTab(
          vm: vm,
          canDelete: canDelete,
          washingGroups: washingGroups,
        );
      case 'gilingan':
        return _buildGilinganTab(
          vm: vm,
          canDelete: canDelete,
          gilinganGroups: gilinganGroups,
        );
      default:
        return _buildMixerTab(
          vm: vm,
          canDelete: canDelete,
          mixerGroups: mixerGroups,
        );
    }
  }

  // ── BB Tab ─────────────────────────────────────────────────────────────────

  Widget _buildBbTab({
    required MixerProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BbItem>> bbGroups,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: bbGroups.isEmpty
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
                  // Selalu tampilkan noBahanBaku[-noPallet] (nomor label
                  // asli), bukan noBBPartial — grouping key (entry.key)
                  // tetap dipakai untuk matching/delete temp item.
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
                        '${num2(entry.value.fold<double>(0, (s, i) => s + (i.berat ?? 0)))} kg',
                      ),
                    ],
                    color: _kMixerPrimary,
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
                        ? _bbPairLabel(
                            entry.value.firstWhere((x) => x.isPartialRow),
                          )
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final dbItems =
                          vm
                              .inputsOf(widget.noProduksi)
                              ?.bb
                              .where((x) => _bbTitleKey(x) == entry.key) ??
                          const [];
                      final items = [
                        ...vm.tempBbPartial.where(
                          (x) => _bbTitleKey(x) == entry.key,
                        ),
                        ...dbItems,
                        ...vm.tempBb.where((x) => _bbTitleKey(x) == entry.key),
                      ];
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
            ),
    );
  }

  // ── Broker Tab ─────────────────────────────────────────────────────────────

  Widget _buildBrokerTab({
    required MixerProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<BrokerItem>> brokerGroups,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: brokerGroups.isEmpty
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
                children: brokerGroups.entries.map((entry) {
                  final hasPartial = entry.value.any((x) => x.isPartialRow);
                  final firstPartial = hasPartial
                      ? entry.value.firstWhere((x) => x.isPartialRow)
                      : null;
                  // Selalu tampilkan noBroker (nomor label asli), bukan
                  // noBrokerPartial — grouping key (entry.key) tetap
                  // dipakai untuk matching/delete temp item.
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
                        '${num2(entry.value.fold<double>(0, (s, i) => s + (i.berat ?? 0)))} kg',
                      ),
                    ],
                    color: _kMixerPrimary,
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
                        ? (firstPartial?.noBrokerPartial ??
                              firstPartial?.noBroker)
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final dbItems =
                          vm
                              .inputsOf(widget.noProduksi)
                              ?.broker
                              .where((x) => _brokerTitleKey(x) == entry.key) ??
                          const [];
                      final items = [
                        ...vm.tempBrokerPartial.where(
                          (x) => _brokerTitleKey(x) == entry.key,
                        ),
                        ...dbItems,
                        ...vm.tempBroker.where(
                          (x) => _brokerTitleKey(x) == entry.key,
                        ),
                      ];
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
              ),
            ),
    );
  }

  // ── Washing Tab ────────────────────────────────────────────────────────────

  Widget _buildWashingTab({
    required MixerProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<WashingItem>> washingGroups,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: washingGroups.isEmpty
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
                children: washingGroups.entries.map((entry) {
                  return ProductionInputGroupTile(
                    title:
                        (entry.value.isNotEmpty
                            ? entry.value.first.namaJenis
                            : '-') ??
                        '-',
                    headerSubtitle: entry.key,
                    tileMetrics: [
                      (Icons.inventory_2_outlined, '${entry.value.length} sak'),
                      (
                        Icons.scale_outlined,
                        '${num2(entry.value.fold<double>(0, (s, i) => s + (i.berat ?? 0)))} kg',
                      ),
                    ],
                    color: _kMixerPrimary,
                    isTemp: vm.tempWashing.any(
                      (x) => _washingTitleKey(x) == entry.key,
                    ),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : () => startSelectingInput(entry.key, entry.value),
                    chipItemsBuilder: () {
                      final dbItems =
                          vm
                              .inputsOf(widget.noProduksi)
                              ?.washing
                              .where((x) => _washingTitleKey(x) == entry.key) ??
                          const [];
                      final items = [
                        ...dbItems,
                        ...vm.tempWashing.where(
                          (x) => _washingTitleKey(x) == entry.key,
                        ),
                      ];
                      return items.map((item) {
                        final isTemp = vm.tempWashing.contains(item);
                        return ProductionSakChip(
                          label: 'Sak ${item.noSak ?? '-'}',
                          berat: item.berat,
                          isTemp: isTemp,
                          onDelete: isTemp
                              ? () => vm.deleteTempWashingItem(item)
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

  // ── Gilingan Tab ───────────────────────────────────────────────────────────

  Widget _buildGilinganTab({
    required MixerProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<GilinganItem>> gilinganGroups,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: gilinganGroups.isEmpty
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
                children: gilinganGroups.entries.map((entry) {
                  final hasPartial = entry.value.any((x) => x.isPartialRow);
                  // Selalu tampilkan noGilingan (nomor label asli), bukan
                  // noGilinganPartial — grouping key (entry.key) tetap
                  // dipakai untuk matching/delete temp item.
                  final displaySubtitle = entry.value.isNotEmpty
                      ? ((entry.value.first.noGilingan ?? '').trim().isNotEmpty
                            ? entry.value.first.noGilingan!.trim()
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
                        Icons.scale_outlined,
                        '${num2(entry.value.fold<double>(0, (s, i) => s + (i.berat ?? 0)))} kg',
                      ),
                    ],
                    color: _kMixerPrimary,
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
                                  .noGilingan ??
                              '-')
                        : null,
                    detailsBuilder: () {
                      final dbItems =
                          vm
                              .inputsOf(widget.noProduksi)
                              ?.gilingan
                              .where(
                                (x) => _gilinganTitleKey(x) == entry.key,
                              ) ??
                          const [];
                      final items = [
                        ...vm.tempGilinganPartial.where(
                          (x) => _gilinganTitleKey(x) == entry.key,
                        ),
                        ...dbItems,
                        ...vm.tempGilingan.where(
                          (x) => _gilinganTitleKey(x) == entry.key,
                        ),
                      ];
                      return items.map((item) {
                        final isTemp =
                            vm.tempGilingan.contains(item) ||
                            vm.tempGilinganPartial.contains(item);
                        final columns = item.isPartialRow
                            ? <String>[
                                item.noGilingan ?? '-',
                                '${num2(item.berat)} kg',
                              ]
                            : <String>['${num2(item.berat)} kg'];
                        return TooltipTableRow(
                          columns: columns,
                          showDelete: isTemp,
                          onDelete: () {
                            if (isTemp) vm.deleteTempGilinganItem(item);
                          },
                          isTempRow: isTemp,
                          isHighlighted: isTemp,
                          isDisabled: !isTemp && !canDelete,
                          itemData: item,
                        );
                      }).toList();
                    },
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ── Mixer Tab ──────────────────────────────────────────────────────────────

  Widget _buildMixerTab({
    required MixerProductionInputViewModel vm,
    required bool canDelete,
    required Map<String, List<MixerItem>> mixerGroups,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: mixerGroups.isEmpty
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
                children: mixerGroups.entries.map((entry) {
                  final hasPartial = entry.value.any((x) => x.isPartialRow);
                  final firstPartial = hasPartial
                      ? entry.value.firstWhere((x) => x.isPartialRow)
                      : null;
                  // Selalu tampilkan noMixer (nomor label asli), bukan
                  // noMixerPartial — grouping key (entry.key) tetap dipakai
                  // untuk matching/delete temp item.
                  final displaySubtitle = entry.value.isNotEmpty
                      ? ((entry.value.first.noMixer ?? '').trim().isNotEmpty
                            ? entry.value.first.noMixer!.trim()
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
                        '${num2(entry.value.fold<double>(0, (s, i) => s + (i.berat ?? 0)))} kg',
                      ),
                    ],
                    color: _kMixerPrimary,
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
                        ? (firstPartial?.noMixerPartial ??
                              firstPartial?.noMixer ??
                              '-')
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final dbItems =
                          vm
                              .inputsOf(widget.noProduksi)
                              ?.mixer
                              .where((x) => _mixerTitleKey(x) == entry.key) ??
                          const [];
                      final items = [
                        ...vm.tempMixerPartial.where(
                          (x) => _mixerTitleKey(x) == entry.key,
                        ),
                        ...dbItems,
                        ...vm.tempMixer.where(
                          (x) => _mixerTitleKey(x) == entry.key,
                        ),
                      ];
                      return items.map((item) {
                        final isTemp =
                            vm.tempMixer.contains(item) ||
                            vm.tempMixerPartial.contains(item);
                        return ProductionSakChip(
                          label: 'Sak ${item.noSak ?? '-'}',
                          berat: item.berat,
                          isTemp: isTemp,
                          isPartial: item.isPartialRow,
                          onDelete: isTemp
                              ? () => vm.deleteTempMixerItem(item)
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

  // ── Summary helper ─────────────────────────────────────────────────────────

  SectionSummary _selectedTabSummary({
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
  }) {
    int sak = 0;
    double berat = 0.0;
    switch (_selectedTab) {
      case 'bb':
        for (final e in bbGroups.values) {
          for (final i in e) {
            sak++;
            berat += i.berat ?? 0;
          }
        }
        return SectionSummary(
          totalData: bbGroups.length,
          totalSak: sak,
          totalBerat: berat,
        );
      case 'broker':
        for (final e in brokerGroups.values) {
          for (final i in e) {
            sak++;
            berat += i.berat ?? 0;
          }
        }
        return SectionSummary(
          totalData: brokerGroups.length,
          totalSak: sak,
          totalBerat: berat,
        );
      case 'washing':
        for (final e in washingGroups.values) {
          for (final i in e) {
            sak++;
            berat += i.berat ?? 0;
          }
        }
        return SectionSummary(
          totalData: washingGroups.length,
          totalSak: sak,
          totalBerat: berat,
        );
      case 'gilingan':
        for (final e in gilinganGroups.values) {
          for (final i in e) {
            berat += i.berat ?? 0;
          }
        }
        return SectionSummary(
          totalData: gilinganGroups.length,
          totalSak: 0,
          totalBerat: berat,
        );
      default:
        for (final e in mixerGroups.values) {
          for (final i in e) {
            sak++;
            berat += i.berat ?? 0;
          }
        }
        return SectionSummary(
          totalData: mixerGroups.length,
          totalSak: sak,
          totalBerat: berat,
        );
    }
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

  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<MixerProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noProduksi);
        final err = vm.inputsError(widget.noProduksi);
        final inputs = vm.inputsOf(widget.noProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _isLockedOrComplete;
        final canDelete = perm.can('label_washing:delete') && !locked;

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
            backgroundColor: _kMixerSurface,
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
                    primaryColor: _kMixerPrimary,
                    onGanti: locked ? null : _openSplitDialog,
                    onRiwayat: _openTimelineDialog,
                    onRefresh: () {
                      vm.loadInputs(widget.noProduksi, force: true);
                      vm.loadOutputs(widget.noProduksi, force: true);
                      _showSnack('Data di-refresh');
                    },
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

                      final bbAll = loading
                          ? <BbItem>[]
                          : [
                              ...vm.tempBb.reversed,
                              ...vm.tempBbPartial.reversed,
                              ...?inputs?.bb,
                            ];
                      final brokerAll = loading
                          ? <BrokerItem>[]
                          : [
                              ...vm.tempBroker.reversed,
                              ...vm.tempBrokerPartial.reversed,
                              ...?inputs?.broker,
                            ];
                      final washingAll = loading
                          ? <WashingItem>[]
                          : [...vm.tempWashing.reversed, ...?inputs?.washing];
                      final gilinganAll = loading
                          ? <GilinganItem>[]
                          : [
                              ...vm.tempGilingan.reversed,
                              ...vm.tempGilinganPartial.reversed,
                              ...?inputs?.gilingan,
                            ];
                      final mixerAll = loading
                          ? <MixerItem>[]
                          : [
                              ...vm.tempMixer.reversed,
                              ...vm.tempMixerPartial.reversed,
                              ...?inputs?.mixer,
                            ];

                      final bbGroups = groupBy(bbAll, _bbTitleKey);
                      final brokerGroups = groupBy(brokerAll, _brokerTitleKey);
                      final washingGroups = groupBy(
                        washingAll,
                        _washingTitleKey,
                      );
                      final gilinganGroups = groupBy(
                        gilinganAll,
                        _gilinganTitleKey,
                      );
                      final mixerGroups = groupBy(mixerAll, _mixerTitleKey);

                      final outputs = vm.outputsOf(widget.noProduksi) ?? [];
                      final outputLoading = vm.isOutputsLoading(
                        widget.noProduksi,
                      );
                      final outputErr = vm.outputsError(widget.noProduksi);

                      double grandInputBerat = 0.0;
                      for (final i in bbAll) {
                        grandInputBerat += i.berat ?? 0.0;
                      }
                      for (final i in brokerAll) {
                        grandInputBerat += i.berat ?? 0.0;
                      }
                      for (final i in washingAll) {
                        grandInputBerat += i.berat ?? 0.0;
                      }
                      for (final i in gilinganAll) {
                        grandInputBerat += i.berat ?? 0.0;
                      }
                      for (final i in mixerAll) {
                        grandInputBerat += i.berat ?? 0.0;
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
                                bbGroups: bbGroups,
                                brokerGroups: brokerGroups,
                                washingGroups: washingGroups,
                                gilinganGroups: gilinganGroups,
                                mixerGroups: mixerGroups,
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
