// lib/features/production/packing/view_model/packing_production_input_view_model.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../model/packing_output_model.dart';
import '../repository/packing_production_input_repository.dart';
import '../model/packing_production_inputs_model.dart';

// shared lookup result model (dipakai untuk lookup label)
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
  final List<FurnitureWipItem> furnitureWipItems;
  final List<FurnitureWipItem> furnitureWipPartials;
  final DateTime addedAt;

  TempItemsByLabel({
    required this.labelCode,
    this.furnitureWipItems = const [],
    this.furnitureWipPartials = const [],
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int get totalCount => furnitureWipItems.length + furnitureWipPartials.length;
  bool get isEmpty => totalCount == 0;

  List<dynamic> get allItems => [...furnitureWipItems, ...furnitureWipPartials];
}

// -----------------------------------------------------------------------------
// ViewModel
// -----------------------------------------------------------------------------
class PackingProductionInputViewModel extends ChangeNotifier {
  final PackingProductionInputRepository repository;
  PackingProductionInputViewModel({required this.repository});

  // ---------------------------------------------------------------------------
  // Debug control
  // ---------------------------------------------------------------------------
  static const bool _verbose = true;
  void _d(String message) {
    if (kDebugMode && _verbose) debugPrint('[PackingInputVM] $message');
  }

  String _nn(Object? v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();

  String _kg(num? v) =>
      v == null ? '-' : (v is int ? '$v' : v.toStringAsFixed(2));

  String _labelOf(dynamic it) => _getItemLabelCode(it) ?? '-';

  String displayTitleOf(dynamic it) {
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
    _dumpList('tempFurnitureWip', tempFurnitureWip, _keyFromFurnitureWipItem);
    _dumpList(
      'tempFurnitureWipPartial',
      tempFurnitureWipPartial,
      _keyFromFurnitureWipItem,
    );
    _dumpList(
      'tempCabinetMaterial',
      tempCabinetMaterial,
      _keyFromCabinetMaterialItem,
    );
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
      _d(
        'Label "$label" • total=${bucket.totalCount} • since=${bucket.addedAt.toIso8601String()}',
      );
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
  // Inputs per row (cache, loading & error per NoPacking)
  // ---------------------------------------------------------------------------
  final Map<String, PackingProductionInputs> _inputsCache = {};
  final Map<String, bool> _inputsLoading = {};
  final Map<String, String?> _inputsError = {};
  final Map<String, Future<PackingProductionInputs>> _inflight = {};

  bool isInputsLoading(String noPacking) => _inputsLoading[noPacking] == true;
  String? inputsError(String noPacking) => _inputsError[noPacking];
  PackingProductionInputs? inputsOf(String noPacking) =>
      _inputsCache[noPacking];
  int inputsCount(String noPacking, String key) =>
      _inputsCache[noPacking]?.summary[key] ?? 0;

  Future<PackingProductionInputs?> loadInputs(
    String noPacking, {
    bool force = false,
  }) async {
    final key = noPacking.trim();
    if (key.isEmpty) return null;

    if (!force && _inputsCache.containsKey(key)) {
      return _inputsCache[key];
    }
    if (!force && _inflight.containsKey(key)) {
      try {
        return await _inflight[key];
      } catch (_) {}
    }

    _inputsLoading[key] = true;
    _inputsError[key] = null;
    notifyListeners();

    final future = repository.fetchInputs(key, force: force);
    _inflight[key] = future;

    try {
      final result = await future;
      _inputsCache[key] = result;
      return result;
    } catch (e) {
      _inputsError[key] = e.toString();
      return null;
    } finally {
      _inflight.remove(key);
      _inputsLoading[key] = false;
      notifyListeners();
    }
  }

  void clearInputsCache([String? noPacking]) {
    if (noPacking == null) {
      _inputsCache.clear();
      _inputsLoading.clear();
      _inputsError.clear();
    } else {
      final key = noPacking.trim();
      _inputsCache.remove(key);
      _inputsLoading.remove(key);
      _inputsError.remove(key);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Outputs (Barang Jadi)
  // ---------------------------------------------------------------------------
  final Map<String, List<PackingOutput>> _outputsCache = {};
  final Map<String, bool> _outputsLoading = {};
  final Map<String, String?> _outputsError = {};

  bool isOutputsLoading(String noPacking) =>
      _outputsLoading[noPacking] == true;
  String? outputsError(String noPacking) => _outputsError[noPacking];
  List<PackingOutput>? outputsOf(String noPacking) =>
      _outputsCache[noPacking];

  Future<void> loadOutputs(String noPacking, {bool force = false}) async {
    final key = noPacking.trim();
    if (key.isEmpty) return;

    if (!force && _outputsCache.containsKey(key)) return;

    _outputsLoading[key] = true;
    _outputsError[key] = null;
    notifyListeners();

    try {
      final result = await repository.fetchOutputs(key, force: force);
      _outputsCache[key] = result;
    } catch (e) {
      _outputsError[key] = e.toString();
    } finally {
      _outputsLoading[key] = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Master Cabinet Materials
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
  // Lookup label (scan)
  // ---------------------------------------------------------------------------
  final Map<String, ProductionLabelLookupResult> _lookupCache = {};
  bool isLookupLoading = false;
  String? lookupError;
  ProductionLabelLookupResult? lastLookup;

  final Map<String, TempItemsByLabel> _tempItemsByLabel = {};

  Future<ProductionLabelLookupResult?> lookupLabel(
    String code, {
    bool force = false,
  }) async {
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
  /// tanpa dialog pilih. Label yang sudah pernah discan di-skip agar
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

  // ---------------------------------------------------------------------------
  // Cabinet Material TEMP (manual from master dropdown)
  // ---------------------------------------------------------------------------
  void addTempCabinetMaterialFromMaster({
    required CabinetMaterialItem masterItem,
    required num Jumlah,
  }) {
    final id = masterItem.IdCabinetMaterial ?? 0;
    if (id <= 0) {
      _d('⚠️ addTempCabinetMaterialFromMaster: IdCabinetMaterial invalid');
      return;
    }

    final idx = tempCabinetMaterial.indexWhere(
      (x) => (x.IdCabinetMaterial ?? 0) == id,
    );
    if (idx >= 0) {
      final old = tempCabinetMaterial[idx];
      tempCabinetMaterial[idx] = old.copyWith(Jumlah: Jumlah);
      _d(
        '✅ Updated existing material temp: ${tempCabinetMaterial[idx].toDebugString()}',
      );
      debugDumpTempLists(tag: 'after addTempCabinetMaterialFromMaster(update)');
      notifyListeners();
      return;
    }

    final newItem = masterItem.copyWith(Jumlah: Jumlah);

    tempCabinetMaterial.add(newItem);
    _tempKeys.add(_keyFromCabinetMaterialItem(newItem));

    _d('✅ Added cabinet material to temp: ${newItem.toDebugString()}');
    debugDumpTempLists(tag: 'after addTempCabinetMaterialFromMaster(add)');
    notifyListeners();
  }

  void updateTempCabinetMaterialJumlah({
    required int IdCabinetMaterial,
    required num Jumlah,
  }) {
    final idx = tempCabinetMaterial.indexWhere(
      (x) => (x.IdCabinetMaterial ?? 0) == IdCabinetMaterial,
    );
    if (idx == -1) {
      _d('⚠️ Material $IdCabinetMaterial not found in temp');
      return;
    }
    final old = tempCabinetMaterial[idx];
    tempCabinetMaterial[idx] = old.copyWith(Jumlah: Jumlah);

    _d(
      '✅ Updated cabinet material temp: ${tempCabinetMaterial[idx].toDebugString()}',
    );
    debugDumpTempLists(tag: 'after updateTempCabinetMaterialJumlah');
    notifyListeners();
  }

  bool hasCabinetMaterialInTemp(int IdCabinetMaterial) {
    return tempCabinetMaterial.any(
      (x) => (x.IdCabinetMaterial ?? 0) == IdCabinetMaterial,
    );
  }

  num getTotalCabinetMaterialJumlah(String noPacking) {
    final inputs = _inputsCache[noPacking];

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
    if (t.furnitureWipItems.isNotEmpty) {
      s.add('${t.furnitureWipItems.length} FWIP (full)');
    }
    if (t.furnitureWipPartials.isNotEmpty) {
      s.add('${t.furnitureWipPartials.length} FWIP Partial');
    }
    return s.join(', ');
  }

  void Function(TempItemsByLabel)? onShowTemporaryDataDialog;
  void showTemporaryDataDialog(String labelCode) {
    final t = getTemporaryDataForLabel(labelCode);
    if (t != null && !t.isEmpty) onShowTemporaryDataDialog?.call(t);
  }

  void removeTemporaryItemsForLabel(
    String labelCode,
    List<dynamic> itemsToRemove,
  ) {
    final trimmed = labelCode.trim();
    final t = _tempItemsByLabel[trimmed];
    if (t == null) return;

    for (final item in itemsToRemove) {
      if (item is FurnitureWipItem) {
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

    final fwipFull = tempFurnitureWip
        .where((e) => _getItemLabelCode(e) == code)
        .toList();
    final fwipPart = tempFurnitureWipPartial
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    if ([fwipFull, fwipPart].every((l) => l.isEmpty)) {
      _tempItemsByLabel.remove(code);
      return;
    }

    _tempItemsByLabel[code] = TempItemsByLabel(
      labelCode: code,
      furnitureWipItems: fwipFull,
      furnitureWipPartials: fwipPart,
      addedAt: _tempItemsByLabel[code]?.addedAt ?? DateTime.now(),
    );
  }

  String? _getItemLabelCode(dynamic item) {
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
  final List<FurnitureWipItem> tempFurnitureWip = [];
  final List<FurnitureWipItem> tempFurnitureWipPartial = [];
  final List<CabinetMaterialItem> tempCabinetMaterial = [];

  /// Label Bahan Pendukung (BP.) yang sudah discan per material temp.
  /// IdCabinetMaterial -> kumpulan NoBahanPendukung (dikirim pada submit agar
  /// backend menandai DateUsage sehingga label tidak terpanggil lagi).
  final Map<int, Set<String>> _scannedBahanPendukungByMaterial = {};

  final Set<String> _pickedKeys = <String>{};
  final List<Map<String, dynamic>> _pickedRows = <Map<String, dynamic>>[];
  final Map<String, int> _keyToRowIndex = {};

  final Set<String> _tempKeys = <String>{};

  // ===== key builders =====
  String _keyFromFurnitureWipItem(FurnitureWipItem i) =>
      'F.|FurnitureWIP|${i.noFurnitureWIP ?? '-'}|';
  String _keyFromCabinetMaterialItem(CabinetMaterialItem i) =>
      'MAT|${i.IdCabinetMaterial ?? 0}';

  Set<String> _dbKeysFor(String noPacking) {
    final keys = <String>{};
    final db = _inputsCache[noPacking];
    if (db != null) {
      for (final x in db.furnitureWip) {
        keys.add(_keyFromFurnitureWipItem(x));
      }
      // cabinet material: tidak masuk key tracking (karena update jumlah)
    }
    return keys;
  }

  Set<String> _allKeysFor(String noPacking) {
    final all = _dbKeysFor(noPacking);
    all.addAll(_tempKeys);
    return all;
  }

  // ===== public helpers =====
  bool isRowAlreadyPresent(Map<String, dynamic> row, String noPacking) {
    final ctx = lastLookup;
    if (ctx == null) return false;
    final simpleKey = ctx.simpleKey(row);
    return _tempKeys.contains(simpleKey);
  }

  int countNewRowsInLastLookup(String noPacking) {
    final ctx = lastLookup;
    if (ctx == null) return 0;
    return ctx.data.where((r) => !_tempKeys.contains(ctx.simpleKey(r))).length;
  }

  bool willBeDuplicate(Map<String, dynamic> row, String noPacking) {
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

  void pickAllNew(String noPacking) {
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
  List<Map<String, dynamic>> get pickedRows => List.unmodifiable(_pickedRows);

  void clearPicks() {
    _pickedKeys.clear();
    _pickedRows.clear();
    _keyToRowIndex.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Commit picked → TEMP (FWIP)
  // ---------------------------------------------------------------------------
  bool _rowIsPartial(Map<String, dynamic> row, PrefixType t) {
    final candKeys = ['IsPartial', 'isPartial', 'IsPartialRow', 'isPartialRow'];
    for (final k in candKeys) {
      final v = row[k];
      if (v is bool && v) return true;
      if (v is num && v != 0) return true;
      if (v is String && (v == '1' || v.toLowerCase() == 'true')) return true;
    }

    final partCode =
        (row['NoFurnitureWIPPartial'] ?? row['noFurnitureWIPPartial'] ?? '')
            .toString()
            .trim();
    return partCode.isNotEmpty;
  }

  TempCommitResult commitPickedToTemp({required String noPacking}) {
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
          final existingPcs = _getPcsFromItem(existingPartial);
          final newPcs = rawRow['pcs'] ?? rawRow['Pcs'];
          if (existingPcs == newPcs) {
            shouldSkip = true;
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

      final String tempKey = item is FurnitureWipItem
          ? _keyFromFurnitureWipItem(item)
          : simpleKey;

      if (!_tempKeys.add(tempKey)) {
        skipped++;
        continue;
      }
      seenTemp.add(simpleKey);

      final newItem = _withTempPartialIfNeeded(item, ctx.prefixType, isPartial);

      bool itemAdded = false;
      if (newItem is FurnitureWipItem) {
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

  dynamic _findExistingPartialItem(dynamic item, PrefixType type) {
    if (item is FurnitureWipItem) {
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

  // ---------------------------------------------------------------------------
  // Delete temp items
  // ---------------------------------------------------------------------------
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

  /// Daftar NoBahanPendukung (label BP.) milik material kabinet — untuk baris temp.
  List<String> bahanPendukungLabelsOf(int? IdCabinetMaterial) {
    if (IdCabinetMaterial == null) return const <String>[];
    final s = _scannedBahanPendukungByMaterial[IdCabinetMaterial];
    return s == null ? const <String>[] : s.toList()..sort();
  }

  bool deleteIfTemp(dynamic item) {
    bool ok = false;
    if (item is FurnitureWipItem) {
      ok =
          tempFurnitureWip.remove(item) || tempFurnitureWipPartial.remove(item);
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

  void clearAllTempItems() {
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

  String _formatTempPartial(int seq) {
    final numStr = seq.toString().padLeft(1, '0');
    return 'BC.XXXXXXXX ($numStr)';
  }

  dynamic _withTempPartialIfNeeded(dynamic item, PrefixType t, bool isPartial) {
    if (!isPartial) return item;

    if (item is FurnitureWipItem) {
      final already = (item.noFurnitureWIPPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(_nextPartialSeq());
        return item.copyWith(noFurnitureWIPPartial: code);
      }
      return item;
    }

    return item;
  }

  int get totalTempCount =>
      tempFurnitureWip.length +
      tempFurnitureWipPartial.length +
      tempCabinetMaterial.length;

  // ---------------------------------------------------------------------------
  // Submit temp items
  // ---------------------------------------------------------------------------
  bool isSubmitting = false;
  String? submitError;

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};

    // attach full FWIP
    if (tempFurnitureWip.isNotEmpty) {
      payload['furnitureWip'] = tempFurnitureWip
          .map(
            (e) => {
              'noFurnitureWIP': e.noFurnitureWIP, // ✅
            },
          )
          .toList();
    }

    // upsert cabinet material
    if (tempCabinetMaterial.isNotEmpty) {
      payload['cabinetMaterial'] = tempCabinetMaterial
          .map((e) {
            final labels =
                _scannedBahanPendukungByMaterial[e.IdCabinetMaterial ?? 0];
            return {
              'idCabinetMaterial': e.IdCabinetMaterial,
              'jumlah': e.Jumlah,
              // label Bahan Pendukung (BP.) yang dipakai → backend tandai
              // DateUsage = tanggal produksi agar tidak terpanggil lagi
              if (labels != null && labels.isNotEmpty)
                'noBahanPendukung': labels.toList(),
            };
          })
          .toList();
    }

    // create partial FWIP (controller sekarang expect furnitureWipPartial)
    if (tempFurnitureWipPartial.isNotEmpty) {
      payload['furnitureWipPartial'] = tempFurnitureWipPartial
          .map(
            (e) => {
              'noFurnitureWIP': e.noFurnitureWIP, // ✅ match $.noFurnitureWIP
              'pcs': e.pcs, // ✅ match $.pcs
            },
          )
          .toList();
    }

    return payload;
  }

  Future<bool> submitTempItems(String noPacking) async {
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

      _d('Submitting temp items to $noPacking');
      _d('Payload: ${json.encode(payload)}');

      final response = await repository.submitInputsAndPartials(
        noPacking,
        payload,
      );

      _d('Submit response: ${json.encode(response)}');

      final success = response['success'] as bool? ?? false;
      final data = response['data'] as Map<String, dynamic>?;

      if (!success) {
        final message = response['message'] as String? ?? 'Submit gagal';
        submitError = message;

        if (data != null) {
          final details = data['details'] as Map<String, dynamic>?;
          if (details != null) _d('Submit details: ${json.encode(details)}');
        }
        return false;
      }

      _d('Submit successful!');

      if (data != null) {
        final createdPartials =
            data['createdPartials'] as Map<String, dynamic>?;
        if (createdPartials != null) {
          _d('Created partials: ${json.encode(createdPartials)}');
        }
      }

      clearAllTempItems();
      clearLookupCache();
      clearInputsCache(noPacking);
      await loadInputs(noPacking, force: true);

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

  String getSubmitSummary() {
    if (totalTempCount == 0) return 'Tidak ada data';

    final parts = <String>[];
    if (tempFurnitureWip.isNotEmpty) {
      parts.add('${tempFurnitureWip.length} FWIP (full)');
    }
    if (tempFurnitureWipPartial.isNotEmpty) {
      parts.add('${tempFurnitureWipPartial.length} FWIP Partial');
    }
    if (tempCabinetMaterial.isNotEmpty) {
      parts.add('${tempCabinetMaterial.length} Cabinet Material');
    }

    return 'Total $totalTempCount items:\n${parts.join(', ')}';
  }

  // ---------------------------------------------------------------------------
  // Delete inputs & partials (DB items)
  // ---------------------------------------------------------------------------
  bool isDeleting = false;
  String? deleteError;
  Map<String, dynamic>? lastDeleteResult;

  Map<String, dynamic> _buildDeletePayloadFromItems(List<dynamic> items) {
    final payload = <String, dynamic>{};

    void add(String key, Map<String, dynamic> row) {
      final list =
          (payload[key] ?? <Map<String, dynamic>>[])
              as List<Map<String, dynamic>>;
      list.add(row);
      payload[key] = list;
    }

    for (final it in items) {
      if (it is FurnitureWipItem) {
        final isPart =
            it.isPartialRow ||
            ((it.noFurnitureWIPPartial ?? '').trim().isNotEmpty);

        if (isPart) {
          final code = (it.noFurnitureWIPPartial ?? '').trim();
          if (code.isNotEmpty) {
            // ✅ NoFurnitureWIPPartial -> noFurnitureWIPPartial
            add('furnitureWipPartial', {'noFurnitureWIPPartial': code});
          }
        } else {
          // ✅ NoFurnitureWIP -> noFurnitureWIP
          add('furnitureWip', {'noFurnitureWIP': it.noFurnitureWIP});
        }
      } else if (it is CabinetMaterialItem) {
        // ✅ IdCabinetMaterial -> idCabinetMaterial
        add('cabinetMaterial', {'idCabinetMaterial': it.IdCabinetMaterial});
      }
    }

    return payload;
  }

  Future<bool> deleteItems(String noPacking, List<dynamic> items) async {
    if (items.isEmpty) {
      deleteError = 'Tidak ada data yang dipilih untuk dihapus';
      notifyListeners();
      return false;
    }

    final List<dynamic> dbItems = [];
    for (final it in items) {
      final removedFromTemp = deleteIfTemp(it);
      if (!removedFromTemp) dbItems.add(it);
    }

    if (dbItems.isEmpty) {
      _d('deleteItems: hanya menghapus TEMP, tidak call API');
      notifyListeners();
      return true;
    }

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
      _d('deleteItems: calling deleteInputsAndPartials for $noPacking');
      _d('Delete payload: ${json.encode(payload)}');

      final res = await repository.deleteInputsAndPartials(noPacking, payload);
      lastDeleteResult = res;

      final success = res['success'] == true;
      final message = res['message'] as String? ?? '';

      _d('Delete response: ${json.encode(res)}');

      if (!success) {
        deleteError = message.isEmpty ? 'Gagal menghapus data' : message;
        return false;
      }

      clearInputsCache(noPacking);
      await loadInputs(noPacking, force: true);

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
}
