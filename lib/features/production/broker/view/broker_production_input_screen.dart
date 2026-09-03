// lib/features/production/broker/view/washing_production_input_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/production/broker/view_model/broker_production_input_view_model.dart';
import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../repository/broker_production_input_repository.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';
import '../model/broker_production_model.dart';
import '../repository/broker_production_repository.dart';
import '../widgets/broker_input_group_popover.dart';
import '../../shared/widgets/partial_mode_not_supported_dialog.dart';
import '../../shared/widgets/weight_input_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../model/broker_inputs_model.dart';

import 'package:pps_tablet/features/production/shared/shared.dart';
import '../widgets/broker_lookup_label_dialog.dart';
import '../widgets/broker_lookup_label_partial_dialog.dart';
import '../../../label/broker/widgets/broker_form_dialog.dart';
import '../../../label/broker/widgets/broker_production_output_form_dialog.dart';
import '../../../label/bonggolan/widgets/bonggolan_production_output_form_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../label/broker/repository/broker_repository.dart';
import '../../../label/bonggolan/repository/bonggolan_repository.dart';
import '../../../broker_type/model/broker_type_model.dart';
import '../../../broker_type/widgets/broker_type_dropdown.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/broker_workspace_toolbar.dart';

const _kBrokerPrimary = Color(0xFF1E6FD9);
const _kBrokerSurface = Color(0xFFF8F9FB);
const _kBrokerBorder = Color(0xFFE2E6EA);
const _kBrokerRadius = 12.0;
const _kBrokerOutput = Color(0xFF0A7349);

class BrokerProductionInputScreen extends StatefulWidget {
  final String noProduksi;

  const BrokerProductionInputScreen({super.key, required this.noProduksi});

  @override
  State<BrokerProductionInputScreen> createState() =>
      _BrokerProductionInputScreenState();
}

