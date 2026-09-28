// lib/features/label/washing/view_model/washing_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/view_model/label_qc_socket_manager.dart';
import '../model/washing_header_model.dart';
import '../model/washing_detail_model.dart';
import '../repository/washing_repository.dart';

import '../../../shared/plastic_type/jenis_plastik_model.dart';
import '../../../shared/plastic_type/jenis_plastik_repository.dart';

class WashingViewModel extends ChangeNotifier {
  WashingViewModel({required this.repository});

  // =============================
  // Dependencies
  // =============================
  final WashingRepository repository;
  final JenisPlastikRepository jenisRepo = JenisPlastikRepository();

  // =============================
  // Header list state
  // =============================
  List<WashingHeader> items = [];
  bool isLoading = false;
  bool isFetchingMore = false;
  String errorMessage = '';

  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String _search = '';
  bool includeUsed = false;

  int get totalCount => _total;
  bool get hasMore => _page < _totalPages;

  // =============================
  // Selection + detail state
  // =============================
  String? selectedNoWashing; // single source of truth highlight
  List<WashingDetail> details = [];
  bool isDetailLoading = false;
  String detailError = '';

  // =============================
  // Jenis plastik state
  // =============================
  List<JenisPlastik> jenisList = [];
  JenisPlastik? selectedJenisPlastik;
  bool isJenisLoading = false;
  String jenisError = '';

  // =============================
  // Create result
  // =============================
  String? lastCreatedNoWashing;

  // =============================
  // Highlight helpers
  // =============================
  void setSelectedNoWashing(String? no) {
    if (selectedNoWashing == no) return;
    selectedNoWashing = no;
    notifyListeners();
  }

