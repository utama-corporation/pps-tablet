import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/production/shared/shared.dart';

import '../../../../common/widgets/confirm_dialog.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/widgets/add_cabinet_material_dialog.dart';
import '../../shared/widgets/confirm_save_temp_dialog.dart';
import '../../shared/widgets/save_button_with_badge.dart';
import '../../shared/widgets/unsaved_temp_warning_dialog.dart';
import '../model/inject_batch_model.dart' show InjectBatchSubmitResult;
import '../model/inject_output_model.dart';
import '../model/inject_production_inputs_model.dart';
import '../model/inject_formula_model.dart';
import '../model/inject_production_model.dart'
    show InjectOutputJenis, InjectProduction;
import '../repository/inject_production_repository.dart';
import '../view_model/inject_production_input_view_model.dart';

import '../view_model/inject_formula_view_model.dart';
import '../../shared/widgets/production_output_detail_dialog.dart';
import '../../../label/bonggolan/repository/bonggolan_repository.dart';
import '../../../label/furniture_wip/repository/furniture_wip_repository.dart';
import '../../../label/reject/repository/reject_repository.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../widgets/inject_sak_picker_dialog.dart';
import '../widgets/inject_split_time_dialog_v1.dart';
import '../../../label/packing/repository/packing_repository.dart';

// ── Colour palette ─────────────────────────────────────────────────────────────
const _kInjectPrimary = Color(0xFF0277BD); // biru — input
const _kInjectOutput = Color(0xFF00695C); // darker teal — output
const _kInjectSurface = Color(0xFFF8F9FB);
const _kInjectBorder = Color(0xFFE2E6EA);

class InjectProductionInputScreen extends StatefulWidget {
  final String noProduksi;

  const InjectProductionInputScreen({super.key, required this.noProduksi});

  @override
  State<InjectProductionInputScreen> createState() =>
      _InjectProductionInputScreenState();
}

