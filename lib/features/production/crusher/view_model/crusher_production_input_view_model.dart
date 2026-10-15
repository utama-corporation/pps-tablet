// lib/features/production/crusher/view_model/crusher_production_input_view_model.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../repository/crusher_production_input_repository.dart';
import '../model/crusher_inputs_model.dart';
// ⬆️ dari file ini kita dapat: CrusherInputs, BbItem, BonggolanItem
import '../model/crusher_output_model.dart';

import 'package:pps_tablet/features/production/shared/models/production_label_lookup_result.dart';

/// ---------------------------------------------------------------------------
/// Small value objects
/// ---------------------------------------------------------------------------
class TempCommitResult {
  final int added;
  final int skipped;
  const TempCommitResult(this.added, this.skipped);
}

class CrusherTempItemsByLabel {
  final String labelCode;

  final List<BbItem> bbItems;       // full
  final List<BbItem> bbPartials;    // partial
  final List<BonggolanItem> bonggolan;  // full (tidak ada partial)
  final List<RejectItem> reject;   // full + partial digabung

  final DateTime addedAt;

  CrusherTempItemsByLabel({
    required this.labelCode,
    this.bbItems = const [],
    this.bbPartials = const [],
    this.bonggolan = const [],
    this.reject = const [],
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int get totalCount =>
      bbItems.length + bbPartials.length + bonggolan.length + reject.length;

  bool get isEmpty => totalCount == 0;

  List<dynamic> get allItems => [
    ...bbItems,
    ...bbPartials,
    ...bonggolan,
    ...reject,
  ];
}

/// ---------------------------------------------------------------------------
/// ViewModel
/// ---------------------------------------------------------------------------
class CrusherProductionInputViewModel extends ChangeNotifier {
  final CrusherProductionInputRepository repository;

  CrusherProductionInputViewModel({required this.repository});

  // -------------------------------------------------------------------------
  // Debug helpers
  // -------------------------------------------------------------------------
  static const bool _verbose = true;

  void _d(String message) {
    if (kDebugMode && _verbose) debugPrint('[CrusherVM] $message');
  }

  String _nn(Object? v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();

  String _kg(num? v) =>
      v == null ? '-' : (v is int ? '$v' : v.toStringAsFixed(2));

  String _labelOf(dynamic it) => _getItemLabelCode(it) ?? '-';

  String displayTitleOf(dynamic it) {
    if (it is BbItem) {
      final part = (it.noBBPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return _bbTitleKeyFrom(it);
    }
    if (it is BonggolanItem) {
      return _nn(it.noBonggolan);
    }
    if (it is RejectItem) {
      final part = (it.noRejectPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return _nn(it.noReject);
    }
    return '-';
  }

  String _bbTitleKeyFrom(BbItem e) {
    final part = (e.noBBPartial ?? '').trim();
    if (part.isNotEmpty) return part;

    final nb = (e.noBahanBaku ?? '').trim();
    final np = e.noPallet;
    final hasNb = nb.isNotEmpty;
    final hasNp = (np != null && np > 0);

    if (!hasNb && !hasNp) return '-';
    if (hasNb && hasNp) return '$nb-$np';
    if (hasNb) return nb;
    return 'Pallet $np';
  }

  String _fmtItem(dynamic it) {
    final t = displayTitleOf(it);

    if (it is BbItem) {
      final isPart = (it.noBBPartial ?? '').trim().isNotEmpty || it.isPartialRow;
      return isPart
          ? '[BB•PART] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg'
          : '[BB] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg';
    }

    if (it is BonggolanItem) {
      return '[BONG] $t • ${_kg(it.berat)}kg';
    }

    if (it is RejectItem) {
      final isPart = (it.noRejectPartial ?? '').trim().isNotEmpty || it.isPartialRow;
      return isPart
          ? '[REJ•PART] $t • ${_kg(it.berat)}kg'
          : '[REJ] $t • ${_kg(it.berat)}kg';
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
    _d('========== CRUSHER TEMP LIST DUMP$hdr ==========');
    _dumpList('tempBb', tempBb, _keyFromBbItem);
    _dumpList('tempBbPartial', tempBbPartial, _keyFromBbItem);
    _dumpList('tempBonggolan', tempBonggolan, _keyFromBonggolanItem);
    _dumpList('tempReject', tempReject, _keyFromRejectItem);
    _dumpList('tempRejectPartial', tempRejectPartial, _keyFromRejectItem);
    _d('TOTAL TEMP COUNT = $totalTempCount');
    _d('===============================================');
  }

  void debugDumpTempByLabel() {
    if (!_verbose) return;
    _d('---------- CRUSHER TEMP GROUPED BY LABEL ----------');
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
    _d('---------------------------------------------------');
  }

  void debugDumpTempKeys({String tag = ''}) {
    if (!_verbose) return;
    final hdr = tag.isEmpty ? '' : ' <$tag>';
    _d('~~~~ CRUSHER TEMP KEYS DUMP$hdr ~~~~');
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
    _d('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  }

  // -------------------------------------------------------------------------
  // Inputs per NoProduksi (cache)
  // -------------------------------------------------------------------------
  final Map<String, CrusherInputs> _inputsCache = {};
  final Map<String, bool> _inputsLoading = {};
  final Map<String, String?> _inputsError = {};

  bool isInputsLoading(String noProduksi) =>
      _inputsLoading[noProduksi] == true;

  String? inputsError(String noProduksi) => _inputsError[noProduksi];

  CrusherInputs? inputsOf(String noProduksi) => _inputsCache[noProduksi];

  int inputsCount(String noProduksi, String key) =>
      _inputsCache[noProduksi]?.summary[key] ?? 0;

  Future<CrusherInputs?> loadInputs(String noProduksi,
      {bool force = false}) async {
    if (!force && _inputsCache.containsKey(noProduksi)) {
      return _inputsCache[noProduksi];
    }

    _inputsLoading[noProduksi] = true;
    _inputsError[noProduksi] = null;
    notifyListeners();

    try {
      final result = await repository.fetchInputs(noProduksi, force: force);
      _inputsCache[noProduksi] = result;
      return result;
    } catch (e) {
      _inputsError[noProduksi] = e.toString();
      return null;
    } finally {
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

  // -------------------------------------------------------------------------
  // Outputs per NoProduksi (cache)
  // -------------------------------------------------------------------------
  final Map<String, List<CrusherOutput>> _outputsCache = {};
  final Map<String, bool> _outputsLoading = {};
  final Map<String, String?> _outputsError = {};

  bool isOutputsLoading(String noProduksi) =>
      _outputsLoading[noProduksi] == true;

  String? outputsError(String noProduksi) => _outputsError[noProduksi];

  List<CrusherOutput>? outputsOf(String noProduksi) =>
      _outputsCache[noProduksi];

  Future<void> loadOutputs(String noProduksi, {bool force = false}) async {
    if (!force && _outputsCache.containsKey(noProduksi)) return;

    _outputsLoading[noProduksi] = true;
    _outputsError[noProduksi] = null;
    notifyListeners();

    try {
      final result = await repository.fetchOutputs(noProduksi);
      _outputsCache[noProduksi] = result;
    } catch (e) {
      _outputsError[noProduksi] = e.toString();
      _outputsCache.remove(noProduksi);
    } finally {
      _outputsLoading[noProduksi] = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Lookup label (reuse shared model)
  // -------------------------------------------------------------------------
  final Map<String, ProductionLabelLookupResult> _lookupCache = {};
  bool isLookupLoading = false;
  String? lookupError;
  ProductionLabelLookupResult? lastLookup;

  // Track temp items by label code
  final Map<String, CrusherTempItemsByLabel> _tempItemsByLabel = {};

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

  // -------------------------------------------------------------------------
  // Temporary data by label (untuk dialog rescan)
  // -------------------------------------------------------------------------
  bool hasTemporaryDataForLabel(String labelCode) {
    final tempItems = _tempItemsByLabel[labelCode.trim()];
    return tempItems != null && !tempItems.isEmpty;
  }

  CrusherTempItemsByLabel? getTemporaryDataForLabel(String labelCode) =>
      _tempItemsByLabel[labelCode.trim()];

  String getTemporaryDataSummary(String labelCode) {
    final t = getTemporaryDataForLabel(labelCode);
    if (t == null || t.isEmpty) return 'Tidak ada data temporary';

    final s = <String>[];
    if (t.bbItems.isNotEmpty) {
      s.add('${t.bbItems.length} Bahan Baku (full)');
    }
    if (t.bbPartials.isNotEmpty) {
      s.add('${t.bbPartials.length} BB Partial');
    }
    if (t.bonggolan.isNotEmpty) {
      s.add('${t.bonggolan.length} Bonggolan');
    }

    return s.join(', ');
  }

  void Function(CrusherTempItemsByLabel)? onShowTemporaryDataDialog;

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
      if (item is BbItem) {
        tempBb.remove(item);
        tempBbPartial.remove(item);
        _tempKeys.remove(_keyFromBbItem(item));
      } else if (item is BonggolanItem) {
        tempBonggolan.remove(item);
        _tempKeys.remove(_keyFromBonggolanItem(item));
      } else if (item is RejectItem) {
        tempReject.remove(item);
        _tempKeys.remove(_keyFromRejectItem(item));
      } else if (item is RejectItem) {
        tempRejectPartial.remove(item);
        _tempKeys.remove(_keyFromRejectItem(item));
      }
    }

    _updateTempItemsByLabel(trimmed);
    notifyListeners();
  }

  void _updateTempItemsByLabel(String labelCode) {
    final code = labelCode.trim();

    final bbFull =
    tempBb.where((e) => _getItemLabelCode(e) == code).toList();
    final bbPart =
    tempBbPartial.where((e) => _getItemLabelCode(e) == code).toList();
    final bonggolan =
    tempBonggolan.where((e) => _getItemLabelCode(e) == code).toList();
    final reject =
        tempReject.where((e) => _getItemLabelCode(e) == code).toList();

    if ([bbFull, bbPart, bonggolan, reject].every((l) => l.isEmpty)) {
      _tempItemsByLabel.remove(code);
      return;
    }

    _tempItemsByLabel[code] = CrusherTempItemsByLabel(
      labelCode: code,
      bbItems: bbFull,
      bbPartials: bbPart,
      bonggolan: bonggolan,
      reject: reject,
      addedAt: _tempItemsByLabel[code]?.addedAt ?? DateTime.now(),
    );
  }

  String? _getItemLabelCode(dynamic item) {
    if (item is BbItem) {
      final part = (item.noBBPartial ?? '').trim();
      if (part.isNotEmpty) return part;

      final noBb = (item.noBahanBaku ?? '').trim();
      final noPallet = item.noPallet;
      if (noPallet == null || noPallet == 0) return noBb;
      return '$noBb-$noPallet';
    }

    if (item is BonggolanItem) {
      return item.noBonggolan;
    }

    if (item is RejectItem) {
      final part = (item.noRejectPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noReject;
    }

    return null;
  }

  // -------------------------------------------------------------------------
  // Temp selections & keys
  // -------------------------------------------------------------------------
  final List<BbItem> tempBb = [];
  final List<BbItem> tempBbPartial = [];

  final List<BonggolanItem> tempBonggolan = [];

  final List<RejectItem> tempReject = [];
  final List<RejectItem> tempRejectPartial = [];

  final Set<String> _pickedKeys = <String>{};
  final List<Map<String, dynamic>> _pickedRows = <Map<String, dynamic>>[];
  final Map<String, int> _keyToRowIndex = {};

  final Set<String> _tempKeys = <String>{};

  // key builders (TEMP)
  String _keyFromBbItem(BbItem i) {
    final noBB = i.noBahanBaku ?? '-';
    final noSak = (i.noSak ?? '').toString().trim();
    final noPallet = i.noPallet ?? 0;

    return 'A.|BahanBaku_d|$noBB|$noPallet|$noSak';
  }

  String _keyFromBonggolanItem(BonggolanItem i) =>
      'E.|Bonggolan|${i.noBonggolan ?? '-'}|';

  String _keyFromRejectItem(RejectItem i) =>
      'BF.|RejectV2|${i.noReject ?? '-'}|';

  // DB keys (untuk future: kalau mau gabung DB+TEMP)
  Set<String> _dbKeysFor(String noProduksi) {
    final keys = <String>{};
    final db = _inputsCache[noProduksi];
    if (db != null) {
      for (final x in db.bb) keys.add(_keyFromBbItem(x));
      for (final x in db.bonggolan) keys.add(_keyFromBonggolanItem(x));
      for (final x in db.reject) keys.add(_keyFromRejectItem(x));
    }
    return keys;
  }

  Set<String> _allKeysFor(String noProduksi) {
    final all = _dbKeysFor(noProduksi);
    all.addAll(_tempKeys);
    return all;
  }

  // -------------------------------------------------------------------------
  // PUBLIC API untuk duplicate check di TEMP saja
  // -------------------------------------------------------------------------
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

  // -------------------------------------------------------------------------
  // Picks (UI)
  // -------------------------------------------------------------------------
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
    return '${pickedCount} ${ctx.prefixType.displayName} dipilih';
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

  // -------------------------------------------------------------------------
  // Partial helpers (BB & Reject punya partial)
  // -------------------------------------------------------------------------
  bool _rowIsPartial(Map<String, dynamic> row, PrefixType t) {
    // Generic flag fallback
    const candKeys = ['IsPartial', 'isPartial', 'IsPartialRow', 'isPartialRow'];
    for (final k in candKeys) {
      final v = row[k];
      if (v is bool && v) return true;
      if (v is num && v != 0) return true;
      if (v is String &&
          (v == '1' || v.toLowerCase() == 'true')) return true;
    }

    switch (t) {
      case PrefixType.bb:
        final s =
        (row['NoBBPartial'] ?? row['noBBPartial'] ?? '').toString().trim();
        return s.isNotEmpty;
      case PrefixType.reject:
        final s =
        (row['NoRejectPartial'] ?? row['noRejectPartial'] ?? '').toString().trim();
        return s.isNotEmpty;
      default:
        return false;
    }
  }

  String _getBaseKeyWithoutWeight(Map<String, dynamic> row, PrefixType t) {
    switch (t) {
      case PrefixType.bb:
        final noBb = row['NoBahanBaku'] ?? row['noBahanBaku'] ?? '';
        final noPallet = row['NoPallet'] ?? row['noPallet'] ?? 0;
        final noSak = row['NoSak'] ?? row['noSak'] ?? '';
        return 'A.|BahanBaku_d|$noBb|$noPallet|$noSak';
      case PrefixType.reject:
        final noRej = row['NoReject'] ?? row['noReject'] ?? '';
        return 'BF.|RejectV2|$noRej';
      default:
        return '';
    }
  }

  dynamic _findExistingPartialItem(dynamic item, PrefixType t) {
    if (item is BbItem) {
      for (final existing in tempBbPartial) {
        if (existing.noBahanBaku == item.noBahanBaku &&
            existing.noPallet == item.noPallet &&
            existing.noSak == item.noSak) {
          return existing;
        }
      }
    } else if (item is RejectItem) {
      for (final existing in tempRejectPartial) {
        if (existing.noReject == item.noReject) {
          return existing;
        }
      }
    }
    return null;
  }

  double? _getWeightFromItem(dynamic item) {
    if (item is BbItem) return item.berat;
    if (item is BonggolanItem) return item.berat;
    if (item is RejectItem) return item.berat;
    return null;
  }

  // -------------------------------------------------------------------------
  // Temp-partial numbering (BB & Reject)
  // -------------------------------------------------------------------------
  final Map<PrefixType, int> _tempPartialSeq = {
    PrefixType.bb: 0,
    PrefixType.reject: 0,
  };

  int _nextPartialSeq(PrefixType t) {
    final n = (_tempPartialSeq[t] ?? 0) + 1;
    _tempPartialSeq[t] = n;
    return n;
  }

  String _formatTempPartial(PrefixType tp, int seq) {
    final numStr = seq.toString().padLeft(1, '0');
    switch (tp) {
      case PrefixType.bb:
        return 'P.XXXXXXXX ($numStr)';
      case PrefixType.reject:
        return 'BK.XXXXXXXX ($numStr)';
      default:
        return '';
    }
  }

  dynamic _withTempPartialIfNeeded(
      dynamic item, PrefixType t, bool isPartial) {
    final supports = t == PrefixType.bb || t == PrefixType.reject;
    if (!supports || !isPartial) return item;

    if (item is BbItem) {
      final already = (item.noBBPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq(t));
        return item.copyWith(noBBPartial: code);
      }
      return item;
    }

    if (item is RejectItem) {
      final already = (item.noRejectPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq(t));
        return item.copyWith(noRejectPartial: code);
      }
      return item;
    }

    return item;
  }

  int get totalTempCount =>
      tempBb.length +
          tempBbPartial.length +
          tempBonggolan.length +
          tempReject.length +
          tempRejectPartial.length;

  // -------------------------------------------------------------------------
  // Commit picked → TEMP (strict anti-duplicate)
  // -------------------------------------------------------------------------
  TempCommitResult commitPickedToTemp({required String noProduksi}) {
    final ctx = lastLookup;
    if (ctx == null || _pickedRows.isEmpty) {
      return const TempCommitResult(0, 0);
    }

    final Set<String> seenTemp = Set<String>.from(_tempKeys);

    int added = 0;
    int skipped = 0;

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

      // Hanya proses tipe yang relevan
      if (item is! BbItem && item is! BonggolanItem && item is! RejectItem) {
        _d('commitPickedToTemp: tipe item tidak didukung di Crusher ($item), skip');
        skipped++;
        continue;
      }

      final simpleKey = ctx.simpleKey(rawRow);
      final bool isPartial =
      _rowIsPartial(rawRow, ctx.prefixType); // bb & reject bisa true

      bool shouldSkip = false;

      if (isPartial) {
        final baseKey = _getBaseKeyWithoutWeight(rawRow, ctx.prefixType);
        final existingPartial =
        _findExistingPartialItem(item, ctx.prefixType);

        if (existingPartial != null) {
          final existingWeight = _getWeightFromItem(existingPartial);
          final newWeight = rawRow['berat'] ?? rawRow['Berat'];

          if (existingWeight == newWeight) {
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

      final String tempKey = item is BbItem
          ? _keyFromBbItem(item)
          : item is BonggolanItem
          ? _keyFromBonggolanItem(item)
          : item is RejectItem
          ? _keyFromRejectItem(item)
          : simpleKey;

      // Kalau key TEMP sudah ada → skip
      if (!_tempKeys.add(tempKey)) {
        skipped++;
        continue;
      }

      // Simpan juga simpleKey agar fungsi duplicate cek yg pakai simpleKey ikut jalan
      if (simpleKey.isNotEmpty) {
        _tempKeys.add(simpleKey);
      }

      seenTemp.add(simpleKey);

      final newItem =
      _withTempPartialIfNeeded(item, ctx.prefixType, isPartial);

      bool itemAdded = false;

      if (newItem is BbItem) {
        if (newItem.isPartialRow ||
            (newItem.noBBPartial ?? '').trim().isNotEmpty) {
          tempBbPartial.add(newItem);
        } else {
          tempBb.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is BonggolanItem) {
        tempBonggolan.add(newItem);
        itemAdded = true;
      } else if (newItem is RejectItem) {
        if (newItem.isPartialRow ||
            (newItem.noRejectPartial ?? '').trim().isNotEmpty) {
          tempRejectPartial.add(newItem);
        } else {
          tempReject.add(newItem);
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
        if (simpleKey.isNotEmpty) _tempKeys.remove(simpleKey);
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

  // -------------------------------------------------------------------------
  // Delete temp items (maintain _tempKeys)
  // -------------------------------------------------------------------------
  void deleteTempBbItem(BbItem item) {
    tempBb.remove(item);
    tempBbPartial.remove(item);
    _tempKeys.remove(_keyFromBbItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);

    debugDumpTempLists(tag: 'after deleteTempBbItem');
    notifyListeners();
  }

  void deleteTempBonggolanItem(BonggolanItem item) {
    tempBonggolan.remove(item);
    _tempKeys.remove(_keyFromBonggolanItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);

    debugDumpTempLists(tag: 'after deleteTempBonggolanItem');
    notifyListeners();
  }

  void deleteTempRejectItem(RejectItem item) {
    tempReject.remove(item);
    tempRejectPartial.remove(item);
    _tempKeys.remove(_keyFromRejectItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);

    debugDumpTempLists(tag: 'after deleteTempRejectItem');
    notifyListeners();
  }

  bool isInTempKeys(String key) => _tempKeys.contains(key);

  Set<String> getTempKeysForDebug() => Set.unmodifiable(_tempKeys);

  void clearAllTempItems() {
    tempBb.clear();
    tempBbPartial.clear();
    tempBonggolan.clear();
    tempReject.clear();
    tempRejectPartial.clear();

    _tempKeys.clear();
    _tempItemsByLabel.clear();
    clearPicks();
    _tempPartialSeq.updateAll((_, __) => 0);

    _d('clearAllTempItems() called');
    debugDumpTempLists(tag: 'after clearAllTempItems');
    debugDumpTempByLabel();
    debugDumpTempKeys(tag: 'after clearAllTempItems');

    notifyListeners();
  }

  bool deleteIfTemp(dynamic item) {
    bool ok = false;

    if (item is BbItem) {
      ok = tempBb.remove(item) || tempBbPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromBbItem(item));
    } else if (item is BonggolanItem) {
      ok = tempBonggolan.remove(item);
      if (ok) _tempKeys.remove(_keyFromBonggolanItem(item));
    } else if (item is RejectItem) {
      ok = tempReject.remove(item) || tempRejectPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromRejectItem(item));
    }

    if (ok) debugDumpTempLists(tag: 'after deleteIfTemp');
    return ok;
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

  // -------------------------------------------------------------------------
  // Submit temp items ke backend
  // -------------------------------------------------------------------------
  bool isSubmitting = false;
  String? submitError;

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};

    if (tempBb.isNotEmpty) {
      payload['bb'] = tempBb
          .map((e) => {
        'noBahanBaku': e.noBahanBaku,
        'noPallet': e.noPallet,
        'noSak': e.noSak,
      })
          .toList();
    }

    if (tempBonggolan.isNotEmpty) {
      payload['bonggolan'] = tempBonggolan
          .map((e) => {
        'noBonggolan': e.noBonggolan,
      })
          .toList();
    }

    if (tempBbPartial.isNotEmpty) {
      payload['bbPartialNew'] = tempBbPartial
          .map((e) => {
        'noBahanBaku': e.noBahanBaku,
        'noPallet': e.noPallet,
        'noSak': e.noSak,
        'berat': e.berat,
      })
          .toList();
    }

    if (tempReject.isNotEmpty) {
      payload['reject'] = tempReject
          .map((e) => {
        'noReject': e.noReject,
      })
          .toList();
    }

    if (tempRejectPartial.isNotEmpty) {
      payload['rejectPartialNew'] = tempRejectPartial
          .map((e) => {
        'noReject': e.noReject,
        'berat': e.berat,
      })
          .toList();
    }

    return payload;
  }

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

      _d('Submitting crusher temp items to $noProduksi');
      _d('Payload: ${json.encode(payload)}');

      final response = await repository.submitInputsAndPartials(
        noProduksi,
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
          if (details != null) {
            _d('Submit details: ${json.encode(details)}');
          }
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

  String getSubmitSummary() {
    if (totalTempCount == 0) return 'Tidak ada data';

    final parts = <String>[];

    if (tempBb.isNotEmpty) {
      parts.add('${tempBb.length} Bahan Baku');
    }
    if (tempBbPartial.isNotEmpty) {
      parts.add('${tempBbPartial.length} BB Partial');
    }
    if (tempBonggolan.isNotEmpty) {
      parts.add('${tempBonggolan.length} Bonggolan');
    }
    if (tempReject.isNotEmpty) {
      parts.add('${tempReject.length} Reject');
    }
    if (tempRejectPartial.isNotEmpty) {
      parts.add('${tempRejectPartial.length} Reject Partial');
    }

    return 'Total $totalTempCount items:\n${parts.join(', ')}';
  }

  // -------------------------------------------------------------------------
  // Delete inputs & partials (DB + TEMP)
  // -------------------------------------------------------------------------
  bool isDeleting = false;
  String? deleteError;
  Map<String, dynamic>? lastDeleteResult;

  Map<String, dynamic> _buildDeletePayloadFromItems(List<dynamic> items) {
    final payload = <String, dynamic>{};

    void add(String key, Map<String, dynamic> row) {
      final list =
      (payload[key] ?? <Map<String, dynamic>>[]) as List<Map<String, dynamic>>;
      list.add(row);
      payload[key] = list;
    }

    for (final it in items) {
      if (it is BbItem) {
        final isPart =
            it.isPartialRow || ((it.noBBPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noBBPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('bbPartial', {
              'noBBPartial': code,
            });
          }
        } else {
          add('bb', {
            'noBahanBaku': it.noBahanBaku,
            'noPallet': it.noPallet,
            'noSak': it.noSak,
          });
        }
      } else if (it is BonggolanItem) {
        add('bonggolan', {
          'noBonggolan': it.noBonggolan,
        });
      } else if (it is RejectItem) {
        // Partial dihapus lewat kode partial-nya (partialColumn =
        // NoRejectPartial); kode `noReject` tidak akan cocok di sisi server.
        final code = (it.noRejectPartial ?? '').trim();
        if (code.isNotEmpty) {
          add('rejectPartial', {
            'noRejectPartial': code,
          });
        } else {
          add('reject', {
            'noReject': it.noReject,
          });
        }
      }
    }

    return payload;
  }

  Future<bool> deleteItems(String noProduksi, List<dynamic> items) async {
    if (items.isEmpty) {
      deleteError = 'Tidak ada data yang dipilih untuk dihapus';
      notifyListeners();
      return false;
    }

    final List<dynamic> dbItems = [];

    for (final it in items) {
      final removedFromTemp = deleteIfTemp(it);
      if (!removedFromTemp) {
        dbItems.add(it);
      }
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
      _d('deleteItems: calling deleteInputsAndPartials for $noProduksi');
      _d('Delete payload: ${json.encode(payload)}');

      final res =
      await repository.deleteInputsAndPartials(noProduksi, payload);
      lastDeleteResult = res;

      final success = res['success'] == true;
      final message = res['message'] as String? ?? '';

      _d('Delete response: ${json.encode(res)}');

      if (!success) {
        deleteError =
        message.isEmpty ? 'Gagal menghapus data' : message;
        return false;
      }

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
}
