import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../core/network/api_error.dart';
import '../model/spk_models.dart';
import '../repository/spk_repository.dart';

class SpkViewModel extends ChangeNotifier {
  SpkViewModel(this.repository) {
    pagingController = PagingController<int, SpkStockItem>(
      fetchPage: _fetchPage,
      getNextPageKey: _getNextPageKey,
    );
  }

  final SpkRepository repository;

  late final PagingController<int, SpkStockItem> pagingController;

  List<SpkStockItem> items = [];
  Map<String, int> summary = const {};
  bool isLoading = false;
  String errorMessage = '';

  int _total = 0;
  int get totalCount => _total;

  String _search = '';
  String get currentSearch => _search;

  String status = '', sort = 'barang', dir = 'asc';

  int _generation = 0;

  bool get hasMore => pagingController.value.hasNextPage;

  // ---------------------------------------------------------------------------
  // Row selection for "Buat SPK". Like the web, the selection is keyed by IdBJ
  // and survives search, filter, sort and paging until cleared or submitted.
  // ---------------------------------------------------------------------------
  final Map<int, SpkStockItem> _selected = {};

  List<SpkStockItem> get selectedItems => List.unmodifiable(_selected.values);
  int get selectedCount => _selected.length;
  bool get hasSelection => _selected.isNotEmpty;
  double get selectedRecommendationTotal =>
      _selected.values.fold(0, (sum, i) => sum + i.recommendation);

  bool isSelected(SpkStockItem item) => _selected.containsKey(item.id);

  void toggleSelection(SpkStockItem item) {
    if (_selected.remove(item.id) == null) _selected[item.id] = item;
    notifyListeners();
  }

  /// true = all loaded rows selected, false = none, null = some (tristate).
  bool? get loadedSelectionState {
    if (items.isEmpty) return false;
    final count = items.where(isSelected).length;
    if (count == 0) return false;
    return count == items.length ? true : null;
  }

  void setLoadedSelected(bool select) {
    for (final item in items) {
      if (select) {
        _selected[item.id] = item;
      } else {
        _selected.remove(item.id);
      }
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  void setStatus(String value) {
    if (status == value) return;
    status = value;
    fetchHeaders();
  }

  void setSort(String value) {
    if (sort == value) return;
    sort = value;
    dir = 'asc';
    fetchHeaders();
  }

  void setDir(String value) {
    if (dir == value) return;
    dir = value;
    fetchHeaders();
  }

  void toggleDir() => setDir(dir == 'asc' ? 'desc' : 'asc');

  Future<void> fetchHeaders({String? search}) async {
    if (search != null) _search = search.trim();
    errorMessage = '';
    _total = 0;
    items = [];
    summary = const {};
    _generation++;

    isLoading = true;
    notifyListeners();

    pagingController.refresh();
  }

  Future<void> refreshCurrent() => fetchHeaders();

  Future<List<SpkStockItem>> _fetchPage(int pageKey) async {
    final generation = _generation;
    try {
      if (pageKey == 1 && generation == _generation) {
        isLoading = true;
        errorMessage = '';
        notifyListeners();
      }

      final result = await repository.monitoring(
        page: pageKey,
        search: _search,
        status: status,
        sort: sort,
        dir: dir,
      );

      if (generation != _generation) {
        return result.items;
      }

      _total = result.total;
      summary = result.summary;
      errorMessage = '';

      if (pageKey == 1) {
        items = List<SpkStockItem>.from(result.items);
      } else {
        items = [...items, ...result.items];
      }
      // Keep selected rows in sync with the latest stock snapshot.
      for (final item in result.items) {
        if (_selected.containsKey(item.id)) _selected[item.id] = item;
      }

      return result.items;
    } catch (e) {
      if (generation == _generation) errorMessage = apiErrorMessage(e);
      rethrow;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  int? _getNextPageKey(PagingState<int, SpkStockItem> state) {
    if (state.lastPageIsEmpty) return null;
    return state.nextIntPageKey;
  }

  @override
  void dispose() {
    pagingController.dispose();
    super.dispose();
  }
}
