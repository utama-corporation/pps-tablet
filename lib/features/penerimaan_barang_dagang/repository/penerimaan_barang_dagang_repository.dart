// lib/features/penerimaan_barang_dagang/repository/penerimaan_barang_dagang_repository.dart
//
// Endpoint backend (D:\backend\pps_backend\src\modules\production\
// penerimaan-barang-dagang), mounted di /api/penerimaan-barang-dagang:
//   GET    /api/penerimaan-barang-dagang/tim-status         — status tim
//   GET    /api/penerimaan-barang-dagang                     — riwayat (paginated)
//   GET    /api/penerimaan-barang-dagang/:noPenerimaan
//   POST   /api/penerimaan-barang-dagang                     — fase 1: create header
//   POST   /api/penerimaan-barang-dagang/:noPenerimaan/items — fase 2: add items
//   DELETE /api/penerimaan-barang-dagang/:noPenerimaan
//
// Master jenis barang dagang diambil dari GET /api/mst-barang-dagang
// (tidak di-scope per warehouse, beda dengan cabinet-materials).
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../model/barang_dagang_master_item.dart';
import '../model/penerimaan_barang_dagang_model.dart';
import '../model/tim_penerimaan_barang_dagang_model.dart';

/// Satu barang yang dikirim sebagai bagian dari payload addItems.
class PenerimaanBarangDagangItemInput {
  final int idSupplier;
  final int idBarangDagang;
  final double qty;
  final String? keterangan;

  const PenerimaanBarangDagangItemInput({
    required this.idSupplier,
    required this.idBarangDagang,
    required this.qty,
    this.keterangan,
  });

  Map<String, dynamic> toJson() => {
    'idSupplier': idSupplier,
    'idBarangDagang': idBarangDagang,
    'qty': qty,
    if (keterangan != null && keterangan!.trim().isNotEmpty)
      'keterangan': keterangan!.trim(),
  };
}

/// Header yang baru dibuat lewat
/// [PenerimaanBarangDagangRepository.createHeader] — hasil fase 1 (POST
/// /api/penerimaan-barang-dagang), sebelum barang apapun ditambahkan.
class PenerimaanBarangDagangHeaderResult {
  final String noPenerimaan;
  final DateTime tanggal;
  final int idTim;

  const PenerimaanBarangDagangHeaderResult({
    required this.noPenerimaan,
    required this.tanggal,
    required this.idTim,
  });
}

class PenerimaanBarangDagangRepository {
  final ApiClient api;

  PenerimaanBarangDagangRepository({required this.api});

  List<BarangDagangMasterItem>? _masterCache;

  static List<BarangDagangMasterItem> _parseMasterItems(
    Map<String, dynamic> body,
  ) {
    final data = body['data'];
    if (data == null) return <BarangDagangMasterItem>[];
    if (data is! List) return <BarangDagangMasterItem>[];
    return data
        .whereType<Map>()
        .map((e) => BarangDagangMasterItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<BarangDagangMasterItem>> fetchMasterBarangDagang({
    bool force = false,
  }) async {
    if (!force && _masterCache != null) {
      return _masterCache!;
    }
    final body = await api.getJson('/api/mst-barang-dagang');
    final items = await compute(_parseMasterItems, body);
    _masterCache = items;
    return items;
  }

  // ==========================================
  //  STATUS TIM
  //  GET /api/penerimaan-barang-dagang/tim-status
  // ==========================================
  Future<List<TimPenerimaanInfo>> fetchTimStatus() async {
    final body = await api.getJson('/api/penerimaan-barang-dagang/tim-status');
    final List dataList = (body['data'] ?? []) as List;
    return dataList
        .map((e) => TimPenerimaanInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  RIWAYAT (paginated)
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? filter,
  }) async {
    final body = await api.getJson(
      '/api/penerimaan-barang-dagang',
      query: {
        'page': page,
        'pageSize': pageSize,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => PenerimaanBarangDagang.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] as int?) ?? 1;
    final total = (body['totalData'] ?? items.length) as int;

    return {
      'items': items,
      'page': currentPage,
      'totalPages': totalPages,
      'total': total,
    };
  }

  Future<PenerimaanBarangDagangDetail> fetchDetail(String noPenerimaan) async {
    final body = await api.getJson(
      '/api/penerimaan-barang-dagang/$noPenerimaan',
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Data penerimaan tidak ditemukan');
    return PenerimaanBarangDagangDetail.fromJson(data);
  }

  // ==========================================
  //  FASE 1: CREATE HEADER
  //  POST /api/penerimaan-barang-dagang
  // ==========================================
  Future<PenerimaanBarangDagangHeaderResult> createHeader({
    required DateTime tglPenerimaan,
    required int idTim,
  }) async {
    final body = await api.postJson(
      '/api/penerimaan-barang-dagang',
      body: {'tglPenerimaan': _dateOnly(tglPenerimaan), 'idTim': idTim},
    );

    final data = body['data'] as Map<String, dynamic>?;
    final noPenerimaan = data?['noPenerimaan']?.toString();
    if (noPenerimaan == null) {
      throw Exception('Response create header penerimaan tidak valid');
    }
    return PenerimaanBarangDagangHeaderResult(
      noPenerimaan: noPenerimaan,
      tanggal: tglPenerimaan,
      idTim: idTim,
    );
  }

  // ==========================================
  //  FASE 2: ADD ITEMS ke header yang sudah ada
  //  POST /api/penerimaan-barang-dagang/:noPenerimaan/items
  //  Boleh dipanggil >1x per NoPenerimaan.
  // ==========================================
  Future<void> addItems({
    required String noPenerimaan,
    required List<PenerimaanBarangDagangItemInput> items,
  }) async {
    await api.postJson(
      '/api/penerimaan-barang-dagang/$noPenerimaan/items',
      body: {'items': items.map((it) => it.toJson()).toList()},
    );
  }

  Future<void> delete(String noPenerimaan) async {
    await api.deleteJson('/api/penerimaan-barang-dagang/$noPenerimaan');
  }

  Future<void> markComplete(String noPenerimaan) async {
    await api.patchJson(
      '/api/penerimaan-barang-dagang/$noPenerimaan/complete',
    );
  }

  // ==========================================
  //  PRINT LABEL — increment HasBeenPrinted setelah label berhasil dicetak
  //  PATCH /api/labels/barang-dagang/:noBarangDagang/print
  //  Returns HasBeenPrinted terbaru dari server, atau null kalau gagal parse.
  // ==========================================
  Future<int?> markItemPrinted(String noBarangDagang) async {
    final body = await api.patchJson(
      '/api/labels/barang-dagang/$noBarangDagang/print',
    );
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final raw = data['HasBeenPrinted'];
      if (raw is num) return raw.toInt();
      if (raw != null) return int.tryParse('$raw');
    }
    return null;
  }

  // ==========================================
  //  DELETE 1 BARANG — DELETE /api/labels/barang-dagang/:noBarangDagang
  // ==========================================
  Future<void> deleteItem(String noBarangDagang) async {
    await api.deleteJson('/api/labels/barang-dagang/$noBarangDagang');
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
