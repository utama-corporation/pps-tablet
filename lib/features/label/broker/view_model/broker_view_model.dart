import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/view_model/label_qc_socket_manager.dart';
import '../model/broker_header_model.dart';
import '../model/broker_detail_model.dart';
import '../model/broker_partial_model.dart';
import '../repository/broker_repository.dart';
import '../../../shared/plastic_type/jenis_plastik_model.dart';
import '../../../shared/plastic_type/jenis_plastik_repository.dart';

class BrokerViewModel extends ChangeNotifier {
  final BrokerRepository repository;

  BrokerViewModel({required this.repository});

  // === HEADER STATE ===
  List<BrokerHeader> items = [];
  bool isLoading = false;
  bool isFetchingMore = false;
  String errorMessage = '';

  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _search = '';
  bool includeUsed = false;

  /// Public getter for total rows from the API
  int get totalCount => _total;

  // === DETAIL STATE ===
  String? selectedNoBroker; // ⬅️ satu-satunya sumber highlight
  List<BrokerDetail> details = [];
  bool isDetailLoading = false;
  String detailError = '';

  // === JENIS PLASTIK STATE ===
  final JenisPlastikRepository jenisRepo = JenisPlastikRepository();
  List<JenisPlastik> jenisList = [];
  JenisPlastik? selectedJenisPlastik;
  bool isJenisLoading = false;
  String jenisError = '';

  String? lastCreatedNoBroker;

  // === PARTIAL INFO STATE ===
  BrokerPartialInfo? partialInfo;
  bool isPartialLoading = false;
  String? partialError;

  // Helper: current selected broker code (you already store it)
  String? get currentNoBroker => selectedNoBroker;

  // =============================
  //  Highlight helpers
  // =============================

  /// Set / pindahkan highlight ke [no] (atau null untuk clear) tanpa memuat detail.
  void setSelectedNoBroker(String? no) {
    // ⬅️ baru
    if (selectedNoBroker == no) return;
    selectedNoBroker = no;
    notifyListeners();
  }

  // BrokerViewModel
  Future<void> loadJenisPlastik({int? preselectId}) async {
    isJenisLoading = true;
    jenisError = '';
    notifyListeners();

    try {
      final list = await jenisRepo.fetchAll(onlyActive: true);

      // Dedupe by id
      final byId = <int, JenisPlastik>{};
      for (final e in list) {
        byId[e.idJenisPlastik] = e;
      }
      jenisList = byId.values.toList();

      if (preselectId != null && jenisList.isNotEmpty) {
        selectedJenisPlastik = jenisList.firstWhere(
          (e) => e.idJenisPlastik == preselectId,
          orElse: () => jenisList.first,
        );
      } else if (jenisList.isNotEmpty) {
        // optional auto-select pertama
        // selectedJenisPlastik = jenisList.first;
      }
    } catch (e) {
      jenisError = e.toString();
      jenisList = [];
      selectedJenisPlastik = null;
    } finally {
      isJenisLoading = false;
      notifyListeners();
    }
  }

  // === FILTER: include used ===
  void setIncludeUsed(bool value) {
    if (includeUsed == value) return;
    includeUsed = value;
    fetchBrokerHeaders(search: _search);
  }