class _InjectProductionInputScreenState
    extends State<InjectProductionInputScreen> {
  String _selectedInputTab = 'fwip';
  String _selectedOutputTab = 'fwip';

  // ── Scan mode (full = auto-add semua item baru, partial/select = dialog manual) ──
  String _selectedMode = 'full';

  // ── Multi-select state (input) ────────────────────────────────────────────
  bool _isSelecting = false;
  final Map<String, List<dynamic>> _selectedGroups = {};

  // ── Multi-select state (output) ───────────────────────────────────────────
  bool _isSelectingOutput = false;
  final Map<String, dynamic> _selectedOutputItems = {};

  // ── Header (fetched from API) ─────────────────────────────────────────────
  final _prodRepo = InjectProductionRepository();
  InjectProduction? _header;
  // Cache label so dispose() can read it after _header may be gone
  late String _cachedBreadcrumbLabel;

  List<BreadcrumbSegment> _prevBreadcrumb = [];
  String get _breadcrumbLabel {
    final mesin = (_header?.namaMesin ?? '').trim();
    if (mesin.isNotEmpty) return '$mesin (${widget.noProduksi})';
    return widget.noProduksi;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cachedBreadcrumbLabel = widget.noProduksi;
    _loadHeader();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Capture prev here (not in initState) so any pending dispose callbacks
      // from the previous screen have already fired and reset the breadcrumb.
      _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
      _updateBreadcrumb();

      final vm = context.read<InjectProductionInputViewModel>();
      if (vm.inputsOf(widget.noProduksi) == null &&
          !vm.isInputsLoading(widget.noProduksi)) {
        vm.loadInputs(widget.noProduksi);
      }
      if (vm.outputsOf(widget.noProduksi) == null &&
          !vm.isOutputsLoading(widget.noProduksi)) {
        vm.loadOutputs(widget.noProduksi);
      }
      if (vm.bjOutputsOf(widget.noProduksi) == null &&
          !vm.isBjOutputsLoading(widget.noProduksi)) {
        vm.loadBjOutputs(widget.noProduksi);
      }
      if (vm.rejectOutputsOf(widget.noProduksi) == null &&
          !vm.isRejectOutputsLoading(widget.noProduksi)) {
        vm.loadRejectOutputs(widget.noProduksi);
      }
      if (vm.bonggolanOutputsOf(widget.noProduksi) == null &&
          !vm.isBonggolanOutputsLoading(widget.noProduksi)) {
        vm.loadBonggolanOutputs(widget.noProduksi);
      }

      context.read<InjectFormulaViewModel>().load(widget.noProduksi);
    });
  }

  Future<void> _loadHeader() async {
    try {
      final header = await _prodRepo.fetchOne(widget.noProduksi);
      if (!mounted) return;
      setState(() {
        _header = header;
        _cachedBreadcrumbLabel = _breadcrumbLabel;
        _selectedOutputTab = header.outputCategory == 'barangjadi'
            ? 'bj'
            : 'fwip';
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

  @override
  void dispose() {
    // Breadcrumb must update after the current frame — updating a ValueNotifier
    // during unmount triggers setState on AppShell while the tree is locked.
    final prev = _prevBreadcrumb;
    final label = _cachedBreadcrumbLabel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = AppShell.breadcrumb.value;
      if (current.isNotEmpty && current.last.label == label) {
        AppShell.breadcrumb.value = prev;
      }
    });
    super.dispose();
  }

  // ── Back ───────────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    final vm = context.read<InjectProductionInputViewModel>();
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
    final vm = context.read<InjectProductionInputViewModel>();
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

  Future<void> _confirmClearTemp() async {
    final vm = context.read<InjectProductionInputViewModel>();
    if (vm.totalTempCount == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Semua Temp?',
        message:
            'Apakah Anda yakin ingin menghapus ${vm.totalTempCount} item temp?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_sweep,
      ),
    );
    if (confirmed != true || !mounted) return;
    vm.clearAllTempItems();
    _showSnack('Semua temp items dihapus');
  }

  // ── Split Time (Ganti) ────────────────────────────────────────────────────

  Future<void> _openSplitTimeDialog() async {
    final h = _header;
    if (h == null || h.idMesin == 0 || h.tglProduksi == null) return;

    // Tampilkan menu pilih mode ganti
    final mode = await showDialog<_GantiMode>(
      context: context,
      builder: (ctx) => _GantiModeDialog(
        currentCetakan: h.namaCetakan,
        currentWarna: h.namaWarna,
        currentMaterial: h.namaFurnitureMaterial,
      ),
    );
    if (!mounted || mode == null) return;

    final result = await showDialog<InjectBatchSubmitResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InjectSplitTimeDialogV1(
        idMesin: h.idMesin,
        tglProduksi: h.tglProduksi!,
        currentHourEnd: h.hourEnd,
        currentCetakan: h.namaCetakan,
        currentWarna: h.namaWarna,
        currentMaterial: h.namaFurnitureMaterial,
        lockedIdCetakan: mode == _GantiMode.warnaAndMaterial
            ? h.idCetakan
            : null,
        lockedNamaCetakan: mode == _GantiMode.warnaAndMaterial
            ? h.namaCetakan
            : null,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      _showSnack('✅ Produksi berhasil diganti', backgroundColor: Colors.green);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── Complete (Selesaikan produksi) ─────────────────────────────────────────

  Future<void> _handleComplete() async {
    final vm = context.read<InjectProductionInputViewModel>();
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

  // ── Scan / Lookup ──────────────────────────────────────────────────────────

  Future<void> _openScanDialog() async {
    // Formula inputs (material yang diterima) untuk panel kiri dialog scan —
    // pola yang sama seperti Washing production input screen.
    final formulaData = context.read<InjectFormulaViewModel>().data;

    // Master Input/Output belum diset: formula termuat & ada output, tapi tidak
    // ada satu pun input formula → scan label tidak dapat dilakukan.
    final outputs = formulaData?.outputs ?? const [];
    final hasAnyFormula = outputs.any((o) => o.formulas.isNotEmpty);
    if (formulaData != null && outputs.isNotEmpty && !hasAnyFormula) {
      final jenis = outputs
          .map((o) => o.namaJenis.trim())
          .where((n) => n.isNotEmpty)
          .join(', ');
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorStatusDialog(
          title: 'Master Input Output Belum Diset',
          message:
              'Isi data output "$jenis" ke dalam Master Input Output '
              'terlebih dahulu untuk dapat melakukan proses scan label.',
        ),
      );
      return;
    }

    final formulaOutputs = outputs
        .map(
          (o) => ProductionFormulaOutput(
            idJenis: o.idJenis,
            namaJenis: o.namaJenis,
            formulas: o.formulas
                .map(
                  (f) => ProductionFormulaItem(
                    inputId: f.inputId,
                    inputNama: f.inputNama ?? '',
                    kategoriNama: f.inputKategoriNama,
                    prefixLabel: f.inputKategoriKode,
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    await showDialog<void>(
      context: context,
      builder: (_) => ProductionScanLabelDialog(
        manualHint: 'BB. / D. / H. / V.',
        headerSubtitle: _modeLabel(_selectedMode),
        primaryColor: _kInjectPrimary,
        formulaOutputs: formulaOutputs,
        onLookup: _onCodeReady,
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'full':
        return 'FULL PALLET';
      case 'partial':
        return 'PARTIAL';
      default:
        return mode.toUpperCase();
    }
  }

  // Prefix label yang valid untuk proses Inject (sesuai validasi server).
  static const List<String> _validInjectPrefixes = ['BB.', 'D.', 'H.', 'V.'];

  Future<String?> _onCodeReady(String code) async {
    // Validasi prefix di sisi klien agar pesan jelas (server balas 500 untuk
    // prefix tak dikenal: "Invalid prefix ...").
    final normalized = code.trim().toUpperCase();
    if (!_validInjectPrefixes.any((p) => normalized.startsWith(p))) {
      final prefix = normalized.contains('.')
          ? normalized.substring(0, normalized.indexOf('.') + 1)
          : normalized;
      return 'Prefix "$prefix" tidak diizinkan. '
          'Label valid: BB. (Furniture WIP), D. (Broker), H. (Mixer), V. (Gilingan).';
    }

    final vm = context.read<InjectProductionInputViewModel>();
    final res = await vm.lookupLabel(code, force: true);
    if (!mounted) return 'Halaman sudah tidak aktif';
    if (vm.lookupError != null) return 'Gagal ambil data: ${vm.lookupError}';
    if (res == null || res.found == false || res.data.isEmpty) {
      return 'Label "$code" tidak memiliki data yang tersedia.';
    }

    // Validasi kategori + jenis terhadap formula hasil fetch API (jika sudah dimuat)
    final formulaData = context.read<InjectFormulaViewModel>().data;
    if (formulaData != null && formulaData.outputs.isNotEmpty) {
      final allowedTabs = _computeAllowedTabs(formulaData);
      final tab = _tabForPrefixType(res.prefixType);

      if (allowedTabs.isNotEmpty && tab != null && !allowedTabs.contains(tab)) {
        return 'Kategori label "${code.trim()}" tidak sesuai dengan formula produksi ini.';
      }

      if (tab != null) {
        final allowedInputIds =
            _computeAllowedInputIdsByTab(formulaData)[tab] ?? const <int>{};
        if (allowedInputIds.isNotEmpty) {
          final firstRow = res.data.first;
          final rawIdJenis = firstRow['idJenis'] ?? firstRow['IdJenis'];
          if (rawIdJenis != null) {
            final idJenis = (rawIdJenis as num).toInt();
            if (!allowedInputIds.contains(idJenis)) {
              final namaJenis =
                  firstRow['namaJenis'] ??
                  firstRow['NamaJenis'] ??
                  firstRow['Jenis'] ??
                  'tidak diketahui';
              return 'Jenis "$namaJenis" tidak terdaftar dalam formula produksi ini.';
            }
          }
        }
      }
    }

    if (res.prefixType == PrefixType.furnitureWip) {
      await _handleFwipPcsFlow(vm, res);
    } else {
      // Mode FULL, SELECT & PARTIAL sama-sama menampilkan dialog konfirmasi
      // berformat kartu sak sebelum commit ke temp — mengikuti pola Mixer
      // production input screen.
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => InjectSakPickerDialog(
          noProduksi: widget.noProduksi,
          isPartialMode: _selectedMode == 'partial',
        ),
      );
    }
    return null;
  }

  /// Set tab yang boleh ditampilkan berdasarkan kategori input pada formula.
  /// Kosong = formula belum termuat / tak dikenali → tampilkan semua tab.
  Set<String> _computeAllowedTabs(InjectFormulaData? data) {
    if (data == null || data.outputs.isEmpty) return const {};
    final tabs = <String>{};
    for (final o in data.outputs) {
      for (final f in o.formulas) {
        final k = '${f.inputKategoriKode} ${f.inputKategoriNama}'.toLowerCase();
        if (k.contains('furniture') ||
            k.contains('fwip') ||
            k.contains('wip')) {
          tabs.add('fwip');
        }
        if (k.contains('broker')) tabs.add('broker');
        if (k.contains('mixer')) tabs.add('mixer');
        if (k.contains('gilingan')) tabs.add('gilingan');
        if (k.contains('material') ||
            k.contains('kabinet') ||
            k.contains('cabinet')) {
          tabs.add('material');
        }
      }
    }
    return tabs;
  }

  /// InputId formula yang diizinkan per tab, berdasarkan kategori input pada
  /// formula (hasil fetch API). Dipakai untuk validasi jenis label saat scan.
  Map<String, Set<int>> _computeAllowedInputIdsByTab(InjectFormulaData? data) {
    final map = <String, Set<int>>{};
    if (data == null) return map;
    for (final o in data.outputs) {
      for (final f in o.formulas) {
        final k = '${f.inputKategoriKode} ${f.inputKategoriNama}'.toLowerCase();
        String? tab;
        if (k.contains('furniture') ||
            k.contains('fwip') ||
            k.contains('wip')) {
          tab = 'fwip';
        } else if (k.contains('broker')) {
          tab = 'broker';
        } else if (k.contains('mixer')) {
          tab = 'mixer';
        } else if (k.contains('gilingan')) {
          tab = 'gilingan';
        }
        if (tab != null) {
          (map[tab] ??= <int>{}).add(f.inputId);
        }
      }
    }
    return map;
  }

  String? _tabForPrefixType(PrefixType type) {
    switch (type) {
      case PrefixType.furnitureWip:
        return 'fwip';
      case PrefixType.broker:
        return 'broker';
      case PrefixType.mixer:
        return 'mixer';
      case PrefixType.gilingan:
        return 'gilingan';
      default:
        return null;
    }
  }

  Future<void> _handleFwipPcsFlow(
    InjectProductionInputViewModel vm,
    ProductionLabelLookupResult res,
  ) async {
    int totalAdded = 0, totalSkipped = 0;
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
          primaryColor: _kInjectPrimary,
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
    _showSnack(
      totalAdded > 0
          ? '✅ Ditambahkan $totalAdded item${totalSkipped > 0 ? ' • $totalSkipped terlewati' : ''}'
          : 'Tidak ada item yang ditambahkan',
      backgroundColor: totalAdded > 0 ? Colors.green : Colors.orange,
    );
  }

  // ── Cabinet Material ───────────────────────────────────────────────────────

  Future<void> _openAddMaterialDialog(InjectProductionInputViewModel vm) async {
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
    InjectProductionInputViewModel vm,
    CabinetMaterialItem item,
  ) async {
    final name = item.Nama ?? 'Material';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Material?',
        message: 'Yakin ingin menghapus $name?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
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

  // ── Multi-select helpers ───────────────────────────────────────────────────

  void _startSelecting(String key, List<dynamic> items) {
    setState(() {
      _isSelecting = true;
      _selectedGroups[key] = items;
    });
  }

  void _toggleSelection(String key, List<dynamic> items) {
    setState(() {
      if (_selectedGroups.containsKey(key)) {
        _selectedGroups.remove(key);
        if (_selectedGroups.isEmpty) _isSelecting = false;
      } else {
        _selectedGroups[key] = items;
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelecting = false;
      _selectedGroups.clear();
    });
  }

  Future<void> _deleteSelected(InjectProductionInputViewModel vm) async {
    if (_selectedGroups.isEmpty) return;
    final count = _selectedGroups.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Keluarkan Label Input?',
        message:
            'Yakin ingin mengeluarkan $count label dari proses ini?\n'
            'Label tidak akan dihapus, hanya dilepas dari proses.',
        confirmLabel: 'Keluarkan',
        confirmIcon: Icons.logout,
      ),
    );
    if (confirmed != true || !mounted) return;
    final allItems = _selectedGroups.values.expand((l) => l).toList();
    final success = await vm.deleteItems(widget.noProduksi, allItems);
    if (!mounted) return;
    _cancelSelection();
    _showSnack(
      success
          ? '✅ $count label berhasil dikeluarkan dari proses'
          : (vm.deleteError ?? 'Gagal'),
      backgroundColor: success ? Colors.green : Colors.red,
    );
  }

  // ── Multi-select output helpers ────────────────────────────────────────────

  void _startSelectingOutput(String labelCode, dynamic item) {
    setState(() {
      _isSelectingOutput = true;
      _selectedOutputItems[labelCode] = item;
    });
  }

  void _toggleOutputSelection(String labelCode, dynamic item) {
    setState(() {
      if (_selectedOutputItems.containsKey(labelCode)) {
        _selectedOutputItems.remove(labelCode);
        if (_selectedOutputItems.isEmpty) _isSelectingOutput = false;
      } else {
        _selectedOutputItems[labelCode] = item;
      }
    });
  }

  void _cancelOutputSelection() {
    setState(() {
      _isSelectingOutput = false;
      _selectedOutputItems.clear();
    });
  }

  Future<void> _deleteSelectedOutputs(VoidCallback onRefresh) async {
    if (_selectedOutputItems.isEmpty) return;
    final count = _selectedOutputItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Label Output?',
        message:
            'Yakin ingin menghapus $count label yang dipilih?\n'
            'Aksi ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    int deleted = 0;
    int failed = 0;
    for (final item in _selectedOutputItems.values) {
      try {
        if (item is InjectOutputItem) {
          await FurnitureWipRepository().deleteFurnitureWip(
            item.noFurnitureWip,
          );
        } else if (item is InjectBjOutputItem) {
          await PackingRepository(api: ApiClient()).deletePacking(item.noBj);
        } else if (item is InjectRejectOutputItem) {
          await RejectRepository(api: ApiClient()).deleteReject(item.noReject);
        } else if (item is InjectBonggolanOutputItem) {
          await BonggolanRepository().deleteBonggolan(item.noBonggolan);
        }
        deleted++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _cancelOutputSelection();
    onRefresh();
    _showSnack(
      failed == 0
          ? '✅ $deleted label output berhasil dihapus'
          : '$deleted berhasil dihapus, $failed gagal',
      backgroundColor: failed == 0 ? Colors.green : Colors.orange,
    );
  }

  Widget _buildOutputSelectionBar(VoidCallback onRefresh) {
    final count = _selectedOutputItems.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kInjectOutput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count label dipilih',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: _cancelOutputSelection,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Batal', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => _deleteSelectedOutputs(onRefresh),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text(
              'Hapus',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapOutputTile({
    required String labelCode,
    required dynamic item,
    required Widget Function(VoidCallback? overrideTap) builder,
  }) {
    final isSelected = _selectedOutputItems.containsKey(labelCode);
    final tile = builder(
      _isSelectingOutput ? () => _toggleOutputSelection(labelCode, item) : null,
    );
    return GestureDetector(
      onLongPress: _isSelectingOutput
          ? null
          : () => _startSelectingOutput(labelCode, item),
      child: Stack(
        children: [
          tile,
          if (isSelected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF1565C0),
                      width: 2,
                    ),
                    color: const Color(0xFFE3F2FD).withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          if (isSelected)
            Positioned(
              top: 4,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Delete input group (single, legacy — tidak dipakai langsung) ───────────

  Future<void> _deleteInputGroup(
    InjectProductionInputViewModel vm,
    String labelKey,
    List<dynamic> items,
  ) async {
    _startSelecting(labelKey, items);
  }

  // ── Title keys ─────────────────────────────────────────────────────────────

  String _fwipTitleKey(FurnitureWipItem e) {
    final part = (e.noFurnitureWIPPartial ?? '').trim();
    return part.isNotEmpty ? part : (e.noFurnitureWIP ?? '-');
  }

  String _brokerTitleKey(BrokerItem e) {
    final part = (e.noBrokerPartial ?? '').trim();
    return part.isNotEmpty ? part : (e.noBroker ?? '-');
  }

  String _mixerTitleKey(MixerItem e) {
    final part = (e.noMixerPartial ?? '').trim();
    return part.isNotEmpty ? part : (e.noMixer ?? '-');
  }

  String _gilinganTitleKey(GilinganItem e) {
    final part = (e.noGilinganPartial ?? '').trim();
    return part.isNotEmpty ? part : (e.noGilingan ?? '-');
  }

  // ── Input panel ────────────────────────────────────────────────────────────

  Widget _buildInputPanel({
    required InjectProductionInputViewModel vm,
    required bool locked,
    required bool loading,
    required bool canDelete,
    required Map<String, List<FurnitureWipItem>> fwipGroups,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<MixerItem>> mixerGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required List<CabinetMaterialItem> materialAll,
    required Set<int> tempMaterialIds,
  }) {
    // ── per-tab metrics ────────────────────────────────────────────
    double fwipBerat = 0;
    int fwipPcs = 0;
    for (final items in fwipGroups.values) {
      for (final i in items) {
        fwipPcs += i.pcs ?? 0;
        fwipBerat += i.berat ?? 0;
      }
    }
    int brokerSak = 0;
    double brokerBerat = 0;
    for (final items in brokerGroups.values) {
      for (final i in items) {
        brokerSak += 1;
        brokerBerat += i.berat ?? 0;
      }
    }
    int mixerSak = 0;
    double mixerBerat = 0;
    for (final items in mixerGroups.values) {
      for (final i in items) {
        mixerSak += 1;
        mixerBerat += i.berat ?? 0;
      }
    }
    double gilinganBerat = 0;
    for (final items in gilinganGroups.values) {
      for (final i in items) {
        gilinganBerat += i.berat ?? 0;
      }
    }
    final materialCount = materialAll.length;

    // ── grand total ────────────────────────────────────────────────
    final grandLabel =
        fwipGroups.length +
        brokerGroups.length +
        mixerGroups.length +
        gilinganGroups.length +
        materialCount;
    final grandSak = brokerSak + mixerSak;
    final grandBerat = fwipBerat + brokerBerat + mixerBerat + gilinganBerat;

    // ── active-tab summary ─────────────────────────────────────────
    SectionSummary activeTabSummary() {
      switch (_selectedInputTab) {
        case 'fwip':
          return SectionSummary(
            totalData: fwipGroups.length,
            totalSak: fwipPcs,
            totalBerat: 0,
          );
        case 'broker':
          return SectionSummary(
            totalData: brokerGroups.length,
            totalSak: brokerSak,
            totalBerat: brokerBerat,
          );
        case 'mixer':
          return SectionSummary(
            totalData: mixerGroups.length,
            totalSak: mixerSak,
            totalBerat: mixerBerat,
          );
        case 'gilingan':
          return SectionSummary(
            totalData: gilinganGroups.length,
            totalSak: 0,
            totalBerat: gilinganBerat,
          );
        case 'material':
          return SectionSummary(
            totalData: materialCount,
            totalSak: materialCount,
            totalBerat: 0,
          );
        default:
          return SectionSummary(totalData: 0, totalSak: 0, totalBerat: 0);
      }
    }

    final tabCounts = {
      'fwip': fwipGroups.length,
      'broker': brokerGroups.length,
      'mixer': mixerGroups.length,
      'gilingan': gilinganGroups.length,
      'material': materialCount,
    };

    return Container(
      decoration: productionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 1, 1, 1),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.input_rounded,
                  'Label Input',
                  primaryColor: _kInjectPrimary,
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
          const Divider(height: 1, color: _kInjectBorder),
          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductionFolderTabBar(
                    selectedValue: _selectedInputTab,
                    accentColor: _kInjectPrimary,
                    tabs: [
                      ProductionTabItem(
                        value: 'fwip',
                        label: 'Furniture WIP',
                        count: tabCounts['fwip'] ?? 0,
                      ),
                      ProductionTabItem(
                        value: 'broker',
                        label: 'Broker',
                        count: tabCounts['broker'] ?? 0,
                      ),
                      ProductionTabItem(
                        value: 'mixer',
                        label: 'Mixer',
                        count: tabCounts['mixer'] ?? 0,
                      ),
                      ProductionTabItem(
                        value: 'gilingan',
                        label: 'Gilingan',
                        count: tabCounts['gilingan'] ?? 0,
                      ),
                      ProductionTabItem(
                        value: 'material',
                        label: 'Material',
                        count: tabCounts['material'] ?? 0,
                      ),
                    ],
                    onChanged: (v) {
                      if (_selectedInputTab != v) {
                        setState(() {
                          _selectedInputTab = v;
                          _isSelecting = false;
                          _selectedGroups.clear();
                        });
                      }
                    },
                  ),
                  Expanded(
                    child: ProductionInputCategoryBlock(
                      color: _kInjectPrimary,
                      isLoading: loading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (ctx, c) => SizedBox(
                                width: c.maxWidth,
                                child: _buildActiveInputTab(
                                  vm: vm,
                                  locked: locked,
                                  canDelete: canDelete,
                                  fwipGroups: fwipGroups,
                                  brokerGroups: brokerGroups,
                                  mixerGroups: mixerGroups,
                                  gilinganGroups: gilinganGroups,
                                  materialAll: materialAll,
                                  tempMaterialIds: tempMaterialIds,
                                  constraints: c,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_isSelecting)
                            _buildSelectionBar(vm)
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ProductionCategorySummaryTile(
                                        summary: activeTabSummary(),
                                        accentColor: _kInjectPrimary,
                                        sakLabel:
                                            (_selectedInputTab == 'fwip' ||
                                                _selectedInputTab == 'material')
                                            ? 'Qty'
                                            : 'Sak',
                                        showBerat:
                                            _selectedInputTab != 'fwip' &&
                                            _selectedInputTab != 'material',
                                        showLabel:
                                            _selectedInputTab != 'material',
                                      ),
                                      const SizedBox(height: 6),
                                      ProductionInputGrandTotalBar(
                                        totalLabel: grandLabel,
                                        totalSak: grandSak,
                                        totalBerat: grandBerat,
                                        color: _kInjectPrimary,
                                        sakLabel: 'Qty',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_selectedInputTab == 'material')
                                  FloatingActionButton(
                                    heroTag: 'fab_add_inject_material',
                                    mini: true,
                                    backgroundColor: locked
                                        ? Colors.grey.shade300
                                        : _kInjectPrimary,
                                    foregroundColor: Colors.white,
                                    onPressed: locked
                                        ? null
                                        : () => _openAddMaterialDialog(vm),
                                    child: const Icon(Icons.add),
                                  )
                                else
                                  FloatingActionButton(
                                    heroTag: 'fab_scan_inject_input',
                                    mini: true,
                                    backgroundColor: locked
                                        ? Colors.grey.shade300
                                        : _kInjectPrimary,
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

  Widget _buildActiveInputTab({
    required InjectProductionInputViewModel vm,
    required bool locked,
    required bool canDelete,
    required Map<String, List<FurnitureWipItem>> fwipGroups,
    required Map<String, List<BrokerItem>> brokerGroups,
    required Map<String, List<MixerItem>> mixerGroups,
    required Map<String, List<GilinganItem>> gilinganGroups,
    required List<CabinetMaterialItem> materialAll,
    required Set<int> tempMaterialIds,
    required BoxConstraints constraints,
  }) {
    switch (_selectedInputTab) {
      case 'fwip':
        return _buildFwipTab(
          vm: vm,
          fwipGroups: fwipGroups,
          constraints: constraints,
        );
      case 'broker':
        return _buildLabelGroupTab<BrokerItem>(
          groups: brokerGroups,
          emptyMessage: 'Belum ada label Broker',
          constraints: constraints,
          tileBuilder: (key, items) => ProductionInputGroupTile(
            title: (items.isNotEmpty ? items.first.namaJenis : '-') ?? '-',
            headerSubtitle: key,
            tileMetrics: [
              (
                Icons.scale_outlined,
                '${items.fold<double>(0, (s, i) => s + (i.berat ?? 0)).toStringAsFixed(1)} kg',
              ),
            ],
            color: _kInjectPrimary,
            isTemp: items.any(
              (x) =>
                  vm.tempBroker.contains(x) || vm.tempBrokerPartial.contains(x),
            ),
            isPartialGroup: items.any((x) => x.isPartialRow),
            isSelected: _selectedGroups.containsKey(key),
            onTap: _isSelecting ? () => _toggleSelection(key, items) : null,
            onLongPress: _isSelecting
                ? null
                : () => _deleteInputGroup(vm, key, items),
            chipItemsBuilder: () => items.map<ProductionSakChip>((item) {
              final isTemp =
                  vm.tempBroker.contains(item) ||
                  vm.tempBrokerPartial.contains(item);
              return ProductionSakChip(
                label: item.noBroker ?? '-',
                berat: item.berat,
                isTemp: isTemp,
                isPartial: item.isPartialRow,
                onDelete: isTemp ? () => vm.deleteTempBrokerItem(item) : null,
              );
            }).toList(),
          ),
        );
      case 'mixer':
        return _buildLabelGroupTab<MixerItem>(
          groups: mixerGroups,
          emptyMessage: 'Belum ada label Mixer',
          constraints: constraints,
          tileBuilder: (key, items) => ProductionInputGroupTile(
            title: (items.isNotEmpty ? items.first.namaJenis : '-') ?? '-',
            headerSubtitle: key,
            tileMetrics: [
              (
                Icons.scale_outlined,
                '${items.fold<double>(0, (s, i) => s + (i.berat ?? 0)).toStringAsFixed(1)} kg',
              ),
            ],
            color: _kInjectPrimary,
            isTemp: items.any(
              (x) =>
                  vm.tempMixer.contains(x) || vm.tempMixerPartial.contains(x),
            ),
            isPartialGroup: items.any((x) => x.isPartialRow),
            isSelected: _selectedGroups.containsKey(key),
            onTap: _isSelecting ? () => _toggleSelection(key, items) : null,
            onLongPress: _isSelecting
                ? null
                : () => _deleteInputGroup(vm, key, items),
            chipItemsBuilder: () => items.map<ProductionSakChip>((item) {
              final isTemp =
                  vm.tempMixer.contains(item) ||
                  vm.tempMixerPartial.contains(item);
              return ProductionSakChip(
                label: item.noMixer ?? '-',
                berat: item.berat,
                isTemp: isTemp,
                isPartial: item.isPartialRow,
                onDelete: isTemp ? () => vm.deleteTempMixerItem(item) : null,
              );
            }).toList(),
          ),
        );
      case 'gilingan':
        return _buildLabelGroupTab<GilinganItem>(
          groups: gilinganGroups,
          emptyMessage: 'Belum ada label Gilingan',
          constraints: constraints,
          tileBuilder: (key, items) => ProductionInputGroupTile(
            title: (items.isNotEmpty ? items.first.namaJenis : '-') ?? '-',
            headerSubtitle: key,
            tileMetrics: [
              (
                Icons.scale_outlined,
                '${items.fold<double>(0, (s, i) => s + (i.berat ?? 0)).toStringAsFixed(1)} kg',
              ),
            ],
            color: _kInjectPrimary,
            isTemp: items.any(
              (x) =>
                  vm.tempGilingan.contains(x) ||
                  vm.tempGilinganPartial.contains(x),
            ),
            isPartialGroup: items.any((x) => x.isPartialRow),
            isSelected: _selectedGroups.containsKey(key),
            onTap: _isSelecting ? () => _toggleSelection(key, items) : null,
            onLongPress: _isSelecting
                ? null
                : () => _deleteInputGroup(vm, key, items),
            chipItemsBuilder: () => items.map<ProductionSakChip>((item) {
              final isTemp =
                  vm.tempGilingan.contains(item) ||
                  vm.tempGilinganPartial.contains(item);
              return ProductionSakChip(
                label: item.noGilingan ?? '-',
                berat: item.berat,
                isTemp: isTemp,
                isPartial: item.isPartialRow,
                onDelete: isTemp ? () => vm.deleteTempGilinganItem(item) : null,
              );
            }).toList(),
          ),
        );
      case 'material':
        return _buildMaterialTab(
          vm: vm,
          locked: locked,
          canDelete: canDelete,
          materialAll: materialAll,
          tempMaterialIds: tempMaterialIds,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFwipTab({
    required InjectProductionInputViewModel vm,
    required Map<String, List<FurnitureWipItem>> fwipGroups,
    required BoxConstraints constraints,
  }) {
    return ProductionOutputCategoryContent(
      footer: const SizedBox.shrink(),
      child: fwipGroups.isEmpty
          ? const Center(
              child: Text('Tidak ada data', style: TextStyle(fontSize: 11)),
            )
          : GridView(
              padding: const EdgeInsets.all(6),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth < 380 ? 2 : 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                mainAxisExtent: 72,
              ),
              children: fwipGroups.entries.map((entry) {
                final hasPartial = entry.value.any((x) => x.isPartialRow);
                // Selalu tampilkan noFurnitureWIP (nomor label asli), bukan
                // noFurnitureWIPPartial — grouping key (entry.key) tetap
                // dipakai untuk matching/delete temp item.
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
                  color: _kInjectPrimary,
                  isTemp: entry.value.any(
                    (x) =>
                        vm.tempFurnitureWip.contains(x) ||
                        vm.tempFurnitureWipPartial.contains(x),
                  ),
                  expandable: !hasPartial,
                  isPartialGroup: hasPartial,
                  isSelected: _selectedGroups.containsKey(entry.key),
                  onTap: _isSelecting
                      ? () => _toggleSelection(entry.key, entry.value)
                      : null,
                  onLongPress: _isSelecting
                      ? null
                      : () => _deleteInputGroup(vm, entry.key, entry.value),
                  partialReference: hasPartial
                      ? (entry.value
                                .firstWhere((x) => x.isPartialRow)
                                .noFurnitureWIP ??
                            '-')
                      : null,
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
    );
  }

  Widget _buildSelectionBar(InjectProductionInputViewModel vm) {
    final count = _selectedGroups.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count label dipilih',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: _cancelSelection,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Batal', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: vm.isDeleting ? null : () => _deleteSelected(vm),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: vm.isDeleting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout, size: 14),
            label: Text(
              vm.isDeleting ? 'Memproses...' : 'Keluarkan',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelGroupTab<T>({
    required Map<String, List<T>> groups,
    required String emptyMessage,
    required BoxConstraints constraints,
    required Widget Function(String key, List<T> items) tileBuilder,
  }) {
    if (groups.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return GridView(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: constraints.maxWidth < 380 ? 2 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        mainAxisExtent: 72,
      ),
      children: groups.entries.map((e) => tileBuilder(e.key, e.value)).toList(),
    );
  }

  Widget _buildMaterialTab({
    required InjectProductionInputViewModel vm,
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

  // ── Toolbar skeleton ─────────────────────────────────────────────────────

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

  // ── Output FAB visibility ────────────────────────────────────────────────

  bool _isFabVisible({
    required bool isBj,
    required bool isReject,
    required bool isBonggolan,
  }) {
    // Reject dan Bonggolan selalu tampil
    if (isReject || isBonggolan) return true;
    final cat = _header?.outputCategory;
    if (cat == null) return true; // tidak ada kunci, semua tampil
    if (isBj) return cat == 'barangjadi';
    return cat == 'furnitureWip'; // tab fwip
  }

  // ── Output FAB actions ────────────────────────────────────────────────────

  Future<InjectOutputJenis?> _pickOutputJenis(
    List<InjectOutputJenis> options,
  ) async {
    if (options.length == 1) return options.first;
    return showDialog<InjectOutputJenis>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kInjectOutput.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.list_alt_outlined,
                        color: _kInjectOutput,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Pilih Jenis Output',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _kInjectBorder),
              // Options list
              ...options.asMap().entries.map((entry) {
                final i = entry.key;
                final o = entry.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(ctx).pop(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _kInjectOutput.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kInjectOutput,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                o.namaJenis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < options.length - 1)
                      const Divider(
                        height: 1,
                        color: _kInjectBorder,
                        indent: 18,
                        endIndent: 18,
                      ),
                  ],
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddFwipOutputDialog(VoidCallback onRefresh) async {
    int? lockedId;
    String? lockedNama;
    final lockedOutputs = _header?.outputs ?? const [];
    if (lockedOutputs.isNotEmpty) {
      final picked = await _pickOutputJenis(lockedOutputs);
      if (picked == null || !mounted) return;
      lockedId = picked.idJenis;
      lockedNama = picked.namaJenis;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductionFwipOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        accentColor: _kInjectOutput,
        lockedIdJenis: lockedId,
        lockedNamaJenis: lockedNama,
      ),
    );
    if (result == true) onRefresh();
  }

  Future<void> _openAddBjOutputDialog(VoidCallback onRefresh) async {
    int? lockedId;
    String? lockedNama;
    final lockedOutputs = _header?.outputs ?? const [];
    if (lockedOutputs.isNotEmpty) {
      final picked = await _pickOutputJenis(lockedOutputs);
      if (picked == null || !mounted) return;
      lockedId = picked.idJenis;
      lockedNama = picked.namaJenis;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductionBjOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        accentColor: _kInjectOutput,
        lockedIdJenis: lockedId,
        lockedNamaJenis: lockedNama,
      ),
    );
    if (result == true) onRefresh();
  }

  Future<void> _openAddRejectOutputDialog(VoidCallback onRefresh) async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductionRejectOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        accentColor: _kInjectOutput,
      ),
    );
    if (result != null && result != false) onRefresh();
  }

  Future<void> _deleteRejectOutput(
    InjectRejectOutputItem item,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Label Reject?',
        message:
            'Yakin ingin menghapus ${item.noReject}?\nAksi ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await RejectRepository(api: ApiClient()).deleteReject(item.noReject);
      if (!mounted) return;
      _showSnack(
        '✅ ${item.noReject} berhasil dihapus',
        backgroundColor: Colors.green,
      );
      onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menghapus: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _deleteBjOutput(
    InjectBjOutputItem item,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Label Barang Jadi?',
        message:
            'Yakin ingin menghapus ${item.noBj}?\nAksi ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await PackingRepository(api: ApiClient()).deletePacking(item.noBj);
      if (!mounted) return;
      _showSnack(
        '✅ ${item.noBj} berhasil dihapus',
        backgroundColor: Colors.green,
      );
      onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menghapus: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _deleteFwipOutput(
    InjectOutputItem item,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Label Furniture WIP?',
        message:
            'Yakin ingin menghapus ${item.noFurnitureWip}?\nAksi ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FurnitureWipRepository().deleteFurnitureWip(item.noFurnitureWip);
      if (!mounted) return;
      _showSnack(
        '✅ ${item.noFurnitureWip} berhasil dihapus',
        backgroundColor: Colors.green,
      );
      onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menghapus: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _deleteBonggolanOutput(
    InjectBonggolanOutputItem item,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Label Bonggolan?',
        message:
            'Yakin ingin menghapus ${item.noBonggolan}?\nAksi ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await BonggolanRepository().deleteBonggolan(item.noBonggolan);
      if (!mounted) return;
      _showSnack(
        '✅ ${item.noBonggolan} berhasil dihapus',
        backgroundColor: Colors.green,
      );
      onRefresh();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Gagal menghapus: $e', backgroundColor: Colors.red);
    }
  }

  Future<void> _openAddBonggolanOutputDialog(VoidCallback onRefresh) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductionBonggolanOutputFormDialog(
        noProduksi: widget.noProduksi,
        tglProduksi: _header?.tglProduksi,
        accentColor: _kInjectOutput,
      ),
    );
    if (result == true) onRefresh();
  }

  // ── Output panel ───────────────────────────────────────────────────────────

  Widget _buildOutputPanel({
    required List<InjectOutputItem> fwipOutputs,
    required bool fwipLoading,
    required String? fwipError,
    required List<InjectBjOutputItem> bjOutputs,
    required bool bjLoading,
    required String? bjError,
    required List<InjectRejectOutputItem> rejectOutputs,
    required bool rejectLoading,
    required String? rejectError,
    required List<InjectBonggolanOutputItem> bonggolanOutputs,
    required bool bonggolanLoading,
    required String? bonggolanError,
    required VoidCallback onRefresh,
  }) {
    final isReject = _selectedOutputTab == 'reject';
    final isBj = _selectedOutputTab == 'bj';
    final isBonggolan = _selectedOutputTab == 'bonggolan';
    final isLoading = isBonggolan
        ? bonggolanLoading
        : isReject
        ? rejectLoading
        : isBj
        ? bjLoading
        : fwipLoading;
    final error = isBonggolan
        ? bonggolanError
        : isReject
        ? rejectError
        : isBj
        ? bjError
        : fwipError;
    final fwipPcs = fwipOutputs.fold<int>(0, (s, o) => s + o.pcs);
    final fwipBerat = fwipOutputs.fold<double>(0, (s, o) => s + o.berat);
    final bjPcs = bjOutputs.fold<int>(0, (s, o) => s + o.pcs);
    final rejectBerat = rejectOutputs.fold<double>(0, (s, o) => s + o.berat);
    final bonggolanBerat = bonggolanOutputs.fold<double>(
      0,
      (s, o) => s + o.berat,
    );

    return Container(
      decoration: productionPanelDecoration(
        borderColor: _kInjectOutput.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 1, 1, 1),
            child: Row(
              children: [
                productionSectionHeader(
                  Icons.output_rounded,
                  'Label Output',
                  iconColor: _kInjectOutput,
                  primaryColor: _kInjectPrimary,
                ),
                const Spacer(),
                Opacity(
                  opacity: 0,
                  child: IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kInjectBorder),
          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null) ...[
                    ProductionOutputErrorBanner(message: error),
                    const SizedBox(height: 10),
                  ],
                  ProductionFolderTabBar(
                    selectedValue: _selectedOutputTab,
                    accentColor: _kInjectOutput,
                    tabs: [
                      if (_header?.outputCategory != 'barangjadi')
                        ProductionTabItem(
                          value: 'fwip',
                          label: 'Furniture WIP',
                          count: fwipOutputs.length,
                        ),
                      if (_header?.outputCategory != 'furnitureWip')
                        ProductionTabItem(
                          value: 'bj',
                          label: 'Barang Jadi',
                          count: bjOutputs.length,
                        ),
                      ProductionTabItem(
                        value: 'reject',
                        label: 'Reject',
                        count: rejectOutputs.length,
                      ),
                      ProductionTabItem(
                        value: 'bonggolan',
                        label: 'Bonggolan',
                        count: bonggolanOutputs.length,
                      ),
                    ],
                    onChanged: (v) {
                      if (_selectedOutputTab == v) return;
                      setState(() {
                        _selectedOutputTab = v;
                        _isSelectingOutput = false;
                        _selectedOutputItems.clear();
                      });
                    },
                  ),
                  Expanded(
                    child: ProductionInputCategoryBlock(
                      color: _kInjectOutput,
                      isLoading: isLoading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (ctx, c) =>
                                  ProductionOutputCategoryContent(
                                    footer: const SizedBox.shrink(),
                                    child: isBonggolan
                                        ? _buildBonggolanOutputGrid(
                                            bonggolanOutputs,
                                            c,
                                            onRefresh,
                                          )
                                        : isReject
                                        ? _buildRejectOutputGrid(
                                            rejectOutputs,
                                            c,
                                            onRefresh,
                                          )
                                        : isBj
                                        ? _buildBjOutputGrid(
                                            bjOutputs,
                                            c,
                                            onRefresh,
                                          )
                                        : _buildFwipOutputGrid(
                                            fwipOutputs,
                                            c,
                                            onRefresh,
                                          ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_isSelectingOutput)
                            _buildOutputSelectionBar(onRefresh)
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ProductionCategorySummaryTile(
                                        summary: SectionSummary(
                                          totalData: isBonggolan
                                              ? bonggolanOutputs.length
                                              : isReject
                                              ? rejectOutputs.length
                                              : isBj
                                              ? bjOutputs.length
                                              : fwipOutputs.length,
                                          totalSak: isBj
                                              ? bjPcs
                                              : (!isBonggolan && !isReject)
                                              ? fwipPcs
                                              : 0,
                                          totalBerat: isBonggolan
                                              ? bonggolanBerat
                                              : isReject
                                              ? rejectBerat
                                              : fwipBerat,
                                        ),
                                        accentColor: _kInjectOutput,
                                        sakLabel: 'Qty',
                                      ),
                                      const SizedBox(height: 6),
                                      ProductionInputGrandTotalBar(
                                        totalLabel:
                                            fwipOutputs.length +
                                            bjOutputs.length +
                                            rejectOutputs.length +
                                            bonggolanOutputs.length,
                                        totalSak: fwipPcs + bjPcs,
                                        totalBerat:
                                            fwipBerat +
                                            rejectBerat +
                                            bonggolanBerat,
                                        color: _kInjectOutput,
                                        sakLabel: 'Qty',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_isFabVisible(
                                  isBj: isBj,
                                  isReject: isReject,
                                  isBonggolan: isBonggolan,
                                ))
                                  FloatingActionButton(
                                    heroTag:
                                        'fab_add_inject_output_$_selectedOutputTab',
                                    mini: true,
                                    backgroundColor:
                                        (_header == null || _header!.isLocked)
                                        ? Colors.grey.shade300
                                        : _kInjectOutput,
                                    foregroundColor: Colors.white,
                                    onPressed:
                                        (_header == null || _header!.isLocked)
                                        ? null
                                        : () {
                                            if (isBonggolan) {
                                              _openAddBonggolanOutputDialog(
                                                onRefresh,
                                              );
                                            } else if (isReject) {
                                              _openAddRejectOutputDialog(
                                                onRefresh,
                                              );
                                            } else if (isBj) {
                                              _openAddBjOutputDialog(onRefresh);
                                            } else {
                                              _openAddFwipOutputDialog(
                                                onRefresh,
                                              );
                                            }
                                          },
                                    child: const Icon(Icons.add),
                                  )
                                else
                                  const SizedBox(width: 40),
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

  Widget _buildFwipOutputGrid(
    List<InjectOutputItem> outputs,
    BoxConstraints c,
    VoidCallback onRefresh,
  ) {
    if (outputs.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada label output furniture WIP',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return GridView(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: c.maxWidth < 380 ? 2 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        mainAxisExtent: 78,
      ),
      children: outputs
          .map(
            (o) => _wrapOutputTile(
              labelCode: o.noFurnitureWip,
              item: o,
              builder: (overrideTap) => ProductionFwipOutputTile(
                labelCode: o.noFurnitureWip,
                namaJenis: o.namaJenis,
                pcs: o.pcs,
                berat: o.berat,
                printCount: o.hasBeenPrinted,
                accentColor: _kInjectOutput,
                onTap:
                    overrideTap ??
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => ProductionOutputDetailDialog(
                        labelCode: o.noFurnitureWip,
                        namaJenis: o.namaJenis,
                        printCount: o.hasBeenPrinted,
                        accentColor: _kInjectOutput,
                        pdfUrl: ApiConstants.furnitureWipLabelPdf(
                          o.noFurnitureWip,
                        ),
                        feature: 'furniture_wip',
                        markAsPrinted: () => FurnitureWipRepository()
                            .markAsPrinted(o.noFurnitureWip),
                        onDelete: (_header == null || _header!.isLocked)
                            ? null
                            : () => _deleteFwipOutput(o, onRefresh),
                        metrics: [
                          ProductionMetric(
                            icon: Icons.inventory_2_outlined,
                            text: '${o.pcs} pcs',
                          ),
                          if (o.berat > 0)
                            ProductionMetric(
                              icon: Icons.scale_outlined,
                              text: '${o.berat} kg',
                            ),
                        ],
                      ),
                    ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBonggolanOutputGrid(
    List<InjectBonggolanOutputItem> outputs,
    BoxConstraints c,
    VoidCallback onRefresh,
  ) {
    if (outputs.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada label output bonggolan',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return GridView(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: c.maxWidth < 380 ? 2 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        mainAxisExtent: 78,
      ),
      children: outputs
          .map(
            (o) => _wrapOutputTile(
              labelCode: o.noBonggolan,
              item: o,
              builder: (overrideTap) => ProductionBonggolanOutputTile(
                labelCode: o.noBonggolan,
                namaJenis: o.namaBonggolan,
                berat: o.berat,
                printCount: o.hasBeenPrinted,
                accentColor: _kInjectOutput,
                onTap:
                    overrideTap ??
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => ProductionOutputDetailDialog(
                        labelCode: o.noBonggolan,
                        namaJenis: o.namaBonggolan,
                        printCount: o.hasBeenPrinted,
                        accentColor: _kInjectOutput,
                        pdfUrl: ApiConstants.bonggolanLabelPdf(o.noBonggolan),
                        feature: 'bonggolan',
                        markAsPrinted: () =>
                            BonggolanRepository().markAsPrinted(o.noBonggolan),
                        onDelete: (_header == null || _header!.isLocked)
                            ? null
                            : () => _deleteBonggolanOutput(o, onRefresh),
                        metrics: [
                          ProductionMetric(
                            icon: Icons.scale_outlined,
                            text: '${o.berat} kg',
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRejectOutputGrid(
    List<InjectRejectOutputItem> outputs,
    BoxConstraints c,
    VoidCallback onRefresh,
  ) {
    if (outputs.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada label output reject',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return GridView(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: c.maxWidth < 380 ? 2 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        mainAxisExtent: 78,
      ),
      children: outputs
          .map(
            (o) => _wrapOutputTile(
              labelCode: o.noReject,
              item: o,
              builder: (overrideTap) => ProductionRejectOutputTile(
                labelCode: o.noReject,
                namaJenis: o.namaJenis,
                berat: o.berat,
                printCount: o.hasBeenPrinted,
                pcs: o.pcs,
                accentColor: _kInjectOutput,
                onTap:
                    overrideTap ??
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => ProductionOutputDetailDialog(
                        labelCode: o.noReject,
                        namaJenis: o.namaJenis,
                        printCount: o.hasBeenPrinted,
                        accentColor: _kInjectOutput,
                        pdfUrl: ApiConstants.rejectLabelPdf(o.noReject),
                        feature: 'reject',
                        markAsPrinted: () => RejectRepository(
                          api: ApiClient(),
                        ).markAsPrinted(o.noReject),
                        onDelete: (_header == null || _header!.isLocked)
                            ? null
                            : () => _deleteRejectOutput(o, onRefresh),
                        metrics: [
                          ProductionMetric(
                            icon: Icons.scale_outlined,
                            text: '${o.berat} kg',
                          ),
                          if (o.pcs != null)
                            ProductionMetric(
                              icon: Icons.inventory_2_outlined,
                              text: '${o.pcs} pcs',
                            ),
                        ],
                      ),
                    ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBjOutputGrid(
    List<InjectBjOutputItem> outputs,
    BoxConstraints c,
    VoidCallback onRefresh,
  ) {
    if (outputs.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada label output barang jadi',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    return GridView(
      padding: const EdgeInsets.all(6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: c.maxWidth < 380 ? 2 : 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        mainAxisExtent: 78,
      ),
      children: outputs
          .map(
            (o) => _wrapOutputTile(
              labelCode: o.noBj,
              item: o,
              builder: (overrideTap) => ProductionBjOutputTile(
                labelCode: o.noBj,
                namaJenis: o.namaJenis,
                pcs: o.pcs,
                isPrinted: o.isPrinted,
                accentColor: _kInjectOutput,
                onTap:
                    overrideTap ??
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => ProductionOutputDetailDialog(
                        labelCode: o.noBj,
                        namaJenis: o.namaJenis,
                        printCount: o.hasBeenPrinted,
                        accentColor: _kInjectOutput,
                        pdfUrl: ApiConstants.packingLabelPdf(o.noBj),
                        feature: 'packing',
                        markAsPrinted: () => PackingRepository(
                          api: ApiClient(),
                        ).markAsPrinted(o.noBj),
                        onDelete: (_header == null || _header!.isLocked)
                            ? null
                            : () => _deleteBjOutput(o, onRefresh),
                        metrics: [
                          ProductionMetric(
                            icon: Icons.inventory_2_outlined,
                            text: '${o.pcs} pcs',
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<InjectProductionInputViewModel>(
      builder: (context, vm, _) {
        final loading = vm.isInputsLoading(widget.noProduksi);
        final err = vm.inputsError(widget.noProduksi);
        final inputs = vm.inputsOf(widget.noProduksi);
        final perm = context.watch<PermissionViewModel>();
        final locked = _header?.isLocked == true;
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
            backgroundColor: _kInjectSurface,
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                if (_header == null)
                  _buildToolbarSkeleton()
                else
                  ProductionWorkspaceToolbar(
                    isLocked: locked,
                    idMesin: _header?.idMesin,
                    namaJenis: _header?.namaJenis ?? _header?.namaMesin,
                    namaJenisList: (_header?.outputs ?? [])
                        .map((o) => o.namaJenis)
                        .toList(),
                    tglProduksi: _header?.tglProduksi,
                    shift: _header?.shift,
                    hourStart: _header?.hourStart,
                    hourEnd: _header?.hourEnd,
                    showTimeInfo: false,
                    primaryColor: _kInjectPrimary,
                    produksiStatus: _header?.produksiStatus,
                    onComplete: (_header?.isComplete == true)
                        ? null
                        : _handleComplete,
                    completeDisabledReason: (_header?.isComplete == true)
                        ? 'Produksi sudah selesai'
                        : null,
                    onGanti: _openSplitTimeDialog,
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
                      final brokerAll = loading
                          ? <BrokerItem>[]
                          : [
                              ...vm.tempBroker.reversed,
                              ...vm.tempBrokerPartial.reversed,
                              ...?inputs?.broker,
                            ];
                      final mixerAll = loading
                          ? <MixerItem>[]
                          : [
                              ...vm.tempMixer.reversed,
                              ...vm.tempMixerPartial.reversed,
                              ...?inputs?.mixer,
                            ];
                      final gilinganAll = loading
                          ? <GilinganItem>[]
                          : [
                              ...vm.tempGilingan.reversed,
                              ...vm.tempGilinganPartial.reversed,
                              ...?inputs?.gilingan,
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
                      final brokerGroups = _groupBy(brokerAll, _brokerTitleKey);
                      final mixerGroups = _groupBy(mixerAll, _mixerTitleKey);
                      final gilinganGroups = _groupBy(
                        gilinganAll,
                        _gilinganTitleKey,
                      );

                      final outputPanel = Expanded(
                        child: _buildOutputPanel(
                          fwipOutputs: vm.outputsOf(widget.noProduksi) ?? [],
                          fwipLoading: vm.isOutputsLoading(widget.noProduksi),
                          fwipError: vm.outputsError(widget.noProduksi),
                          bjOutputs: vm.bjOutputsOf(widget.noProduksi) ?? [],
                          bjLoading: vm.isBjOutputsLoading(widget.noProduksi),
                          bjError: vm.bjOutputsError(widget.noProduksi),
                          rejectOutputs:
                              vm.rejectOutputsOf(widget.noProduksi) ?? [],
                          rejectLoading: vm.isRejectOutputsLoading(
                            widget.noProduksi,
                          ),
                          rejectError: vm.rejectOutputsError(widget.noProduksi),
                          bonggolanOutputs:
                              vm.bonggolanOutputsOf(widget.noProduksi) ?? [],
                          bonggolanLoading: vm.isBonggolanOutputsLoading(
                            widget.noProduksi,
                          ),
                          bonggolanError: vm.bonggolanOutputsError(
                            widget.noProduksi,
                          ),
                          onRefresh: () {
                            vm.loadOutputs(widget.noProduksi, force: true);
                            vm.loadBjOutputs(widget.noProduksi, force: true);
                            vm.loadRejectOutputs(
                              widget.noProduksi,
                              force: true,
                            );
                            vm.loadBonggolanOutputs(
                              widget.noProduksi,
                              force: true,
                            );
                          },
                        ),
                      );
                      final inputPanel = Expanded(
                        child: _buildInputPanel(
                          vm: vm,
                          locked: locked,
                          loading: loading,
                          canDelete: canDelete,
                          fwipGroups: fwipGroups,
                          brokerGroups: brokerGroups,
                          mixerGroups: mixerGroups,
                          gilinganGroups: gilinganGroups,
                          materialAll: materialAll,
                          tempMaterialIds: tempMaterialIds,
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            inputPanel,
                            const SizedBox(width: 16),
                            outputPanel,
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

// ── Ganti mode ────────────────────────────────────────────────────────────────

enum _GantiMode { cetakan, warnaAndMaterial }

class _GantiModeDialog extends StatelessWidget {
  const _GantiModeDialog({
    this.currentCetakan,
    this.currentWarna,
    this.currentMaterial,
  });

  final String? currentCetakan;
  final String? currentWarna;
  final String? currentMaterial;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0F766E);

    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Pilih Jenis Ganti',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if ((currentCetakan ?? '').isNotEmpty) ...[
                Text(
                  'Produksi saat ini: ${currentCetakan ?? '-'}'
                  '${(currentWarna ?? '').isNotEmpty ? ' · ${currentWarna}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              option(
                icon: Icons.view_in_ar_rounded,
                title: 'Ganti Cetakan',
                subtitle: 'Pilih cetakan, warna & material baru dari awal',
                onTap: () => Navigator.of(context).pop(_GantiMode.cetakan),
              ),
              const SizedBox(height: 10),
              option(
                icon: Icons.palette_outlined,
                title: 'Ganti Warna & Material',
                subtitle: 'Cetakan tetap sama, hanya ganti warna & material',
                onTap: () =>
                    Navigator.of(context).pop(_GantiMode.warnaAndMaterial),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isTemp ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTemp ? const Color(0xFFFFD54F) : const Color(0xFFE2E6EA),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.Nama ?? 'Material',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jumlah: ${item.Jumlah ?? 0} ${item.NamaUOM ?? ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (isTemp && onDeleteTemp != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
              onPressed: onDeleteTemp,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            )
          else if (!isTemp && onDeleteExisting != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFF9CA3AF),
              ),
              onPressed: onDeleteExisting,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}
