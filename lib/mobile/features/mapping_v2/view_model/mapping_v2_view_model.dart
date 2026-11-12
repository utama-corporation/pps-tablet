import 'package:flutter/foundation.dart';

import '../../../core/network/api_errors.dart';
import '../model/mapping_v2_models.dart';
import '../repository/mapping_v2_repository.dart';

class MappingV2ViewModel extends ChangeNotifier {
  MappingV2ViewModel({MappingV2Repository? repository})
    : repository = repository ?? MappingV2Repository();

  final MappingV2Repository repository;

  List<MappingV2Blok> bloks = [];
  List<MappingV2Lokasi> locations = [];
  List<MappingV2Label> labels = [];

  MappingV2Blok? selectedBlok;
  MappingV2Lokasi? selectedLocation;

  bool isLoadingBloks = false;
  bool isLoadingLocations = false;
  bool isLoadingLabels = false;
  bool isLoadingMore = false;
  String? error;

  int currentPage = 1;
  int totalPages = 1;
  int totalData = 0;

  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Pemanggilan async (load/select/scanner) bisa selesai setelah screen sudah
  /// di-pop dan ViewModel di-dispose. notifyListeners() pada ChangeNotifier yang
  /// sudah di-dispose melempar error dari dalam listener provider, yang membuat
  /// elemen provider/dependents tidak konsisten saat tree dibongkar.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  bool get canLoadMore =>
      currentPage < totalPages || labels.length < totalData;

  Future<void> loadBloks() async {
    if (_disposed) return;
    isLoadingBloks = true;
    error = null;
    _notify();
    try {
      final fetched = await repository.fetchBlok();
      if (_disposed) return;
      bloks = fetched..sort((a, b) => a.blok.compareTo(b.blok));
    } catch (e) {
      if (!_disposed) error = _message(e);
    }
    if (_disposed) return;
    isLoadingBloks = false;
    _notify();
  }

  Future<void> selectBlok(MappingV2Blok blok) async {
    if (_disposed) return;
    selectedBlok = blok;
    selectedLocation = null;
    locations = [];
    labels = [];
    _resetLabelSummary();
    isLoadingLocations = true;
    error = null;
    _notify();
    try {
      final fetched = await repository.fetchLokasi(blok.blok);
      if (_disposed) return;
      locations = fetched..sort((a, b) => a.idLokasi.compareTo(b.idLokasi));
    } catch (e) {
      if (!_disposed) error = _message(e);
    }
    if (_disposed) return;
    isLoadingLocations = false;
    _notify();
  }

  Future<void> selectLocation(MappingV2Lokasi location) async {
    if (_disposed) return;
    selectedLocation = location;
    await loadLabels(reset: true);
  }

  Future<void> loadLabels({required bool reset}) async {
    final blok = selectedBlok;
    final location = selectedLocation;
    if (blok == null || location == null) return;
    if (_disposed) return;

    final requestedPage = reset ? 1 : currentPage + 1;
    if (reset) {
      currentPage = 1;
      labels = [];
      isLoadingLabels = true;
    } else {
      if (!canLoadMore || isLoadingMore) return;
      isLoadingMore = true;
    }
    error = null;
    _notify();

    try {
      final page = await repository.fetchLabels(
        blok: blok.blok,
        idLokasi: location.idLokasi,
        page: requestedPage,
      );
      if (_disposed) return;
      if (reset) {
        labels = page.items;
      } else {
        labels = [...labels, ...page.items];
      }
      currentPage = requestedPage;
      totalPages = page.totalPages;
      totalData = page.totalData;
    } catch (e) {
      if (!_disposed) error = _message(e);
    }
    if (_disposed) return;
    isLoadingLabels = false;
    isLoadingMore = false;
    _notify();
  }

  void backToLocations() {
    if (_disposed) return;
    selectedLocation = null;
    labels = [];
    _resetLabelSummary();
    error = null;
    _notify();
  }

  void backToBloks() {
    if (_disposed) return;
    selectedBlok = null;
    selectedLocation = null;
    locations = [];
    labels = [];
    _resetLabelSummary();
    error = null;
    _notify();
  }

  void _resetLabelSummary() {
    currentPage = 1;
    totalPages = 1;
    totalData = 0;
  }

  static String _message(Object error) {
    if (error is ApiFailure) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
