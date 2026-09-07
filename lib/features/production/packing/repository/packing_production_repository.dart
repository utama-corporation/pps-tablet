// lib/features/shared/packing_production/packing_production_repository.dart
import 'dart:async';
import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_formatter.dart';
import '../model/packing_production_model.dart';

class PackingProductionRepository {
  final ApiClient api;

  PackingProductionRepository({ApiClient? api}) : api = api ?? ApiClient();

  // =========================
  //  GET BY DATE
  //  GET /api/production/packing/:date (YYYY-MM-DD)
  // =========================
  Future<List<PackingProduction>> fetchByDate(DateTime date) async {
    final dateDb = toDbDateString(date); // yyyy-MM-dd

    final Map<String, dynamic> body =
    await api.getJson('/api/production/packing/$dateDb');

    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => PackingProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  MESIN STATUS
  //  GET /api/mst-mesin/packing
  // ==========================================
  Future<List<PackingMesinInfo>> fetchPackingMesin() async {
    final body = await api.getJson('/api/mst-mesin/packing');
    final list = (body['data'] as List<dynamic>? ?? []);
    return list
        .map((e) => PackingMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST
  //  GET /api/production/packing?page=&pageSize=&search=
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? noPacking,
    String? dateFrom, // optional: 'yyyy-MM-dd'
    String? dateTo, // optional: 'yyyy-MM-dd'
    int? idMesin,
  }) async {
    final String? effectiveSearch =
    (noPacking != null && noPacking.trim().isNotEmpty)
        ? noPacking.trim()
        : (search != null && search.trim().isNotEmpty ? search.trim() : null);

    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (effectiveSearch != null) 'search': effectiveSearch,
      if (dateFrom != null && dateFrom.trim().isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.trim().isNotEmpty) 'dateTo': dateTo,
      if (idMesin != null) 'idMesin': idMesin,
    };

    final body = await api.getJson('/api/production/packing', query: qp);

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => PackingProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) is int
        ? (meta['page'] ?? page) as int
        : int.tryParse('${meta['page'] ?? page}') ?? page;

    final totalPages = (meta['totalPages'] ?? 1) is int
        ? (meta['totalPages'] ?? 1) as int
        : int.tryParse('${meta['totalPages'] ?? 1}') ?? 1;

    final totalData = (body['totalData'] ?? meta['total'] ?? 0) is int
        ? (body['totalData'] ?? meta['total'] ?? 0) as int
        : int.tryParse('${body['totalData'] ?? meta['total'] ?? 0}') ?? 0;

    print(
        '✅ Packing parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items, // List<PackingProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  Future<PackingProduction> fetchOne(String noPacking) async {
    final result = await fetchAll(
      page: 1,
      pageSize: 1,
      noPacking: noPacking.trim(),
    );
    final items = result['items'] as List<PackingProduction>;
    if (items.isEmpty) {
      throw Exception('Data tidak ditemukan untuk $noPacking');
    }
    return items.first;
  }

