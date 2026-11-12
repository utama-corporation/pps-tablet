import 'package:flutter/foundation.dart';

import '../../../core/network/api_errors.dart';
import '../model/so_v2_models.dart';
import '../repository/so_v2_repository.dart';

class SoV2DetailViewModel extends ChangeNotifier {
  SoV2DetailViewModel({
    required this.stockOpnameNo,
    required this.categoryCode,
    required this.location,
    SoV2Repository? repository,
  }) : repository = repository ?? SoV2Repository();

  final String stockOpnameNo;
  String categoryCode;
  final SoV2Lokasi location;
  final SoV2Repository repository;

  List<SoV2LabelGroup> groups = [];

  bool isLoadingLabels = false;
  bool isLoadingMore = false;
  String? error;

  int currentPage = 1;
  int totalPages = 1;
  int totalRecords = 0;
  int totalScanned = 0;
  double totalQuantity = 0;
  String search = '';

  String get unit =>
      categoryCode.toLowerCase() == 'furniturewip' ? 'pcs' : 'kg';
  int get loadedLabelCount =>
      groups.fold<int>(0, (total, group) => total + group.labels.length);
  bool get canLoadMore =>
      currentPage < totalPages || loadedLabelCount < totalRecords;
  bool get isComplete => totalRecords > 0 && totalScanned >= totalRecords;

  Future<void> init() async {
    error = null;
    search = '';
    await loadLabels(reset: true);
  }

  Future<void> setSearch(String value) async {
    search = value.trim();
    await loadLabels(reset: true);
  }

  Future<void> loadLabels({required bool reset}) async {
    final requestedPage = reset ? 1 : currentPage + 1;
    if (reset) {
      currentPage = 1;
      groups = [];
      isLoadingLabels = true;
    } else {
      if (!canLoadMore || isLoadingMore) return;
      isLoadingMore = true;
    }
    error = null;
    notifyListeners();

    try {
      final page = await repository.fetchLabels(
        stockOpnameNo: stockOpnameNo,
        blok: location.blok,
        locationId: location.locationId,
        page: requestedPage,
        search: search,
      );
      if (reset) {
        groups = page.groups;
      } else {
        groups = _mergeGroups(groups, page.groups);
      }
      // Gunakan halaman yang benar-benar diminta. Ini tetap bekerja apabila
      // backend tidak mengirim currentPage atau mengirim nilai fallback.
      currentPage = requestedPage;
      totalPages = page.totalPages;
      totalRecords = page.totalRecords;
      totalScanned = page.totalScanned;
      totalQuantity = page.totalQuantity;
      if (categoryCode.isEmpty) categoryCode = page.categoryCode;
    } catch (e) {
      error = _message(e);
    } finally {
      isLoadingLabels = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  List<SoV2LabelGroup> _mergeGroups(
    List<SoV2LabelGroup> existing,
    List<SoV2LabelGroup> incoming,
  ) {
    final merged = [...existing];
    for (final next in incoming) {
      final index = merged.indexWhere(
        (current) => current.typeId != null && next.typeId != null
            ? current.typeId == next.typeId
            : current.typeName == next.typeName,
      );
      if (index < 0) {
        merged.add(next);
        continue;
      }

      final current = merged[index];
      merged[index] = SoV2LabelGroup(
        typeId: current.typeId ?? next.typeId,
        typeName: current.typeName.isNotEmpty
            ? current.typeName
            : next.typeName,
        labelCount: next.labelCount,
        totalQuantity: next.totalQuantity,
        labels: [...current.labels, ...next.labels],
      );
    }
    return merged;
  }

  static String _message(Object error) {
    if (error is ApiFailure) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}
