import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/api_constants.dart';
import '../model/stock_opname_label_model.dart';

class StockOpnameDetailViewModel extends ChangeNotifier {
  // ===== State filter =====
  String noSO = '';
  String? currentFilter;        // kategori: all/bahanbaku/dll
  String? currentBlok;          // ex: 'A', 'B', ...
  int? currentIdLokasi;         // ex: 31, 0/null = all
  String? searchKeyword;        // kata kunci pencarian

  // ===== Data list =====
  final List<StockOpnameLabel> labels = [];

  // ===== Paging & aggregate =====
  int page = 1;
  int pageSize = 50;
  int totalData = 0;
  int totalSak = 0;
  double totalBerat = 0.0;
  bool hasMoreData = true;

  // ===== UI flags =====
  bool isInitialLoading = false;
  bool isLoadingMore = false;
  bool hasError = false;
  String errorMessage = '';

  // ===== Helpers =====
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // ===== Public APIs =====
  Future<void> fetchInitialData(
      String selectedNoSO, {
        String filterBy = 'all',
        String? blok,
        int? idLokasi,
        String? search,
      }) async {
    noSO = selectedNoSO;
    currentFilter = filterBy;
    currentBlok = blok;
    currentIdLokasi = idLokasi;
    searchKeyword = search;

    page = 1;
    hasMoreData = true;
    labels.clear();

    isInitialLoading = true;
    hasError = false;
    errorMessage = '';
    notifyListeners();

    await _fetchData();
  }

  Future<void> search(String keyword) async {
    searchKeyword = keyword;
    page = 1;
    hasMoreData = true;
    labels.clear();

    isInitialLoading = true;
    hasError = false;
    errorMessage = '';
    notifyListeners();

    await _fetchData();
  }

  void clearSearch() {
    searchKeyword = null;
    page = 1;
    hasMoreData = true;
    labels.clear();

    isInitialLoading = true;
    hasError = false;
    errorMessage = '';
    notifyListeners();

    _fetchData();
  }

  Future<void> loadMoreData() async {
    if (isLoadingMore || !hasMoreData) return;
    isLoadingMore = true;
    page += 1;
    notifyListeners();

    await _fetchData();
  }

  void reset() {
    labels.clear();
    page = 1;
    totalData = 0;
    totalSak = 0;
    totalBerat = 0.0;
    hasMoreData = true;
    errorMessage = '';
    hasError = false;

    currentFilter = null;
    currentBlok = null;
    currentIdLokasi = null;
    searchKeyword = null;

    notifyListeners();
  }

  // ===== Core fetch =====
  Future<void> _fetchData() async {
    try {
      final token = await _getToken();

      final url = Uri.parse(
        ApiConstants.labelSOList(
          selectedNoSO: noSO,
          page: page,
          pageSize: pageSize,
          filterBy: currentFilter,
          blok: currentBlok,                 // ← kirim blok (boleh null)
          idLokasi: currentIdLokasi,         // ← kirim int? (null/0 → 'all' di ApiConstants)
          search: searchKeyword,             // ← kirim search jika ada
        ),
      );

      // debug print
      // print('🌐 GET: $url');

      debugPrint('[HTTP] GET $url');
      final resp = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint('[HTTP] GET $url -> ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;

        final List<dynamic> list = body['data'] ?? [];
        final fetched = list.map((e) => StockOpnameLabel.fromJson(e)).toList();

        if (page == 1) {
          labels
            ..clear()
            ..addAll(fetched);
        } else {
          labels.addAll(fetched);
        }

        totalData  = (body['totalData']  as num?)?.toInt() ?? labels.length;
        totalSak   = (body['totalSak']   as num?)?.toInt() ?? 0;
        totalBerat = (body['totalBerat'] as num?)?.toDouble() ?? 0.0;

        hasMoreData = labels.length < totalData;
        hasError = false;
        errorMessage = '';
      } else {
        hasError = true;
        errorMessage = 'Gagal mengambil data (status: ${resp.statusCode})';
      }
    } catch (e) {
      hasError = true;
      errorMessage = 'Kesalahan jaringan: $e';
    } finally {
      isInitialLoading = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }
}