  /// Convenience if you only need list for a given page
  Future<List<PackingProduction>> fetchAllList({
    required int page,
    int pageSize = 20,
    String? search,
    String? noPacking,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final r = await fetchAll(
      page: page,
      pageSize: pageSize,
      search: search,
      noPacking: noPacking,
      dateFrom: dateFrom == null ? null : toDbDateString(dateFrom),
      dateTo: dateTo == null ? null : toDbDateString(dateTo),
    );
    return (r['items'] as List<PackingProduction>);
  }

  // =========================
  //  CREATE (POST)
  //  POST /api/production/packing
  //  backend: hourStart & hourEnd required
  // =========================
  Future<PackingProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int outputJenisId,
    required int idRegu,
    required int shift,
    required String hourStart,
    required String hourEnd,
    int? jamKerja,
    double? hourMeter,
  }) async {
    final tglStr = toDbDateString(tglProduksi);

    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      if (t.length == 5) return '$t:00'; // HH:mm -> HH:mm:00
      return t;
    }

    final payload = <String, dynamic>{
      'tglProduksi': tglStr,
      'idMesin': idMesin,
      'idOperators': idOperators,
      'outputJenisId': outputJenisId,
      'idRegu': idRegu,
      'shift': shift,
      'hourStart': _normalizeTime(hourStart),
      'hourEnd': _normalizeTime(hourEnd),
      if (jamKerja != null) 'jamKerja': jamKerja,
      if (hourMeter != null) 'hourMeter': hourMeter,
    };

    print('📦 Packing create payload: $payload');

    final body = await api.postJson('/api/production/packing', body: payload);

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header packing');
    }

    return PackingProduction.fromJson(data);
  }

  // =========================
  //  UPDATE (PUT)
  //  PUT /api/production/packing/:noPacking
  //  Partial update (send only changed fields)
  // =========================
  Future<PackingProduction> updateProduksi({
    required String noPacking,
    DateTime? tglProduksi,
    int? idMesin,
    int? idOperator,
    dynamic jamKerja, // int atau String
    int? shift,
    String? hourStart,
    String? hourEnd,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    double? hourMeter,
  }) async {
    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      if (t.length == 5) return '$t:00';
      return t;
    }

    final payload = <String, dynamic>{};

    if (tglProduksi != null) payload['tglProduksi'] = toDbDateString(tglProduksi);
    if (idMesin != null) payload['idMesin'] = idMesin;
    if (idOperator != null) payload['idOperator'] = idOperator;
    if (shift != null) payload['shift'] = shift;

    if (jamKerja != null) payload['jamKerja'] = jamKerja;

    // backend: hourStart/hourEnd distinguish "not sent" vs null
    // so: if user wants clear -> send "" or null based on your UI design
    if (hourStart != null) payload['hourStart'] = _normalizeTime(hourStart);
    if (hourEnd != null) payload['hourEnd'] = _normalizeTime(hourEnd);

    if (checkBy1 != null) payload['checkBy1'] = checkBy1;
    if (checkBy2 != null) payload['checkBy2'] = checkBy2;
    if (approveBy != null) payload['approveBy'] = approveBy;
    if (hourMeter != null) payload['hourMeter'] = hourMeter;

    print('📦 Packing update payload: $payload');

    final body = await api.putJson(
      '/api/production/packing/$noPacking',
      body: payload,
    );

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header packing');
    }

    return PackingProduction.fromJson(data);
  }

  // =========================
  //  SPLIT TIME (GANTI PRODUKSI)
  //  POST /api/packing/split-time/:idMesin/:tanggal
  // =========================
  Future<Map<String, dynamic>> splitTime({
    required int idMesin,
    required DateTime tanggal,
    required String hourStart,
    required int outputJenisId,
  }) async {
    final dateStr =
        '${tanggal.year.toString().padLeft(4, '0')}-'
        '${tanggal.month.toString().padLeft(2, '0')}-'
        '${tanggal.day.toString().padLeft(2, '0')}';
    return api.postJson(
      '/api/production/packing/split-time/$idMesin/$dateStr',
      body: {'hourStart': hourStart, 'outputJenisId': outputJenisId},
    );
  }

  // =========================
  //  DELETE
  //  DELETE /api/production/packing/:noPacking
  // =========================
  //  PATCH /api/production/packing/:noPacking/complete
  Future<void> completeProduksi(String noPacking) async {
    print('✅ Completing packing production: $noPacking');
    try {
      await api.patchJson('/api/production/packing/$noPacking/complete');
    } catch (e) {
      print('❌ Complete packing production error: $e');
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menyelesaikan packing produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menyelesaikan packing produksi (${e.statusCode})');
      }
      rethrow;
    }
  }

  /// Buka kunci produksi (IsComplete -> 0) supaya bisa diubah lagi.
  Future<void> uncompleteProduksi(String noPacking) async {
    print('🔓 Uncompleting packing production: $noPacking');
    try {
      await api.patchJson('/api/production/packing/$noPacking/uncomplete');
    } catch (e) {
      print('❌ Uncomplete packing production error: $e');
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal membuka kunci packing produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal membuka kunci packing produksi (${e.statusCode})');
      }
      rethrow;
    }
  }

  Future<void> deleteProduksi(String noPacking) async {
    print('🗑️ Deleting packing production: $noPacking');

    try {
      await api.deleteJson('/api/production/packing/$noPacking');
      print('✅ Packing production deleted successfully');
    } catch (e) {
      print('❌ Delete packing production error: $e');

      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menghapus packing produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menghapus packing produksi (${e.statusCode})');
      }

      rethrow;
    }
  }
}
