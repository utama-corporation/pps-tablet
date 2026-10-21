// lib/features/report/model/report_item.dart
import 'package:flutter/material.dart';

enum ReportSource { crystalReport, ppsApi, baseApi }

class ReportItem {
  final String title;
  final String subtitle;
  final String reportName;
  final IconData icon;
  final bool needsDateRange;
  final bool isSingleDate;
  final ReportSource source;

  /// Diisi saat [source] == [ReportSource.ppsApi].
  /// Berisi path endpoint, misal '/api/reports/pps/rekap-produksi/inject/pdf'.
  final String? ppsApiPath;

  /// Diisi saat [source] == [ReportSource.baseApi].
  /// Path relatif terhadap API_BASE_URL (server utama, port 7500), misal
  /// '/api/laporan/rekap/hot-stamping/pdf'.
  final String? baseApiPath;

  /// Nama parameter tanggal awal untuk endpoint [baseApiPath].
  final String baseApiStartDateParam;

  /// Nama parameter tanggal akhir untuk endpoint [baseApiPath].
  final String baseApiEndDateParam;

  /// Format tanggal untuk kedua parameter di atas, misal 'yyyy-MM-dd'.
  final String baseApiDateFormat;

  const ReportItem({
    required this.title,
    required this.subtitle,
    required this.reportName,
    required this.icon,
    this.needsDateRange = true,
    this.isSingleDate = false,
    this.source = ReportSource.crystalReport,
    this.ppsApiPath,
    this.baseApiPath,
    this.baseApiStartDateParam = 'tglAwal',
    this.baseApiEndDateParam = 'tglAkhir',
    this.baseApiDateFormat = 'yyyy-MM-dd',
  });
}
