// lib/features/label/view_model/label_view_model.dart
import 'package:flutter/material.dart';
import '../model/label_item.dart';
import '../repository/label_repository.dart';

class LabelViewModel extends ChangeNotifier {
  final LabelRepository repository;
  LabelViewModel({required this.repository});

  // ===== State list =====
  final List<LabelItem> _items = [];
  List<LabelItem> get items => List.unmodifiable(_items);

  // ===== Loading states =====
  bool isLoading = false;
  bool isLoadingMore = false;
  String errorMessage = '';

  // ===== Pagination =====
  int _page = 1;
  final int _limit = 50;
  int _totalPages = 1;
  bool get hasMore => _page < _totalPages;

  // ===== Filters =====
  String? _selectedKategori; // null/empty = semua
  String? _selectedIdLokasi; // null/empty = semua
  String? _selectedBlok; // null/empty = semua

  String? get selectedKategori => _selectedKategori;
  String? get selectedIdLokasi => _selectedIdLokasi;
  String? get selectedBlok => _selectedBlok;

  // ===== Aggregates dari backend =====
  int totalData = 0;      // alias dari totalData response (jumlah hasil filter)
  num totalQty = 0;       // bisa int/double
  double totalBerat = 0;  // total berat (kg)

  // ===== Setter filter =====
  void setKategori(String? kategori) {
    _selectedKategori = (kategori != null && kategori.isNotEmpty) ? kategori : null;
    refresh(); // reload data ketika filter berubah
  }

  void setLokasi({String? idLokasi, String? blok}) {
    _selectedIdLokasi = (idLokasi != null && idLokasi.isNotEmpty) ? idLokasi : null;
    _selectedBlok = (blok != null && blok.isNotEmpty) ? blok : null;

    debugPrint('🔍 Selected Lokasi → IdLokasi: $_selectedIdLokasi | Blok: $_selectedBlok');
    refresh(); // 🔹 hanya 1 kali fetch API
  }



  // ===== Public actions =====
  Future<void> refresh() async {
    _items.clear();
    _page = 1;
    _totalPages = 1;
    await fetchFirstPage();
  }

  Future<void> fetchFirstPage() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final resp = await repository.fetchLabels(
        page: _page,
        limit: _limit,
        kategori: _selectedKategori,
        // ⬇️ samakan dengan signature repository kamu
        idLokasi: _selectedIdLokasi,
        blok: _selectedBlok
      );

      // pagination
      _totalPages = resp.totalPages;

      // data
      _items
        ..clear()
        ..addAll(resp.data);

      // aggregates
      totalData = resp.totalData;        // atau resp.data.length jika ingin yg tampil di page ini saja
      totalQty = resp.totalQty;
      totalBerat = resp.totalBerat;
    } catch (e, st) {
      errorMessage = e.toString();
      debugPrint('LabelViewModel ERROR → $errorMessage\n$st');
      _items.clear();
      totalData = 0;
      totalQty = 0;
      totalBerat = 0;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      _page += 1;

      final resp = await repository.fetchLabels(
        page: _page,
        limit: _limit,
        kategori: _selectedKategori,
        // ⬇️ lagi-lagi pastikan pake 'idlokasi'
        idLokasi: _selectedIdLokasi,
      );

      _totalPages = resp.totalPages;

      // tambahkan data baru ke list
      _items.addAll(resp.data);

      // Catatan: biasanya totalQty/totalBerat itu agregat global hasil filter,
      // jadi boleh di-update pakai resp terbaru (nilainya sama antar page).
      totalData = resp.totalData;
      totalQty = resp.totalQty;
      totalBerat = resp.totalBerat;
    } catch (e, st) {
      _page -= 1; // rollback page jika gagal
      debugPrint('LabelViewModel LOAD MORE ERROR → $e\n$st');
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
