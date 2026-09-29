// lib/features/stock_opname_v2/view_model/so_v2_riwayat_view_model.dart
//
// State khusus panel "Riwayat Stock Opname" di sisi kanan layar kategori.
// Sengaja dipisah dari [SoV2KategoriListViewModel]: grid utama harus
// selalu menampilkan sesi yang SEDANG berjalan (live scan), sementara
// panel menampilkan seluruh riwayat sesi yang sudah lewat.
//
// Paging-nya server-side (`GET /api/stock-opname-v2/transaksi?page=…`)
// lewat `PagingController` — pola yang sama dengan daftar label di
// [SoV2LabelListViewModel], jadi tidak ada request sia-sia saat panel
// masih tertutup (PagingListener baru dipasang saat drawer dibuka).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../model/so_v2_kategori.dart';
import '../model/so_v2_riwayat_sesi.dart';
import '../repository/so_v2_repository.dart';

class SoV2RiwayatViewModel extends ChangeNotifier {
  final SoV2Repository repository;

  SoV2RiwayatViewModel({SoV2Repository? repository})
    : repository = repository ?? SoV2Repository() {
    pagingController = PagingController<int, SoV2RiwayatSesi>(
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
      fetchPage: _fetchPage,
    );
  }

  static const int pageSize = 20;

  late final PagingController<int, SoV2RiwayatSesi> pagingController;

  String _search = '';
  SoV2Status? _status;

  /// Total sesi di seluruh periode (dari meta paging halaman terakhir),
  /// bukan cuma jumlah baris yang sudah termuat.
  int totalRecords = 0;
  int totalPages = 0;

  SoV2Status? get statusFilter => _status;
  String get search => _search;

  Future<List<SoV2RiwayatSesi>> _fetchPage(int pageKey) async {
    final page = await repository.fetchRiwayat(
      page: pageKey,
      pageSize: pageSize,
      search: _search,
      status: _status,
    );
    totalRecords = page.totalRecords;
    totalPages = page.totalPages;
    notifyListeners();
    // `>` (bukan `>=`) supaya halaman terakhir tetap dirender; pemutus
    // rantai paging adalah satu request tambahan yang mengembalikan [].
    // Ini juga aman kalau `totalPages` tidak dikirim server (default 1).
    if (pageKey > page.totalPages) return [];
    return page.data;
  }

  /// Muat ulang dari halaman 1 — dipakai setelah keluar dari layar detail
  /// sesi, karena status/progress sesi bisa berubah di sana. Kembaliannya
  /// `void` (mengikuti `PagingController.refresh`), jadi `RefreshIndicator`
  /// yang memakainya akan menutup begitu state berikutnya selesai update.
  void refresh() => pagingController.refresh();

  void setStatusFilter(SoV2Status? status) {
    if (_status == status) return;
    _status = status;
    pagingController.refresh();
  }

  Timer? _debounce;

  /// Debounce 350ms supaya mengetik tidak memicu request per huruf —
  /// pola sama dengan pencarian label di layar detail.
  void setSearchDebounced(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = text.trim();
      pagingController.refresh();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    pagingController.dispose();
    super.dispose();
  }
}
