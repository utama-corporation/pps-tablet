// lib/features/label/bahan_pend_support/view_model/bahan_pend_support_view_model.dart

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/bahan_pend_support_header_model.dart';
import '../repository/bahan_pend_support_repository.dart';

class BahanPendukungViewModel extends ChangeNotifier {
  final BahanPendukungRepository repository;
  BahanPendukungViewModel({required this.repository}) {
    // PagingController v5 — pola sama dengan RejectViewModel. Dipakai agar
    // tabel bisa memakai AtlasPagedDataTable yang mendukung scroll horizontal.
    pagingController = PagingController<int, BahanPendukungHeader>(
      // pageKey = index halaman (0,1,2,...)
      fetchPage: _fetchPage,
      getNextPageKey: _getNextPageKey,
    );
  }

  static const int _pageSize = 20;

  /// Controller untuk AtlasPagedDataTable.
  late final PagingController<int, BahanPendukungHeader> pagingController;

  // === LIST STATE ===
  List<BahanPendukungHeader> items = [];
  bool isLoading = false;
  bool isDeleting = false;
  String errorMessage = '';

  int _total = 0;
  int get totalCount => _total;

  String _search = '';
  String get currentSearch => _search;

  /// Pakai info dari PagingState.
  bool get hasMore => pagingController.value.hasNextPage;

  bool includeUsed = false;

  void setIncludeUsed(bool value) {
    if (includeUsed == value) return;
    includeUsed = value;
    fetchHeaders(search: _search);
  }

  // === SELECTED ROW ===
  String? selectedNoBahanPendukung;

  BahanPendukungHeader? get selectedItem {
    final i = items.indexWhere(
      (e) => e.noBahanPendukung == selectedNoBahanPendukung,
    );
    return i == -1 ? null : items[i];
  }

  void setSelected(String? no) {
    if (selectedNoBahanPendukung == no) return;
    selectedNoBahanPendukung = no;
    notifyListeners();
  }

  // === FETCH (memicu ulang paging dari halaman pertama) ===

  Future<void> fetchHeaders({String search = ''}) async {
    _search = search;
    errorMessage = '';
    selectedNoBahanPendukung = null;
    notifyListeners();
    pagingController.refresh();
  }

  Future<void> refreshCurrent() => fetchHeaders(search: _search);

  // === IMPLEMENTASI PAGING ===

  Future<List<BahanPendukungHeader>> _fetchPage(int pageKey) async {
    try {
      if (pageKey == 0) {
        isLoading = true;
        errorMessage = '';
        notifyListeners();
      }

      final result = await repository.fetchHeaders(
        page: pageKey,
        limit: _pageSize,
        search: _search,
        includeUsed: includeUsed,
      );

      final list = result['items'] as List<BahanPendukungHeader>;
      _total = (result['total'] as int?) ?? list.length;
      errorMessage = '';

      // Cache lokal (flatten) — dipakai untuk selectedItem & totalCount.
      if (pageKey == 0) {
        items = List<BahanPendukungHeader>.from(list);
      } else {
        items = [...items, ...list];
      }

      return list;
    } catch (e) {
      errorMessage = e.toString();
      rethrow; // biar PagingController juga tau kalau error
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  int? _getNextPageKey(PagingState<int, BahanPendukungHeader> state) {
    if (state.lastPageIsEmpty) return null;
    return state.nextIntPageKey;
  }

  // === DELETE ===

  Future<void> deleteLabel(String noBahanPendukung) async {
    isDeleting = true;
    errorMessage = '';
    notifyListeners();

    try {
      await repository.deleteLabel(noBahanPendukung);
      selectedNoBahanPendukung = null;
      await refreshCurrent();
    } catch (e) {
      // Disimpan apa adanya supaya layar bisa menampilkannya lewat DialogService.
      errorMessage = bahanPendukungDeleteErrorMessage(e);
      rethrow;
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  // === PRINT ===

  /// Optimistic update jumlah cetak supaya badge di tabel langsung berubah.
  Future<void> markAsPrinted(String noBahanPendukung) async {
    final count = await repository.markAsPrinted(noBahanPendukung);
    final idx = items.indexWhere(
      (e) => e.noBahanPendukung == noBahanPendukung,
    );
    if (idx == -1) return;

    items[idx] = items[idx].copyWith(
      hasBeenPrinted: count ?? items[idx].hasBeenPrinted + 1,
    );
    notifyListeners();
  }

  void resetForScreen() {
    _total = 0;
    _search = '';
    includeUsed = false;
    errorMessage = '';
    selectedNoBahanPendukung = null;
  }

  @override
  void dispose() {
    pagingController.dispose();
    super.dispose();
  }
}