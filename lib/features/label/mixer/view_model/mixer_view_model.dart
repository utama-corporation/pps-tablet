import 'package:flutter/material.dart';

import '../model/mixer_detail_model.dart';
import '../model/mixer_partial_model.dart';
import '../model/mixer_header_model.dart';
import '../repository/mixer_repository.dart';

class MixerViewModel extends ChangeNotifier {
  final MixerRepository repository;

  MixerViewModel({required this.repository});

  // === HEADER STATE ===
  List<MixerHeader> items = [];
  bool isLoading = false;
  bool isFetchingMore = false;
  String errorMessage = '';

  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _search = '';

  /// Public getter for total rows from the API
  int get totalCount => _total;
  bool includeUsed = false;

  void setIncludeUsed(bool value) {
    if (includeUsed == value) return;
    includeUsed = value;
    fetchHeaders(search: _search);
  }

  // === DETAIL STATE ===
  String? selectedNoMixer; // single source of highlight
  List<MixerDetail> details = [];
  bool isDetailLoading = false;
  String detailError = '';

  String? lastCreatedNoMixer;

  // === PARTIAL INFO STATE ===
  MixerPartialInfo? partialInfo;
  bool isPartialLoading = false;
  String? partialError;

  // Helper: current selected mixer code
  String? get currentNoMixer => selectedNoMixer;

  // =============================
  //  Highlight helpers
  // =============================

  /// Set / move highlight to [no] (or null to clear) without loading detail.
  void setSelectedNoMixer(String? no) {
    if (selectedNoMixer == no) return;
    selectedNoMixer = no;
    notifyListeners();
  }

  // =============================
  //  FETCH HEADER (RESET)
  // =============================
  Future<void> fetchHeaders({String search = ''}) async {
    _page = 1;
    _search = search;
    items = [];
    errorMessage = '';
    isLoading = true;

    // reset selection when list reloads
    selectedNoMixer = null;
    notifyListeners();

    try {
      final result = await repository.fetchHeaders(
        page: _page,
        limit: 20,
        search: _search,
        includeUsed: includeUsed,
      );

      items = result['items'] as List<MixerHeader>;
      _totalPages = result['totalPages'] ?? 1;
      _total = result['total'] ?? 0;

      debugPrint("✅ Mixer page $_page loaded, total items: ${items.length}");
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error fetchHeaders (Mixer): $errorMessage");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  //  LOAD MORE (PAGINATION)
  // =============================
  Future<void> loadMore() async {
    if (isFetchingMore || _page >= _totalPages) return;

    isFetchingMore = true;
    notifyListeners();

    try {
      _page++;
      final result = await repository.fetchHeaders(
        page: _page,
        limit: 20,
        search: _search,
        includeUsed: includeUsed,
      );

      final moreItems = result['items'] as List<MixerHeader>;
      items.addAll(moreItems);

      debugPrint(
        "📥 Mixer load more page $_page, total items: ${items.length}",
      );
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error loadMore (Mixer): $errorMessage");
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  bool get hasMore => _page < _totalPages;

  // =============================
  //  FETCH DETAIL
  // =============================
  Future<void> fetchDetails(String noMixer) async {
    // ensure highlight matches the mixer whose details are loaded
    setSelectedNoMixer(noMixer);

    details = [];
    detailError = '';
    isDetailLoading = true;
    notifyListeners();

    try {
      details = await repository.fetchDetails(noMixer);
      debugPrint(
        "✅ Mixer details loaded for $noMixer, count: ${details.length}",
      );
    } catch (e) {
      detailError = e.toString();
      debugPrint("❌ Error fetchDetails($noMixer): $detailError");
    } finally {
      isDetailLoading = false;
      notifyListeners();
    }
  }

  // =============================
  //  CREATE MIXER
  // =============================
  Future<Map<String, dynamic>?> createMixer(
    MixerHeader header,
    List<MixerDetail> details, {
    required String outputCode, // <-- wajib, diisi dari UI
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      debugPrint(
        "➡️ [MixerVM] createMixer noMixer=${header.noMixer}, "
        "outputCode=$outputCode, details=${details.length}",
      );

      final res = await repository.createMixer(
        header: header,
        details: details,
        outputCode: outputCode, // selalu diteruskan ke repository
      );

      lastCreatedNoMixer = res['data']?['header']?['NoMixer'] as String?;

      // refresh list
      await fetchHeaders(search: _search);

      // auto-highlight newly created mixer
      if (lastCreatedNoMixer != null) {
        setSelectedNoMixer(lastCreatedNoMixer);
      }
      return res;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error createMixer: $errorMessage");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  //  UPDATE MIXER
  // =============================
  Future<Map<String, dynamic>?> updateMixer(
    MixerHeader header,
    List<MixerDetail> details,
  ) async {
    final noMixer = header.noMixer;
    try {
      isLoading = true;
      notifyListeners();

      debugPrint(
        "➡️ [MixerVM] updateMixer noMixer=$noMixer, "
        "details=${details.length}",
      );

      final res = await repository.updateMixer(
        noMixer: noMixer,
        header: header,
        details: details,
        // outputCode: null → biarkan mapping lama (tidak disentuh)
      );

      // refresh list so updated data is visible
      await fetchHeaders(search: _search);

      // auto-highlight updated mixer
      setSelectedNoMixer(noMixer);

      return res;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error updateMixer: $errorMessage");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> updateMixerQc({
    required String noMixer,
    required double? moisture1,
    required double? moisture2,
    required double? moisture3,
    required double? minMeltTemp,
    required double? maxMeltTemp,
    required double? mfi,
    required String? visualNote,
  }) async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final res = await repository.updateMixerQc(
        noMixer: noMixer,
        moisture1: moisture1,
        moisture2: moisture2,
        moisture3: moisture3,
        minMeltTemp: minMeltTemp,
        maxMeltTemp: maxMeltTemp,
        mfi: mfi,
        visualNote: visualNote,
      );

      await fetchHeaders(search: _search);
      setSelectedNoMixer(noMixer);
      return res;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error updateMixerQc: $errorMessage");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  //  DELETE MIXER
  // =============================
  Future<bool> deleteMixer(String noMixer) async {
    try {
      isLoading = true;
      notifyListeners();

      debugPrint("🗑 [MixerVM] deleteMixer noMixer=$noMixer");

      await repository.deleteMixer(noMixer);

      await fetchHeaders(search: _search);

      // clear detail after delete
      details = [];
      detailError = '';
      selectedNoMixer = null;
      notifyListeners();

      return true;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error deleteMixer: $errorMessage");
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  //  LOAD PARTIAL INFO
  // =============================
  Future<void> loadPartialInfo({required int noSak}) async {
    final nm = currentNoMixer;
    if (nm == null || nm.isEmpty) {
      partialError = "NoMixer not selected";
      partialInfo = null;
      notifyListeners();
      return;
    }

    try {
      isPartialLoading = true;
      partialError = null;
      notifyListeners();

      debugPrint("➡️ [MixerVM] loadPartialInfo noMixer=$nm noSak=$noSak");

      partialInfo = await repository.fetchPartialInfo(
        noMixer: nm,
        noSak: noSak,
      );
    } catch (e) {
      partialError = e.toString();
      partialInfo = null;
      debugPrint("❌ Error loadPartialInfo($nm, $noSak): $partialError");
    } finally {
      isPartialLoading = false;
      notifyListeners();
    }
  }

  // =============================
  //  RESET FOR SCREEN
  // =============================
  void resetForScreen() {
    selectedNoMixer = null;
    details = [];
    detailError = '';
    // items will be refilled by fetchHeaders()
    notifyListeners();
  }
}
