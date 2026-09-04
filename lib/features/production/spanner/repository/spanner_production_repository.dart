// lib/features/shared/spanner_production/spanner_production_repository.dart
import 'dart:async';
import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/date_formatter.dart';
import '../model/spanner_production_model.dart';



class SpannerProductionRepository {
  final ApiClient api;

  SpannerProductionRepository({ApiClient? api}) : api = api ?? ApiClient();

  // =========================
  //  GET MESIN STATUS
  //  GET /api/mst-mesin/spanner
  // =========================
  Future<List<SpannerMesinInfo>> fetchSpannerMesin() async {
    final body = await api.getJson('/api/mst-mesin/spanner');
    final List data = (body['data'] ?? []) as List;
    return data
        .map((e) => SpannerMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  //  GET BY DATE
  //  GET /api/spanner/spanner/:date (YYYY-MM-DD)
  // =========================
  Future<List<SpannerProduction>> fetchByDate(DateTime date) async {
    final dateDb = toDbDateString(date); // yyyy-MM-dd

    final Map<String, dynamic> body =
    await api.getJson('/api/production/spanner/$dateDb');

    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => SpannerProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST
  //  GET /api/spanner/spanner?page=&pageSize=&search=
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
  }) async {
    final String? effectiveSearch =
    (noProduksi != null && noProduksi.trim().isNotEmpty)
        ? noProduksi.trim()
        : (search != null && search.trim().isNotEmpty ? search.trim() : null);

    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (effectiveSearch != null) 'search': effectiveSearch,
      // sebenarnya backend kamu support ?noProduksi= juga,
      // tapi karena controller sudah merge ke "search", cukup kirim 'search'
    };

    final body = await api.getJson('/api/production/spanner', query: qp);

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => SpannerProduction.fromJson(e as Map<String, dynamic>))
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
        '✅ Spanner parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items, // List<SpannerProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  Future<SpannerProduction> fetchOne(String noProduksi) async {
    final result = await fetchAll(
      page: 1,
      pageSize: 1,
      noProduksi: noProduksi.trim(),
    );
    final items = result['items'] as List<SpannerProduction>;
    if (items.isEmpty) {
      throw Exception('Data tidak ditemukan untuk $noProduksi');
    }
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<SpannerProduction>> fetchAllList({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
  }) async {
    final r = await fetchAll(
      page: page,
      pageSize: pageSize,
      search: search,
      noProduksi: noProduksi,
    );
    return (r['items'] as List<SpannerProduction>);
  }

  // =========================
  //  CREATE (POST)
  //  POST /api/production/spanner
  // =========================
  Future<SpannerProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int outputJenisId,
    required int idRegu,
    required int shift,
    required String hourStart,
    required String hourEnd,
  }) async {
    String norm(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final payload = <String, dynamic>{
      'tglProduksi': toDbDateString(tglProduksi),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'outputJenisId': outputJenisId,
      'idRegu': idRegu,
      'shift': shift,
      'hourStart': norm(hourStart),
      'hourEnd': norm(hourEnd),
    };

    final body = await api.postJson('/api/production/spanner', body: payload);

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header spanner');
    }

    return SpannerProduction.fromJson(data);
  }

  // =========================
  //  UPDATE (PUT)
  //  PUT /api/spanner/spanner/:noProduksi
  //  Partial update (kirim hanya yang berubah)
  // =========================
  Future<SpannerProduction> updateProduksi({
    required String noProduksi,
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

    // per backend: hourStart/hourEnd distinguish "not sent" vs null
    // jadi kalau user memang mau clear: kirim "" atau null sesuai kebutuhan UI kamu
    if (hourStart != null) payload['hourStart'] = _normalizeTime(hourStart);
    if (hourEnd != null) payload['hourEnd'] = _normalizeTime(hourEnd);

    if (checkBy1 != null) payload['checkBy1'] = checkBy1;
    if (checkBy2 != null) payload['checkBy2'] = checkBy2;
    if (approveBy != null) payload['approveBy'] = approveBy;
    if (hourMeter != null) payload['hourMeter'] = hourMeter;

    print('📦 Spanner update payload: $payload');

    final body = await api.putJson(
      '/api/production/spanner/$noProduksi',
      body: payload,
    );

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header spanner');
    }

    return SpannerProduction.fromJson(data);
  }

  // =========================
  //  DELETE
  //  DELETE /api/spanner/spanner/:noProduksi
  // =========================
  //  PATCH /api/production/spanner/:noProduksi/complete
  Future<void> completeProduksi(String noProduksi) async {
    print('✅ Completing spanner production: $noProduksi');
    try {
      await api.patchJson('/api/production/spanner/$noProduksi/complete');
    } catch (e) {
      print('❌ Complete spanner production error: $e');
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menyelesaikan spanner produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menyelesaikan spanner produksi (${e.statusCode})');
      }
      rethrow;
    }
  }

  Future<void> deleteProduksi(String noProduksi) async {
    print('🗑️ Deleting spanner production: $noProduksi');

    try {
      await api.deleteJson('/api/production/spanner/$noProduksi');
      print('✅ Spanner production deleted successfully');
    } catch (e) {
      print('❌ Delete spanner production error: $e');

      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menghapus spanner produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menghapus spanner produksi (${e.statusCode})');
      }

      rethrow;
    }
  }
}
