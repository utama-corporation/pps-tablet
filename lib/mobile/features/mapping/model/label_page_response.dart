// lib/features/label/model/label_page_response.dart
import 'label_item.dart';

class LabelPageResponse {
  final bool success;
  final String message;
  final String kategori;
  final String idlokasi;
  final int totalData;
  final int currentPage;
  final int totalPages;
  final int perPage;
  final num totalQty;     // bisa int/double, pakai num
  final double totalBerat;
  final List<LabelItem> data;

  LabelPageResponse({
    required this.success,
    required this.message,
    required this.kategori,
    required this.idlokasi,
    required this.totalData,
    required this.currentPage,
    required this.totalPages,
    required this.perPage,
    required this.totalQty,
    required this.totalBerat,
    required this.data,
  });

  factory LabelPageResponse.fromJson(Map<String, dynamic> json) {
    // ambil angka yang mungkin datang sebagai int/double/string
    num _readNum(dynamic v, {num defaultValue = 0}) {
      if (v == null) return defaultValue;
      if (v is num) return v;
      final s = v.toString();
      return num.tryParse(s) ?? defaultValue;
    }

    // fallback ke legacy fields kalau field “alias” tidak ada
    final totalData = (json['totalData'] ?? json['total'] ?? 0) as int;
    final currentPage = (json['currentPage'] ?? json['page'] ?? 1) as int;
    final perPage = (json['perPage'] ?? json['limit'] ?? 50) as int;
    final totalPages = (json['totalPages'] ??
        ((totalData > 0 && perPage > 0) ? ((totalData + perPage - 1) ~/ perPage) : 1)) as int;

    final totalQty = _readNum(json['totalQty'], defaultValue: 0);
    final totalBerat = _readNum(json['totalBerat'], defaultValue: 0).toDouble();

    return LabelPageResponse(
      success: json['success'] == true,
      message: (json['message'] ?? '').toString(),
      kategori: (json['kategori'] ?? 'semua').toString(),
      idlokasi: (json['idlokasi'] ?? 'semua').toString(),
      totalData: totalData,
      currentPage: currentPage,
      totalPages: totalPages,
      perPage: perPage,
      totalQty: totalQty,
      totalBerat: totalBerat,
      data: (json['data'] as List? ?? [])
          .map((e) => LabelItem.fromJson(e))
          .toList(),
    );
  }
}
