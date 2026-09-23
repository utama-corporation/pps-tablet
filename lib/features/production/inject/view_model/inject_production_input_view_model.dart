// lib/features/production/inject_production/view_model/inject_production_input_view_model.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../repository/inject_production_input_repository.dart';
import '../model/inject_output_model.dart';
import '../model/inject_production_inputs_model.dart';

// ⬇️ shared lookup result model
import 'package:pps_tablet/features/production/shared/models/production_label_lookup_result.dart';
import 'package:pps_tablet/features/production/shared/models/bahan_pendukung_item.dart';

// -----------------------------------------------------------------------------
// Small value objects
// -----------------------------------------------------------------------------
class TempCommitResult {
  final int added;
  final int skipped;
  const TempCommitResult(this.added, this.skipped);
}

class TempItemsByLabel {
  final String labelCode;
  final List<BrokerItem> brokerItems;
  final List<BrokerItem> brokerPartials;
  final List<MixerItem> mixerItems;
  final List<MixerItem> mixerPartials;
  final List<GilinganItem> gilinganItems;
  final List<GilinganItem> gilinganPartials;
  final List<FurnitureWipItem> furnitureWipItems;
  final List<FurnitureWipItem> furnitureWipPartials;
  final DateTime addedAt;

  TempItemsByLabel({
    required this.labelCode,
    this.brokerItems = const [],
    this.brokerPartials = const [],
    this.mixerItems = const [],
    this.mixerPartials = const [],
    this.gilinganItems = const [],
    this.gilinganPartials = const [],
    this.furnitureWipItems = const [],
    this.furnitureWipPartials = const [],
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int get totalCount =>
      brokerItems.length +
          brokerPartials.length +
          mixerItems.length +
          mixerPartials.length +
          gilinganItems.length +
          gilinganPartials.length +
          furnitureWipItems.length +
          furnitureWipPartials.length;

  bool get isEmpty => totalCount == 0;

  List<dynamic> get allItems => [
    ...brokerItems,
    ...brokerPartials,
    ...mixerItems,
    ...mixerPartials,
    ...gilinganItems,
    ...gilinganPartials,
    ...furnitureWipItems,
    ...furnitureWipPartials,
  ];
}

// -----------------------------------------------------------------------------
// ViewModel
// -----------------------------------------------------------------------------
class InjectProductionInputViewModel extends ChangeNotifier {
  final InjectProductionInputRepository repository;
  InjectProductionInputViewModel({required this.repository});

  // ---------------------------------------------------------------------------
  // Debug control
  // ---------------------------------------------------------------------------
  static const bool _verbose = true;
  void _d(String message) {
    if (kDebugMode && _verbose) debugPrint('[InjectInputVM] $message');
  }

  // ---------- DEBUG HELPERS ----------
  String _nn(Object? v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();

  String _kg(num? v) =>
      v == null ? '-' : (v is int ? '$v' : v.toStringAsFixed(2));

  String _labelOf(dynamic it) => _getItemLabelCode(it) ?? '-';

  String displayTitleOf(dynamic it) {
    if (it is BrokerItem) {
      return (it.noBrokerPartial ?? '').trim().isNotEmpty
          ? it.noBrokerPartial!
          : '${_nn(it.noBroker)} #${it.noSak ?? 0}';
    }
    if (it is MixerItem) {
      return (it.noMixerPartial ?? '').trim().isNotEmpty
          ? it.noMixerPartial!
          : '${_nn(it.noMixer)} #${it.noSak ?? 0}';
    }
    if (it is GilinganItem) {
      return (it.noGilinganPartial ?? '').trim().isNotEmpty
          ? it.noGilinganPartial!
          : _nn(it.noGilingan);
    }
    if (it is FurnitureWipItem) {
      return (it.noFurnitureWIPPartial ?? '').trim().isNotEmpty
          ? it.noFurnitureWIPPartial!
          : _nn(it.noFurnitureWIP);
    }
    if (it is CabinetMaterialItem) {
      return it.Nama ?? 'Material ${it.IdCabinetMaterial ?? 0}';
    }
    return '-';
  }

  String _fmtItem(dynamic it) {
    final t = displayTitleOf(it);
    if (it is BrokerItem) {
      final isPart = (it.noBrokerPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[BROKER•PART] $t • ${_kg(it.berat)}kg'
          : '[BROKER] $t • ${_kg(it.berat)}kg';
    }
    if (it is MixerItem) {
      final isPart = (it.noMixerPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[MIXER•PART] $t • ${_kg(it.berat)}kg'
          : '[MIXER] $t • ${_kg(it.berat)}kg';
    }
    if (it is GilinganItem) {
      final isPart = (it.noGilinganPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[GILINGAN•PART] $t • ${_kg(it.berat)}kg'
          : '[GILINGAN] $t • ${_kg(it.berat)}kg';
    }
    if (it is FurnitureWipItem) {
      final isPart = (it.noFurnitureWIPPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[FWIP•PART] $t • ${it.pcs ?? 0} pcs • ${_kg(it.berat)}kg'
          : '[FWIP] $t • ${it.pcs ?? 0} pcs • ${_kg(it.berat)}kg';
    }
    if (it is CabinetMaterialItem) {
      final j = it.Jumlah ?? 0;
      final u = it.NamaUOM ?? 'unit';
      final s = it.SaldoAkhir ?? 0;
      return '[MAT] $t • Jumlah=$j $u • SaldoAkhir=$s $u';
    }
    return '[UNKNOWN] $it';
  }

  void _dumpList<T>(String name, List<T> list, String Function(T) keyer) {
    _d('$name (${list.length})');
    for (var i = 0; i < list.length; i++) {
      final it = list[i] as dynamic;
      _d('  [$i] ${_fmtItem(it)} | label=${_labelOf(it)} | key=${keyer(it)}');
    }
  }

  void debugDumpTempLists({String tag = ''}) {
    if (!_verbose) return;
    final hdr = tag.isEmpty ? '' : ' <$tag>';
    _d('========== TEMP LIST DUMP$hdr ==========');
    _dumpList('tempBroker', tempBroker, _keyFromBrokerItem);
    _dumpList('tempBrokerPartial', tempBrokerPartial, _keyFromBrokerItem);
    _dumpList('tempMixer', tempMixer, _keyFromMixerItem);
    _dumpList('tempMixerPartial', tempMixerPartial, _keyFromMixerItem);
    _dumpList('tempGilingan', tempGilingan, _keyFromGilinganItem);
    _dumpList('tempGilinganPartial', tempGilinganPartial, _keyFromGilinganItem);
    _dumpList('tempFurnitureWip', tempFurnitureWip, _keyFromFurnitureWipItem);
    _dumpList('tempFurnitureWipPartial', tempFurnitureWipPartial, _keyFromFurnitureWipItem);
    _dumpList('tempCabinetMaterial', tempCabinetMaterial, _keyFromCabinetMaterialItem);
    _d('TOTAL TEMP COUNT = $totalTempCount');
    _d('========================================');
  }

  void debugDumpTempByLabel() {
    if (!_verbose) return;
    _d('---------- TEMP GROUPED BY LABEL ----------');
    if (_tempItemsByLabel.isEmpty) {
      _d('(empty)');
      return;
    }
    _tempItemsByLabel.forEach((label, bucket) {
      _d('Label "$label" • total=${bucket.totalCount} • since=${bucket.addedAt.toIso8601String()}');
      for (final it in bucket.allItems) {
        _d('  - ${_fmtItem(it)}');
      }
    });
    _d('-------------------------------------------');
  }

  void debugDumpTempKeys({String tag = ''}) {
    if (!_verbose) return;
    final hdr = tag.isEmpty ? '' : ' <$tag>';
    _d('~~~~ TEMP KEYS DUMP$hdr ~~~~');
    _d('_tempKeys (${_tempKeys.length})');
    if (_tempKeys.isEmpty) {
      _d('(empty)');
    } else {
      var i = 0;
      for (final k in _tempKeys) {
        _d('  [$i] $k');
        i++;
        if (i >= 300) {
          _d('  ... (truncated)');
          break;
        }
      }
    }
    _d('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  // ---------------------------------------------------------------------------
  // Inputs per row (cache, loading & error per NoProduksi)
  // ---------------------------------------------------------------------------
  final Map<String, InjectProductionInputs> _inputsCache = {};
  final Map<String, bool> _inputsLoading = {};
  final Map<String, String?> _inputsError = {};
  final Map<String, Future<InjectProductionInputs>> _inflight = {};

  bool isInputsLoading(String noProduksi) =>
      _inputsLoading[noProduksi] == true;
  String? inputsError(String noProduksi) => _inputsError[noProduksi];
  InjectProductionInputs? inputsOf(String noProduksi) => _inputsCache[noProduksi];
  int inputsCount(String noProduksi, String key) =>
      _inputsCache[noProduksi]?.summary[key] ?? 0;

  Future<InjectProductionInputs?> loadInputs(String noProduksi,
      {bool force = false}) async {
    if (!force && _inputsCache.containsKey(noProduksi)) {
      return _inputsCache[noProduksi];
    }
    if (!force && _inflight.containsKey(noProduksi)) {
      try {
        return await _inflight[noProduksi];
      } catch (_) {}
    }

    _inputsLoading[noProduksi] = true;
    _inputsError[noProduksi] = null;
    notifyListeners();

    final future = repository.fetchInputs(noProduksi, force: force);
    _inflight[noProduksi] = future;

    try {
      final result = await future;
      _inputsCache[noProduksi] = result;
      return result;
    } catch (e) {
      _inputsError[noProduksi] = e.toString();
      return null;
    } finally {
      _inflight.remove(noProduksi);
      _inputsLoading[noProduksi] = false;
      notifyListeners();
    }
  }

  void clearInputsCache([String? noProduksi]) {
    if (noProduksi == null) {
      _inputsCache.clear();
      _inputsLoading.clear();
      _inputsError.clear();
    } else {
      _inputsCache.remove(noProduksi);
      _inputsLoading.remove(noProduksi);
      _inputsError.remove(noProduksi);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Outputs (Furniture WIP)
  // ---------------------------------------------------------------------------
  final Map<String, List<InjectOutputItem>> _outputsCache = {};
  final Map<String, bool> _outputsLoading = {};
  final Map<String, String?> _outputsError = {};

  bool isOutputsLoading(String noProduksi) =>
      _outputsLoading[noProduksi] == true;
  String? outputsError(String noProduksi) => _outputsError[noProduksi];
  List<InjectOutputItem>? outputsOf(String noProduksi) =>
      _outputsCache[noProduksi];

  Future<void> loadOutputs(String noProduksi, {bool force = false}) async {
    if (!force && _outputsCache.containsKey(noProduksi)) return;
    _outputsLoading[noProduksi] = true;
    _outputsError[noProduksi] = null;
    notifyListeners();
    try {
      final items = await repository.fetchOutputs(noProduksi, force: force);
      _outputsCache[noProduksi] = items;
    } catch (e) {
      _outputsError[noProduksi] = e.toString();
    } finally {
      _outputsLoading[noProduksi] = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // BJ Outputs (Barang Jadi)
  // ---------------------------------------------------------------------------
  final Map<String, List<InjectBjOutputItem>> _bjOutputsCache = {};
  final Map<String, bool> _bjOutputsLoading = {};
  final Map<String, String?> _bjOutputsError = {};

  bool isBjOutputsLoading(String noProduksi) =>
      _bjOutputsLoading[noProduksi] == true;
  String? bjOutputsError(String noProduksi) => _bjOutputsError[noProduksi];
  List<InjectBjOutputItem>? bjOutputsOf(String noProduksi) =>
      _bjOutputsCache[noProduksi];

  Future<void> loadBjOutputs(String noProduksi, {bool force = false}) async {
    if (!force && _bjOutputsCache.containsKey(noProduksi)) return;
    _bjOutputsLoading[noProduksi] = true;
    _bjOutputsError[noProduksi] = null;
    notifyListeners();
    try {
      final items = await repository.fetchBjOutputs(noProduksi, force: force);
      _bjOutputsCache[noProduksi] = items;
    } catch (e) {
      _bjOutputsError[noProduksi] = e.toString();
    } finally {
      _bjOutputsLoading[noProduksi] = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Reject Outputs
  // ---------------------------------------------------------------------------
  final Map<String, List<InjectRejectOutputItem>> _rejectOutputsCache = {};
  final Map<String, bool> _rejectOutputsLoading = {};
  final Map<String, String?> _rejectOutputsError = {};

  bool isRejectOutputsLoading(String noProduksi) =>
      _rejectOutputsLoading[noProduksi] == true;
  String? rejectOutputsError(String noProduksi) =>
      _rejectOutputsError[noProduksi];
  List<InjectRejectOutputItem>? rejectOutputsOf(String noProduksi) =>
      _rejectOutputsCache[noProduksi];

  Future<void> loadRejectOutputs(
    String noProduksi, {
    bool force = false,
  }) async {
    if (!force && _rejectOutputsCache.containsKey(noProduksi)) return;
    _rejectOutputsLoading[noProduksi] = true;
    _rejectOutputsError[noProduksi] = null;
    notifyListeners();
    try {
      final items = await repository.fetchRejectOutputs(
        noProduksi,
        force: force,
      );
      _rejectOutputsCache[noProduksi] = items;
    } catch (e) {
      _rejectOutputsError[noProduksi] = e.toString();
    } finally {
      _rejectOutputsLoading[noProduksi] = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Bonggolan Outputs
  // ---------------------------------------------------------------------------
  final Map<String, List<InjectBonggolanOutputItem>> _bonggolanOutputsCache =
      {};
  final Map<String, bool> _bonggolanOutputsLoading = {};
  final Map<String, String?> _bonggolanOutputsError = {};

  bool isBonggolanOutputsLoading(String noProduksi) =>
      _bonggolanOutputsLoading[noProduksi] == true;
  String? bonggolanOutputsError(String noProduksi) =>
      _bonggolanOutputsError[noProduksi];
  List<InjectBonggolanOutputItem>? bonggolanOutputsOf(String noProduksi) =>
      _bonggolanOutputsCache[noProduksi];

  Future<void> loadBonggolanOutputs(
    String noProduksi, {
    bool force = false,
  }) async {
    if (!force && _bonggolanOutputsCache.containsKey(noProduksi)) return;
    _bonggolanOutputsLoading[noProduksi] = true;
    _bonggolanOutputsError[noProduksi] = null;
    notifyListeners();
    try {
      final items = await repository.fetchBonggolanOutputs(
        noProduksi,
        force: force,
      );
      _bonggolanOutputsCache[noProduksi] = items;
    } catch (e) {
      _bonggolanOutputsError[noProduksi] = e.toString();
    } finally {
      _bonggolanOutputsLoading[noProduksi] = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Master Cabinet Materials (fetch all from endpoint)
  // ---------------------------------------------------------------------------
  final Map<int, List<CabinetMaterialItem>> _masterCabinetByWh = {};
  final Map<int, bool> _masterCabinetLoading = {};
  final Map<int, String?> _masterCabinetError = {};

  bool isMasterCabinetLoading(int idWarehouse) =>
      _masterCabinetLoading[idWarehouse] == true;
  String? masterCabinetError(int idWarehouse) =>
      _masterCabinetError[idWarehouse];
  List<CabinetMaterialItem> masterCabinetMaterials(int idWarehouse) =>
      _masterCabinetByWh[idWarehouse] ?? const [];

  Future<List<CabinetMaterialItem>> loadMasterCabinetMaterials({
    required int idWarehouse,
    bool force = false,
  }) async {
    if (!force && _masterCabinetByWh.containsKey(idWarehouse)) {
      return _masterCabinetByWh[idWarehouse]!;
    }

    _masterCabinetLoading[idWarehouse] = true;
    _masterCabinetError[idWarehouse] = null;
    notifyListeners();

    try {
      final items = await repository.fetchMasterCabinetMaterials(
        idWarehouse: idWarehouse,
        force: force,
      );
      _masterCabinetByWh[idWarehouse] = items;
      return items;
    } catch (e) {
      _masterCabinetError[idWarehouse] = e.toString();
      return const [];
    } finally {
      _masterCabinetLoading[idWarehouse] = false;
      notifyListeners();
    }
  }

  void clearMasterCabinetCache([int? idWarehouse]) {
    if (idWarehouse == null) {
      _masterCabinetByWh.clear();
      _masterCabinetLoading.clear();
      _masterCabinetError.clear();
    } else {
      _masterCabinetByWh.remove(idWarehouse);
      _masterCabinetLoading.remove(idWarehouse);
      _masterCabinetError.remove(idWarehouse);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lookup Label (MULTI-PREFIX: BB., D., H., V.)
  // ---------------------------------------------------------------------------
  final Map<String, ProductionLabelLookupResult> _lookupCache = {};
  bool isLookupLoading = false;
  String? lookupError;
  ProductionLabelLookupResult? lastLookup;

  final Map<String, TempItemsByLabel> _tempItemsByLabel = {};

  /// ✅ Universal label lookup (supports BB., D., H., V.)
  Future<ProductionLabelLookupResult?> lookupLabel(String code,
      {bool force = false}) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      lookupError = 'Kode label kosong';
      notifyListeners();
      return null;
    }

    if (!force && _lookupCache.containsKey(trimmed)) {
      lastLookup = _lookupCache[trimmed];
      lookupError = null;
      notifyListeners();
      return lastLookup;
    }

    isLookupLoading = true;
    lookupError = null;
    notifyListeners();

    try {
      final result = await repository.lookupLabel(trimmed);
      _lookupCache[trimmed] = result;
      lastLookup = result;
      return result;
    } catch (e) {
      lookupError = e.toString();
      return null;
    } finally {
      isLookupLoading = false;
      notifyListeners();
    }
  }

  void clearLookupCache([String? code]) {
    if (code == null) {
      _lookupCache.clear();
    } else {
      _lookupCache.remove(code.trim());
    }
    lastLookup = null;
    lookupError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cabinet Material TEMP (manual from master dropdown)
  // ---------------------------------------------------------------------------

  /// ✅ Add cabinet material to temp using master item + jumlah input
  void addTempCabinetMaterialFromMaster({
    required CabinetMaterialItem masterItem,
    required num Jumlah,
  }) {
    final id = masterItem.IdCabinetMaterial ?? 0;
    if (id <= 0) {
      _d('⚠️ addTempCabinetMaterialFromMaster: IdCabinetMaterial invalid');
      return;
    }

    // ✅ Jika sudah ada, update Jumlah
    final idx = tempCabinetMaterial
        .indexWhere((x) => (x.IdCabinetMaterial ?? 0) == id);
    if (idx >= 0) {
      final old = tempCabinetMaterial[idx];
      tempCabinetMaterial[idx] = old.copyWith(Jumlah: Jumlah);
      _d('✅ Updated existing material temp: ${tempCabinetMaterial[idx].toDebugString()}');
      debugDumpTempLists(tag: 'after addTempCabinetMaterialFromMaster(update)');
      notifyListeners();
      return;
    }

    // ✅ Create temp item = copy master + set Jumlah
    final newItem = masterItem.copyWith(Jumlah: Jumlah);

    tempCabinetMaterial.add(newItem);
    _tempKeys.add(_keyFromCabinetMaterialItem(newItem));

    _d('✅ Added cabinet material to temp: ${newItem.toDebugString()}');
    debugDumpTempLists(tag: 'after addTempCabinetMaterialFromMaster(add)');
    notifyListeners();
  }

  /// ✅ Update jumlah material yang sudah ada di temp
  void updateTempCabinetMaterialJumlah({
    required int IdCabinetMaterial,
    required num Jumlah,
  }) {
    final idx = tempCabinetMaterial
        .indexWhere((x) => (x.IdCabinetMaterial ?? 0) == IdCabinetMaterial);
    if (idx == -1) {
      _d('⚠️ Material $IdCabinetMaterial not found in temp');
      return;
    }
    final old = tempCabinetMaterial[idx];
    tempCabinetMaterial[idx] = old.copyWith(Jumlah: Jumlah);

    _d('✅ Updated cabinet material temp: ${tempCabinetMaterial[idx].toDebugString()}');
    debugDumpTempLists(tag: 'after updateTempCabinetMaterialJumlah');
    notifyListeners();
  }

  /// ✅ Check if cabinet material already in temp
  bool hasCabinetMaterialInTemp(int IdCabinetMaterial) {
    return tempCabinetMaterial
        .any((x) => (x.IdCabinetMaterial ?? 0) == IdCabinetMaterial);
  }

  // ---------------------------------------------------------------------------
  // Bahan Pendukung (BP.) scan — langsung ambil semua quantity
  // ---------------------------------------------------------------------------

  bool hasScannedBahanPendukungLabel(String labelCode) {
    final c = labelCode.trim();
    if (c.isEmpty) return false;
    for (final labels in _scannedBahanPendukungByMaterial.values) {
      if (labels.contains(c)) return true;
    }
    return false;
  }

  /// ✅ Tambahkan bahan pendukung dari hasil scan/input manual — langsung
  /// mengambil SEMUA quantity label (Qty/QtySisa) menjadi material temp,
  /// tanpa dialog pilih sak. Label yang sudah pernah discan di-skip agar
  /// jumlahnya tidak dobel.
  ///
  /// Mengembalikan jumlah material yang baru ditambahkan.
  int addScannedBahanPendukung(List<BahanPendukungItem> items) {
    final seenInScan = <String>{};
    final groups =
        <int, ({BahanPendukungItem item, num qty, List<String> labels})>{};
    for (final it in items) {
      final id = it.idCabinetMaterial ?? 0;
      if (id <= 0) continue;
      final label = (it.noBahanPendukung ?? '').trim();
      final isDup = label.isNotEmpty &&
          (seenInScan.contains(label) ||
              hasScannedBahanPendukungLabel(label));
      seenInScan.add(label);

      final prev = groups[id]?.labels ?? const <String>[];
      final prevQty = groups[id]?.qty ?? 0;
      groups[id] = (
        item: it,
        qty: prevQty + (isDup ? 0 : it.quantity),
        labels: [if (label.isNotEmpty) ...prev, if (label.isNotEmpty) label],
      );
    }

    int added = 0;
    groups.forEach((id, g) {
      final idx = tempCabinetMaterial
          .indexWhere((x) => (x.IdCabinetMaterial ?? 0) == id);
      if (idx >= 0) {
        final old = tempCabinetMaterial[idx];
        tempCabinetMaterial[idx] =
            old.copyWith(Jumlah: (old.Jumlah ?? 0) + g.qty);
      } else {
        tempCabinetMaterial.add(
          CabinetMaterialItem(
            IdCabinetMaterial: id,
            Nama: g.item.namaJenis,
            NamaUOM: g.item.namaUom,
            ItemCode: g.item.itemCode,
            Jumlah: g.qty,
          ),
        );
        _tempKeys.add(_keyFromCabinetMaterialItem(tempCabinetMaterial.last));
      }
      (_scannedBahanPendukungByMaterial[id] ??= <String>{}).addAll(g.labels);
      if (g.qty > 0) added++;
    });
    if (added > 0) notifyListeners();
    return added;
  }

  /// ✅ Get total jumlah cabinet material (temp + db)
  num getTotalCabinetMaterialJumlah(String noProduksi) {
    final inputs = _inputsCache[noProduksi];

    final tempTotal = tempCabinetMaterial.fold<num>(
      0,
          (sum, item) => sum + (item.Jumlah ?? 0),
    );

    final dbTotal = (inputs?.cabinetMaterial ?? []).fold<num>(
      0,
          (sum, item) => sum + (item.Jumlah ?? 0),
    );

    return tempTotal + dbTotal;
  }

  // ---------------------------------------------------------------------------
  // Temporary data by label
  // ---------------------------------------------------------------------------
  bool hasTemporaryDataForLabel(String labelCode) {
    final tempItems = _tempItemsByLabel[labelCode.trim()];
    return tempItems != null && !tempItems.isEmpty;
  }

  TempItemsByLabel? getTemporaryDataForLabel(String labelCode) =>
      _tempItemsByLabel[labelCode.trim()];

  String getTemporaryDataSummary(String labelCode) {
    final t = getTemporaryDataForLabel(labelCode);
    if (t == null || t.isEmpty) return 'Tidak ada data temporary';
    final s = <String>[];
    if (t.brokerItems.isNotEmpty) s.add('${t.brokerItems.length} Broker');
    if (t.brokerPartials.isNotEmpty) s.add('${t.brokerPartials.length} Broker Partial');
    if (t.mixerItems.isNotEmpty) s.add('${t.mixerItems.length} Mixer');
    if (t.mixerPartials.isNotEmpty) s.add('${t.mixerPartials.length} Mixer Partial');
    if (t.gilinganItems.isNotEmpty) s.add('${t.gilinganItems.length} Gilingan');
    if (t.gilinganPartials.isNotEmpty) s.add('${t.gilinganPartials.length} Gilingan Partial');
    if (t.furnitureWipItems.isNotEmpty) s.add('${t.furnitureWipItems.length} FWIP');
    if (t.furnitureWipPartials.isNotEmpty) s.add('${t.furnitureWipPartials.length} FWIP Partial');
    return s.join(', ');
  }

  void Function(TempItemsByLabel)? onShowTemporaryDataDialog;
  void showTemporaryDataDialog(String labelCode) {
    final t = getTemporaryDataForLabel(labelCode);
    if (t != null && !t.isEmpty) onShowTemporaryDataDialog?.call(t);
  }

  void removeTemporaryItemsForLabel(
      String labelCode, List<dynamic> itemsToRemove) {
    final trimmed = labelCode.trim();
    final t = _tempItemsByLabel[trimmed];
    if (t == null) return;

    for (final item in itemsToRemove) {
      if (item is BrokerItem) {
        tempBroker.remove(item);
        tempBrokerPartial.remove(item);
        _tempKeys.remove(_keyFromBrokerItem(item));
      } else if (item is MixerItem) {
        tempMixer.remove(item);
        tempMixerPartial.remove(item);
        _tempKeys.remove(_keyFromMixerItem(item));
      } else if (item is GilinganItem) {
        tempGilingan.remove(item);
        tempGilinganPartial.remove(item);
        _tempKeys.remove(_keyFromGilinganItem(item));
      } else if (item is FurnitureWipItem) {
        tempFurnitureWip.remove(item);
        tempFurnitureWipPartial.remove(item);
        _tempKeys.remove(_keyFromFurnitureWipItem(item));
      }
    }

    _updateTempItemsByLabel(trimmed);
    notifyListeners();
  }

  void _updateTempItemsByLabel(String labelCode) {
    final code = labelCode.trim();

    final brokerFull = tempBroker.where((e) => _getItemLabelCode(e) == code).toList();
    final brokerPart = tempBrokerPartial.where((e) => _getItemLabelCode(e) == code).toList();
    final mixerFull = tempMixer.where((e) => _getItemLabelCode(e) == code).toList();
    final mixerPart = tempMixerPartial.where((e) => _getItemLabelCode(e) == code).toList();
    final gilingFull = tempGilingan.where((e) => _getItemLabelCode(e) == code).toList();
    final gilingPart = tempGilinganPartial.where((e) => _getItemLabelCode(e) == code).toList();
    final fwipFull = tempFurnitureWip.where((e) => _getItemLabelCode(e) == code).toList();
    final fwipPart = tempFurnitureWipPartial.where((e) => _getItemLabelCode(e) == code).toList();

    if ([brokerFull, brokerPart, mixerFull, mixerPart, gilingFull, gilingPart, fwipFull, fwipPart]
        .every((l) => l.isEmpty)) {
      _tempItemsByLabel.remove(code);
      return;
    }

    _tempItemsByLabel[code] = TempItemsByLabel(
      labelCode: code,
      brokerItems: brokerFull,
      brokerPartials: brokerPart,
      mixerItems: mixerFull,
      mixerPartials: mixerPart,
      gilinganItems: gilingFull,
      gilinganPartials: gilingPart,
      furnitureWipItems: fwipFull,
      furnitureWipPartials: fwipPart,
      addedAt: _tempItemsByLabel[code]?.addedAt ?? DateTime.now(),
    );
  }

  String? _getItemLabelCode(dynamic item) {
    if (item is BrokerItem) {
      final part = (item.noBrokerPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noBroker;
    }
    if (item is MixerItem) {
      final part = (item.noMixerPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noMixer;
    }
    if (item is GilinganItem) {
      final part = (item.noGilinganPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noGilingan;
    }
    if (item is FurnitureWipItem) {
      final part = (item.noFurnitureWIPPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noFurnitureWIP;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Temp selections (anti-duplicate)
  // ---------------------------------------------------------------------------
  final List<BrokerItem> tempBroker = [];
  final List<BrokerItem> tempBrokerPartial = [];
  final List<MixerItem> tempMixer = [];
  final List<MixerItem> tempMixerPartial = [];
  final List<GilinganItem> tempGilingan = [];
  final List<GilinganItem> tempGilinganPartial = [];
  final List<FurnitureWipItem> tempFurnitureWip = [];
  final List<FurnitureWipItem> tempFurnitureWipPartial = [];
  final List<CabinetMaterialItem> tempCabinetMaterial = [];

  // Label bahan pendukung (BP.) yang sudah pernah discan, dikelompokkan per
  // material. Dipakai supaya scan ulang label yang sama tidak menghitung qty
  // ganda. Direset saat material dihapus dari temp / semua temp dibersihkan.
  final Map<int, Set<String>> _scannedBahanPendukungByMaterial = {};

  final Set<String> _pickedKeys = <String>{};
  final List<Map<String, dynamic>> _pickedRows = <Map<String, dynamic>>[];
  final Map<String, int> _keyToRowIndex = {};

  final Set<String> _tempKeys = <String>{};

  // ====== key builders ======
  String _keyFromBrokerItem(BrokerItem i) =>
      'B|Broker|${i.noBroker ?? '-'}|${i.noSak ?? 0}';
  String _keyFromMixerItem(MixerItem i) =>
      'M|Mixer|${i.noMixer ?? '-'}|${i.noSak ?? 0}';
  String _keyFromGilinganItem(GilinganItem i) =>
      'G|Gilingan|${i.noGilingan ?? '-'}|';
  String _keyFromFurnitureWipItem(FurnitureWipItem i) =>
      'F|FurnitureWIP|${i.noFurnitureWIP ?? '-'}|';
  String _keyFromCabinetMaterialItem(CabinetMaterialItem i) =>
      'MAT|${i.IdCabinetMaterial ?? 0}';

  // ====== keys in DB ======
  Set<String> _dbKeysFor(String noProduksi) {
    final keys = <String>{};
    final db = _inputsCache[noProduksi];
    if (db != null) {
      for (final x in db.broker) keys.add(_keyFromBrokerItem(x));
      for (final x in db.mixer) keys.add(_keyFromMixerItem(x));
      for (final x in db.gilingan) keys.add(_keyFromGilinganItem(x));
      for (final x in db.furnitureWip) keys.add(_keyFromFurnitureWipItem(x));
    }
    return keys;
  }

  Set<String> _allKeysFor(String noProduksi) {
    final all = _dbKeysFor(noProduksi);
    all.addAll(_tempKeys);
    return all;
  }

  // ====== PUBLIC API ======
  bool isRowAlreadyPresent(Map<String, dynamic> row, String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return false;
    final simpleKey = ctx.simpleKey(row);
    return _tempKeys.contains(simpleKey);
  }

  int countNewRowsInLastLookup(String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return 0;
    return ctx.data
        .where((r) => !_tempKeys.contains(ctx.simpleKey(r)))
        .length;
  }

  bool willBeDuplicate(Map<String, dynamic> row, String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return false;
    final simpleKey = ctx.simpleKey(row);
    return _tempKeys.contains(simpleKey);
  }

  // Picks (UI)
  void togglePick(Map<String, dynamic> row) {
    final ctx = lastLookup;
    if (ctx == null) return;
    final index = ctx.data.indexOf(row);
    if (index == -1) return;

    final uniqueKey = ctx.rowKey(row);
    if (_pickedKeys.contains(uniqueKey)) {
      _pickedKeys.remove(uniqueKey);
      _pickedRows.removeWhere((r) => ctx.data.indexOf(r) == index);
      _keyToRowIndex.remove(uniqueKey);
    } else {
      _pickedKeys.add(uniqueKey);
      _pickedRows.add(row);
      _keyToRowIndex[uniqueKey] = index;
    }
    notifyListeners();
  }

  bool isPicked(Map<String, dynamic> row) {
    final ctx = lastLookup;
    if (ctx == null) return false;
    return _pickedKeys.contains(ctx.rowKey(row));
  }

  int get pickedCount => _pickedKeys.length;
  bool get hasPicked => _pickedKeys.isNotEmpty;

  String get pickedSummary {
    final ctx = lastLookup;
    if (ctx == null || !hasPicked) return '';
    return '$pickedCount ${ctx.prefixType.displayName} dipilih';
  }

  void pickAllNew(String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return;

    for (int i = 0; i < ctx.data.length; i++) {
      final row = ctx.data[i];
      final key = ctx.simpleKey(row);
      if (!_tempKeys.contains(key) && ctx.isRowValid(row)) {
        final uniqueKey = ctx.rowKey(row);
        if (_pickedKeys.add(uniqueKey)) {
          _pickedRows.add(row);
          _keyToRowIndex[uniqueKey] = i;
        }
      }
    }
    notifyListeners();
  }

  void unpickAll() => clearPicks();
  List<Map<String, dynamic>> get pickedRows =>
      List.unmodifiable(_pickedRows);

  void clearPicks() {
    _pickedKeys.clear();
    _pickedRows.clear();
    _keyToRowIndex.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Commit picked → TEMP (untuk semua kategori)
  // ---------------------------------------------------------------------------
  bool _rowIsPartial(Map<String, dynamic> row, PrefixType t) {
    final candKeys = [
      'IsPartial',
      'isPartial',
      'IsPartialRow',
      'isPartialRow'
    ];
    for (final k in candKeys) {
      final v = row[k];
      if (v is bool && v) return true;
      if (v is num && v != 0) return true;
      if (v is String && (v == '1' || v.toLowerCase() == 'true')) return true;
    }

    // Check partial codes based on prefix
    if (t == PrefixType.broker) {
      final partCode = (row['NoBrokerPartial'] ?? row['noBrokerPartial'] ?? '').toString().trim();
      return partCode.isNotEmpty;
    }
    if (t == PrefixType.mixer) {
      final partCode = (row['NoMixerPartial'] ?? row['noMixerPartial'] ?? '').toString().trim();
      return partCode.isNotEmpty;
    }
    if (t == PrefixType.gilingan) {
      final partCode = (row['NoGilinganPartial'] ?? row['noGilinganPartial'] ?? '').toString().trim();
      return partCode.isNotEmpty;
    }
    if (t == PrefixType.furnitureWip) {
      final partCode = (row['NoFurnitureWIPPartial'] ?? row['noFurnitureWIPPartial'] ?? '').toString().trim();
      return partCode.isNotEmpty;
    }

    return false;
  }

  TempCommitResult commitPickedToTemp({required String noProduksi}) {
    final ctx = lastLookup;
    if (ctx == null || _pickedRows.isEmpty) {
      return const TempCommitResult(0, 0);
    }

    final Set<String> seenTemp = Set<String>.from(_tempKeys);

    int added = 0, skipped = 0;

    final filteredData = List<Map<String, dynamic>>.from(_pickedRows);
    final filteredCtx = ProductionLabelLookupResult(
      found: ctx.found,
      message: ctx.message,
      prefix: ctx.prefix,
      tableName: ctx.tableName,
      totalRecords: filteredData.length,
      data: filteredData,
      raw: ctx.raw,
    );

    final typedItems = filteredCtx.typedItems;
    final Set<String> affectedLabels = <String>{};

    for (int i = 0; i < typedItems.length; i++) {
      final item = typedItems[i];
      final rawRow = filteredData[i];

      final simpleKey = ctx.simpleKey(rawRow);
      final bool isPartial = _rowIsPartial(rawRow, ctx.prefixType);

      bool shouldSkip = false;

      if (isPartial) {
        final existingPartial = _findExistingPartialItem(item, ctx.prefixType);
        if (existingPartial != null) {
          // For broker/mixer/gilingan: check berat
          // For FWIP: check pcs
          if (item is FurnitureWipItem) {
            final existingPcs = _getPcsFromItem(existingPartial);
            final newPcs = rawRow['pcs'] ?? rawRow['Pcs'];
            if (existingPcs == newPcs) {
              shouldSkip = true;
            }
          } else {
            final existingBerat = _getBeratFromItem(existingPartial);
            final newBerat = rawRow['berat'] ?? rawRow['Berat'];
            if (existingBerat == newBerat) {
              shouldSkip = true;
            }
          }
        }
      } else {
        if (seenTemp.contains(simpleKey)) {
          shouldSkip = true;
        }
      }

      if (shouldSkip) {
        skipped++;
        continue;
      }

      final String tempKey = _getTempKey(item);

      if (!_tempKeys.add(tempKey)) {
        skipped++;
        continue;
      }
      seenTemp.add(simpleKey);

      final newItem = _withTempPartialIfNeeded(item, ctx.prefixType, isPartial);

      bool itemAdded = false;
      if (newItem is BrokerItem) {
        if (newItem.isPartialRow) {
          tempBrokerPartial.add(newItem);
        } else {
          tempBroker.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is MixerItem) {
        if (newItem.isPartialRow) {
          tempMixerPartial.add(newItem);
        } else {
          tempMixer.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is GilinganItem) {
        if (newItem.isPartialRow) {
          tempGilinganPartial.add(newItem);
        } else {
          tempGilingan.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is FurnitureWipItem) {
        if (newItem.isPartialRow) {
          tempFurnitureWipPartial.add(newItem);
        } else {
          tempFurnitureWip.add(newItem);
        }
        itemAdded = true;
      }

      if (itemAdded) {
        final code = _getItemLabelCode(newItem);
        if (code != null && code.trim().isNotEmpty) {
          affectedLabels.add(code.trim());
        }
        added++;
      } else {
        _tempKeys.remove(tempKey);
        skipped++;
      }
    }

    for (final label in affectedLabels) {
      _updateTempItemsByLabel(label);
    }

    debugDumpTempLists(tag: 'after commitPickedToTemp');
    debugDumpTempByLabel();
    debugDumpTempKeys(tag: 'after commit');

    clearPicks();
    notifyListeners();
    return TempCommitResult(added, skipped);
  }

  String _getTempKey(dynamic item) {
    if (item is BrokerItem) return _keyFromBrokerItem(item);
    if (item is MixerItem) return _keyFromMixerItem(item);
    if (item is GilinganItem) return _keyFromGilinganItem(item);
    if (item is FurnitureWipItem) return _keyFromFurnitureWipItem(item);
    return '';
  }

  dynamic _findExistingPartialItem(dynamic item, PrefixType type) {
    if (item is BrokerItem) {
      for (final existing in tempBrokerPartial) {
        if (existing.noBroker == item.noBroker && existing.noSak == item.noSak) {
          return existing;
        }
      }
    } else if (item is MixerItem) {
      for (final existing in tempMixerPartial) {
        if (existing.noMixer == item.noMixer && existing.noSak == item.noSak) {
          return existing;
        }
      }
    } else if (item is GilinganItem) {
      for (final existing in tempGilinganPartial) {
        if (existing.noGilingan == item.noGilingan) {
          return existing;
        }
      }
    } else if (item is FurnitureWipItem) {
      for (final existing in tempFurnitureWipPartial) {
        if (existing.noFurnitureWIP == item.noFurnitureWIP) {
          return existing;
        }
      }
    }
    return null;
  }

  int? _getPcsFromItem(dynamic item) {
    if (item is FurnitureWipItem) return item.pcs;
    return null;
  }

  double? _getBeratFromItem(dynamic item) {
    if (item is BrokerItem) return item.berat;
    if (item is MixerItem) return item.berat;
    if (item is GilinganItem) return item.berat;
    if (item is FurnitureWipItem) return item.berat;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Delete temp items
  // ---------------------------------------------------------------------------

  void deleteTempBrokerItem(BrokerItem item) {
    tempBroker.remove(item);
    tempBrokerPartial.remove(item);
    _tempKeys.remove(_keyFromBrokerItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempBrokerItem');
    notifyListeners();
  }

  void deleteTempMixerItem(MixerItem item) {
    tempMixer.remove(item);
    tempMixerPartial.remove(item);
    _tempKeys.remove(_keyFromMixerItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempMixerItem');
    notifyListeners();
  }

  void deleteTempGilinganItem(GilinganItem item) {
    tempGilingan.remove(item);
    tempGilinganPartial.remove(item);
    _tempKeys.remove(_keyFromGilinganItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempGilinganItem');
    notifyListeners();
  }

  void deleteTempFurnitureWipItem(FurnitureWipItem item) {
    tempFurnitureWip.remove(item);
    tempFurnitureWipPartial.remove(item);
    _tempKeys.remove(_keyFromFurnitureWipItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempFurnitureWipItem');
    notifyListeners();
  }

  void deleteTempCabinetMaterialItem(CabinetMaterialItem item) {
    tempCabinetMaterial.remove(item);
    _tempKeys.remove(_keyFromCabinetMaterialItem(item));
    _scannedBahanPendukungByMaterial.remove(item.IdCabinetMaterial);
    debugDumpTempLists(tag: 'after deleteTempCabinetMaterialItem');
    notifyListeners();
  }

  bool isInTempKeys(String key) => _tempKeys.contains(key);
  Set<String> getTempKeysForDebug() => Set.unmodifiable(_tempKeys);

  /// ✅ Clear all temp items
  void clearAllTempItems() {
    tempBroker.clear();
    tempBrokerPartial.clear();
    tempMixer.clear();
    tempMixerPartial.clear();
    tempGilingan.clear();
    tempGilinganPartial.clear();
    tempFurnitureWip.clear();
    tempFurnitureWipPartial.clear();
    tempCabinetMaterial.clear();

    _tempKeys.clear();
    _tempItemsByLabel.clear();
    _scannedBahanPendukungByMaterial.clear();
    clearPicks();
    _tempPartialSeq = 0;

    _d('clearAllTempItems() called');
    debugDumpTempLists(tag: 'after clearAllTempItems');
    debugDumpTempByLabel();
    debugDumpTempKeys(tag: 'after clearAllTempItems');

    notifyListeners();
  }

  /// ✅ Delete any item from temp if exists (generic)
  bool deleteIfTemp(dynamic item) {
    bool ok = false;
    if (item is BrokerItem) {
      ok = tempBroker.remove(item) || tempBrokerPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromBrokerItem(item));
    } else if (item is MixerItem) {
      ok = tempMixer.remove(item) || tempMixerPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromMixerItem(item));
    } else if (item is GilinganItem) {
      ok = tempGilingan.remove(item) || tempGilinganPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromGilinganItem(item));
    } else if (item is FurnitureWipItem) {
      ok = tempFurnitureWip.remove(item) || tempFurnitureWipPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromFurnitureWipItem(item));
    } else if (item is CabinetMaterialItem) {
      ok = tempCabinetMaterial.remove(item);
      if (ok) {
        _tempKeys.remove(_keyFromCabinetMaterialItem(item));
        _scannedBahanPendukungByMaterial.remove(item.IdCabinetMaterial);
      }
    }
    if (ok) debugDumpTempLists(tag: 'after deleteIfTemp');
    return ok;
  }

  /// ✅ Delete all temp items for specific label
  int deleteAllTempForLabel(String labelCode) {
    final t = _tempItemsByLabel[labelCode.trim()];
    if (t == null || t.isEmpty) return 0;

    int removed = 0;
    for (final it in t.allItems) {
      if (deleteIfTemp(it)) removed++;
    }
    _updateTempItemsByLabel(labelCode);

    debugDumpTempLists(tag: 'after deleteAllTempForLabel:$labelCode');
    debugDumpTempByLabel();
    debugDumpTempKeys(tag: 'after deleteAllTempForLabel');

    if (removed > 0) notifyListeners();
    return removed;
  }

  // ===== Temp-partial numbering =====
  int _tempPartialSeq = 0;

  int _nextPartialSeq() {
    _tempPartialSeq++;
    return _tempPartialSeq;
  }

  String _formatTempPartial(PrefixType type, int seq) {
    final numStr = seq.toString().padLeft(1, '0');
    switch (type) {
      case PrefixType.broker:
        return 'Q.XXXXXXXX ($numStr)';
      case PrefixType.mixer:
        return 'T.XXXXXXXX ($numStr)';
      case PrefixType.gilingan:
        return 'Y.XXXXXXXX ($numStr)';
      case PrefixType.furnitureWip:
        return 'BC.XXXXXXXX ($numStr)';
      default:
        return 'TEMP ($numStr)';
    }
  }

  dynamic _withTempPartialIfNeeded(dynamic item, PrefixType t, bool isPartial) {
    if (!isPartial) return item;

    if (item is BrokerItem) {
      final already = (item.noBrokerPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq());
        return item.copyWith(noBrokerPartial: code);
      }
      return item;
    } else if (item is MixerItem) {
      final already = (item.noMixerPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq());
        return item.copyWith(noMixerPartial: code);
      }
      return item;
    } else if (item is GilinganItem) {
      final already = (item.noGilinganPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq());
        return item.copyWith(noGilinganPartial: code);
      }
      return item;
    } else if (item is FurnitureWipItem) {
      final already = (item.noFurnitureWIPPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq());
        return item.copyWith(noFurnitureWIPPartial: code);
      }
      return item;
    }

    return item;
  }

  /// ✅ Total count of all temp items
  int get totalTempCount =>
      tempBroker.length +
          tempBrokerPartial.length +
          tempMixer.length +
          tempMixerPartial.length +
          tempGilingan.length +
          tempGilinganPartial.length +
          tempFurnitureWip.length +
          tempFurnitureWipPartial.length +
          tempCabinetMaterial.length;

  // ---------------------------------------------------------------------------
  // Submit temp items
  // ---------------------------------------------------------------------------
  bool isSubmitting = false;
  String? submitError;

  /// ✅ Build payload for submit (ALL 5 categories)
  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};

    // =========================
    // Full inputs
    // =========================
    if (tempBroker.isNotEmpty) {
      payload['broker'] = tempBroker
          .map((e) => {
        'noBroker': e.noBroker,
        'noSak': e.noSak,
      })
          .toList();
    }

    if (tempMixer.isNotEmpty) {
      payload['mixer'] = tempMixer
          .map((e) => {
        'noMixer': e.noMixer,
        'noSak': e.noSak,
      })
          .toList();
    }

    if (tempGilingan.isNotEmpty) {
      payload['gilingan'] = tempGilingan
          .map((e) => {
        'noGilingan': e.noGilingan,
      })
          .toList();
    }

    if (tempFurnitureWip.isNotEmpty) {
      payload['furnitureWip'] = tempFurnitureWip
          .map((e) => {
        'noFurnitureWIP': e.noFurnitureWIP,
      })
          .toList();
    }

if (tempCabinetMaterial.isNotEmpty) {
      payload['cabinetMaterial'] = tempCabinetMaterial
          .map((e) {
        final labels =
            _scannedBahanPendukungByMaterial[e.IdCabinetMaterial ?? 0];
        return {
          'idCabinetMaterial': e.IdCabinetMaterial,
          'pcs': e.Jumlah, // backend expects 'pcs'
          // label Bahan Pendukung (BP.) yang dipakai → backend tandai
          // DateUsage=@TglProduksi agar tidak terpanggil lagi
          if (labels != null && labels.isNotEmpty)
            'noBahanPendukung': labels.toList(),
        };
      })
          .toList();
    }

    // =========================
    // Partial inputs (create partial)
    // Backend expects: brokerPartial, mixerPartial, gilinganPartial, furnitureWipPartial
    // =========================
    if (tempBrokerPartial.isNotEmpty) {
      payload['brokerPartial'] = tempBrokerPartial
          .map((e) => {
        'noBroker': e.noBroker,
        'noSak': e.noSak,
        'berat': e.berat,
      })
          .toList();
    }

    if (tempMixerPartial.isNotEmpty) {
      payload['mixerPartial'] = tempMixerPartial
          .map((e) => {
        'noMixer': e.noMixer,
        'noSak': e.noSak,
        'berat': e.berat,
      })
          .toList();
    }

    if (tempGilinganPartial.isNotEmpty) {
      payload['gilinganPartial'] = tempGilinganPartial
          .map((e) => {
        'noGilingan': e.noGilingan,
        'berat': e.berat,
      })
          .toList();
    }

    if (tempFurnitureWipPartial.isNotEmpty) {
      payload['furnitureWipPartial'] = tempFurnitureWipPartial
          .map((e) => {
        'noFurnitureWIP': e.noFurnitureWIP,
        'pcs': e.pcs,
      })
          .toList();
    }

    return payload;
  }


  /// ✅ Submit all temp items to backend
  Future<bool> submitTempItems(String noProduksi) async {
    if (totalTempCount == 0) {
      submitError = 'Tidak ada data untuk disubmit';
      notifyListeners();
      return false;
    }

    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final payload = _buildPayload();

      _d('Submitting temp items to $noProduksi');
      _d('Payload: ${json.encode(payload)}');

      final response =
      await repository.submitInputsAndPartials(noProduksi, payload);

      _d('Submit response: ${json.encode(response)}');

      final success = response['success'] as bool? ?? false;
      final data = response['data'] as Map<String, dynamic>?;

      if (!success) {
        final message = response['message'] as String? ?? 'Submit gagal';
        submitError = message;

        if (data != null) {
          final details = data['details'] as Map<String, dynamic>?;
          if (details != null) {
            _d('Submit details: ${json.encode(details)}');
          }
        }

        return false;
      }

      _d('Submit successful!');

      if (data != null) {
        final createdPartials = data['createdPartials'] as Map<String, dynamic>?;
        if (createdPartials != null) {
          _d('Created partials: ${json.encode(createdPartials)}');
        }
      }

      // ✅ Clear temp dan reload data
      clearAllTempItems();
      clearLookupCache();
      clearInputsCache(noProduksi);
      await loadInputs(noProduksi, force: true);

      return true;
    } catch (e) {
      _d('Submit error: $e');
      submitError = e.toString();
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /// ✅ Get submit summary for confirmation dialog
  String getSubmitSummary() {
    if (totalTempCount == 0) return 'Tidak ada data';

    final parts = <String>[];

    if (tempBroker.isNotEmpty) parts.add('${tempBroker.length} Broker');
    if (tempBrokerPartial.isNotEmpty) parts.add('${tempBrokerPartial.length} Broker Partial');
    if (tempMixer.isNotEmpty) parts.add('${tempMixer.length} Mixer');
    if (tempMixerPartial.isNotEmpty) parts.add('${tempMixerPartial.length} Mixer Partial');
    if (tempGilingan.isNotEmpty) parts.add('${tempGilingan.length} Gilingan');
    if (tempGilinganPartial.isNotEmpty) parts.add('${tempGilinganPartial.length} Gilingan Partial');
    if (tempFurnitureWip.isNotEmpty) parts.add('${tempFurnitureWip.length} FWIP');
    if (tempFurnitureWipPartial.isNotEmpty) parts.add('${tempFurnitureWipPartial.length} FWIP Partial');
    if (tempCabinetMaterial.isNotEmpty) parts.add('${tempCabinetMaterial.length} Cabinet Material');

    return 'Total $totalTempCount items:\n${parts.join(', ')}';
  }

  // ---------------------------------------------------------------------------
  // Delete inputs & partials (DB items)
  // ---------------------------------------------------------------------------
  bool isDeleting = false;
  String? deleteError;
  Map<String, dynamic>? lastDeleteResult;

  /// ✅ Build delete payload from items
  Map<String, dynamic> _buildDeletePayloadFromItems(List<dynamic> items) {
    final payload = <String, dynamic>{};

    void add(String key, Map<String, dynamic> row) {
      final list = (payload[key] ?? <Map<String, dynamic>>[])
      as List<Map<String, dynamic>>;
      list.add(row);
      payload[key] = list;
    }

    for (final it in items) {
      if (it is BrokerItem) {
        final isPart = it.isPartialRow ||
            ((it.noBrokerPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noBrokerPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('brokerPartial', {'noBrokerPartial': code});
          }
        } else {
          add('broker', {
            'noBroker': it.noBroker,
            'noSak': it.noSak,
          });
        }
      } else if (it is MixerItem) {
        final isPart = it.isPartialRow ||
            ((it.noMixerPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noMixerPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('mixerPartial', {'noMixerPartial': code});
          }
        } else {
          add('mixer', {
            'noMixer': it.noMixer,
            'noSak': it.noSak,
          });
        }
      } else if (it is GilinganItem) {
        final isPart = it.isPartialRow ||
            ((it.noGilinganPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noGilinganPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('gilinganPartial', {'noGilinganPartial': code});
          }
        } else {
          add('gilingan', {'noGilingan': it.noGilingan});
        }
      } else if (it is FurnitureWipItem) {
        final isPart = it.isPartialRow ||
            ((it.noFurnitureWIPPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noFurnitureWIPPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('furnitureWipPartial', {'noFurnitureWIPPartial': code});
          }
        } else {
          add('furnitureWip', {'noFurnitureWIP': it.noFurnitureWIP});
        }
      } else if (it is CabinetMaterialItem) {
        add('cabinetMaterial', {'idCabinetMaterial': it.IdCabinetMaterial});
      }
    }

    return payload;
  }

  /// ✅ Delete items (TEMP + DB)
  Future<bool> deleteItems(String noProduksi, List<dynamic> items) async {
    if (items.isEmpty) {
      deleteError = 'Tidak ada data yang dipilih untuk dihapus';
      notifyListeners();
      return false;
    }

    // ✅ Separate TEMP vs DB items
    final List<dynamic> dbItems = [];

    for (final it in items) {
      final removedFromTemp = deleteIfTemp(it);
      if (!removedFromTemp) {
        dbItems.add(it);
      }
    }

    // ✅ If all items were TEMP, no API call needed
    if (dbItems.isEmpty) {
      _d('deleteItems: hanya menghapus TEMP, tidak call API');
      notifyListeners();
      return true;
    }

    // ✅ Build payload for DB items
    final payload = _buildDeletePayloadFromItems(dbItems);
    if (payload.isEmpty) {
      deleteError = 'Tidak ada data valid untuk dihapus (payload kosong)';
      notifyListeners();
      return false;
    }

    isDeleting = true;
    deleteError = null;
    notifyListeners();

    try {
      _d('deleteItems: calling deleteInputsAndPartials for $noProduksi');
      _d('Delete payload: ${json.encode(payload)}');

      final res =
      await repository.deleteInputsAndPartials(noProduksi, payload);
      lastDeleteResult = res;

      final success = res['success'] == true;
      final message = res['message'] as String? ?? '';

      _d('Delete response: ${json.encode(res)}');

      if (!success) {
        deleteError = message.isEmpty ? 'Gagal menghapus data' : message;
        return false;
      }

      // ✅ Refresh data after successful delete
      clearInputsCache(noProduksi);
      await loadInputs(noProduksi, force: true);

      return true;
    } catch (e) {
      _d('Delete error: $e');
      deleteError = e.toString();
      return false;
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}