class _BrokerProductionInputScreenState extends State<BrokerProductionInputScreen>
    with
        ProductionOutputMultiSelectMixin<BrokerProductionInputScreen>,
        ProductionInputMultiSelectMixin<BrokerProductionInputScreen> {
  final _prodRepo = BrokerProductionRepository();
  final _inputRepo = BrokerProductionInputRepository();

  /// Produksi sudah selesai / terkunci → tidak boleh diubah maupun dicetak.
  bool get _isLockedOrComplete =>
      _header?.isLocked == true || _header?.isComplete == true;
  @override
  bool get isOutputInteractionLocked => _isLockedOrComplete;
  @override
  bool get isInputInteractionLocked => _isLockedOrComplete;

  BrokerProduction? _header;
  late String _cachedBreadcrumbLabel;

  String _selectedMode = 'full';
  String _selectedInputTab = 'broker';
  String _selectedOutputTab = 'broker';

  List<ProductionFormulaOutput> _formulaOutputs = [];
  Set<String>? _allowedInputKategori; // null = belum dimuat, tampilkan semua

  // Mapping InputKategoriKode (dari API) ke nilai tab di layar
  static const _kategoriToTab = {
    'bahanbaku': 'bb',
    'washing': 'washing',
    'broker': 'broker',
    'crusher': 'crusher',
    'gilingan': 'gilingan',
    'mixer': 'mixer',
    'reject': 'reject',
  };

  bool _isTabAllowed(String tab) {
    final kodes = _allowedInputKategori;
    if (kodes == null) return true;
    return kodes.any((k) => _kategoriToTab[k] == tab);
  }

  String? _firstAllowedTab(Set<String> kodes) {
    for (final tab in [
      'broker',
      'bb',
      'washing',
      'crusher',
      'gilingan',
      'mixer',
      'reject',
    ]) {
      if (kodes.any((k) => _kategoriToTab[k] == tab)) return tab;
    }
    return null;
  }

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
    _loadFormulaInputs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
      _updateBreadcrumb();
      context.read<BrokerProductionInputViewModel>().loadInputs(
        widget.noProduksi,
        force: true,
      );
      context.read<BrokerProductionInputViewModel>().loadOutputs(
        widget.noProduksi,
      );
    });
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

  Future<void> _loadFormulaInputs() async {
    try {
      final result = await _inputRepo.fetchFormulaInputs(widget.noProduksi);
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

  Widget _buildToolbarSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(height: 56, color: Colors.white),
    );
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

  @override
  void dispose() {
    // Guard: hanya restore jika breadcrumb terakhir masih milik screen ini.
    // Jika sidebar sudah ganti breadcrumb (via pushNamedAndRemoveUntil),
    // jangan overwrite � itu yang menyebabkan breadcrumb kacau saat pindah menu.
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

  // ? TAMBAHKAN: Method untuk handle back button
  Future<bool> _onWillPop() async {
    final vm = context.read<BrokerProductionInputViewModel>();

    // Tidak ada temp data, boleh keluar langsung
    if (vm.totalTempCount == 0) {
      AppShell.breadcrumb.value = _prevBreadcrumb;
      return true;
    }

    // Tampilkan dialog konfirmasi
    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UnsavedTempWarningDialog(
        totalTempCount: vm.totalTempCount,
        submitSummary: vm.getSubmitSummary(),
        onSavePressed: () {
          Navigator.of(dialogContext).pop(false);
          _handleSave(context);
        },
      ),
    );

    // Jika user pilih "Keluar & Hapus"
    if (shouldPop == true) {
      vm.clearAllTempItems();
      AppShell.breadcrumb.value = _prevBreadcrumb;
      return true;
    }

    // Batal / Simpan Dulu -> jangan keluar
    return false;
  }

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
        primaryColor: _kBrokerPrimary,
        borderColor: _kBrokerBorder,
        loadTimeline: () async {
          final list = await BrokerProductionRepository()
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

  Future<void> _openSplitDialog() async {
    if (!mounted) return;
    await ProductionFlowHelpers.openSplitAndReplace<
      ({BrokerProduction prod, String namaJenis})
    >(
      context: context,
      idMesin: _header?.idMesin,
      tanggal: _header?.tglProduksi,
      onMissingContext: () => _showSnack(
        'Data mesin/tanggal tidak tersedia',
        backgroundColor: Colors.orange,
      ),
      showSplitDialog: (idMesin, tgl) {
        return showDialog<({BrokerProduction prod, String namaJenis})>(
          context: context,
          barrierDismissible: true,
          builder: (_) =>
              ProductionGantiProduksiDialog<
                ({BrokerProduction prod, String namaJenis}),
                BrokerType
              >(
                tanggal: tgl,
                shift: _header?.shift ?? 1,
                primaryColor: _kBrokerPrimary,
                borderColor: _kBrokerBorder,
                jenisRequiredMessage: 'Pilih jenis broker terlebih dahulu',
                submitLabel: 'Ganti Produksi',
                dropdownBuilder: (selected, onChanged) => BrokerTypeDropdown(
                  preselectId: selected?.idBroker,
                  onChanged: onChanged,
                ),
                jenisNameOf: (j) => j.nama,
                onSubmit: (hourStart, jenis) async {
                  final prod = await BrokerProductionRepository().addProduksi(
                    idMesin: idMesin,
                    tanggal: tgl,
                    hourStart: hourStart,
                    outputJenisId: jenis.idBroker,
                  );
                  return (prod: prod, namaJenis: jenis.nama);
                },
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
            builder: (_) => BrokerProductionInputScreen(
              noProduksi: splitResult.prod.noProduksi,
            ),
          ),
        );
      },
    );
  }

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────

  Future<void> _handleComplete() async {
    final vm = context.read<BrokerProductionInputViewModel>();
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

  Future<void> _openScanDialog({String mode = 'full'}) async {
    setState(() => _selectedMode = mode);
    await showDialog<void>(
      context: context,
      builder: (_) => ProductionScanLabelDialog(
        manualHint: 'X.XXXXXXXXXX',
        headerSubtitle: _modeLabel(_selectedMode),
        primaryColor: _kBrokerPrimary,
        formulaOutputs: _formulaOutputs,
        onLookup: (code) async => _onCodeReady(context, code),
      ),
    );
  }

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

  Widget _categorySlot({
    required bool visible,
    required Widget child,
    double? width,
  }) {
    return visible
        ? SizedBox(width: width ?? 360, child: child)
        : const SizedBox.shrink();
  }

  /// ? Handler untuk bulk delete
  Future<bool> _handleBulkDelete(List<dynamic> items) async {
    final vm = context.read<BrokerProductionInputViewModel>();

    final success = await vm.deleteItems(widget.noProduksi, items);

    if (!success && mounted) {
      final errMsg = vm.deleteError ?? 'Gagal menghapus item';
      await showDialog(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menghapus', message: errMsg),
      );
    }

    return success;
  }

  Future<void> _showTempCardOptions(String labelTitle) async {
    final vm = context.read<BrokerProductionInputViewModel>();

    final tempData = vm.getTemporaryDataForLabel(labelTitle);
    final isSakBased =
        tempData != null &&
        (tempData.brokerItems.isNotEmpty ||
            tempData.brokerPartials.isNotEmpty ||
            tempData.bbItems.isNotEmpty ||
            tempData.bbPartials.isNotEmpty ||
            tempData.washingItems.isNotEmpty ||
            tempData.mixerItems.isNotEmpty ||
            tempData.mixerPartials.isNotEmpty);
    // Partial not supported for Washing (B.) and Crusher (F.)
    final supportsPartial =
        tempData != null &&
        (tempData.brokerItems.isNotEmpty ||
            tempData.brokerPartials.isNotEmpty ||
            tempData.bbItems.isNotEmpty ||
            tempData.bbPartials.isNotEmpty ||
            tempData.gilinganItems.isNotEmpty ||
            tempData.gilinganPartials.isNotEmpty ||
            tempData.mixerItems.isNotEmpty ||
            tempData.mixerPartials.isNotEmpty ||
            tempData.rejectItems.isNotEmpty ||
            tempData.rejectPartials.isNotEmpty);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => ProductionTempCardOptionsDialog(
        labelTitle: labelTitle,
        showSebagian: isSakBased,
        showPartial: supportsPartial,
        primaryColor: _kBrokerPrimary,
        surfaceColor: _kBrokerSurface,
        borderColor: _kBrokerBorder,
      ),
    );
    if (result == null || !mounted) return;

    if (result == 'delete') {
      vm.deleteTempItemsForLabel(labelTitle);
    } else if (result == 'select' || result == 'partial') {
      // Delete existing temp for this label so user can choose a subset/partial
      vm.deleteTempItemsForLabel(labelTitle);
      setState(() => _selectedMode = result);

      if (!mounted) return;

      // Reload lookup for this label (uses cache, no new scan needed)
      final lookupResult = await vm.lookupLabel(labelTitle);
      if (!mounted) return;

      if (lookupResult == null) {
        _showSnack(
          'Gagal memuat data label "$labelTitle".',
          backgroundColor: Colors.red,
        );
        return;
      }

      if (result == 'partial') {
        await _handlePartialMode(context, vm, lookupResult);
      } else {
        await _handleSelectMode(context, vm, lookupResult);
      }
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    final vm = context.read<BrokerProductionInputViewModel>();

    if (vm.totalTempCount == 0) {
      _showSnack(
        'Tidak ada data untuk disimpan',
        backgroundColor: Colors.orange,
      );
      return;
    }

    // ?? Dialog konfirmasi formal
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ConfirmSaveTempDialog(
        totalTempCount: vm.totalTempCount,
        submitSummary: vm.getSubmitSummary(),
      ),
    );

    if (confirm != true || !mounted) return;

    // Eksekusi submit ? skeleton muncul dari state isSubmitting
    final success = await vm.submitTempItems(widget.noProduksi);

    if (!mounted) return;

    if (success) {
      _showSnack('? Data berhasil disimpan', backgroundColor: Colors.green);
    } else {
      final errMsg = vm.submitError ?? 'Kesalahan tidak diketahui';

      await showDialog(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menyimpan', message: errMsg),
      );
      // retry kalau mau, user tinggal tekan tombol Save lagi
    }
  }

  Future<String?> _onCodeReady(BuildContext context, String code) async {
    final vm = context.read<BrokerProductionInputViewModel>();

    // ? VALIDASI: Cek jika mode partial tidak support untuk washing/crusher
    if (_selectedMode == 'partial') {
      final normalized = code.trim().toUpperCase();
      final prefix = normalized.length >= 2 ? normalized.substring(0, 2) : '';

      if (prefix == 'B.' || prefix == 'F.') {
        final labelType = prefix == 'B.' ? 'Washing' : 'Crusher';

        // ? Tampilkan dialog informatif
        await PartialModeNotSupportedDialog.show(
          context: context,
          labelType: labelType,
          onOk: () {
            // Optional: Bisa tambahkan aksi setelah user klik OK
            // Misalnya log atau analytics
          },
        );

        return '$labelType tidak mendukung mode PARTIAL';
      }
    }

    // ? Lanjutkan proses lookup jika validasi OK
    final res = await vm.lookupLabel(code, force: true);
    if (!mounted) return 'Halaman sudah tidak aktif';

    if (vm.lookupError != null) {
      return 'Label "${code.trim()}" tidak dapat diproses pada produksi broker ini.';
    }

    if (res == null || res.found == false || res.data.isEmpty) {
      return 'Label "$code" tidak memiliki data yang tersedia.';
    }

    // DEBUG LOG
    final dbgTab = _tabForLookupResult(res);
    final dbgRow = res.data.isNotEmpty ? res.data.first : <String, dynamic>{};
    final dbgPrefix = code.trim().length >= 2 ? code.trim().substring(0, 2).toUpperCase() : '??';
    final dbgIdJenis = dbgRow['IdJenis'] ?? dbgRow['idJenis'] ?? dbgRow['JenisId'] ?? dbgRow['jenisId'];
    final dbgNamaJenis = dbgRow['NamaJenis'] ?? dbgRow['namaJenis'] ?? dbgRow['Jenis'] ?? '-';
    debugPrint('=== BROKER SCAN DEBUG ===');
    debugPrint('  code       : $code');
    debugPrint('  prefix     : $dbgPrefix');
    debugPrint('  tab        : $dbgTab');
    debugPrint('  idJenis    : $dbgIdJenis');
    debugPrint('  namaJenis  : $dbgNamaJenis');
    debugPrint('  rawKeys    : ${dbgRow.keys.toList()}');
    debugPrint('  allowedKat : $_allowedInputKategori');
    debugPrint('  isTabAllow : ${dbgTab != null ? _isTabAllowed(dbgTab) : 'tab=null'}');
    debugPrint('  formulaOut : ${_formulaOutputs.map((o) => '(id=${o.idJenis}, nama=${o.namaJenis})').toList()}');
    debugPrint('=========================');

    // Validasi kategori + jenis terhadap formula (jika sudah dimuat)
    if (_allowedInputKategori != null && _formulaOutputs.isNotEmpty) {
      final tab = _tabForLookupResult(res);

      // 1. Cek kategori
      if (tab != null && !_isTabAllowed(tab)) {
        return 'Kategori label "${code.trim()}" tidak sesuai dengan formula produksi ini.';
      }

      // 2. Cek idJenis vs InputId formula untuk prefix yang sama
      final scanPrefix = code.trim().length >= 2
          ? code.trim().substring(0, 2).toUpperCase()
          : '';
      if (scanPrefix.isNotEmpty) {
        final firstRow = res.data.first;
        final rawIdJenis = firstRow['idJenis'] ?? firstRow['IdJenis'];
        if (rawIdJenis != null) {
          final idJenis = (rawIdJenis as num).toInt();
          // Kumpulkan semua InputId yang diizinkan untuk prefix ini
          final allowedInputIds = _formulaOutputs
              .expand((o) => o.formulas)
              .where((f) => f.prefixLabel.toUpperCase() == scanPrefix)
              .map((f) => f.inputId)
              .toSet();
          if (allowedInputIds.isNotEmpty && !allowedInputIds.contains(idJenis)) {
            final namaJenis = firstRow['namaJenis'] ?? firstRow['NamaJenis'] ?? firstRow['Jenis'] ?? 'tidak diketahui';
            return 'Jenis "$namaJenis" tidak terdaftar dalam formula produksi ini.';
          }
        }
      }
    }

    // Auto-switch ke tab sesuai tipe label yang discan
    final tab = _tabForLookupResult(res);
    if (tab != null && tab != _selectedInputTab) {
      setState(() => _selectedInputTab = tab);
    }

    // ===== ROUTING BERDASARKAN MODE =====
    if (_selectedMode == 'full') {
      await _handleFullMode(context, vm, res);
    } else if (_selectedMode == 'partial') {
      await _handlePartialMode(context, vm, res);
    } else {
      await _handleSelectMode(context, vm, res);
    }

    return null;
  }

  /// MODE FULL: Langsung commit semua data tanpa dialog
  Future<void> _handleFullMode(
    BuildContext context,
    BrokerProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    final freshCount = vm.countNewRowsInLastLookup(widget.noProduksi);

    if (freshCount == 0) {
      final labelCode = _labelCodeOfFirst(res);
      final hasTemp =
          labelCode != null && vm.hasTemporaryDataForLabel(labelCode);
      final suffix = hasTemp
          ? ' � ${vm.getTemporaryDataSummary(labelCode!)}'
          : '';
      _showSnack(
        'Semua item untuk ${labelCode ?? "label ini"} sudah ada.$suffix',
      );
      return;
    }

    // Auto-select semua item baru (non-duplicate)
    vm.clearPicks();
    vm.pickAllNew(widget.noProduksi);

    // Commit langsung tanpa dialog
    final result = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

    final msg = result.added > 0
        ? '? Auto-added ${result.added} item${result.skipped > 0 ? ' � Duplikat terlewati ${result.skipped}' : ''}'
        : 'Tidak ada item baru ditambahkan';

    _showSnack(
      msg,
      backgroundColor: result.added > 0 ? Colors.green : Colors.orange,
    );
  }

  /// MODE PARTIAL: Dialog khusus untuk partial dengan radio button (single selection)
  Future<void> _handlePartialMode(
    BuildContext context,
    BrokerProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    // Non-sak items (gilingan/reject): langsung tanya berat saja
    final firstItem = res.typedItems.isNotEmpty ? res.typedItems.first : null;
    final isNonSak = firstItem is GilinganItem || firstItem is RejectItem;

    if (isNonSak && res.data.isNotEmpty) {
      final row = res.data.first;
      final beratRaw = row['berat'] ?? row['Berat'];
      final originalBerat = beratRaw != null
          ? (beratRaw as num).toDouble()
          : null;
      if (originalBerat == null || originalBerat <= 0) return;

      final newWeight = await WeightInputDialog.show(
        context,
        maxWeight: originalBerat,
        currentWeight: null,
      );
      if (!mounted || newWeight == null) return;

      final originalIsPartial = row['isPartial'];
      row['isPartial'] = true;
      row['IsPartial'] = true;
      row['berat'] = newWeight;
      row['Berat'] = newWeight;

      vm.clearPicks();
      vm.togglePick(row);
      final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

      row['berat'] = originalBerat;
      row['Berat'] = originalBerat;
      row['isPartial'] = originalIsPartial;
      row['IsPartial'] = originalIsPartial;

      _showSnack(
        r.added > 0
            ? '? Ditambahkan ${r.added} item partial'
            : 'Item sudah ada atau gagal ditambahkan',
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
      );
      return;
    }

    // Sak-based: tampilkan dialog partial normal
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LookupLabelPartialDialog(
        noProduksi: widget.noProduksi,
        selectedMode: _selectedMode,
      ),
    );
  }

  /// MODE SELECT: Dialog dengan checkbox (default all selected untuk item baru)
  Future<void> _handleSelectMode(
    BuildContext context,
    BrokerProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    final freshCount = vm.countNewRowsInLastLookup(widget.noProduksi);

    if (freshCount == 0) {
      final labelCode = _labelCodeOfFirst(res);
      final hasTemp =
          labelCode != null && vm.hasTemporaryDataForLabel(labelCode);
      final suffix = hasTemp
          ? ' � ${vm.getTemporaryDataSummary(labelCode!)}'
          : '';
      _showSnack(
        'Semua item untuk ${labelCode ?? "label ini"} sudah ada.$suffix',
      );
      return;
    }

    // Tampilkan dialog biasa (dengan auto-select default)
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BrokerLookupLabelDialog(
        noProduksi: widget.noProduksi,
        selectedMode: _selectedMode,
      ),
    );
  }

  String? _tabForLookupResult(ProductionLabelLookupResult res) {
    if (res.typedItems.isEmpty) return null;
    final item = res.typedItems.first;
    if (item is BrokerItem) return 'broker';
    if (item is BbItem) return 'bb';
    if (item is WashingItem) return 'washing';
    if (item is CrusherItem) return 'crusher';
    if (item is GilinganItem) return 'gilingan';
    if (item is MixerItem) return 'mixer';
    if (item is RejectItem) return 'reject';
    return null;
  }

  String? _labelCodeOfFirst(ProductionLabelLookupResult res) {
    if (res.typedItems.isEmpty) return null;
    final item = res.typedItems.first;

    if (item is BrokerItem) {
      // ?? TAMBAHKAN: Cek partial code terlebih dahulu
      return (item.noBrokerPartial ?? '').trim().isNotEmpty
          ? item.noBrokerPartial
          : item.noBroker;
    }
    if (item is BbItem) {
      final npart = (item.noBBPartial ?? '').trim();
      return npart.isNotEmpty ? npart : item.noBahanBaku;
    }
    if (item is WashingItem) return item.noWashing;
    if (item is CrusherItem) return item.noCrusher;
    if (item is GilinganItem) {
      return (item.noGilinganPartial ?? '').trim().isNotEmpty
          ? item.noGilinganPartial
          : item.noGilingan;
    }
    if (item is MixerItem) {
      return (item.noMixerPartial ?? '').trim().isNotEmpty
          ? item.noMixerPartial
          : item.noMixer;
    }
    if (item is RejectItem) {
      return (item.noRejectPartial ?? '').trim().isNotEmpty
          ? item.noRejectPartial
          : item.noReject;
    }
    return null;
  }

  Widget _buildInputPanel({
    required BuildContext buttonContext,
    required BrokerProductionInputViewModel vm,
    required bool locked,
    required bool isLookupLoading,
    required int labelCount,
    required Widget child,
  }) {
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
                  primaryColor: _kBrokerPrimary,
                ),
                const Spacer(),
                SaveButtonWithBadge(
                  count: vm.totalTempCount,
                  isLoading: vm.isSubmitting,
                  onPressed: () => _handleSave(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Hapus Semua Temp',
                  onPressed: vm.totalTempCount > 0
                      ? () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Hapus Semua Temp?'),
                              content: Text(
                                'Apakah Anda yakin ingin menghapus ${vm.totalTempCount} item temp?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
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
                      : null,
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
          const Divider(height: 1, color: _kBrokerBorder),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ],
      ),
    );
  }

  // ── Multi-select output (long-press) ──────────────────────────────────────

  String? _outputCode(Object? item) {
    final raw = item is BrokerOutput
        ? item.noBroker
        : item is BonggolanOutput
        ? item.noBonggolan
        : null;
    final code = (raw ?? '').trim();
    return code.isEmpty ? null : code;
  }

  ProductionOutputPrintTarget? _outputPrintTarget(Object item) {
    if (item is BrokerOutput) {
      final code = (item.noBroker ?? '').trim();
      if (code.isEmpty) return null;
      return ProductionOutputPrintTarget(
        code: code,
        pdfUrl: ApiConstants.brokerLabelPdf(code),
        feature: 'broker',
        markAsPrinted: () => BrokerRepository(api: ApiClient()).markAsPrinted(
          code,
        ),
      );
    }
    if (item is BonggolanOutput) {
      final code = (item.noBonggolan ?? '').trim();
      if (code.isEmpty) return null;
      return ProductionOutputPrintTarget(
        code: code,
        pdfUrl: ApiConstants.bonggolanLabelPdf(code),
        feature: 'bonggolan',
        markAsPrinted: () => BonggolanRepository().markAsPrinted(code),
      );
    }
    return null;
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
      if (item is BrokerOutput) {
        await BrokerRepository(
          api: ApiClient(),
        ).deleteBroker((item.noBroker ?? '').trim());
      } else if (item is BonggolanOutput) {
        await BonggolanRepository().deleteBonggolan(
          (item.noBonggolan ?? '').trim(),
        );
      }
    });
    if (!mounted) return;
    context.read<BrokerProductionInputViewModel>().loadOutputs(widget.noProduksi);
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

  Widget _outputSelectionBar(List<Object> currentOutputs) {
    final total = currentOutputs
        .where((o) => _outputCode(o) != null)
        .length;
    final allSelected = total > 0 && selectedOutputCount >= total;
    return ProductionOutputSelectionBar(
      accentColor: _kBrokerOutput,
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
    required List<BrokerOutput> brokerOutputs,
    required List<BonggolanOutput> bonggolanOutputs,
    required bool isLoading,
    required String? error,
    required double grandInputBerat,
  }) {
    int totalSakBroker = 0;
    double totalBeratBroker = 0.0;
    for (final output in brokerOutputs) {
      totalSakBroker += output.totalSak;
      totalBeratBroker += output.totalBerat;
    }

    double totalBeratBonggolan = 0.0;
    for (final output in bonggolanOutputs) {
      totalBeratBonggolan += output.berat ?? 0.0;
    }

    final totalLabel = brokerOutputs.length + bonggolanOutputs.length;
    final isBrokerOutputTab = _selectedOutputTab == 'broker';
    final activeOutputLabel = isBrokerOutputTab ? 'Broker' : 'Bonggolan';
    final selectedOutputSummary = isBrokerOutputTab
        ? _BrokerOutputSummaryTile(
            totalLabel: brokerOutputs.length,
            totalSak: totalSakBroker,
            totalBerat: totalBeratBroker,
          )
        : _BonggolanOutputSummaryTile(
            totalLabel: bonggolanOutputs.length,
            totalBerat: totalBeratBonggolan,
          );
    Future<void> onAddOutput() async {
      // Input & output bebas diisi tanpa urutan/batasan berat.
      if (isBrokerOutputTab) {
        if (_header?.outputJenisId != null) {
          await showDialog<void>(
            context: context,
            builder: (_) => BrokerProductionOutputFormDialog(
              noProduksi: widget.noProduksi,
              tglProduksi: _header?.tglProduksi,
              outputJenisId: _header!.outputJenisId!,
              outputJenisNama: _header?.outputJenisNama ?? '',
              namaMesin: _header?.namaMesin,
            ),
          );
        } else {
          await showDialog<void>(
            context: context,
            builder: (_) => BrokerFormDialog(
              preselectNoProduksi: widget.noProduksi,
              preselectNamaMesin: _header?.namaMesin,
              preselectDate: _header?.tglProduksi,
            ),
          );
        }
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => BonggolanProductionOutputFormDialog(
            noProduksi: widget.noProduksi,
            tglProduksi: _header?.tglProduksi,
            namaMesin: _header?.namaMesin,
          ),
        );
      }

      if (!mounted) return;
      context.read<BrokerProductionInputViewModel>().loadOutputs(
        widget.noProduksi,
      );
    }

    final selectedTabChild = _selectedOutputTab == 'broker'
        ? ProductionOutputCategoryContent(
            footer: const SizedBox.shrink(),
            child: brokerOutputs.isEmpty
                ? const ProductionEmptyCategory(
                    message: 'Belum ada output broker',
                  )
                : LayoutBuilder(
                    builder: (_, c) => GridView(
                      padding: const EdgeInsets.all(6),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: c.maxWidth < 380 ? 2 : 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        mainAxisExtent: 78,
                      ),
                      children: brokerOutputs
                          .map(
                            (output) => wrapOutputTile(
                              code: (output.noBroker ?? '').trim(),
                              item: output,
                              accentColor: _kBrokerOutput,
                              builder: (overrideTap) => _BrokerOutputTile(
                                output: output,
                                onTap: overrideTap,
                                canPrint: !_isLockedOrComplete,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          )
        : ProductionOutputCategoryContent(
            footer: const SizedBox.shrink(),
            child: bonggolanOutputs.isEmpty
                ? const ProductionEmptyCategory(
                    message: 'Belum ada output bonggolan',
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
                      children: bonggolanOutputs
                          .map(
                            (output) => wrapOutputTile(
                              code: (output.noBonggolan ?? '').trim(),
                              item: output,
                              accentColor: _kBrokerOutput,
                              builder: (overrideTap) => _BonggolanOutputTile(
                                output: output,
                                onTap: overrideTap,
                                canPrint: !_isLockedOrComplete,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          );

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kBrokerOutput.withValues(alpha: 0.3),
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
                  'Label Output',
                  iconColor: _kBrokerOutput,
                  primaryColor: _kBrokerPrimary,
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBrokerBorder),
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
                                accentColor: _kBrokerOutput,
                                tabs: [
                                  ProductionTabItem(
                                    value: 'broker',
                                    label: 'Broker',
                                    count: brokerOutputs.length,
                                  ),
                                  ProductionTabItem(
                                    value: 'bonggolan',
                                    label: 'Bonggolan',
                                    count: bonggolanOutputs.length,
                                  ),
                                ],
                                onChanged: (value) {
                                  if (_selectedOutputTab == value) return;
                                  setState(() => _selectedOutputTab = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: ProductionInputCategoryBlock(
                            color: _kBrokerOutput,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SizedBox(
                                        width: constraints.maxWidth,
                                        child: selectedTabChild,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (isSelectingOutput)
                                  _outputSelectionBar(
                                    isBrokerOutputTab
                                        ? brokerOutputs
                                        : bonggolanOutputs,
                                  )
                                else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          selectedOutputSummary,
                                          const SizedBox(height: 10),
                                          _OutputGrandTotalBar(
                                            totalLabel: totalLabel,
                                            totalSak: totalSakBroker,
                                            totalBerat:
                                                totalBeratBroker +
                                                totalBeratBonggolan,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FloatingActionButton(
                                      heroTag: 'fab_add_broker_output',
                                      mini: true,
                                      backgroundColor:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? Colors.grey.shade300
                                          : _kBrokerOutput,
                                      foregroundColor: Colors.white,
                                      tooltip: 'Tambah $activeOutputLabel',
                                      onPressed:
                                          (_header == null ||
                                              _isLockedOrComplete)
                                          ? null
                                          : onAddOutput,
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

  static bool _boolish(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 't' || s == 'yes' || s == 'y';
  }

  static bool _isPartialOf(dynamic item, Map<String, dynamic> row) {
    if (_boolish(row['isPartial']) || _boolish(row['IsPartial'])) return true;

    try {
      if (item is BbItem && item.isPartialRow == true) return true;
      final dynamic dyn = item;
      final hasIsPartial = (dyn as dynamic?)?.isPartial;
      if (hasIsPartial is bool && hasIsPartial) return true;
    } catch (_) {}
    return false;
  }

  // ── Multi-select input (long-press → Keluarkan) ───────────────────────────

  Future<void> _releaseSelectedInput(BrokerProductionInputViewModel vm) async {
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
    BrokerProductionInputViewModel vm,
    Map<String, List<Object>> groups,
  ) {
    final total = groups.length;
    final allSelected = total > 0 && selectedInputCount >= total;
    return ProductionInputSelectionBar(
      accentColor: _kBrokerPrimary,
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
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
    required Map<String, List<RejectItem>> rejectGroups,
  }) {
    switch (_selectedInputTab) {
      case 'bb':
        return {for (final e in bbGroups.entries) e.key: e.value};
      case 'washing':
        return {for (final e in washingGroups.entries) e.key: e.value};
      case 'crusher':
        return {for (final e in crusherGroups.entries) e.key: e.value};
      case 'gilingan':
        return {for (final e in gilinganGroups.entries) e.key: e.value};
      case 'mixer':
        return {for (final e in mixerGroups.entries) e.key: e.value};
      case 'reject':
        return {for (final e in rejectGroups.entries) e.key: e.value};
      default:
        return {for (final e in brokerGroups.entries) e.key: e.value};
    }
  }

  Widget _buildSelectedInputTabChild({
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
    required Map<String, List<RejectItem>> rejectGroups,
    required BrokerProductionInputViewModel vm,
    required bool canDelete,
    bool showFooter = true,
  }) {
    ProductionCategorySummaryTile summaryFor({
      required int totalData,
      required int totalSak,
      required double totalBerat,
    }) {
      return ProductionCategorySummaryTile(
        summary: SectionSummary(
          totalData: totalData,
          totalSak: totalSak,
          totalBerat: totalBerat,
        ),
        accentColor: _kBrokerPrimary,
      );
    }

    Widget grid;
    Widget? footer;

    if (_selectedInputTab == 'broker') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in brokerGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: brokerGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
      grid = brokerGroups.isEmpty
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
                  // Selalu tampilkan noBroker (nomor label asli), bukan
                  // noBrokerPartial — grouping key (entry.key) tetap dipakai
                  // untuk matching/delete temp item.
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
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
                        : () => startSelectingInput(entry.key, entry.value),
                    expandable: !hasPartial,
                    isPartialGroup: hasPartial,
                    partialReference: hasPartial
                        ? (entry.value
                                  .firstWhere((x) => x.isPartialRow)
                                  .noBroker
                                  ?.toString() ??
                              '-')
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final dbItems = currentInputs == null
                          ? <BrokerItem>[]
                          : currentInputs.broker.where(
                              (x) => brokerTitleKey(x) == entry.key,
                            );
                      final tempFull = vm.tempBroker.where(
                        (x) => brokerTitleKey(x) == entry.key,
                      );
                      final tempPart = vm.tempBrokerPartial.where(
                        (x) => brokerTitleKey(x) == entry.key,
                      );
                      final items = <BrokerItem>[
                        ...tempPart,
                        ...dbItems,
                        ...tempFull,
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
            );
    } else if (_selectedInputTab == 'bb') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in bbGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: bbGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
      grid = bbGroups.isEmpty
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
                      ? bbPairLabel(
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
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
                        : () => startSelectingInput(entry.key, entry.value),
                    expandable: !hasPartial,
                    isPartialGroup: hasPartial,
                    partialReference: hasPartial
                        ? bbPairLabel(
                            entry.value.firstWhere((x) => x.isPartialRow),
                          )
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final dbItems = currentInputs == null
                          ? <BbItem>[]
                          : currentInputs.bb.where(
                              (x) => bbTitleKey(x) == entry.key,
                            );
                      final tempFull = vm.tempBb.where(
                        (x) => bbTitleKey(x) == entry.key,
                      );
                      final tempPart = vm.tempBbPartial.where(
                        (x) => bbTitleKey(x) == entry.key,
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
    } else if (_selectedInputTab == 'washing') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in washingGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: washingGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
      grid = washingGroups.isEmpty
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
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
                        : () => startSelectingInput(entry.key, entry.value),
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final items = [
                        if (currentInputs != null)
                          ...currentInputs.washing.where(
                            (x) => (x.noWashing ?? '-') == entry.key,
                          ),
                        ...vm.tempWashing.where(
                          (x) => (x.noWashing ?? '-') == entry.key,
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
            );
    } else if (_selectedInputTab == 'crusher') {
      double totalBerat = 0.0;
      for (final entry in crusherGroups.entries) {
        for (final item in entry.value) {
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: crusherGroups.length,
        totalSak: 0,
        totalBerat: totalBerat,
      );
      grid = crusherGroups.isEmpty
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
                children: crusherGroups.entries.map((entry) {
                  return ProductionInputGroupTile(
                    title:
                        (entry.value.isNotEmpty
                            ? entry.value.first.namaJenis
                            : '-') ??
                        '-',
                    headerSubtitle: entry.key,
                    tileMetrics: [
                      (
                        Icons.scale_outlined,
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
                        : () => startSelectingInput(entry.key, entry.value),
                    detailsBuilder: () {
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final items = [
                        if (currentInputs != null)
                          ...currentInputs.crusher.where(
                            (x) => (x.noCrusher ?? '-') == entry.key,
                          ),
                        ...vm.tempCrusher.where(
                          (x) => (x.noCrusher ?? '-') == entry.key,
                        ),
                      ];
                      return items.map((item) {
                        final isTemp = vm.tempCrusher.contains(item);
                        return TooltipTableRow(
                          columns: ['${num2(item.berat)} kg'],
                          showDelete: isTemp,
                          onDelete: isTemp
                              ? () => vm.deleteTempCrusherItem(item)
                              : null,
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
            );
    } else if (_selectedInputTab == 'gilingan') {
      double totalBerat = 0.0;
      for (final entry in gilinganGroups.entries) {
        for (final item in entry.value) {
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: gilinganGroups.length,
        totalSak: 0,
        totalBerat: totalBerat,
      );
      grid = gilinganGroups.isEmpty
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
                      ? ((entry.value.first.noGilingan ?? '')
                                .trim()
                                .isNotEmpty
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
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
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
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final dbItems = currentInputs == null
                          ? <GilinganItem>[]
                          : currentInputs.gilingan.where(
                              (x) => gilinganTitleKey(x) == entry.key,
                            );
                      final tempFull = vm.tempGilingan.where(
                        (x) => gilinganTitleKey(x) == entry.key,
                      );
                      final tempPart = vm.tempGilinganPartial.where(
                        (x) => gilinganTitleKey(x) == entry.key,
                      );
                      final items = [...tempPart, ...dbItems, ...tempFull];
                      return items.map((item) {
                        final isTemp =
                            vm.tempGilingan.contains(item) ||
                            vm.tempGilinganPartial.contains(item);
                        final columns = item.isPartialRow
                            ? <String>[
                                (item.noGilingan ?? '-'),
                                '${num2(item.berat)} kg',
                              ]
                            : <String>['${num2(item.berat)} kg'];
                        return TooltipTableRow(
                          columns: columns,
                          showDelete: isTemp,
                          onDelete: isTemp
                              ? () => vm.deleteTempGilinganItem(item)
                              : null,
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
            );
    } else if (_selectedInputTab == 'mixer') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in mixerGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: mixerGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
      grid = mixerGroups.isEmpty
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
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
                        : () => startSelectingInput(entry.key, entry.value),
                    expandable: !hasPartial,
                    isPartialGroup: hasPartial,
                    partialReference: hasPartial
                        ? (entry.value
                                  .firstWhere((x) => x.isPartialRow)
                                  .noMixer ??
                              '-')
                        : null,
                    detailsBuilder: () => [],
                    chipItemsBuilder: () {
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final dbItems = currentInputs == null
                          ? <MixerItem>[]
                          : currentInputs.mixer
                                .where((x) => mixerTitleKey(x) == entry.key)
                                .toList();
                      final tempFull = vm.tempMixer
                          .where((x) => mixerTitleKey(x) == entry.key)
                          .toList();
                      final tempPart = vm.tempMixerPartial
                          .where((x) => mixerTitleKey(x) == entry.key)
                          .toList();
                      final items = [...tempPart, ...dbItems, ...tempFull];
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
            );
    } else {
      // reject
      double totalBerat = 0.0;
      for (final entry in rejectGroups.entries) {
        for (final item in entry.value) {
          totalBerat += item.berat ?? 0.0;
        }
      }
      footer = summaryFor(
        totalData: rejectGroups.length,
        totalSak: 0,
        totalBerat: totalBerat,
      );
      grid = rejectGroups.isEmpty
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
                children: rejectGroups.entries.map((entry) {
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
                      (
                        Icons.scale_outlined,
                        '${num2(entry.value.fold<double>(0.0, (sum, item) => sum + (item.berat ?? 0.0)))} kg',
                      ),
                    ],
                    color: Colors.blue,
                    isTemp: vm.hasTemporaryDataForLabel(entry.key),
                    isSelected: isInputGroupSelected(entry.key),
                    onTap: isSelectingInput
                        ? () => toggleInputGroup(entry.key, entry.value)
                        : null,
                    onLongPress: isSelectingInput
                        ? null
                        : vm.hasTemporaryDataForLabel(entry.key)
                        ? () => _showTempCardOptions(entry.key)
                        : () => startSelectingInput(entry.key, entry.value),
                    isPartialGroup: hasPartial,
                    partialReference: hasPartial
                        ? (entry.value
                                  .firstWhere((x) => x.isPartialRow)
                                  .noReject ??
                              '-')
                        : null,
                    detailsBuilder: () {
                      final currentInputs = vm.inputsOf(widget.noProduksi);
                      final dbItems = currentInputs == null
                          ? <RejectItem>[]
                          : currentInputs.reject.where(
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
                        final columns = item.isPartialRow
                            ? <String>[
                                (item.noReject ?? '-'),
                                '${num2(item.berat)} kg',
                              ]
                            : <String>['${num2(item.berat)} kg'];
                        return TooltipTableRow(
                          columns: columns,
                          showDelete: isTemp,
                          onDelete: isTemp
                              ? () => vm.deleteTempRejectItem(item)
                              : null,
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
            );
    }

    return ProductionOutputCategoryContent(
      footer: showFooter ? footer : const SizedBox.shrink(),
      child: grid,
    );
  }

  SectionSummary _selectedInputSummary({
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<BbItem>> bbGroups,
    required Map<String, List<WashingItem>> washingGroups,
    required Map<String, List<CrusherItem>> crusherGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required Map<String, List<MixerItem>> mixerGroups,
    required Map<String, List<RejectItem>> rejectGroups,
  }) {
    if (_selectedInputTab == 'broker') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in brokerGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      return SectionSummary(
        totalData: brokerGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
    } else if (_selectedInputTab == 'bb') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in bbGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      return SectionSummary(
        totalData: bbGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
    } else if (_selectedInputTab == 'washing') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in washingGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      return SectionSummary(
        totalData: washingGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
    } else if (_selectedInputTab == 'crusher') {
      double totalBerat = 0.0;
      for (final entry in crusherGroups.entries) {
        for (final item in entry.value) {
          totalBerat += item.berat ?? 0.0;
        }
      }
      return SectionSummary(
        totalData: crusherGroups.length,
        totalSak: 0,
        totalBerat: totalBerat,
      );
    } else if (_selectedInputTab == 'gilingan') {
      double totalBerat = 0.0;
      for (final entry in gilinganGroups.entries) {
        for (final item in entry.value) {
          totalBerat += item.berat ?? 0.0;
        }
      }
      return SectionSummary(
        totalData: gilinganGroups.length,
        totalSak: 0,
        totalBerat: totalBerat,
      );
    } else if (_selectedInputTab == 'mixer') {
      int totalSak = 0;
      double totalBerat = 0.0;
      for (final entry in mixerGroups.entries) {
        for (final item in entry.value) {
          totalSak += 1;
          totalBerat += item.berat ?? 0.0;
        }
      }
      return SectionSummary(
        totalData: mixerGroups.length,
        totalSak: totalSak,
        totalBerat: totalBerat,
      );
    }
    double totalBerat = 0.0;
    for (final entry in rejectGroups.entries) {
      for (final item in entry.value) {
        totalBerat += item.berat ?? 0.0;
      }
    }
    return SectionSummary(
      totalData: rejectGroups.length,
      totalSak: 0,
      totalBerat: totalBerat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BrokerProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noProduksi);
        final err = vm.inputsError(widget.noProduksi);
        final inputs = vm.inputsOf(widget.noProduksi);
        final outputLoading = vm.isOutputsLoading(widget.noProduksi);
        final outputErr = vm.outputsError(widget.noProduksi);
        final outputs = vm.outputsOf(widget.noProduksi);
        final bonggolanOutputs = vm.bonggolanOutputsOf(widget.noProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _isLockedOrComplete;

        final canDeleteByPerm = perm.can('label_broker:delete');
        final canDelete = canDeleteByPerm && !locked;

        // ? WRAP dengan WillPopScope untuk intercept back button
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            backgroundColor: _kBrokerSurface,
            resizeToAvoidBottomInset: false,
            body: Builder(
              builder: (_) {
                if (err != null) {
                  return Center(child: Text('Gagal memuat inputs:\n$err'));
                }

                // ===== MERGE DB + TEMP (termasuk PARTIAL) =====
                final brokerAll = loading
                    ? <BrokerItem>[]
                    : [
                        ...vm.tempBroker.reversed,
                        ...vm.tempBrokerPartial.reversed,
                        ...?inputs?.broker,
                      ];
                final bbAll = loading
                    ? <BbItem>[]
                    : [
                        ...vm.tempBb.reversed,
                        ...vm.tempBbPartial.reversed,
                        ...?inputs?.bb,
                      ];
                final washingAll = loading
                    ? <WashingItem>[]
                    : [...vm.tempWashing, ...?inputs?.washing];
                final crusherAll = loading
                    ? <CrusherItem>[]
                    : [...vm.tempCrusher, ...?inputs?.crusher];
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
                final rejectAll = loading
                    ? <RejectItem>[]
                    : [
                        ...vm.tempReject.reversed,
                        ...vm.tempRejectPartial.reversed,
                        ...?inputs?.reject,
                      ];

                // ===== GROUPED (key = titleKey yang sudah handle partial) =====
                final brokerGroups = groupBy(brokerAll, brokerTitleKey);
                final bbGroups = groupBy(bbAll, bbTitleKey);
                final washingGroups = groupBy(
                  washingAll,
                  (WashingItem e) => e.noWashing ?? '-',
                );
                final crusherGroups = groupBy(
                  crusherAll,
                  (CrusherItem e) => e.noCrusher ?? '-',
                );
                final gilinganGroups = groupBy(gilinganAll, gilinganTitleKey);
                final mixerGroups = groupBy(mixerAll, mixerTitleKey);
                final rejectGroups = groupBy(rejectAll, rejectTitleKey);

                final locked = _isLockedOrComplete;
                final closed = _header?.lastClosedDate; // boleh null

                return Column(
                  children: [
                    if (_header == null)
                      _buildToolbarSkeleton()
                    else
                      BrokerWorkspaceToolbar(
                        idMesin: _header?.idMesin,
                        shift: _header?.shift,
                        tglProduksi: _header?.tglProduksi,
                        isLocked: locked,
                        hourStart: _header?.hourStart,
                        hourEnd: _header?.hourEnd,
                        namaJenis: _header?.outputJenisNama,
                        onGanti: _openSplitDialog,
                        onTimeline: _openTimelineDialog,
                        onRefresh: () {
                          final vm = context
                              .read<BrokerProductionInputViewModel>();
                          vm.loadInputs(widget.noProduksi, force: true);
                          vm.loadOutputs(widget.noProduksi);
                          _showSnack('Data di-refresh');
                        },
                        showGantiRiwayat: _header?.tglProduksi != null &&
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
                      child: LayoutBuilder(
                        builder: (context, outerConstraints) {
                          final isWide = outerConstraints.maxWidth >= 800;

                          // -- build input panel --------------------------
                          final inputPanelWidget = Builder(
                            builder: (buttonContext) => _buildInputPanel(
                              buttonContext: buttonContext,
                              vm: vm,
                              locked: locked,
                              isLookupLoading: vm.isLookupLoading,
                              labelCount:
                                  brokerGroups.length +
                                  bbGroups.length +
                                  washingGroups.length +
                                  crusherGroups.length +
                                  gilinganGroups.length +
                                  mixerGroups.length +
                                  rejectGroups.length,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ProductionFolderTabBar(
                                    selectedValue: _selectedInputTab,
                                    accentColor: _kBrokerPrimary,
                                    tabs: [
                                      if (_isTabAllowed('broker'))
                                        ProductionTabItem(
                                          value: 'broker',
                                          label: 'Broker',
                                          count: brokerGroups.length,
                                        ),
                                      if (_isTabAllowed('bb'))
                                        ProductionTabItem(
                                          value: 'bb',
                                          label: 'Bahan Baku',
                                          count: bbGroups.length,
                                        ),
                                      if (_isTabAllowed('washing'))
                                        ProductionTabItem(
                                          value: 'washing',
                                          label: 'Washing',
                                          count: washingGroups.length,
                                        ),
                                      if (_isTabAllowed('crusher'))
                                        ProductionTabItem(
                                          value: 'crusher',
                                          label: 'Crusher',
                                          count: crusherGroups.length,
                                        ),
                                      if (_isTabAllowed('gilingan'))
                                        ProductionTabItem(
                                          value: 'gilingan',
                                          label: 'Gilingan',
                                          count: gilinganGroups.length,
                                        ),
                                      if (_isTabAllowed('mixer'))
                                        ProductionTabItem(
                                          value: 'mixer',
                                          label: 'Mixer',
                                          count: mixerGroups.length,
                                        ),
                                      if (_isTabAllowed('reject'))
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
                                      color: _kBrokerPrimary,
                                      isLoading: loading,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                return SizedBox(
                                                  width: constraints.maxWidth,
                                                  child:
                                                      _buildSelectedInputTabChild(
                                                        brokerGroups:
                                                            brokerGroups,
                                                        bbGroups: bbGroups,
                                                        washingGroups:
                                                            washingGroups,
                                                        crusherGroups:
                                                            crusherGroups,
                                                        gilinganGroups:
                                                            gilinganGroups,
                                                        mixerGroups:
                                                            mixerGroups,
                                                        rejectGroups:
                                                            rejectGroups,
                                                        vm: vm,
                                                        canDelete: canDelete,
                                                        showFooter: false,
                                                      ),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Builder(
                                            builder: (context) {
                                              double grandBerat = 0.0;
                                              int grandSak =
                                                  brokerAll.length +
                                                  bbAll.length +
                                                  washingAll.length +
                                                  mixerAll.length;
                                              for (final i in brokerAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              for (final i in bbAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              for (final i in washingAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              for (final i in crusherAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              for (final i in gilinganAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              for (final i in mixerAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              for (final i in rejectAll) {
                                                grandBerat += i.berat ?? 0.0;
                                              }
                                              final selectedSummary =
                                                  _selectedInputSummary(
                                                    brokerGroups: brokerGroups,
                                                    bbGroups: bbGroups,
                                                    washingGroups:
                                                        washingGroups,
                                                    crusherGroups:
                                                        crusherGroups,
                                                    gilinganGroups:
                                                        gilinganGroups,
                                                    mixerGroups: mixerGroups,
                                                    rejectGroups: rejectGroups,
                                                  );
                                              if (isSelectingInput) {
                                                return _inputSelectionBar(
                                                  vm,
                                                  _activeInputGroups(
                                                    brokerGroups: brokerGroups,
                                                    bbGroups: bbGroups,
                                                    washingGroups: washingGroups,
                                                    crusherGroups: crusherGroups,
                                                    gilinganGroups:
                                                        gilinganGroups,
                                                    mixerGroups: mixerGroups,
                                                    rejectGroups: rejectGroups,
                                                  ),
                                                );
                                              }
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ProductionCategorySummaryTile(
                                                          summary:
                                                              selectedSummary,
                                                          accentColor:
                                                              _kBrokerPrimary,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        ProductionInputGrandTotalBar(
                                                          totalLabel:
                                                              brokerGroups
                                                                  .length +
                                                              bbGroups.length +
                                                              washingGroups
                                                                  .length +
                                                              crusherGroups
                                                                  .length +
                                                              gilinganGroups
                                                                  .length +
                                                              mixerGroups
                                                                  .length +
                                                              rejectGroups
                                                                  .length,
                                                          totalSak: grandSak,
                                                          totalBerat:
                                                              grandBerat,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  FloatingActionButton(
                                                    heroTag:
                                                        'fab_scan_broker_input',
                                                    mini: true,
                                                    backgroundColor:
                                                        locked ||
                                                            vm.isLookupLoading
                                                        ? Colors.grey.shade300
                                                        : _kBrokerPrimary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    onPressed:
                                                        locked ||
                                                            vm.isLookupLoading
                                                        ? null
                                                        : () =>
                                                              _openScanDialog(),
                                                    child: vm.isLookupLoading
                                                        ? const SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          )
                                                        : const Icon(
                                                            Icons
                                                                .qr_code_scanner,
                                                          ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          // -- build output panel -------------------------
                          double grandInputBerat = 0.0;
                          for (final i in brokerAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }
                          for (final i in bbAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }
                          for (final i in washingAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }
                          for (final i in crusherAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }
                          for (final i in gilinganAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }
                          for (final i in mixerAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }
                          for (final i in rejectAll) {
                            grandInputBerat += i.berat ?? 0.0;
                          }

                          final outputPanelWidget = _buildOutputSection(
                            brokerOutputs: outputs,
                            bonggolanOutputs: bonggolanOutputs,
                            isLoading: outputLoading,
                            error: outputErr,
                            grandInputBerat: grandInputBerat,
                          );

                          // -- responsive layout --------------------------
                          if (isWide) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: inputPanelWidget),
                                  const SizedBox(width: 16),
                                  Expanded(child: outputPanelWidget),
                                ],
                              ),
                            );
                          }

                          // narrow: stacked, each panel gets half height
                          final panelH =
                              (outerConstraints.maxHeight - 16 - 32) / 2;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: panelH,
                                  child: inputPanelWidget,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: panelH,
                                  child: outputPanelWidget,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _BrokerOutputTile extends StatelessWidget {
  final BrokerOutput output;
  final VoidCallback? onTap;
  final bool canPrint;

  const _BrokerOutputTile({
    required this.output,
    this.onTap,
    this.canPrint = true,
  });

  Future<void> _handlePrint(BuildContext context) async {
    final noBroker = (output.noBroker ?? '').trim();
    if (noBroker.isEmpty) return;

    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final lockApi = LabelPrintLockApi();
    final repo = BrokerRepository(api: ApiClient());
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    var isLockAcquired = false;
    var isPrinted = false;

    try {
      await lockApi.acquire(noBroker);
      isLockAcquired = true;

      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: Uri.parse(ApiConstants.brokerLabelPdf(noBroker)),
        title: noBroker,
        onPrinted: () {
          isPrinted = true;
          () async {
            var needsIncrement = false;
            var needsRelease = false;

            try {
              final count = await repo.markAsPrinted(noBroker);
              if (count != null) {
                lockVm.setPrintCount(noBroker, count);
              }
            } catch (_) {
              needsIncrement = true;
            }

            try {
              await lockApi.release(noBroker);
            } catch (_) {
              needsRelease = true;
            }

            if (needsIncrement || needsRelease) {
              await queue.enqueue(
                feature: 'broker',
                noLabel: noBroker,
                needsIncrement: needsIncrement,
                needsReleaseLock: needsRelease,
              );
            }
          }().ignore();
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (isLockAcquired && !isPrinted) {
        () async {
          try {
            await lockApi.release(noBroker);
          } catch (_) {
            await queue.enqueue(
              feature: 'broker',
              noLabel: noBroker,
              needsReleaseLock: true,
            );
          }
        }().ignore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBrokerBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            onTap ??
            () {
          showDialog<void>(
            context: context,
            builder: (_) => _BrokerOutputDetailDialog(
              output: output,
              onPrint: canPrint ? () => _handlePrint(context) : null,
              onPrintQc: !canPrint
                  ? null
                  : () async {
                final noBroker = (output.noBroker ?? '').trim();
                if (noBroker.isEmpty) return;
                final rootCtx = Navigator.of(
                  context,
                  rootNavigator: true,
                ).context;
                try {
                  // ignore: use_build_context_synchronously
                  await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
                    context: rootCtx,
                    pdfUrl: Uri.parse(ApiConstants.brokerQcPdf(noBroker)),
                    title: '$noBroker – QC',
                  );
                } catch (e) {
                  if (!rootCtx.mounted) return;
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Title row: noBroker + print count
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (output.namaJenis ?? '').isNotEmpty
                          ? output.namaJenis!
                          : (output.noBroker ?? '-'),
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
                    color: output.printedCount > 0
                        ? _kBrokerOutput
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'x${output.printedCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: output.printedCount > 0
                          ? _kBrokerOutput
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                output.noBroker ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              // Metrics
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  ProductionMiniMetric(
                    icon: Icons.inventory_2_outlined,
                    text: '${output.totalSak} sak',
                  ),
                  ProductionMiniMetric(
                    icon: Icons.scale_outlined,
                    text: '${num2(output.totalBerat)} kg',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BonggolanOutputTile extends StatelessWidget {
  final BonggolanOutput output;
  final VoidCallback? onTap;
  final bool canPrint;

  const _BonggolanOutputTile({
    required this.output,
    this.onTap,
    this.canPrint = true,
  });

  Future<void> _handlePrint(BuildContext context) async {
    final noBonggolan = (output.noBonggolan ?? '').trim();
    if (noBonggolan.isEmpty) return;

    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final lockApi = LabelPrintLockApi();
    final repo = BonggolanRepository();
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    var isLockAcquired = false;
    var isPrinted = false;

    try {
      await lockApi.acquire(noBonggolan);
      isLockAcquired = true;

      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: Uri.parse(ApiConstants.bonggolanLabelPdf(noBonggolan)),
        title: noBonggolan,
        onPrinted: () {
          isPrinted = true;
          () async {
            var needsIncrement = false;
            var needsRelease = false;

            try {
              final count = await repo.markAsPrinted(noBonggolan);
              if (count != null) {
                lockVm.setPrintCount(noBonggolan, count);
              }
            } catch (_) {
              needsIncrement = true;
            }

            try {
              await lockApi.release(noBonggolan);
            } catch (_) {
              needsRelease = true;
            }

            if (needsIncrement || needsRelease) {
              await queue.enqueue(
                feature: 'bonggolan',
                noLabel: noBonggolan,
                needsIncrement: needsIncrement,
                needsReleaseLock: needsRelease,
              );
            }
          }().ignore();
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (isLockAcquired && !isPrinted) {
        () async {
          try {
            await lockApi.release(noBonggolan);
          } catch (_) {
            await queue.enqueue(
              feature: 'bonggolan',
              noLabel: noBonggolan,
              needsReleaseLock: true,
            );
          }
        }().ignore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBrokerBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            onTap ??
            () {
              showDialog<void>(
                context: context,
                builder: (_) => _BonggolanOutputDetailDialog(
                  output: output,
                  onPrint: canPrint ? () => _handlePrint(context) : null,
                ),
              );
            },
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
                      (output.namaBonggolan ?? '').isNotEmpty
                          ? output.namaBonggolan!
                          : (output.noBonggolan ?? '-'),
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
                    color: output.printedCount > 0
                        ? _kBrokerOutput
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'x${output.printedCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: output.printedCount > 0
                          ? _kBrokerOutput
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                output.noBonggolan ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              ProductionMiniMetric(
                icon: Icons.scale_outlined,
                text: '${num2(output.berat)} kg',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrokerOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;

  const _BrokerOutputSummaryTile({
    required this.totalLabel,
    required this.totalSak,
    required this.totalBerat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kBrokerOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBrokerOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kBrokerOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Sak',
            value: '$totalSak',
            color: _kBrokerOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: _kBrokerOutput,
          ),
        ],
      ),
    );
  }
}

class _OutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;

  const _OutputGrandTotalBar({
    required this.totalLabel,
    required this.totalSak,
    required this.totalBerat,
  });

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
              const Icon(
                Icons.summarize_outlined,
                size: 13,
                color: _kBrokerOutput,
              ),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kBrokerOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: _kBrokerOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Sak',
                value: '$totalSak',
                color: _kBrokerOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Berat',
                value: '${num2(totalBerat)} kg',
                color: _kBrokerOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BonggolanOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final double totalBerat;

  const _BonggolanOutputSummaryTile({
    required this.totalLabel,
    required this.totalBerat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kBrokerOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBrokerOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kBrokerOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: _kBrokerOutput,
          ),
        ],
      ),
    );
  }
}

class _BrokerOutputDetailDialog extends StatelessWidget {
  final BrokerOutput output;
  final VoidCallback? onPrint;
  final VoidCallback? onPrintQc;

  const _BrokerOutputDetailDialog({
    required this.output,
    this.onPrint,
    this.onPrintQc,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _kBrokerOutput,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.list_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          output.namaJenis ?? '-',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          output.noBroker ?? '-',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            const Divider(height: 1, color: _kBrokerBorder),
            // Grid sak
            Flexible(
              child: output.detailSak.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Tidak ada detail sak',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                              childAspectRatio: 1.6,
                            ),
                        itemCount: output.detailSak.length,
                        itemBuilder: (_, i) {
                          final s = output.detailSak[i];
                          return Container(
                            decoration: BoxDecoration(
                              color: _kBrokerOutput.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: _kBrokerOutput.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sak ${s.noSak ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _kBrokerOutput,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${num2(s.berat)} kg',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const Divider(height: 1, color: _kBrokerBorder),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onPrintQc != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onPrintQc!();
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
                      label: const Text('Print QC'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: BorderSide(color: Colors.deepPurple.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (onPrintQc != null) const SizedBox(width: 8),
                  if (onPrint != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onPrint!();
                      },
                      icon: const Icon(Icons.print_outlined, size: 15),
                      label: const Text('Print Label'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kBrokerOutput,
                        side: BorderSide(
                          color: _kBrokerOutput.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  if (onPrint != null) const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBrokerBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

class _BonggolanOutputDetailDialog extends StatelessWidget {
  final BonggolanOutput output;
  final VoidCallback? onPrint;

  const _BonggolanOutputDetailDialog({required this.output, this.onPrint});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _kBrokerOutput,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.list_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      output.namaBonggolan ?? '-',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    output.noBonggolan ?? '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D23),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProductionMiniMetric(
                    icon: Icons.scale_outlined,
                    text: '${num2(output.berat)} kg',
                  ),
                  const SizedBox(height: 8),
                  ProductionMiniMetric(
                    icon: Icons.print_outlined,
                    text: 'Print ${output.printedCount}x',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBrokerBorder),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onPrint != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onPrint!();
                      },
                      icon: const Icon(Icons.print_outlined, size: 15),
                      label: const Text('Print'),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kBrokerBorder),
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
