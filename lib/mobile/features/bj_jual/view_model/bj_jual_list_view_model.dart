import 'package:flutter/material.dart';
import '../../../constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../model/bj_jual_model.dart';

class BjJualListViewModel extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<BjJual> _bjJualList = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  String _searchQuery = '';
  String? _dateFrom;
  String? _dateTo;

  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasNextPage = false;
  int _totalData = 0;

  List<BjJual> get bjJualList => _bjJualList;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String get errorMessage => _errorMessage;
  bool get hasNextPage => _hasNextPage;
  int get totalData => _totalData;
  String get searchQuery => _searchQuery;
  String? get dateFrom => _dateFrom;
  String? get dateTo => _dateTo;

  Future<void> fetchBjJual({bool reset = true}) async {
    if (reset) {
      _currentPage = 1;
      _bjJualList = [];
      _isLoading = true;
      _errorMessage = '';
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasNextPage) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final url = ApiConstants.bjJualList(
        page: _currentPage,
        pageSize: _pageSize,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );

      final response = await _apiClient.getJson(url, useAuth: true);

      final List<dynamic> data = response['data'] ?? [];
      final meta = response['meta'] as Map<String, dynamic>?;

      final newItems = data.map((item) => BjJual.fromJson(item)).toList();

      if (reset) {
        _bjJualList = newItems;
      } else {
        _bjJualList.addAll(newItems);
      }

      _hasNextPage = meta?['hasNextPage'] ?? false;
      _totalData = response['totalData'] ?? 0;
      _errorMessage = '';

      if (_hasNextPage) {
        _currentPage++;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (reset) _bjJualList = [];
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() => fetchBjJual(reset: false);

  void setSearch(String query) {
    _searchQuery = query;
    fetchBjJual();
  }

  void setDateRange(String? from, String? to) {
    _dateFrom = from;
    _dateTo = to;
    fetchBjJual();
  }

  void clearFilters() {
    _searchQuery = '';
    _dateFrom = null;
    _dateTo = null;
    fetchBjJual();
  }
}
