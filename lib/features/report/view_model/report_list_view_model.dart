// lib/features/report/view_model/report_list_view_model.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/report_endpoints.dart';
import '../model/report_item.dart';
import '../service/report_pdf_service.dart';

class ReportListViewModel extends ChangeNotifier {
  /// Batas waktu download PDF laporan. PDF laporan dirender di sisi server
  /// (Crystal Report / Puppeteer) dan server tidak mengirim satu byte pun
  /// sampai selesai, jadi untuk rentang tanggal lebar prosesnya bisa jauh
  /// melewati default 25-30 detik. 10 menit dipakai HANYA untuk request
  /// laporan di [generateReport] - request lain (termasuk cetak label)
  /// tetap memakai default masing-masing.
  static const Duration pdfTimeout = Duration(minutes: 10);

  ReportListViewModel({
    required List<ReportItem> initialReports,
    required ReportPdfService pdfService,
    required ApiClient apiClient,
    required this.username,
  }) : _pdfService = pdfService,
       _apiClient = apiClient,
       _allReports = initialReports,
       _filteredReports = initialReports;

  final ReportPdfService _pdfService;
  final ApiClient _apiClient;
  final String username;

  final List<ReportItem> _allReports;
  List<ReportItem> _filteredReports;

  List<ReportItem> get filteredReports => _filteredReports;

  String _search = '';
  String get search => _search;

  set search(String value) {
    _search = value;
    _filterReports();
  }

  bool _loading = false;
  bool get loading => _loading;

  final df = DateFormat('yyyy-MM-dd');

  void _filterReports() {
    if (_search.isEmpty) {
      _filteredReports = _allReports;
    } else {
      final query = _search.toLowerCase();
      _filteredReports = _allReports.where((r) {
        return r.title.toLowerCase().contains(query) ||
            r.subtitle.toLowerCase().contains(query);
      }).toList();
    }
    notifyListeners();
  }

  Uri _buildCrystalUri(
    String reportName,
    DateTime startDate,
    DateTime endDate,
  ) {
    final qp = <String, String>{
      'reportName': reportName,
      'StartDate': df.format(startDate),
      'EndDate': df.format(endDate),
      'Username': username,
    };
    return ReportEndpoints.exportPdf(qp);
  }

  Future<Uint8List> generateReport({
    required ReportItem item,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      late Uri uri;

      if (item.source == ReportSource.ppsApi) {
        assert(
          item.ppsApiPath != null,
          'ppsApiPath wajib diisi untuk ReportSource.ppsApi',
        );
        final reportDate = DateFormat('dd-MM-yyyy').format(startDate);
        uri = ReportEndpoints.ppsApiPdf(item.ppsApiPath!, reportDate);
        debugPrint('[REPORT] URL => $uri');
        return await _apiClient.getPdfBytes(uri, timeout: pdfTimeout);
      } else if (item.source == ReportSource.baseApi) {
        assert(
          item.baseApiPath != null,
          'baseApiPath wajib diisi untuk ReportSource.baseApi',
        );
        final dateFormat = DateFormat(item.baseApiDateFormat);
        final path = item.baseApiPath!;
        // Endpoint laporan backend selalu baca rentang tanggal:
        //   tglAwal  -> StartDate  (mutasi/stok/umur/produksi)
        //   tglAkhir -> EndDate / PerTgl (rekap)
        // Untuk laporan single date, start == end jadi keduanya sama.
        final query = <String, dynamic>{
          item.baseApiStartDateParam: dateFormat.format(startDate),
          item.baseApiEndDateParam: dateFormat.format(endDate),
        };
        debugPrint(
          '[REPORT] URL => ${ApiConstants.baseUrl}$path?$query',
        );
        return await _apiClient.getPdfBytesForPath(
          path,
          query: query,
          timeout: pdfTimeout,
        );
      } else {
        uri = _buildCrystalUri(item.reportName, startDate, endDate);
        debugPrint('[REPORT] URL => $uri');
        return await _pdfService.downloadPdfBytes(
          uri: uri,
          timeout: pdfTimeout,
        );
      }
    } catch (e) {
      debugPrint('[REPORT] Error: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
