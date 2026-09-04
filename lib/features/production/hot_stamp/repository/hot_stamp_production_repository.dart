// lib/features/shared/hot_stamp_production/hot_stamp_production_repository.dart

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';
import '../model/hot_stamp_production_model.dart';
export '../model/hot_stamp_production_model.dart' show HotStampMesinInfo;


class HotStampProductionRepository {
  final ApiClient api;

  HotStampProductionRepository({ApiClient? api})
      : api = api ?? ApiClient();

  static const _timeout = Duration(seconds: 25);

  // =========================
  //  STAMPING MESIN LIST
  //  GET :7500/api/mst-mesin/stamping
  // =========================
  Future<List<HotStampMesinInfo>> fetchStampingMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/stamping',
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin stamping');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin stamping (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => HotStampMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get HotStamping_h by date
  /// Backend: GET /api/production/hot-stamp/:date (YYYY-MM-DD)
  Future<List<HotStampProduction>> fetchByDate(DateTime date) async {
    final dateDb = toDbDateString(date); // yyyy-MM-dd

    final Map<String, dynamic> body =
    await api.getJson('/api/production/hot-stamp/$dateDb');

    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => HotStampProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST
  //  GET /api/production/hot-stamp
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
    int? idMesin,
  }) async {
    // Prefer explicit noProduksi over generic search
    final String? effectiveSearch =
    (noProduksi != null && noProduksi.trim().isNotEmpty)
        ? noProduksi.trim()
        : (search != null && search.trim().isNotEmpty
        ? search.trim()
        : null);

    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (effectiveSearch != null) 'search': effectiveSearch,
      if (idMesin != null) 'idMesin': idMesin,
    };

    final body = await api.getJson('/api/production/hot-stamp', query: qp);

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => HotStampProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print(
        '✅ HotStamp parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items, // List<HotStampProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  Future<HotStampProduction> fetchOne(String noProduksi) async {
    final result = await fetchAll(page: 1, pageSize: 1, noProduksi: noProduksi.trim());
    final items = result['items'] as List<HotStampProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noProduksi');
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<HotStampProduction>> fetchAllList({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
    int? idMesin,
  }) async {
    final r = await fetchAll(
      page: page,
      pageSize: pageSize,
      search: search,
      noProduksi: noProduksi,
      idMesin: idMesin,
    );
    return (r['items'] as List<HotStampProduction>);
  }

  // =========================
  //  CREATE V2 — req body baru
  //  POST /api/production/hot-stamp
  //  { tglProduksi, idMesin, idOperators[], outputJenisId, idRegu, shift, hourStart, hourEnd }
  // =========================
  Future<HotStampProduction> createProduksiWithJenis({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int outputJenisId,
    required int shift,
    String? hourStart,
    String? hourEnd,
    int? idRegu,
  }) async {
    String normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final payload = <String, dynamic>{
      'tglProduksi': toDbDateString(tglProduksi),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'outputJenisId': outputJenisId,
      'shift': shift,
      if (hourStart != null && hourStart.isNotEmpty)
        'hourStart': normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty)
        'hourEnd': normalizeTime(hourEnd),
      if (idRegu != null) 'idRegu': idRegu,
    };

    final body = await api.postJson('/api/production/hot-stamp', body: payload);
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header hot stamp');
    }
    return HotStampProduction.fromJson(data);
  }

  // =========================
  //  CREATE (POST)
  //  POST /api/production/hot-stamp
  //  DENGAN kolom jam (int atau 'HH:mm-HH:mm')
  // =========================
  Future<HotStampProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required int idOperator,
    required dynamic jam, // int atau String 'HH:mm-HH:mm'
    required int shift,
    String? hourStart,
    String? hourEnd,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    double? hourMeter,
  }) async {
    final tglStr = toDbDateString(tglProduksi);

    // helper kecil biar "08:00" -> "08:00:00"
    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      if (t.length == 5) {
        return '$t:00';
      }
      return t;
    }

    final payload = <String, dynamic>{
      'tglProduksi': tglStr,
      'idMesin': idMesin,
      'idOperator': idOperator,
      'jam': jam, // Backend parse int atau 'HH:mm-HH:mm'
      'shift': shift,
      if (hourStart != null && hourStart.isNotEmpty)
        'hourStart': _normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty)
        'hourEnd': _normalizeTime(hourEnd),
      if (checkBy1 != null) 'checkBy1': checkBy1,
      if (checkBy2 != null) 'checkBy2': checkBy2,
      if (approveBy != null) 'approveBy': approveBy,
      if (hourMeter != null) 'hourMeter': hourMeter,
    };

    print('📦 Hot stamp create payload: $payload');

    final body = await api.postJson('/api/production/hot-stamp', body: payload);

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header hot stamp');
    }

    return HotStampProduction.fromJson(data);
  }

  // =========================
  //  UPDATE (PUT)
  //  PUT /api/production/hot-stamp/:noProduksi
  //  DENGAN jam, partial update (kirim hanya yang diubah)
  // =========================
  Future<HotStampProduction> updateProduksi({
    required String noProduksi,
    DateTime? tglProduksi,
    int? idMesin,
    int? idOperator,
    dynamic jam, // int atau String
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
      if (t.length == 5) {
        return '$t:00'; // HH:mm -> HH:mm:00
      }
      return t;
    }

    final payload = <String, dynamic>{};

    if (tglProduksi != null) {
      payload['tglProduksi'] = toDbDateString(tglProduksi);
    }
    if (idMesin != null) {
      payload['idMesin'] = idMesin;
    }
    if (idOperator != null) {
      payload['idOperator'] = idOperator;
    }
    if (jam != null) {
      payload['jam'] = jam;
    }
    if (shift != null) {
      payload['shift'] = shift;
    }
    if (hourStart != null && hourStart.isNotEmpty) {
      payload['hourStart'] = _normalizeTime(hourStart);
    }
    if (hourEnd != null && hourEnd.isNotEmpty) {
      payload['hourEnd'] = _normalizeTime(hourEnd);
    }
    if (checkBy1 != null) {
      payload['checkBy1'] = checkBy1;
    }
    if (checkBy2 != null) {
      payload['checkBy2'] = checkBy2;
    }
    if (approveBy != null) {
      payload['approveBy'] = approveBy;
    }
    if (hourMeter != null) {
      payload['hourMeter'] = hourMeter;
    }

    print('📦 Hot stamp update payload: $payload');

    final body = await api.putJson(
      '/api/production/hot-stamp/$noProduksi',
      body: payload,
    );

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header hot stamp');
    }

    return HotStampProduction.fromJson(data);
  }

  // =========================
  //  DELETE
  //  DELETE /api/production/hot-stamp/:noProduksi
  // =========================
  //  PATCH /api/production/hot-stamp/:noProduksi/complete
  Future<void> completeProduksi(String noProduksi) async {
    print('✅ Completing hot stamp production: $noProduksi');
    try {
      await api.patchJson('/api/production/hot-stamp/$noProduksi/complete');
    } catch (e) {
      print('❌ Complete hot stamp production error: $e');
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menyelesaikan hot stamp produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menyelesaikan hot stamp produksi (${e.statusCode})');
      }
      rethrow;
    }
  }

  Future<void> deleteProduksi(String noProduksi) async {
    print('🗑️ Deleting hot stamp production: $noProduksi');

    try {
      await api.deleteJson('/api/production/hot-stamp/$noProduksi');
      print('✅ Hot stamp production deleted successfully');
    } catch (e) {
      print('❌ Delete hot stamp production error: $e');

      // Extract user-friendly message from ApiException
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menghapus hot stamp produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menghapus hot stamp produksi (${e.statusCode})');
      }

      rethrow;
    }
  }
}