// lib/features/stock_opname_v2/model/so_v2_riwayat_sesi.dart
//
// Satu sesi stock opname di daftar riwayat. Bentuk field-nya sengaja
// dibuat sama dengan `SoV2Kategori` supaya panel riwayat dan grid
// kategori bisa membaca sumber data yang sama, tapi parsing-nya di sini
// dibuat toleran (semua field opsional) karena endpoint riwayat
// (`GET /api/stock-opname-v2/transaksi`) bisa mengirim sebagian field
// saja — mis. `categoryId` tidak ikut kalau query join-nya dipersempit.
import 'so_v2_kategori.dart';

class SoV2RiwayatSesi {
  final String stockOpnameNo;
  final int categoryId;
  final String categoryCode;
  final String categoryName;
  final SoV2Status status;
  final int labelCount;
  final int scannedCount;
  final DateTime? startDate;
  final DateTime? completedAt;

  const SoV2RiwayatSesi({
    required this.stockOpnameNo,
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.status,
    required this.labelCount,
    required this.scannedCount,
    this.startDate,
    this.completedAt,
  });

  double get progress => labelCount > 0 ? scannedCount / labelCount : 0;

  factory SoV2RiwayatSesi.fromJson(Map<String, dynamic> json) {
    return SoV2RiwayatSesi(
      stockOpnameNo: json['stockOpnameNo']?.toString() ?? '',
      categoryId: (json['categoryId'] as num?)?.toInt() ?? 0,
      categoryCode: json['categoryCode']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      status: SoV2Status.fromApi(json['status']?.toString() ?? 'not_started'),
      labelCount: (json['labelCount'] as num?)?.toInt() ?? 0,
      scannedCount: (json['scannedCount'] as num?)?.toInt() ?? 0,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
    );
  }
}

/// Satu halaman hasil `GET /api/stock-opname-v2/transaksi` — meta paging
/// mengikuti bentuk yang sama dengan `SoV2LabelPage` (currentPage /
/// pageSize / totalRecords / totalPages di level data).
class SoV2RiwayatPage {
  final List<SoV2RiwayatSesi> data;
  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  const SoV2RiwayatPage({
    required this.data,
    required this.currentPage,
    required this.pageSize,
    required this.totalRecords,
    required this.totalPages,
  });

  factory SoV2RiwayatPage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .map(
          (e) => SoV2RiwayatSesi.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    final totalRecords =
        (json['totalRecords'] as num?)?.toInt() ?? items.length;
    return SoV2RiwayatPage(
      data: items,
      currentPage: (json['currentPage'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      totalRecords: totalRecords,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
