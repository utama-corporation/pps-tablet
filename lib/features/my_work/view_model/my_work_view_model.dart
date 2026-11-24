import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/my_work.dart';
import '../repository/my_work_repository.dart';

/// State layar My Work: ringkasan antrian, antrian terpilih, daftar item,
/// pencarian, dan item terpilih untuk panel detail.
class MyWorkViewModel extends ChangeNotifier {
  final MyWorkRepository repository;
  final Duration searchDebounce;
  MyWorkViewModel({
    required this.repository,
    this.searchDebounce = const Duration(milliseconds: 350),
  });

  MyWorkSummary? summary;
  String summaryError = '';
  bool loadingSummary = false;

  String? selectedKey;
  MyWorkItems? items;
  String itemsError = '';
  bool loadingItems = false;
  String search = '';
  MyWorkItem? selectedItem;

  Timer? _debounce;
  int _itemsRequest = 0;
  bool _disposed = false;

  MyWorkQueue? get selectedQueue {
    final key = selectedKey;
    if (key == null) return null;
    for (final q in summary?.queues ?? const <MyWorkQueue>[]) {
      if (q.key == key) return q;
    }
    return null;
  }

  /// Muat ringkasan; pilih antrian pertama yang berisi (atau yang pertama)
  /// bila belum ada antrian terpilih yang masih valid.
  Future<void> load() async {
    loadingSummary = true;
    summaryError = '';
    _notify();
    try {
      final s = await repository.summary();
      summary = s;
      final keys = s.queues.map((q) => q.key).toSet();
      if (selectedKey == null || !keys.contains(selectedKey)) {
        final first = s.queues.where((q) => (q.count ?? 0) > 0).firstOrNull ??
            s.queues.firstOrNull;
        selectedKey = first?.key;
        selectedItem = null;
      }
    } catch (e) {
      summaryError = apiErrorMessage(e);
    } finally {
      loadingSummary = false;
      _notify();
    }
    if (selectedKey != null) await loadItems();
  }

  Future<void> refresh() => load();

  Future<void> selectQueue(String key) async {
    if (key == selectedKey) return;
    selectedKey = key;
    items = null;
    selectedItem = null;
    _notify();
    await loadItems();
  }

  void setSearch(String value) {
    search = value;
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, loadItems);
  }

  void selectItem(MyWorkItem? item) {
    selectedItem = item;
    _notify();
  }

  Future<void> loadItems() async {
    final key = selectedKey;
    if (key == null) return;
    final request = ++_itemsRequest;
    loadingItems = true;
    itemsError = '';
    _notify();
    try {
      final result = await repository.items(key, search: search);
      if (request != _itemsRequest || key != selectedKey) return;
      items = result;
      final keep = selectedItem;
      selectedItem = keep == null
          ? null
          : result.items.where((i) => i.id == keep.id).firstOrNull;
    } catch (e) {
      if (request != _itemsRequest) return;
      itemsError = apiErrorMessage(e);
    } finally {
      if (request == _itemsRequest) {
        loadingItems = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