  // === FETCH HEADER (RESET) ===
  Future<void> fetchBrokerHeaders({String search = ''}) async {
    _page = 1;
    _search = search;
    items = [];
    errorMessage = '';
    isLoading = true;
    // ⬅️ reset selection saat daftar di-refresh supaya warna kembali default
    selectedNoBroker = null;
    notifyListeners();

    try {
      final result = await repository.fetchHeaders(
        page: _page,
        limit: 20,
        search: _search,
        includeUsed: includeUsed,
      );

      items = result['items'] as List<BrokerHeader>;
      _totalPages = result['totalPages'] ?? 1;
      _total = result['total'] ?? 0;

      debugPrint("✅ Page $_page loaded, total items: ${items.length}");
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error fetchBrokerHeaders: $errorMessage");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // === LOAD MORE (PAGINATION) ===
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

      final moreItems = result['items'] as List<BrokerHeader>;
      items.addAll(moreItems);

      debugPrint("📥 Load more page $_page, total items: ${items.length}");
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error loadMore: $errorMessage");
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  bool get hasMore => _page < _totalPages;

  // === FETCH DETAIL ===
  Future<void> fetchDetails(String noBroker) async {
    // ⬅️ pastikan highlight pindah ke item yang dimuat detailnya
    setSelectedNoBroker(noBroker);

    details = [];
    detailError = '';
    isDetailLoading = true;
    notifyListeners();

    try {
      details = await repository.fetchDetails(noBroker);
      debugPrint("✅ Details loaded for $noBroker, count: ${details.length}");
    } catch (e) {
      detailError = e.toString();
      debugPrint("❌ Error fetchDetails($noBroker): $detailError");
    } finally {
      isDetailLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createBroker(
    BrokerHeader header,
    List<BrokerDetail> details,
  ) async {
    try {
      isLoading = true;
      notifyListeners();

      final res = await repository.createBroker(
        header: header,
        details: details,
      );

      lastCreatedNoBroker = res['data']?['header']?['NoBroker'] as String?;

      // refresh list
      await fetchBrokerHeaders(search: _search);

      // ⬅️ opsional: auto-highlight hasil create
      if (lastCreatedNoBroker != null) {
        setSelectedNoBroker(lastCreatedNoBroker);
      }
      return res;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error createBroker: $errorMessage");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> updateBroker(
    String noBroker,
    BrokerHeader header,
    List<BrokerDetail> details,
  ) async {
    try {
      isLoading = true;
      notifyListeners();

      final res = await repository.updateBroker(
        noBroker: noBroker,
        header: header,
        details: details,
      );

      // Refresh list agar data terbaru tampil
      await fetchBrokerHeaders(search: _search);

      // Auto highlight yang barusan diupdate
      setSelectedNoBroker(noBroker);

      return res;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error updateBroker: $errorMessage");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> updateBrokerQc({
    required String noBroker,
    required double? density1,
    required double? density2,
    required double? density3,
    required double? moisture1,
    required double? moisture2,
    required double? moisture3,
    required double? maxMeltTemp,
    required double? minMeltTemp,
    required double? mfi,
    required String? visualNote,
    DateTime? dateQc,
  }) async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final res = await repository.updateBrokerQc(
        noBroker: noBroker,
        density1: density1,
        density2: density2,
        density3: density3,
        moisture1: moisture1,
        moisture2: moisture2,
        moisture3: moisture3,
        maxMeltTemp: maxMeltTemp,
        minMeltTemp: minMeltTemp,
        mfi: mfi,
        visualNote: visualNote,
        dateQc: dateQc,
      );

      // Patch baris yang sama di tempat (bukan refetch seluruh halaman) supaya
      // posisi scroll dan highlight pilihan tidak hilang.
      final idx = items.indexWhere((e) => e.noBroker == noBroker);
      if (idx >= 0) {
        final current = items[idx];
        items[idx] = current.withQc(
          density: density1,
          density2: density2,
          density3: density3,
          moisture: moisture1,
          moisture2: moisture2,
          moisture3: moisture3,
          maxMeltTemp: maxMeltTemp,
          minMeltTemp: minMeltTemp,
          mfi: mfi,
          visualNote: visualNote,
          dateQc: dateQc == null ? current.dateQc : toDbDateString(dateQc),
          qcBy: current.qcBy,
        );
      }

      setSelectedNoBroker(noBroker);

      return res;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error updateBrokerQc: $errorMessage");
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Terapkan update QC realtime dari tablet lain. Return true kalau baris
  ///-nya ada di list yang sedang tampil (jadi ter-highlight hijau).
  bool applyQcRealtime(LabelQcUpdatedEvent event) {
    if (event.kind != LabelQcKind.broker) return false;

    final idx = items.indexWhere((e) => e.noBroker == event.noLabel);
    if (idx < 0) return false;

    items[idx] = items[idx].withQc(
      density: event.density,
      density2: event.density2,
      density3: event.density3,
      moisture: event.moisture,
      moisture2: event.moisture2,
      moisture3: event.moisture3,
      maxMeltTemp: event.maxMeltTemp,
      minMeltTemp: event.minMeltTemp,
      mfi: event.mfi,
      visualNote: event.visualNote,
      dateQc: event.dateQc,
      qcBy: event.updatedBy,
    );
    notifyListeners();
    return true;
  }

  Future<bool> deleteWashing(String noBroker) async {
    try {
      isLoading = true;
      notifyListeners();

      await repository.deleteBroker(noBroker);

      await fetchBrokerHeaders(search: _search);

      // ⬇️ pastikan detail dibersihkan setelah delete
      details = [];
      detailError = '';
      selectedNoBroker = null;
      notifyListeners();

      return true;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint("❌ Error deleteWashing: $errorMessage");
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPartialInfo({required int noSak}) async {
    final nb = currentNoBroker;
    if (nb == null || nb.isEmpty) {
      partialError = "NoBroker not selected";
      partialInfo = null;
      notifyListeners();
      return;
    }

    try {
      isPartialLoading = true;
      partialError = null;
      notifyListeners();

      partialInfo = await repository.fetchPartialInfo(
        noBroker: nb,
        noSak: noSak,
      );
    } catch (e) {
      partialError = e.toString();
      partialInfo = null;
    } finally {
      isPartialLoading = false;
      notifyListeners();
    }
  }

  void resetForScreen() {
    // panggil ini saat masuk/keluar screen
    selectedNoBroker = null;
    details = [];
    detailError = '';
    // items tetap dibiarkan; akan diisi fetchBrokerHeaders
  }
}
