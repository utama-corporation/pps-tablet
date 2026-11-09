// lib/features/broker/view_model/broker_production_view_model.dart
// Cleaned & structured: minimized debug noise, strict anti-duplicate for TEMP,
// partial-aware temp buckets (full vs partial), and small helpers.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'package:pps_tablet/features/production/broker/repository/broker_production_input_repository.dart';

import '../model/broker_production_model.dart';
import '../model/broker_inputs_model.dart';

// ⬇️ shared lookup result model
import 'package:pps_tablet/features/production/shared/models/production_label_lookup_result.dart';

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
  final List<BrokerItem> brokerPartials; // partial - TAMBAHKAN INI
  final List<BbItem> bbItems; // full
  final List<BbItem> bbPartials; // partial
  final List<WashingItem> washingItems;
  final List<CrusherItem> crusherItems;
  final List<GilinganItem> gilinganItems; // full
  final List<GilinganItem> gilinganPartials;
  final List<MixerItem> mixerItems; // full
  final List<MixerItem> mixerPartials;
  final List<RejectItem> rejectItems; // full
  final List<RejectItem> rejectPartials;
  final DateTime addedAt;

  TempItemsByLabel({
    required this.labelCode,
    this.brokerItems = const [],
    this.brokerPartials = const [],
    this.bbItems = const [],
    this.bbPartials = const [],
    this.washingItems = const [],
    this.crusherItems = const [],
    this.gilinganItems = const [],
    this.gilinganPartials = const [],
    this.mixerItems = const [],
    this.mixerPartials = const [],
    this.rejectItems = const [],
    this.rejectPartials = const [],
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int get totalCount =>
      brokerItems.length +
      brokerPartials.length +
      bbItems.length +
      bbPartials.length +
      washingItems.length +
      crusherItems.length +
      gilinganItems.length +
      gilinganPartials.length +
      mixerItems.length +
      mixerPartials.length +
      rejectItems.length +
      rejectPartials.length;

  bool get isEmpty => totalCount == 0;

  List<dynamic> get allItems => [
    ...brokerItems,
    ...brokerPartials,
    ...bbItems,
    ...bbPartials,
    ...washingItems,
    ...crusherItems,
    ...gilinganItems,
    ...gilinganPartials,
    ...mixerItems,
    ...mixerPartials,
    ...rejectItems,
    ...rejectPartials,
  ];
}

// -----------------------------------------------------------------------------
// ViewModel
// -----------------------------------------------------------------------------
class BrokerProductionInputViewModel extends ChangeNotifier {
  final BrokerProductionInputRepository repository;
  BrokerProductionInputViewModel({required this.repository});

  // ---------------------------------------------------------------------------
  // Debug control (single switch)
  // ---------------------------------------------------------------------------
  static const bool _verbose = true; // set true to enable logs
  void _d(String message) {
    if (kDebugMode && _verbose) debugPrint('[BrokerVM] $message');
  }

  // ---------- DEBUG HELPERS ----------
  String _nn(Object? v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();
  String _kg(num? v) =>
      v == null ? '-' : (v is int ? '$v' : v.toStringAsFixed(2));

  String _labelOf(dynamic it) => _getItemLabelCode(it) ?? '-';

  String displayTitleOf(dynamic it) {
    if (it is BrokerItem) {
      // TAMBAHKAN CEK PARTIAL
      return (it.noBrokerPartial ?? '').trim().isNotEmpty
          ? it.noBrokerPartial!
          : _nn(it.noBroker);
    }
    if (it is BbItem) {
      return (it.noBBPartial ?? '').trim().isNotEmpty
          ? it.noBBPartial!
          : _bbTitleKeyFrom(it);
    }
    if (it is GilinganItem) {
      return (it.noGilinganPartial ?? '').trim().isNotEmpty
          ? it.noGilinganPartial!
          : _nn(it.noGilingan);
    }
    if (it is MixerItem) {
      return (it.noMixerPartial ?? '').trim().isNotEmpty
          ? it.noMixerPartial!
          : _nn(it.noMixer);
    }
    if (it is RejectItem) {
      return (it.noRejectPartial ?? '').trim().isNotEmpty
          ? it.noRejectPartial!
          : _nn(it.noReject);
    }
    if (it is BrokerItem) return _nn(it.noBroker);
    if (it is WashingItem) return _nn(it.noWashing);
    if (it is CrusherItem) return _nn(it.noCrusher);
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
    if (it is BrokerItem) {
      final isPart = (it.noBrokerPartial ?? '').trim().isNotEmpty; // TAMBAHKAN
      return isPart
          ? '[BROKER•PART] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg'
          : '[BROKER] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg';
    }
    if (it is BbItem) {
      final isPart = (it.noBBPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[BB•PART] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg'
          : '[BB] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg';
    }
    if (it is WashingItem) {
      return '[WASH] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg';
    }
    if (it is CrusherItem) {
      return '[CRUSH] $t • ${_kg(it.berat)}kg';
    }
    if (it is GilinganItem) {
      final isPart = (it.noGilinganPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[GIL•PART] $t • ${_kg(it.berat)}kg'
          : '[GIL] $t • ${_kg(it.berat)}kg';
    }
    if (it is MixerItem) {
      final isPart = (it.noMixerPartial ?? '').trim().isNotEmpty;
      return isPart
          ? '[MIX•PART] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg'
          : '[MIX] $t • sak ${_nn(it.noSak)} • ${_kg(it.berat)}kg';
    }
    if (it is RejectItem) {
      final isPart = (it.noRejectPartial ?? '').trim().isNotEmpty;
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
    _d('========== TEMP LIST DUMP$hdr ==========');
    _dumpList('tempBroker', tempBroker, _keyFromBrokerItem);
    _dumpList(
      'tempBrokerPartial',
      tempBrokerPartial,
      _keyFromBrokerItem,
    ); // TAMBAHKAN
    _dumpList('tempBb', tempBb, _keyFromBbItem);
    _dumpList('tempBbPartial', tempBbPartial, _keyFromBbItem);
    _dumpList('tempWashing', tempWashing, _keyFromWashingItem);
    _dumpList('tempCrusher', tempCrusher, _keyFromCrusherItem);
    _dumpList('tempGilingan', tempGilingan, _keyFromGilinganItem);
    _dumpList('tempGilinganPartial', tempGilinganPartial, _keyFromGilinganItem);
    _dumpList('tempMixer', tempMixer, _keyFromMixerItem);
    _dumpList('tempMixerPartial', tempMixerPartial, _keyFromMixerItem);
    _dumpList('tempReject', tempReject, _keyFromRejectItem);
    _dumpList('tempRejectPartial', tempRejectPartial, _keyFromRejectItem);
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
  // Mode: by date (fixed)
  // ---------------------------------------------------------------------------
  bool _isByDateMode = false;
  bool get isByDateMode => _isByDateMode;

  List<BrokerProduction> items = [];
  bool isLoading = false;
  String error = '';

  // Create state
  bool isSaving = false;
  String? saveError;

  // ---------------------------------------------------------------------------
  // Paged mode
  // ---------------------------------------------------------------------------
  late final PagingController<int, BrokerProduction> pagingController;
  int pageSize = 20;

  String _search = '';
  String? _noProduksi;
  bool _exactNoProduksi = false;

  int? _shift;
  DateTime? _date;

  String get search => _search;
  String? get noProduksi => _noProduksi;
  bool get exactNoProduksi => _exactNoProduksi;
  int? get shift => _shift;
  DateTime? get date => _date;

  // ---------------------------------------------------------------------------
  // Inputs per row (latest fetched state, loading & error per NoProduksi)
  // ---------------------------------------------------------------------------
  final Map<String, BrokerInputs> _inputsCache = {};
  final Map<String, bool> _inputsLoading = {};
  final Map<String, String?> _inputsError = {};
  final Map<String, List<BrokerOutput>> _outputsByNoProduksi = {};
  final Map<String, List<BonggolanOutput>> _bonggolanOutputsByNoProduksi = {};
  final Map<String, bool> _outputsLoading = {};
  final Map<String, String?> _outputsError = {};

  bool isInputsLoading(String noProduksi) => _inputsLoading[noProduksi] == true;
  String? inputsError(String noProduksi) => _inputsError[noProduksi];
  BrokerInputs? inputsOf(String noProduksi) => _inputsCache[noProduksi];
  int inputsCount(String noProduksi, String key) =>
      _inputsCache[noProduksi]?.summary[key] ?? 0;
  bool isOutputsLoading(String noProduksi) =>
      _outputsLoading[noProduksi] == true;
  String? outputsError(String noProduksi) => _outputsError[noProduksi];
  List<BrokerOutput> outputsOf(String noProduksi) =>
      _outputsByNoProduksi[noProduksi] ?? const <BrokerOutput>[];
  List<BonggolanOutput> bonggolanOutputsOf(String noProduksi) =>
      _bonggolanOutputsByNoProduksi[noProduksi] ?? const <BonggolanOutput>[];

  Future<BrokerInputs?> loadInputs(
    String noProduksi, {
    bool force = false,
  }) async {
    _inputsLoading[noProduksi] = true;
    _inputsError[noProduksi] = null;
    notifyListeners();

    try {
      final result = await repository.fetchInputs(noProduksi, force: true);
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

  Future<List<BrokerOutput>> loadOutputs(String noProduksi) async {
    _outputsLoading[noProduksi] = true;
    _outputsError[noProduksi] = null;
    notifyListeners();

    List<BrokerOutput> brokerOutputs = const <BrokerOutput>[];
    List<BonggolanOutput> bonggolanOutputs = const <BonggolanOutput>[];
    final errors = <String>[];

    try {
      try {
        brokerOutputs = await repository.fetchOutputs(noProduksi);
      } catch (e) {
        errors.add('Broker: $e');
      }

      try {
        bonggolanOutputs = await repository.fetchBonggolanOutputs(noProduksi);
      } catch (e) {
        errors.add('Bonggolan: $e');
      }

      _outputsByNoProduksi[noProduksi] = brokerOutputs;
      _bonggolanOutputsByNoProduksi[noProduksi] = bonggolanOutputs;
      _outputsError[noProduksi] = errors.isEmpty ? null : errors.join('\n');
      return brokerOutputs;
    } finally {
      _outputsLoading[noProduksi] = false;
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

  void clearOutputsState([String? noProduksi]) {
    if (noProduksi == null) {
      _outputsByNoProduksi.clear();
      _bonggolanOutputsByNoProduksi.clear();
      _outputsLoading.clear();
      _outputsError.clear();
    } else {
      _outputsByNoProduksi.remove(noProduksi);
      _bonggolanOutputsByNoProduksi.remove(noProduksi);
      _outputsLoading.remove(noProduksi);
      _outputsError.remove(noProduksi);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Lookup label
  // ---------------------------------------------------------------------------
  final Map<String, ProductionLabelLookupResult> _lookupCache = {};
  bool isLookupLoading = false;
  String? lookupError;
  ProductionLabelLookupResult? lastLookup;

  // Track temp items by label code
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
  // Temporary data by label (for rescan UX)
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
    if (t.brokerPartials.isNotEmpty)
      s.add('${t.brokerPartials.length} Broker Partial'); // TAMBAHKAN
    if (t.bbItems.isNotEmpty) s.add('${t.bbItems.length} Bahan Baku (full)');
    if (t.bbPartials.isNotEmpty) s.add('${t.bbPartials.length} BB Partial');
    if (t.washingItems.isNotEmpty) s.add('${t.washingItems.length} Washing');
    if (t.crusherItems.isNotEmpty) s.add('${t.crusherItems.length} Crusher');
    if (t.gilinganItems.isNotEmpty)
      s.add('${t.gilinganItems.length} Gilingan (full)');
    if (t.gilinganPartials.isNotEmpty)
      s.add('${t.gilinganPartials.length} Gilingan Partial');
    if (t.mixerItems.isNotEmpty) s.add('${t.mixerItems.length} Mixer (full)');
    if (t.mixerPartials.isNotEmpty)
      s.add('${t.mixerPartials.length} Mixer Partial');
    if (t.rejectItems.isNotEmpty)
      s.add('${t.rejectItems.length} Reject (full)');
    if (t.rejectPartials.isNotEmpty)
      s.add('${t.rejectPartials.length} Reject Partial');
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
      if (item is BrokerItem) {
        tempBroker.remove(item);
        tempBrokerPartial.remove(item); // TAMBAHKAN
        _tempKeys.remove(_keyFromBrokerItem(item));
      } else if (item is BbItem) {
        tempBb.remove(item);
        tempBbPartial.remove(item);
        _tempKeys.remove(_keyFromBbItem(item));
      } else if (item is WashingItem) {
        tempWashing.remove(item);
        _tempKeys.remove(_keyFromWashingItem(item));
      } else if (item is CrusherItem) {
        tempCrusher.remove(item);
        _tempKeys.remove(_keyFromCrusherItem(item));
      } else if (item is GilinganItem) {
        tempGilingan.remove(item);
        tempGilinganPartial.remove(item);
        _tempKeys.remove(_keyFromGilinganItem(item));
      } else if (item is MixerItem) {
        tempMixer.remove(item);
        tempMixerPartial.remove(item);
        _tempKeys.remove(_keyFromMixerItem(item));
      } else if (item is RejectItem) {
        tempReject.remove(item);
        tempRejectPartial.remove(item);
        _tempKeys.remove(_keyFromRejectItem(item));
      }
    }

    _updateTempItemsByLabel(trimmed);
    notifyListeners();
  }

  void _updateTempItemsByLabel(String labelCode) {
    final code = labelCode.trim();

    final brokerFull = tempBroker
        .where((e) => _getItemLabelCode(e) == code)
        .toList();
    final brokerPart = tempBrokerPartial
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    // Split full vs partial per kategori
    final bbFull = tempBb.where((e) => _getItemLabelCode(e) == code).toList();
    final bbPart = tempBbPartial
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    final washingItems = tempWashing
        .where((e) => _getItemLabelCode(e) == code)
        .toList();
    final crusherItems = tempCrusher
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    final gilFull = tempGilingan
        .where((e) => _getItemLabelCode(e) == code)
        .toList();
    final gilPart = tempGilinganPartial
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    final mixFull = tempMixer
        .where((e) => _getItemLabelCode(e) == code)
        .toList();
    final mixPart = tempMixerPartial
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    final rejFull = tempReject
        .where((e) => _getItemLabelCode(e) == code)
        .toList();
    final rejPart = tempRejectPartial
        .where((e) => _getItemLabelCode(e) == code)
        .toList();

    if ([
      brokerFull,
      brokerPart,
      bbFull,
      bbPart,
      washingItems,
      crusherItems,
      gilFull,
      gilPart,
      mixFull,
      mixPart,
      rejFull,
      rejPart,
    ].every((l) => l.isEmpty)) {
      _tempItemsByLabel.remove(code);
      return;
    }

    _tempItemsByLabel[code] = TempItemsByLabel(
      labelCode: code,
      brokerItems: brokerFull,
      brokerPartials: brokerPart,
      bbItems: bbFull,
      bbPartials: bbPart,
      washingItems: washingItems,
      crusherItems: crusherItems,
      gilinganItems: gilFull,
      gilinganPartials: gilPart,
      mixerItems: mixFull,
      mixerPartials: mixPart,
      rejectItems: rejFull,
      rejectPartials: rejPart,
      addedAt: _tempItemsByLabel[code]?.addedAt ?? DateTime.now(),
    );
  }

  String? _getItemLabelCode(dynamic item) {
    if (item is BrokerItem) {
      final part = (item.noBrokerPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noBroker;
    }

    if (item is BbItem) {
      final part = (item.noBBPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      final noBb = (item.noBahanBaku ?? '').trim();
      final noPallet = item.noPallet;
      if (noPallet == null || noPallet == 0) return noBb;
      return '$noBb-$noPallet';
    }

    if (item is WashingItem) return item.noWashing;

    if (item is CrusherItem) return item.noCrusher;

    if (item is GilinganItem) {
      final part = (item.noGilinganPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noGilingan;
    }

    if (item is MixerItem) {
      final part = (item.noMixerPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noMixer;
    }

    if (item is RejectItem) {
      final part = (item.noRejectPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noReject;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Temp selections (anti-duplicate)
  // ---------------------------------------------------------------------------
  final List<BrokerItem> tempBroker = [];
  final List<BrokerItem> tempBrokerPartial = []; // TAMBAHKAN INI

  final List<BbItem> tempBb = [];
  final List<BbItem> tempBbPartial = [];

  final List<WashingItem> tempWashing = [];

  final List<CrusherItem> tempCrusher = [];

  final List<GilinganItem> tempGilingan = [];
  final List<GilinganItem> tempGilinganPartial = [];

  final List<MixerItem> tempMixer = [];
  final List<MixerItem> tempMixerPartial = [];

  final List<RejectItem> tempReject = [];
  final List<RejectItem> tempRejectPartial = [];

  final Set<String> _pickedKeys = <String>{};
  final List<Map<String, dynamic>> _pickedRows = <Map<String, dynamic>>[];
  final Map<String, int> _keyToRowIndex = {};

  // Keys we manage
  final Set<String> _tempKeys = <String>{};

  // ====== key builders ======
  String _keyFromBrokerItem(BrokerItem i) =>
      'D.|Broker_d|${i.noBroker ?? '-'}|${(i.noSak ?? '').toString().trim()}';
  String _keyFromBbItem(BbItem i) {
    final noBB = i.noBahanBaku ?? '-';
    final noSak = (i.noSak ?? '').toString().trim();
    final noPallet = i.noPallet ?? 0;

    return 'A.|BahanBaku_d|$noBB|$noPallet|$noSak';
  }

  String _keyFromWashingItem(WashingItem i) =>
      'B.|Washing_d|${i.noWashing ?? '-'}|${(i.noSak ?? '').toString().trim()}';
  String _keyFromCrusherItem(CrusherItem i) =>
      'F.|Crusher|${i.noCrusher ?? '-'}|';
  /// Key untuk item gilingan. Kode (temp/DB) partial ikut disertakan agar
  /// beberapa partial untuk label yang sama tidak saling collision —
  /// full input tetap memakai key tanpa kode (format sama seperti sebelumnya).
  String _keyFromGilinganItem(GilinganItem i) {
    final part = (i.noGilinganPartial ?? '').trim();
    if (part.isEmpty) return 'V.|Gilingan|${i.noGilingan ?? '-'}|';
    return 'V.|Gilingan|${i.noGilingan ?? '-'}|$part';
  }
  String _keyFromMixerItem(MixerItem i) =>
      'H.|Mixer_d|${i.noMixer ?? '-'}|${(i.noSak ?? '').toString().trim()}';
  String _keyFromRejectItem(RejectItem i) =>
      'BF.|RejectV2|${i.noReject ?? '-'}|';

  // ====== keys in DB (from cache) ======
  Set<String> _dbKeysFor(String noProduksi) {
    final keys = <String>{};
    final db = _inputsCache[noProduksi];
    if (db != null) {
      for (final x in db.broker) keys.add(_keyFromBrokerItem(x));
      for (final x in db.bb) keys.add(_keyFromBbItem(x));
      for (final x in db.washing) keys.add(_keyFromWashingItem(x));
      for (final x in db.crusher) keys.add(_keyFromCrusherItem(x));
      for (final x in db.gilingan) keys.add(_keyFromGilinganItem(x));
      for (final x in db.mixer) keys.add(_keyFromMixerItem(x));
      for (final x in db.reject) keys.add(_keyFromRejectItem(x));
    }
    return keys;
  }

  // ====== DB + TEMP ======
  Set<String> _allKeysFor(String noProduksi) {
    final all = _dbKeysFor(noProduksi);
    all.addAll(_tempKeys);
    return all;
  }

  // ====== PUBLIC API (TEMP-only duplicate checks) ======
  bool isRowAlreadyPresent(Map<String, dynamic> row, String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return false;
    final simpleKey = ctx.simpleKey(row);
    // ⬇️ hanya cek di TEMP
    return _tempKeys.contains(simpleKey);
  }

  int countNewRowsInLastLookup(String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return 0;
    // ⬇️ hanya bandingkan dengan TEMP
    return ctx.data.where((r) => !_tempKeys.contains(ctx.simpleKey(r))).length;
  }

  bool willBeDuplicate(Map<String, dynamic> row, String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return false;
    final simpleKey = ctx.simpleKey(row);
    // ⬇️ hanya cek di TEMP
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
    return '${pickedCount} ${ctx.prefixType.displayName} dipilih';
  }

  void pickAllNew(String noProduksi) {
    final ctx = lastLookup;
    if (ctx == null) return;

    // ⬇️ TEMP-only: jangan pakai _allKeysFor
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
  // Commit picked → TEMP (strict anti-duplicate)
  // ---------------------------------------------------------------------------
  bool _rowIsPartial(Map<String, dynamic> row, PrefixType t) {
    final candKeys = const [
      'IsPartial',
      'isPartial',
      'IsPartialRow',
      'isPartialRow',
    ];
    for (final k in candKeys) {
      final v = row[k];
      if (v is bool && v) return true;
      if (v is num && v != 0) return true;
      if (v is String && (v == '1' || v.toLowerCase() == 'true')) return true;
    }
    switch (t) {
      case PrefixType.broker: // TAMBAHKAN
        final s = (row['NoBrokerPartial'] ?? row['noBrokerPartial'] ?? '')
            .toString()
            .trim();
        return s.isNotEmpty;
      case PrefixType.bb:
        final s = (row['NoBBPartial'] ?? row['noBBPartial'] ?? '')
            .toString()
            .trim();
        return s.isNotEmpty;
      case PrefixType.gilingan:
        final s = (row['NoGilinganPartial'] ?? row['noGilinganPartial'] ?? '')
            .toString()
            .trim();
        return s.isNotEmpty;
      case PrefixType.mixer:
        final s = (row['NoMixerPartial'] ?? row['noMixerPartial'] ?? '')
            .toString()
            .trim();
        return s.isNotEmpty;
      case PrefixType.reject:
        final s = (row['NoRejectPartial'] ?? row['noRejectPartial'] ?? '')
            .toString()
            .trim();
        return s.isNotEmpty;
      default:
        return false;
    }
  }

  TempCommitResult commitPickedToTemp({required String noProduksi}) {
    final ctx = lastLookup;
    if (ctx == null || _pickedRows.isEmpty) return const TempCommitResult(0, 0);

    // ⬇️ snapshot TEMP saat ini agar bisa dipakai sebagai "seen" dalam loop
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

      // ⬇️ PENTING: Gunakan rawRow yang sudah mungkin dimodifikasi (berat diubah)
      // Buat simpleKey dari rawRow yang terbaru
      final simpleKey = ctx.simpleKey(rawRow);

      // ⬇️ Cek apakah ini partial dan sudah pernah ada di temp
      final bool isPartial = _rowIsPartial(rawRow, ctx.prefixType);

      // ⬇️ Untuk partial, kita perlu cek lebih lanjut
      // Karena partial dengan berat berbeda bisa dianggap item baru
      bool shouldSkip = false;

      if (isPartial) {
        // Cek apakah ada item dengan base key yang sama di temp
        final existingPartial = _findExistingPartialItem(item, ctx.prefixType);

        if (existingPartial != null) {
          // Ada partial dengan nomor yang sama, tapi berat bisa beda
          // Cek apakah beratnya sama
          final existingWeight = _getWeightFromItem(existingPartial);
          final newWeight = rawRow['berat'] ?? rawRow['Berat'];

          if (existingWeight == newWeight) {
            // Berat sama, skip
            shouldSkip = true;
          }
          // Jika berat beda, lanjutkan (anggap sebagai item baru)
        }

        if (!shouldSkip) {
          // Label yang sudah di-stage sebagai input FULL tidak boleh
          // ditambahkan partial di atasnya (proteksi base-key).
          final baseKey = _getBaseKeyWithoutWeight(rawRow, ctx.prefixType);
          if (baseKey.isNotEmpty && seenTemp.contains(baseKey)) {
            shouldSkip = true;
          }
        }
      } else {
        // Untuk non-partial, gunakan logika lama
        if (seenTemp.contains(simpleKey)) {
          shouldSkip = true;
        } else if (_findExistingPartialItem(item, ctx.prefixType) != null) {
          // Sudah di-stage sebagai partial; input full untuk label yang sama
          // tidak konsisten dengan partial tersebut.
          shouldSkip = true;
        }
      }

      if (shouldSkip) {
        skipped++;
        continue;
      }

      // Kode partial sementara diperoleh SEBELUM key item dihitung supaya
      // key tiap input partial terdiferensiasi per kode partial.
      final newItem = _withTempPartialIfNeeded(item, ctx.prefixType, isPartial);

      final String tempKey = newItem is BrokerItem
          ? _keyFromBrokerItem(newItem)
          : newItem is BbItem
          ? _keyFromBbItem(newItem)
          : newItem is WashingItem
          ? _keyFromWashingItem(newItem)
          : newItem is CrusherItem
          ? _keyFromCrusherItem(newItem)
          : newItem is GilinganItem
          ? _keyFromGilinganItem(newItem)
          : newItem is MixerItem
          ? _keyFromMixerItem(newItem)
          : newItem is RejectItem
          ? _keyFromRejectItem(newItem)
          : simpleKey;

      // ⬇️ kalau key TEMP sama sudah ada, skip (ini juga TEMP-only)
      if (!_tempKeys.add(tempKey)) {
        skipped++;
        continue;
      }
      // masukkan juga ke "seen" supaya batch berikutnya tahu
      seenTemp.add(simpleKey);

      bool itemAdded = false;
      if (newItem is BbItem) {
        if (newItem.isPartialRow) {
          tempBbPartial.add(newItem);
        } else {
          tempBb.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is GilinganItem) {
        if (newItem.isPartialRow) {
          tempGilinganPartial.add(newItem);
        } else {
          tempGilingan.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is MixerItem) {
        if (newItem.isPartialRow) {
          tempMixerPartial.add(newItem);
        } else {
          tempMixer.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is RejectItem) {
        if (newItem.isPartialRow) {
          tempRejectPartial.add(newItem);
        } else {
          tempReject.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is BrokerItem) {
        if (newItem.isPartialRow) {
          tempBrokerPartial.add(newItem);
        } else {
          tempBroker.add(newItem);
        }
        itemAdded = true;
      } else if (newItem is WashingItem) {
        tempWashing.add(newItem);
        itemAdded = true;
      } else if (newItem is CrusherItem) {
        tempCrusher.add(newItem);
        itemAdded = true;
      }

      if (itemAdded) {
        final code = _getItemLabelCode(newItem);
        if (code != null && code.trim().isNotEmpty)
          affectedLabels.add(code.trim());
        added++;
      } else {
        // rollback key yg barusan ditambah
        _tempKeys.remove(tempKey);
        skipped++;
      }
    }

    for (final label in affectedLabels) {
      _updateTempItemsByLabel(label);
    }

    debugDumpTempLists(tag: 'after commitPickedToTemp (TEMP-only dedup)');
    debugDumpTempByLabel();
    debugDumpTempKeys(tag: 'after commit');

    clearPicks();
    notifyListeners();
    return TempCommitResult(added, skipped);
  }

  // Helper methods baru untuk cek partial
  String _getBaseKeyWithoutWeight(Map<String, dynamic> row, PrefixType type) {
    // Buat key tanpa memperhitungkan berat
    switch (type) {
      case PrefixType.broker: // TAMBAHKAN
        final noBroker = row['NoBroker'] ?? row['noBroker'] ?? '';
        final noSak = row['NoSak'] ?? row['noSak'] ?? '';
        return 'D.|Broker_d|$noBroker|$noSak';
      case PrefixType.bb:
        final noBb = row['NoBahanBaku'] ?? row['noBahanBaku'] ?? '';
        final noPallet = row['NoPallet'] ?? row['noPallet'] ?? 0;
        final noSak = row['NoSak'] ?? row['noSak'] ?? '';
        return 'A.|BahanBaku_d|$noBb|$noPallet|$noSak';
      case PrefixType.gilingan:
        final noGil = row['NoGilingan'] ?? row['noGilingan'] ?? '';
        //Harus identik dengan format key item FULL dari _keyFromGilinganItem
        return 'V.|Gilingan|$noGil|';
      case PrefixType.mixer:
        final noMix = row['NoMixer'] ?? row['noMixer'] ?? '';
        final noSak = row['NoSak'] ?? row['noSak'] ?? '';
        return 'H.|Mixer_d|$noMix|$noSak';
      case PrefixType.reject:
        final noRej = row['NoReject'] ?? row['noReject'] ?? '';
        return 'BF.|RejectV2|$noRej';
      default:
        return '';
    }
  }

  dynamic _findExistingPartialItem(dynamic item, PrefixType type) {
    if (item is BrokerItem) {
      for (final existing in tempBrokerPartial) {
        if (existing.noBroker == item.noBroker &&
            existing.noSak == item.noSak) {
          return existing;
        }
      }
    } else if (item is BbItem) {
      // Cari di tempBbPartial
      for (final existing in tempBbPartial) {
        if (existing.noBahanBaku == item.noBahanBaku &&
            existing.noPallet == item.noPallet &&
            existing.noSak == item.noSak) {
          return existing;
        }
      }
    } else if (item is GilinganItem) {
      // Cari di tempGilinganPartial
      for (final existing in tempGilinganPartial) {
        if (existing.noGilingan == item.noGilingan) {
          return existing;
        }
      }
    } else if (item is MixerItem) {
      // Cari di tempMixerPartial
      for (final existing in tempMixerPartial) {
        if (existing.noMixer == item.noMixer && existing.noSak == item.noSak) {
          return existing;
        }
      }
    } else if (item is RejectItem) {
      // Cari di tempRejectPartial
      for (final existing in tempRejectPartial) {
        if (existing.noReject == item.noReject) {
          return existing;
        }
      }
    }
    return null;
  }

  double? _getWeightFromItem(dynamic item) {
    if (item is BrokerItem) return item.berat;
    if (item is BbItem) return item.berat;
    if (item is GilinganItem) return item.berat;
    if (item is MixerItem) return item.berat;
    if (item is RejectItem) return item.berat;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Delete temp items (always maintain _tempKeys)
  // ---------------------------------------------------------------------------
  void deleteTempBrokerItem(BrokerItem item) {
    tempBroker.remove(item);
    tempBrokerPartial.remove(item); // TAMBAHKAN
    _tempKeys.remove(_keyFromBrokerItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempBrokerItem');
    notifyListeners();
  }

  void deleteTempBbItem(BbItem item) {
    tempBb.remove(item);
    tempBbPartial.remove(item);
    _tempKeys.remove(_keyFromBbItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempBbItem');
    notifyListeners();
  }

  void deleteTempWashingItem(WashingItem item) {
    tempWashing.remove(item);
    _tempKeys.remove(_keyFromWashingItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempWashingItem');
    notifyListeners();
  }

  void deleteTempCrusherItem(CrusherItem item) {
    tempCrusher.remove(item);
    _tempKeys.remove(_keyFromCrusherItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempCrusherItem');
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

  void deleteTempMixerItem(MixerItem item) {
    tempMixer.remove(item);
    tempMixerPartial.remove(item);
    _tempKeys.remove(_keyFromMixerItem(item));
    final code = _getItemLabelCode(item);
    if (code != null) _updateTempItemsByLabel(code);
    debugDumpTempLists(tag: 'after deleteTempMixerItem');
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

  void deleteTempItemsForLabel(String labelCode) {
    final t = getTemporaryDataForLabel(labelCode);
    if (t == null || t.isEmpty) return;
    final allItems = [
      ...t.brokerItems,
      ...t.brokerPartials,
      ...t.bbItems,
      ...t.bbPartials,
      ...t.washingItems,
      ...t.crusherItems,
      ...t.gilinganItems,
      ...t.gilinganPartials,
      ...t.mixerItems,
      ...t.mixerPartials,
      ...t.rejectItems,
      ...t.rejectPartials,
    ];
    removeTemporaryItemsForLabel(labelCode, allItems);
  }

  void clearAllTempItems() {
    tempBroker.clear();
    tempBrokerPartial.clear(); // TAMBAHKAN

    tempBb.clear();
    tempBbPartial.clear();

    tempWashing.clear();
    tempCrusher.clear();

    tempGilingan.clear();
    tempGilinganPartial.clear();

    tempMixer.clear();
    tempMixerPartial.clear();

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
    if (item is BrokerItem) {
      ok = tempBroker.remove(item) || tempBrokerPartial.remove(item); // UPDATE
      if (ok) _tempKeys.remove(_keyFromBrokerItem(item));
    } else if (item is BbItem) {
      ok = tempBb.remove(item) || tempBbPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromBbItem(item));
    } else if (item is WashingItem) {
      ok = tempWashing.remove(item);
      if (ok) _tempKeys.remove(_keyFromWashingItem(item));
    } else if (item is CrusherItem) {
      ok = tempCrusher.remove(item);
      if (ok) _tempKeys.remove(_keyFromCrusherItem(item));
    } else if (item is GilinganItem) {
      ok = tempGilingan.remove(item) || tempGilinganPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromGilinganItem(item));
    } else if (item is MixerItem) {
      ok = tempMixer.remove(item) || tempMixerPartial.remove(item);
      if (ok) _tempKeys.remove(_keyFromMixerItem(item));
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

  // ===== Temp-partial numbering state (per kategori) =====
  final Map<PrefixType, int> _tempPartialSeq = {
    PrefixType.broker: 0, // TAMBAHKAN
    PrefixType.bb: 0,
    PrefixType.gilingan: 0,
    PrefixType.mixer: 0,
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
      case PrefixType.broker:
        return 'Q.XXXXXXXX ($numStr)';
      case PrefixType.bb:
        return 'P.XXXXXXXX ($numStr)';
      case PrefixType.gilingan:
        return 'Y.XXXXXXXX ($numStr)';
      case PrefixType.mixer:
        return 'T.XXXXXXXX ($numStr)';
      case PrefixType.reject:
        return 'BK.XXXXXXXX ($numStr)';
      default:
        return '';
    }
  }

  /// create copy with temp-partial only if `isPartial==true` and category supports it
  dynamic _withTempPartialIfNeeded(dynamic item, PrefixType t, bool isPartial) {
    final supports =
        t == PrefixType.broker ||
        t == PrefixType.bb ||
        t == PrefixType.gilingan ||
        t == PrefixType.mixer ||
        t == PrefixType.reject;
    if (!supports || !isPartial) return item;

    if (item is BrokerItem) {
      final already = (item.noBrokerPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq(t));
        return item.copyWith(noBrokerPartial: code);
      }
      return item;
    }

    if (item is BbItem) {
      final already = (item.noBBPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq(t));
        return item.copyWith(noBBPartial: code);
      }
      return item;
    }

    if (item is GilinganItem) {
      final already = (item.noGilinganPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq(t));
        return item.copyWith(noGilinganPartial: code);
      }
      return item;
    }

    if (item is MixerItem) {
      final already = (item.noMixerPartial ?? '').trim().isNotEmpty;
      if (!already) {
        final code = _formatTempPartial(t, _nextPartialSeq(t));
        return item.copyWith(noMixerPartial: code);
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
      tempBroker.length +
      tempBrokerPartial.length + // TAMBAHKAN
      tempBb.length +
      tempBbPartial.length +
      tempWashing.length +
      tempCrusher.length +
      tempGilingan.length +
      tempGilinganPartial.length +
      tempMixer.length +
      tempMixerPartial.length +
      tempReject.length +
      tempRejectPartial.length;

  // ---------------------------------------------------------------------------
  // Submit temp items to backend
  // ---------------------------------------------------------------------------
  bool isSubmitting = false;
  String? submitError;

  /// Build payload dari temp items sesuai format API
  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{};

    // Existing inputs (full items only, tanpa partial)
    if (tempBroker.isNotEmpty) {
      payload['broker'] = tempBroker
          .map((e) => {'noBroker': e.noBroker, 'noSak': e.noSak})
          .toList();
    }

    if (tempBb.isNotEmpty) {
      payload['bb'] = tempBb
          .map(
            (e) => {
              'noBahanBaku': e.noBahanBaku,
              'noPallet': e.noPallet,
              'noSak': e.noSak,
            },
          )
          .toList();
    }

    if (tempWashing.isNotEmpty) {
      payload['washing'] = tempWashing
          .map((e) => {'noWashing': e.noWashing, 'noSak': e.noSak})
          .toList();
    }

    if (tempCrusher.isNotEmpty) {
      payload['crusher'] = tempCrusher
          .map((e) => {'noCrusher': e.noCrusher})
          .toList();
    }

    if (tempGilingan.isNotEmpty) {
      payload['gilingan'] = tempGilingan
          .map((e) => {'noGilingan': e.noGilingan})
          .toList();
    }

    if (tempMixer.isNotEmpty) {
      payload['mixer'] = tempMixer
          .map((e) => {'noMixer': e.noMixer, 'noSak': e.noSak})
          .toList();
    }

    if (tempReject.isNotEmpty) {
      payload['reject'] = tempReject
          .map((e) => {'noReject': e.noReject})
          .toList();
    }

    if (tempBrokerPartial.isNotEmpty) {
      payload['brokerPartial'] = tempBrokerPartial
          .map(
            (e) => {'noBroker': e.noBroker, 'noSak': e.noSak, 'berat': e.berat},
          )
          .toList();
    }

    // NEW partials to create
    if (tempBbPartial.isNotEmpty) {
      payload['bbPartial'] = tempBbPartial
          .map(
            (e) => {
              'noBahanBaku': e.noBahanBaku,
              'noPallet': e.noPallet,
              'noSak': e.noSak,
              'berat': e.berat,
            },
          )
          .toList();
    }

    if (tempGilinganPartial.isNotEmpty) {
      payload['gilinganPartial'] = tempGilinganPartial
          .map((e) => {'noGilingan': e.noGilingan, 'berat': e.berat})
          .toList();
    }

    if (tempMixerPartial.isNotEmpty) {
      payload['mixerPartial'] = tempMixerPartial
          .map(
            (e) => {'noMixer': e.noMixer, 'noSak': e.noSak, 'berat': e.berat},
          )
          .toList();
    }

    if (tempRejectPartial.isNotEmpty) {
      payload['rejectPartial'] = tempRejectPartial
          .map((e) => {'noReject': e.noReject, 'berat': e.berat})
          .toList();
    }

    return payload;
  }

  /// Submit all temp items to backend
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

      final response = await repository.submitInputsAndPartials(
        noProduksi,
        payload,
      );

      _d('Submit response: ${json.encode(response)}');

      // Parse response
      final success = response['success'] as bool? ?? false;
      final data = response['data'] as Map<String, dynamic>?;

      if (!success) {
        final message = response['message'] as String? ?? 'Submit gagal';
        submitError = message;

        // Log details if available
        if (data != null) {
          final details = data['details'] as Map<String, dynamic>?;
          if (details != null) {
            _d('Submit details: ${json.encode(details)}');
          }
        }

        return false;
      }

      // Success - clear temp and refresh
      _d('Submit successful!');

      // Log created partials if any
      if (data != null) {
        final createdPartials =
            data['createdPartials'] as Map<String, dynamic>?;
        if (createdPartials != null) {
          _d('Created partials: ${json.encode(createdPartials)}');
        }
      }

      // Clear all temp items
      clearAllTempItems();

      // ✅ TAMBAHKAN: Clear lookup cache agar lookup berikutnya fresh
      clearLookupCache();

      // Invalidate cache untuk noProduksi ini
      clearInputsCache(noProduksi);
      clearOutputsState(noProduksi);

      // Reload inputs
      await loadInputs(noProduksi, force: true);
      await loadOutputs(noProduksi);

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

  /// Get summary of what will be submitted
  String getSubmitSummary() {
    if (totalTempCount == 0) return 'Tidak ada data';

    final parts = <String>[];

    if (tempBroker.isNotEmpty) {
      parts.add('${tempBroker.length} Broker');
    }
    if (tempBrokerPartial.isNotEmpty) {
      // TAMBAHKAN
      parts.add('${tempBrokerPartial.length} Broker Partial');
    }
    if (tempBb.isNotEmpty) {
      parts.add('${tempBb.length} Bahan Baku');
    }
    if (tempBbPartial.isNotEmpty) {
      parts.add('${tempBbPartial.length} BB Partial');
    }
    if (tempWashing.isNotEmpty) {
      parts.add('${tempWashing.length} Washing');
    }
    if (tempCrusher.isNotEmpty) {
      parts.add('${tempCrusher.length} Crusher');
    }
    if (tempGilingan.isNotEmpty) {
      parts.add('${tempGilingan.length} Gilingan');
    }
    if (tempGilinganPartial.isNotEmpty) {
      parts.add('${tempGilinganPartial.length} Gilingan Partial');
    }
    if (tempMixer.isNotEmpty) {
      parts.add('${tempMixer.length} Mixer');
    }
    if (tempMixerPartial.isNotEmpty) {
      parts.add('${tempMixerPartial.length} Mixer Partial');
    }
    if (tempReject.isNotEmpty) {
      parts.add('${tempReject.length} Reject');
    }
    if (tempRejectPartial.isNotEmpty) {
      parts.add('${tempRejectPartial.length} Reject Partial');
    }

    return 'Total $totalTempCount items:\n${parts.join(', ')}';
  }

  // ---------------------------------------------------------------------------
  // Delete inputs & partials (DB + TEMP)
  // ---------------------------------------------------------------------------
  bool isDeleting = false;
  String? deleteError;
  Map<String, dynamic>? lastDeleteResult;

  /// Build payload untuk endpoint DELETE /api/production/broker/:noProduksi/inputs
  /// dari list item yang berasal dari DB (bukan temp).
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
      if (it is BrokerItem) {
        final isPart =
            it.isPartialRow || ((it.noBrokerPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noBrokerPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('brokerPartial', {'noBrokerPartial': code});
          }
        } else {
          add('broker', {'noBroker': it.noBroker, 'noSak': it.noSak});
        }
      } else if (it is BbItem) {
        final isPart =
            it.isPartialRow || ((it.noBBPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noBBPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('bbPartial', {'noBBPartial': code});
          }
        } else {
          add('bb', {
            'noBahanBaku': it.noBahanBaku,
            'noPallet': it.noPallet,
            'noSak': it.noSak,
          });
        }
      } else if (it is WashingItem) {
        add('washing', {'noWashing': it.noWashing, 'noSak': it.noSak});
      } else if (it is CrusherItem) {
        add('crusher', {'noCrusher': it.noCrusher});
      } else if (it is GilinganItem) {
        final isPart =
            it.isPartialRow || ((it.noGilinganPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noGilinganPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('gilinganPartial', {'noGilinganPartial': code});
          }
        } else {
          add('gilingan', {'noGilingan': it.noGilingan});
        }
      } else if (it is MixerItem) {
        final isPart =
            it.isPartialRow || ((it.noMixerPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noMixerPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('mixerPartial', {'noMixerPartial': code});
          }
        } else {
          add('mixer', {'noMixer': it.noMixer, 'noSak': it.noSak});
        }
      } else if (it is RejectItem) {
        final isPart =
            it.isPartialRow || ((it.noRejectPartial ?? '').trim().isNotEmpty);
        if (isPart) {
          final code = (it.noRejectPartial ?? '').trim();
          if (code.isNotEmpty) {
            add('rejectPartial', {'noRejectPartial': code});
          }
        } else {
          add('reject', {'noReject': it.noReject});
        }
      }
    }

    return payload;
  }

  /// Hapus item (bisa campuran DB & TEMP) untuk satu noProduksi:
  /// - Jika item ada di TEMP → cukup delete dari temp (tanpa call API)
  /// - Jika item dari DB → build payload dan call DELETE API, lalu reload inputs
  Future<bool> deleteItems(String noProduksi, List<dynamic> items) async {
    if (items.isEmpty) {
      deleteError = 'Tidak ada data yang dipilih untuk dihapus';
      notifyListeners();
      return false;
    }

    // 1) Pisahkan: mana yang temp, mana yang DB
    final List<dynamic> dbItems = [];

    for (final it in items) {
      final removedFromTemp = deleteIfTemp(it);
      if (!removedFromTemp) {
        dbItems.add(it); // ini diasumsikan item dari DB (inputs cache)
      }
    }

    // Kalau semua ternyata temp → tidak perlu call API
    if (dbItems.isEmpty) {
      _d('deleteItems: hanya menghapus TEMP, tidak call API');
      // deleteIfTemp sudah update sebagian; update group by label juga sudah dilakukan
      notifyListeners();
      return true;
    }

    // 2) Build payload dari DB items
    final payload = _buildDeletePayloadFromItems(dbItems);
    if (payload.isEmpty) {
      deleteError = 'Tidak ada data valid untuk dihapus (payload kosong)';
      notifyListeners();
      return false;
    }

    // 3) Call API lewat repository
    isDeleting = true;
    deleteError = null;
    notifyListeners();

    try {
      _d('deleteItems: calling deleteInputsAndPartials for $noProduksi');
      _d('Delete payload: ${json.encode(payload)}');

      final res = await repository.deleteInputsAndPartials(noProduksi, payload);
      lastDeleteResult = res;

      final success = res['success'] == true;
      final message = res['message'] as String? ?? '';

      _d('Delete response: ${json.encode(res)}');

      if (!success) {
        deleteError = message.isEmpty ? 'Gagal menghapus data' : message;
        return false;
      }

      // Berhasil: invalidasi & reload inputs
      clearInputsCache(noProduksi);
      clearOutputsState(noProduksi);
      await loadInputs(noProduksi, force: true);
      await loadOutputs(noProduksi);

      // Opsional: bisa juga clear temp untuk label terkait,
      // tapi karena tadi deleteIfTemp sudah dipanggil, state temp sudah bersih untuk item2 yg dihapus.

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

  // ---------------------------------------------------------------------------
  // Move Outputs
  // ---------------------------------------------------------------------------
  bool isMoveOutputLoading = false;
  String? moveOutputError;

  Future<bool> moveOutputs(
    String noProduksi,
    String targetNoProduksi,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      moveOutputError = 'Pilih minimal satu item untuk dipindahkan';
      notifyListeners();
      return false;
    }

    isMoveOutputLoading = true;
    moveOutputError = null;
    notifyListeners();

    try {
      await repository.moveOutputs(noProduksi, targetNoProduksi, items);
      await loadOutputs(noProduksi);
      return true;
    } catch (e) {
      moveOutputError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isMoveOutputLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Move Bonggolan Outputs
  // ---------------------------------------------------------------------------
  bool isMoveBonggolanOutputLoading = false;
  String? moveBonggolanOutputError;

  Future<bool> moveBonggolanOutputs(
    String noProduksi,
    String targetNoProduksi,
    List<String> noBonggolanList,
  ) async {
    if (noBonggolanList.isEmpty) {
      moveBonggolanOutputError =
          'Pilih minimal satu bonggolan untuk dipindahkan';
      notifyListeners();
      return false;
    }

    isMoveBonggolanOutputLoading = true;
    moveBonggolanOutputError = null;
    notifyListeners();

    try {
      await repository.moveBonggolanOutputs(
        noProduksi,
        targetNoProduksi,
        noBonggolanList,
      );
      await loadOutputs(noProduksi);
      return true;
    } catch (e) {
      moveBonggolanOutputError = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isMoveBonggolanOutputLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    try {
      pagingController.dispose();
    } catch (_) {}
    super.dispose();
  }
}
