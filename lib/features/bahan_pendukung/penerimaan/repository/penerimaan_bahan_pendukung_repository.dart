// lib/features/bahan_pendukung/penerimaan/repository/penerimaan_bahan_pendukung_repository.dart
//
// Endpoint backend (D:\backend\pps_backend\src\modules\production\
// penerimaan-bahan-pendukung), mounted di /api/penerimaan-bahan-pendukung:
//   GET    /api/penerimaan-bahan-pendukung/tim-status         — status tim
//   GET    /api/penerimaan-bahan-pendukung                     — riwayat (paginated)
//   GET    /api/penerimaan-bahan-pendukung/:noPenerimaan
//   POST   /api/penerimaan-bahan-pendukung                     — fase 1: create header
//   POST   /api/penerimaan-bahan-pendukung/:noPenerimaan/items — fase 2: add items
//   DELETE /api/penerimaan-bahan-pendukung/:noPenerimaan
//
// Cabinet materials (master nama barang) diambil dari shared endpoint
// GET /api/mst-furniture-material/cabinet-materials?idWarehouse=5
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../production/shared/models/cabinet_material_item.dart';
import '../model/penerimaan_bahan_pendukung_model.dart';
import '../model/tim_penerimaan_model.dart';

/// Satu barang yang dikirim sebagai bagian dari payload addItems.
class PenerimaanBahanPendukungItemInput {
  final int idSupplier;
  final int idCabinetMaterial;
  final double qty;
  final String? keterangan;

  const PenerimaanBahanPendukungItemInput({
    required this.idSupplier,
    required this.idCabinetMaterial,
    required this.qty,
    this.keterangan,
  });

  Map<String, dynamic> toJson() => {
    'idSupplier': idSupplier,
    'idCabinetMaterial': idCabinetMaterial,
    'qty': qty,
    if (keterangan != null && keterangan!.trim().isNotEmpty)
      'keterangan': keterangan!.trim(),
  };
}

/// Header yang baru dibuat lewat
/// [PenerimaanBahanPendukungRepository.createHeader] — hasil fase 1 (POST
/// /api/penerimaan-bahan-pendukung), sebelum barang apapun ditambahkan.
class PenerimaanBahanPendukungHeaderResult {
  final String noPenerimaan;
  final DateTime tanggal;
  final int idTim;

  const PenerimaanBahanPendukungHeaderResult({
    required this.noPenerimaan,
    required this.tanggal,
    required this.idTim,
  });
}

class PenerimaanBahanPendukungRepository {
  final ApiClient api;

  PenerimaanBahanPendukungRepository({required this.api});

  final Map<int, List<CabinetMaterialItem>> _cabinetMasterCache = {};

  static List<CabinetMaterialItem> _parseCabinetMaterials(
    Map<String, dynamic> body,
  ) {
    final data = body['data'];
    if (data == null) return <CabinetMaterialItem>[];
    if (data is! List) return <CabinetMaterialItem>[];
    return data
        .whereType<Map>()
        .map((e) => CabinetMaterialItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CabinetMaterialItem>> fetchMasterCabinetMaterials({
    required int idWarehouse,
    bool force = false,
  }) async {
    if (!force && _cabinetMasterCache.containsKey(idWarehouse)) {
      return _cabinetMasterCache[idWarehouse]!;
    }
    final body = await api.getJson(
      '/api/mst-furniture-material/cabinet-materials',
      query: {'idWarehouse': idWarehouse.toString()},
    );
    final items = await compute(_parseCabinetMaterials, body);
    _cabinetMasterCache[idWarehouse] = items;
    return items;
  }

  // ==========================================
  //  STATUS TIM
  //  GET /api/penerimaan-bahan-pendukung/tim-status
  // ==========================================
  Future<List<TimPenerimaanInfo>> fetchTimStatus() async {
    final body = await api.getJson(
      '/api/penerimaan-bahan-pendukung/tim-status',
    );
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
      '/api/penerimaan-bahan-pendukung',
      query: {
        'page': page,
        'pageSize': pageSize,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      },
    );

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map(
          (e) => PenerimaanBahanPendukung.fromJson(e as Map<String, dynamic>),
        )
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

  Future<PenerimaanBahanPendukungDetail> fetchDetail(
    String noPenerimaan,
  ) async {
    final body = await api.getJson(
      '/api/penerimaan-bahan-pendukung/$noPenerimaan',
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Data penerimaan tidak ditemukan');
    return PenerimaanBahanPendukungDetail.fromJson(data);
  }

  // ==========================================
  //  FASE 1: CREATE HEADER
  //  POST /api/penerimaan-bahan-pendukung
  // ==========================================
  Future<PenerimaanBahanPendukungHeaderResult> createHeader({
    required DateTime tglPenerimaan,
    required int idTim,
  }) async {
    final body = await api.postJson(
      '/api/penerimaan-bahan-pendukung',
      body: {'tglPenerimaan': _dateOnly(tglPenerimaan), 'idTim': idTim},
    );

    final data = body['data'] as Map<String, dynamic>?;
    final noPenerimaan = data?['noPenerimaan']?.toString();
    if (noPenerimaan == null) {
      throw Exception('Response create header penerimaan tidak valid');
    }
    return PenerimaanBahanPendukungHeaderResult(
      noPenerimaan: noPenerimaan,
      tanggal: tglPenerimaan,
      idTim: idTim,
    );
  }

  // ==========================================
  //  FASE 2: ADD ITEMS ke header yang sudah ada
  //  POST /api/penerimaan-bahan-pendukung/:noPenerimaan/items
  //  Boleh dipanggil >1x per NoPenerimaan.
  // ==========================================
  Future<void> addItems({
    required String noPenerimaan,
    required List<PenerimaanBahanPendukungItemInput> items,
  }) async {
    await api.postJson(
      '/api/penerimaan-bahan-pendukung/$noPenerimaan/items',
      body: {'items': items.map((it) => it.toJson()).toList()},
    );
  }

  Future<void> delete(String noPenerimaan) async {
    await api.deleteJson('/api/penerimaan-bahan-pendukung/$noPenerimaan');
  }

  Future<void> markComplete(String noPenerimaan) async {
    await api.patchJson(
      '/api/penerimaan-bahan-pendukung/$noPenerimaan/complete',
    );
  }

  // ==========================================
  //  PRINT LABEL — increment HasBeenPrinted setelah label berhasil dicetak
  //  PATCH /api/labels/bahan-pendukung/:noBahanPendukung/print
  //  Returns HasBeenPrinted terbaru dari server, atau null kalau gagal parse.
  // ==========================================
  Future<int?> markItemPrinted(String noBahanPendukung) async {
    final body = await api.patchJson(
      '/api/labels/bahan-pendukung/$noBahanPendukung/print',
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
  //  DELETE 1 BARANG — DELETE /api/labels/bahan-pendukung/:noBahanPendukung
  // ==========================================
  Future<void> deleteItem(String noBahanPendukung) async {
    await api.deleteJson('/api/labels/bahan-pendukung/$noBahanPendukung');
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
