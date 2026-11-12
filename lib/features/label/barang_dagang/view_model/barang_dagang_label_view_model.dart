import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/network/api_error.dart';
import '../model/barang_dagang_label.dart';
import '../repository/barang_dagang_label_repository.dart';

class BarangDagangLabelViewModel extends ChangeNotifier {
  BarangDagangLabelViewModel({required this.repository}) {
    pagingController = PagingController<int, BarangDagangLabel>(
      fetchPage: _fetchPage,
      getNextPageKey: _getNextPageKey,
    );
  }

  final BarangDagangLabelRepository repository;

  static const int _pageSize = 20;

  late final PagingController<int, BarangDagangLabel> pagingController;

  List<BarangDagangLabel> items = [];
  bool isLoading = false;
  String errorMessage = '';

  int _total = 0;
  int get totalCount => _total;

  String _search = '';
  String get currentSearch => _search;

  bool includeUsed = false;
  int _generation = 0;

  void setIncludeUsed(bool value) {
    if (includeUsed == value) return;
    includeUsed = value;
    fetchHeaders(search: _search);
  }

  bool get hasMore => pagingController.value.hasNextPage;

  String? selectedNoLabel;
  BarangDagangLabel? get selectedItem {
    final i = items.indexWhere((e) => e.code == selectedNoLabel);
    return i == -1 ? null : items[i];
  }

  void setSelected(String? code) {
    if (selectedNoLabel == code) return;
    selectedNoLabel = code;
    notifyListeners();
  }

  @override
  void dispose() {
    pagingController.dispose();
    super.dispose();
  }

  Future<void> fetchHeaders({String search = ''}) async {
    _search = search;
    errorMessage = '';
    _total = 0;
    items = [];
    selectedNoLabel = null;
    _generation++;

    isLoading = true;
    notifyListeners();

    pagingController.refresh();
  }

  Future<void> refreshCurrent() => fetchHeaders(search: _search);
  Future<void> applySearch(String search) => fetchHeaders(search: search);

  Future<List<BarangDagangLabel>> _fetchPage(int pageKey) async {
    final generation = _generation;
    try {
      if (pageKey == 1 && generation == _generation) {
        isLoading = true;
        errorMessage = '';
        notifyListeners();
      }

      final result = await repository.fetchPage(
        page: pageKey,
        limit: _pageSize,
        search: _search,
        includeUsed: includeUsed,
      );

      if (generation != _generation) {
        return result.items;
      }

      _total = result.total;
      errorMessage = '';

      if (pageKey == 1) {
        items = List<BarangDagangLabel>.from(result.items);
      } else {
        items = [...items, ...result.items];
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

  int? _getNextPageKey(PagingState<int, BarangDagangLabel> state) {
    if (state.lastPageIsEmpty) return null;
    return state.nextIntPageKey;
  }

  String? validateUpdate({double? qty}) {
    if (qty != null && qty <= 0) return 'Qty harus lebih besar dari 0.';
    return null;
  }

  Future<Map<String, dynamic>> updateFromForm({
    required String code,
    double? qty,
    String? keterangan,
  }) async {
    final err = validateUpdate(qty: qty);
    if (err != null) throw Exception(err);

    final normalizedQty = qty != null && qty == qty.truncateToDouble()
        ? qty.toInt()
        : qty;

    final header = <String, dynamic>{
      if (normalizedQty != null) 'Qty': normalizedQty,
      'Keterangan': keterangan?.trim() ?? '',
    };

    try {
      isLoading = true;
      errorMessage = '';
      notifyListeners();

      final res = await repository.updateLabel(code, {'header': header});

      await fetchHeaders(search: _search);
      setSelected(code);

      return res;
    } catch (e) {
      errorMessage = apiErrorMessage(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteBarangDagang(String code) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      await repository.deleteLabel(code);

      items.removeWhere((e) => e.code == code);

      if (selectedNoLabel == code) {
        selectedNoLabel = null;
      }

      await refreshCurrent();
    } catch (e) {
      errorMessage = apiErrorMessage(e);
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void resetForScreen() {
    selectedNoLabel = null;
  }
}
