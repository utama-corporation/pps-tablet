// lib/features/shared/key_fitting_production/packing_production_repository.dart
import 'dart:async';
import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';
import 'package:http/http.dart' as http;
import '../model/key_fitting_production_model.dart';
export '../model/key_fitting_production_model.dart' show KeyFittingMesinInfo;

class KeyFittingProductionRepository {
  final ApiClient api;

  KeyFittingProductionRepository({ApiClient? api})
      : api = api ?? ApiClient();

  static const _timeout = Duration(seconds: 25);

  // =========================
  //  PASANG KUNCI MESIN LIST
  //  GET :7500/api/mst-mesin/pasang-kunci
  // =========================
  Future<List<KeyFittingMesinInfo>> fetchPasangKunciMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/pasang-kunci',
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin pasang kunci');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin pasang kunci (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => KeyFittingMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get PasangKunci_h (Key Fitting) by date
  /// Backend: GET /api/production/key-fitting/:date (YYYY-MM-DD)
  Future<List<KeyFittingProduction>> fetchByDate(DateTime date) async {
    final dateDb = toDbDateString(date); // yyyy-MM-dd

    final Map<String, dynamic> body =
    await api.getJson('/api/production/key-fitting/$dateDb');

    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => KeyFittingProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST
  //  GET /api/production/key-fitting
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
    int? idMesin,
  }) async {
    final String? effectiveSearch =
    (noProduksi != null && noProduksi.trim().isNotEmpty)
        ? noProduksi.trim()
        : (search != null && search.trim().isNotEmpty ? search.trim() : null);

    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (effectiveSearch != null) 'search': effectiveSearch,
      if (idMesin != null) 'idMesin': idMesin,
    };

    final body = await api.getJson('/api/production/key-fitting', query: qp);

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => KeyFittingProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print(
        '✅ KeyFitting parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items, // List<KeyFittingProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  Future<KeyFittingProduction> fetchOne(String noProduksi) async {
    final result = await fetchAll(page: 1, pageSize: 1, noProduksi: noProduksi.trim());
    final items = result['items'] as List<KeyFittingProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noProduksi');
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<KeyFittingProduction>> fetchAllList({
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
    return (r['items'] as List<KeyFittingProduction>);
  }

  // =========================
  //  CREATE (POST)
  //  POST /api/production/key-fitting
  // =========================
  Future<KeyFittingProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int outputJenisId,
    required int shift,
    int? idRegu,
    int? jamKerja,
    int? hourMeter,
    String? hourStart,
    String? hourEnd,
  }) async {
    String _normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final payload = <String, dynamic>{
      'tglProduksi': toDbDateString(tglProduksi),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'outputJenisId': outputJenisId,
      'shift': shift,
      if (idRegu != null) 'idRegu': idRegu,
      if (jamKerja != null) 'jamKerja': jamKerja,
      if (hourMeter != null) 'hourMeter': hourMeter,
      if (hourStart != null && hourStart.isNotEmpty)
        'hourStart': _normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty)
        'hourEnd': _normalizeTime(hourEnd),
    };

    print('📦 Key fitting create payload: $payload');

    final body =
        await api.postJson('/api/production/key-fitting', body: payload);

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header key fitting');
    }

    return KeyFittingProduction.fromJson(data);
  }

  // =========================
  //  UPDATE (PUT)
  //  PUT /api/production/key-fitting/:noProduksi
  // =========================
  Future<KeyFittingProduction> updateProduksi({
    required String noProduksi,
    DateTime? tglProduksi,
    int? idMesin,
    List<int>? idOperators,
    int? outputJenisId,
    int? idRegu,
    int? shift,
    int? jamKerja,
    int? hourMeter,
    String? hourStart,
    String? hourEnd,
  }) async {
    String _normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final payload = <String, dynamic>{};

    if (tglProduksi != null) payload['tglProduksi'] = toDbDateString(tglProduksi);
    if (idMesin != null) payload['idMesin'] = idMesin;
    if (idOperators != null) payload['idOperators'] = idOperators;
    if (outputJenisId != null) payload['outputJenisId'] = outputJenisId;
    if (idRegu != null) payload['idRegu'] = idRegu;
    if (shift != null) payload['shift'] = shift;
    if (jamKerja != null) payload['jamKerja'] = jamKerja;
    if (hourMeter != null) payload['hourMeter'] = hourMeter;
    if (hourStart != null && hourStart.isNotEmpty) {
      payload['hourStart'] = _normalizeTime(hourStart);
    }
    if (hourEnd != null && hourEnd.isNotEmpty) {
      payload['hourEnd'] = _normalizeTime(hourEnd);
    }

    print('📦 Key fitting update payload: $payload');

    final body = await api.putJson(
      '/api/production/key-fitting/$noProduksi',
      body: payload,
    );

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data header key fitting');
    }

    return KeyFittingProduction.fromJson(data);
  }

  // =========================
  //  DELETE
  //  DELETE /api/production/key-fitting/:noProduksi
  // =========================
  //  PATCH /api/production/key-fitting/:noProduksi/complete
  Future<void> completeProduksi(String noProduksi) async {
    print('✅ Completing key fitting production: $noProduksi');
    try {
      await api.patchJson('/api/production/key-fitting/$noProduksi/complete');
    } catch (e) {
      print('❌ Complete key fitting production error: $e');
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menyelesaikan key fitting produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menyelesaikan key fitting produksi (${e.statusCode})');
      }
      rethrow;
    }
  }

  /// Buka kunci produksi (IsComplete -> 0) supaya bisa diubah lagi.
  Future<void> uncompleteProduksi(String noProduksi) async {
    print('🔓 Uncompleting key fitting production: $noProduksi');
    try {
      await api.patchJson('/api/production/key-fitting/$noProduksi/uncomplete');
    } catch (e) {
      print('❌ Uncomplete key fitting production error: $e');
      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal membuka kunci key fitting produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal membuka kunci key fitting produksi (${e.statusCode})');
      }
      rethrow;
    }
  }

  Future<void> deleteProduksi(String noProduksi) async {
    print('🗑️ Deleting key fitting production: $noProduksi');

    try {
      await api.deleteJson('/api/production/key-fitting/$noProduksi');
      print('✅ Key fitting production deleted successfully');
    } catch (e) {
      print('❌ Delete key fitting production error: $e');

      if (e is ApiException) {
        if (e.responseBody != null && e.responseBody!.isNotEmpty) {
          try {
            final decoded = jsonDecode(e.responseBody!);
            final msg = decoded['message'] ??
                decoded['error'] ??
                decoded['msg'] ??
                'Gagal menghapus key fitting produksi';
            throw Exception(msg);
          } catch (_) {
            throw Exception(e.responseBody);
          }
        }
        throw Exception('Gagal menghapus key fitting produksi (${e.statusCode})');
      }

      rethrow;
    }
  }
}