  // =============================
  // Jenis Plastik
  // =============================
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
      }
    } catch (e, st) {
      jenisError = e.toString();
      jenisList = [];
      selectedJenisPlastik = null;
      debugPrint('❌ loadJenisPlastik error: $e');
      debugPrint('$st');
    } finally {
      isJenisLoading = false;
      notifyListeners();
    }
  }

  // =============================
  // Filter: include used
  // =============================
  void setIncludeUsed(bool value) {
    if (includeUsed == value) return;
    includeUsed = value;
    fetchWashingHeaders(search: _search);
  }

  // =============================
  // Fetch headers (reset)
  // =============================
  Future<void> fetchWashingHeaders({String search = ''}) async {
    _page = 1;
    _search = search;

    items = [];
    errorMessage = '';
    isLoading = true;

    // reset selection & detail
    selectedNoWashing = null;
    details = [];
    detailError = '';
    isDetailLoading = false;

    notifyListeners();

    try {
      final result = await repository.fetchHeaders(
        page: _page,
        limit: 20,
        search: _search,
        includeUsed: includeUsed,
      );

      items = (result['items'] as List<WashingHeader>);
      _totalPages = (result['totalPages'] ?? 1) as int;
      _total = (result['total'] ?? items.length) as int;

      debugPrint(
        '✅ fetchWashingHeaders page=$_page items=${items.length} total=$_total',
      );
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('❌ fetchWashingHeaders error: $e');
      debugPrint('$st');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  // Load more (pagination)
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

      final moreItems = (result['items'] as List<WashingHeader>);
      items.addAll(moreItems);

      debugPrint(
        '📥 loadMore page=$_page add=${moreItems.length} totalNow=${items.length}',
      );
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('❌ loadMore error: $e');
      debugPrint('$st');
    } finally {
      isFetchingMore = false;
      notifyListeners();
    }
  }

  // =============================
  // Fetch details
  // =============================
  Future<void> fetchDetails(String noWashing) async {
    setSelectedNoWashing(noWashing);

    details = [];
    detailError = '';
    isDetailLoading = true;
    notifyListeners();

    try {
      details = await repository.fetchDetails(noWashing);
      debugPrint('✅ fetchDetails $noWashing count=${details.length}');
    } catch (e, st) {
      detailError = e.toString();
      debugPrint('❌ fetchDetails($noWashing) error: $e');
      debugPrint('$st');
    } finally {
      isDetailLoading = false;
      notifyListeners();
    }
  }

  // =============================
  // Create
  // =============================
  Future<Map<String, dynamic>?> createWashing(
    WashingHeader header,
    List<WashingDetail> detailsData,
  ) async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final res = await repository.createWashing(
        header: header,
        details: detailsData,
      );

      lastCreatedNoWashing = res['data']?['header']?['NoWashing'] as String?;

      // refresh list
      await fetchWashingHeaders(search: _search);

      // optional: auto highlight created
      if (lastCreatedNoWashing != null) {
        setSelectedNoWashing(lastCreatedNoWashing);
      }

      return res;
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('❌ createWashing error: $e');
      debugPrint('$st');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  // Update
  // =============================
  Future<Map<String, dynamic>?> updateWashing(
    String noWashing,
    WashingHeader header,
    List<WashingDetail> detailsData,
  ) async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final res = await repository.updateWashing(
        noWashing: noWashing,
        header: header,
        details: detailsData,
      );

      // refresh list
      await fetchWashingHeaders(search: _search);

      // keep highlight
      setSelectedNoWashing(noWashing);

      return res;
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('❌ updateWashing error: $e');
      debugPrint('$st');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> updateWashingQc({
    required String noWashing,
    required double? density1,
    required double? density2,
    required double? density3,
    required double? moisture1,
    required double? moisture2,
    required double? moisture3,
    DateTime? dateQc,
  }) async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final res = await repository.updateWashingQc(
        noWashing: noWashing,
        density1: density1,
        density2: density2,
        density3: density3,
        moisture1: moisture1,
        moisture2: moisture2,
        moisture3: moisture3,
        dateQc: dateQc,
      );

      // Patch baris yang sama di tempat (bukan refetch seluruh halaman) supaya
      // posisi scroll dan highlight pilihan tidak hilang.
      _applyLocalQc(
        noWashing,
        density: density1,
        density2: density2,
        density3: density3,
        moisture: moisture1,
        moisture2: moisture2,
        moisture3: moisture3,
        dateQc: dateQc == null ? null : toDbDateString(dateQc),
      );

      setSelectedNoWashing(noWashing);

      return res;
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('❌ updateWashingQc error: $e');
      debugPrint('$st');
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _applyLocalQc(
    String noWashing, {
    double? density,
    double? density2,
    double? density3,
    double? moisture,
    double? moisture2,
    double? moisture3,
    String? dateQc,
    String? qcBy,
  }) {
    final idx = items.indexWhere((e) => e.noWashing == noWashing);
    if (idx < 0) return;
    final current = items[idx];
    items[idx] = current.withQc(
      density: density,
      density2: density2,
      density3: density3,
      moisture: moisture,
      moisture2: moisture2,
      moisture3: moisture3,
      dateQc: dateQc ?? current.dateQc,
      qcBy: qcBy ?? current.qcBy,
    );
  }

  /// Terapkan update QC realtime dari tablet lain. Return true kalau baris
  ///-nya ada di list yang sedang tampil (jadi ter-highlight hijau).
  bool applyQcRealtime(LabelQcUpdatedEvent event) {
    if (event.kind != LabelQcKind.washing) return false;

    final idx = items.indexWhere((e) => e.noWashing == event.noLabel);
    if (idx < 0) return false;

    items[idx] = items[idx].withQc(
      density: event.density,
      density2: event.density2,
      density3: event.density3,
      moisture: event.moisture,
      moisture2: event.moisture2,
      moisture3: event.moisture3,
      dateQc: event.dateQc,
      qcBy: event.updatedBy,
    );
    notifyListeners();
    return true;
  }

  // =============================
  // Delete
  // =============================
  Future<bool> deleteWashing(String noWashing) async {
    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      await repository.deleteWashing(noWashing);

      await fetchWashingHeaders(search: _search);

      // clear detail & selection
      details = [];
      detailError = '';
      selectedNoWashing = null;

      notifyListeners();
      return true;
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('❌ deleteWashing error: $e');
      debugPrint('$st');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // =============================
  // Reset screen state
  // =============================
  void resetForScreen() {
    selectedNoWashing = null;

    details = [];
    detailError = '';
    isDetailLoading = false;

    errorMessage = '';
    notifyListeners();
  }
}
