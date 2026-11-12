// lib/features/report/view_model/report_table_view_model.dart
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_error.dart';

class ReportTableColumn {
  const ReportTableColumn({
    required this.key,
    required this.label,
    required this.numeric,
  });

  final String key;
  final String label;

  /// Semua baris untuk kolom ini bertipe angka (atau null).
  final bool numeric;
}

class ReportTableViewModel extends ChangeNotifier {
  ReportTableViewModel({required ApiClient api}) : _api = api;

  final ApiClient _api;

  bool loading = false;
  String error = '';
  List<ReportTableColumn> columns = const [];
  List<Map<String, dynamic>> rows = const [];
  String query = '';
  int page = 1;
  int pageSize = 100;

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return rows;
    return rows
        .where(
          (r) => r.values.any((v) => '$v'.toLowerCase().contains(q)),
        )
        .toList();
  }

  int get filteredTotal => filtered.length;

  int get totalPages {
    final t = filteredTotal;
    return t == 0 ? 1 : (t / pageSize).ceil();
  }

  List<Map<String, dynamic>> get pageItems {
    final items = filtered;
    final start = (page - 1) * pageSize;
    if (start >= items.length) return const [];
    final end = (start + pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  int get fromRow => filteredTotal == 0 ? 0 : (page - 1) * pageSize + 1;
  int get toRow => (fromRow + pageItems.length - 1).clamp(0, filteredTotal);

  void setQuery(String value) {
    if (query == value.trim()) return;
    query = value.trim();
    page = 1;
    notifyListeners();
  }

  void setPage(int value) {
    final clamped = value.clamp(1, totalPages);
    if (page == clamped) return;
    page = clamped;
    notifyListeners();
  }

  void setPageSize(int value) {
    if (pageSize == value) return;
    pageSize = value;
    page = 1;
    notifyListeners();
  }

  Future<void> load(String path, Map<String, String> values) async {
    loading = true;
    error = '';
    notifyListeners();
    try {
      final queryParams = <String, dynamic>{
        for (final entry in values.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      };
      final body = await _api.getJson(path, query: queryParams);
      final rawColumns = body['columns'];
      final rawRows = (body['rows'] as List?) ?? (body['data'] as List?) ?? const [];
      rows = [
        for (final row in rawRows)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
      query = '';
      page = 1;
      columns = _buildColumns(rawColumns, rows);
    } catch (e) {
      error = apiErrorMessage(e);
      columns = const [];
      rows = const [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<ReportTableColumn> _buildColumns(
    dynamic rawColumns,
    List<Map<String, dynamic>> data,
  ) {
    // Sumber kolom: metadata backend, atau key dari baris pertama bila tidak ada.
    final defs = <(String, String)>[];
    if (rawColumns is List && rawColumns.isNotEmpty) {
      for (final c in rawColumns) {
        if (c is Map) {
          final key = (c['key'] ?? '').toString();
          final label = (c['label'] ?? c['key'] ?? '').toString();
          if (key.isNotEmpty) defs.add((key, label));
        }
      }
    } else if (data.isNotEmpty) {
      for (final key in data.first.keys) {
        defs.add((key.toString(), key.toString()));
      }
    }

    final sample = data.length > 50 ? data.sublist(0, 50) : data;
    return [
      for (final (key, label) in defs)
        ReportTableColumn(
          key: key,
          label: label.isEmpty ? key : label,
          numeric: sample.isNotEmpty &&
              sample.every((row) {
                final v = row[key];
                return v == null || v is num;
              }),
        ),
    ];
  }
}
