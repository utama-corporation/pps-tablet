// lib/features/report/view_model/report_list_view_model.dart
import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../model/report_item.dart';

class ReportListViewModel extends ChangeNotifier {
  ReportListViewModel({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// PDF laporan dirender di sisi server (Puppeteer) dan server tidak
  /// mengirim byte apa pun sampai selesai — untuk rentang tanggal lebar
  /// bisa jauh melewati 25–30 detik. Dipakai HANYA untuk request laporan.
  static const Duration pdfTimeout = Duration(minutes: 10);

  String _search = '';
  String get search => _search;
  set search(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  /// Section (dengan item terfilter) untuk [slug]; null/`semua` → semua.
  /// Section tanpa item yang cocok disembunyikan.
  List<ReportKategori> filteredKategori(String? slug) {
    final sections = reportSectionsFor(slug);
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return sections;
    return [
      for (final kategori in sections)
        if (kategori.items.any((i) => i.title.toLowerCase().contains(q)))
          ReportKategori(
            nama: kategori.nama,
            slug: kategori.slug,
            icon: kategori.icon,
            items: [
              for (final i in kategori.items)
                if (i.title.toLowerCase().contains(q)) i,
            ],
          ),
    ];
  }

  int filteredCount(String? slug) =>
      filteredKategori(slug).fold(0, (sum, k) => sum + k.items.length);

  bool _loading = false;
  bool get loading => _loading;

  /// Opsi warehouse dari `GET /api/laporan/warehouse-options` — selalu
  /// diawali 'ALL'. Gagal memuat → hanya 'ALL' yang bisa dipilih.
  Future<List<String>> loadWarehouseOptions() async {
    try {
      final body = await _api.getJson('/api/laporan/warehouse-options');
      final options = body['options'];
      if (options is List) {
        final names = [
          for (final v in options)
            if (v != null && v.toString().trim().isNotEmpty) v.toString(),
        ];
        return ['ALL', ...names.where((n) => n != 'ALL')];
      }
    } catch (_) {}
    return const ['ALL'];
  }

  Future<Uint8List> generateReport({
    required ReportItem item,
    required Map<String, String> values,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final query = <String, dynamic>{
        for (final entry in values.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      };
      debugPrint('[REPORT] GET ${item.path}?$query');
      return await _api.getPdfBytesForPath(
        item.path!,
        query: query,
        timeout: pdfTimeout,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
