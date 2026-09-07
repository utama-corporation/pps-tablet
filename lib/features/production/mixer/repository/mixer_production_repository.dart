// lib/features/shared/mixer_production/mixer_production_repository.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';

import '../model/mixer_production_model.dart';
export '../model/mixer_production_model.dart' show MixerMesinInfo;

class MixerProductionRepository {
  static const _timeout = Duration(seconds: 25);

  String get _base => ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');

  Map<String, String> _headers(String? token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  // =========================
  //  MIXER MESIN LIST
  // =========================
  Future<List<MixerMesinInfo>> fetchMixerMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/mixer',
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin mixer');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin mixer (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => MixerMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get MixerProduksi_h by date
  /// Backend: GET /api/production/mixer/:date (YYYY-MM-DD)
  Future<List<MixerProduction>> fetchByDate(DateTime date) async {
    final token = await TokenStorage.getToken();
    final dateDb = toDbDateString(date); // yyyy-MM-dd
    final url = Uri.parse('$_base/api/production/mixer/$dateDb');

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mixer produksi (byDate)');
    } catch (e) {
      print('❌ Request error (mixer byDate): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in '
        '${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data mixer produksi (${res.statusCode})',
      );
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => MixerProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST
  //  GET /api/production/mixer
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
    int? idMesin,
    int? shift,
    DateTime? date,
  }) async {
    final token = await TokenStorage.getToken();

    final String? effectiveSearch =
        (noProduksi != null && noProduksi.trim().isNotEmpty)
            ? noProduksi.trim()
            : (search != null && search.trim().isNotEmpty
                ? search.trim()
                : null);

    final String? df = date != null ? toDbDateString(date) : null;

    final qp = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (effectiveSearch != null) 'search': effectiveSearch,
      if (idMesin != null) 'idMesin': '$idMesin',
      if (shift != null) 'shift': '$shift',
      if (df != null) 'dateFrom': df,
      if (df != null) 'dateTo': df,
    };

    final url = Uri.parse('$_base/api/production/mixer').replace(
      queryParameters: qp,
    );

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil list mixer produksi');
    } catch (e) {
      print('❌ Request error (mixer list): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in '
        '${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil list mixer produksi (${res.statusCode})');
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => MixerProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print(
        '✅ Mixer parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items, // List<MixerProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  /// GET single record by noProduksi
  Future<MixerProduction> fetchOne(String noProduksi) async {
    final result = await fetchAll(
      page: 1,
      pageSize: 1,
      noProduksi: noProduksi.trim(),
    );
    final items = result['items'] as List<MixerProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noProduksi');
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<MixerProduction>> fetchAllList({
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
    return (r['items'] as List<MixerProduction>);
  }

  // =========================
  //  CREATE V2 (POST JSON)
  //  POST /api/production/mixer
  //  {tglProduksi, idMesin, idOperators[], outputJenisId, idRegu, shift, hourStart, hourEnd}
  // =========================
  Future<MixerProduction> createProduksiWithJenis({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int outputJenisId,
    required int shift,
    String? hourStart,
    String? hourEnd,
    int? idRegu,
    int? hadir,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/mixer');

    String normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final bodyMap = <String, dynamic>{
      'tglProduksi': toDbDateString(tglProduksi),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'outputJenisId': outputJenisId,
      'shift': shift,
      if (hourStart != null && hourStart.isNotEmpty) 'hourStart': normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty) 'hourEnd': normalizeTime(hourEnd),
      if (idRegu != null) 'idRegu': idRegu,
      if (hadir != null) 'hadir': hadir,
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    print('➡️ [POST] $url');
    print('📦 json body (mixer v2): $bodyMap');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: json.encode(bodyMap))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat mixer produksi');
    } catch (e) {
      print('❌ Request error (mixer v2 create): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 201 && res.statusCode != 200) {
      String msg = 'Gagal membuat mixer produksi (${res.statusCode})';
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded['message'] as String?) ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header mixer');
    }

    return MixerProduction.fromJson(data);
  }

  // =========================
  //  CREATE (POST)
  //  POST /api/production/mixer
  //  DENGAN kolom jam (int atau 'HH:mm-HH:mm')
  // =========================
  Future<MixerProduction> createProduksi({
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
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/mixer');

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

    final body = <String, String>{
      'tglProduksi': tglStr,
      'idMesin': idMesin.toString(),
      'idOperator': idOperator.toString(),
      'jam': jam.toString(), // Backend parse int atau 'HH:mm-HH:mm'
      'shift': shift.toString(),
      if (hourStart != null && hourStart.isNotEmpty)
        'hourStart': _normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty)
        'hourEnd': _normalizeTime(hourEnd),
      if (checkBy1 != null) 'checkBy1': checkBy1,
      if (checkBy2 != null) 'checkBy2': checkBy2,
      if (approveBy != null) 'approveBy': approveBy,
      if (jmlhAnggota != null) 'jmlhAnggota': jmlhAnggota.toString(),
      if (hadir != null) 'hadir': hadir.toString(),
      if (hourMeter != null) 'hourMeter': hourMeter.toString(),
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    print('➡️ [POST] $url');
    print('📦 form body (mixer create): $body');

    late http.Response res;
    try {
      res = await http
          .post(
        url,
        headers: headers,
        body: body,
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat mixer produksi');
    } catch (e) {
      print('❌ Request error (mixer create): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 201 && res.statusCode != 200) {
      String msg;
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal membuat mixer produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal membuat mixer produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header mixer');
    }

    return MixerProduction.fromJson(data);
  }

  // =========================
  //  UPDATE (PUT)
  //  PUT /api/production/mixer/:noProduksi
  //  DENGAN jam, partial update (kirim hanya yang diubah)
  // =========================
  Future<MixerProduction> updateProduksi({
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
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/mixer/$noProduksi');

    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      if (t.length == 5) {
        return '$t:00'; // HH:mm -> HH:mm:00
      }
      return t;
    }

    final body = <String, String>{};

    if (tglProduksi != null) {
      body['tglProduksi'] = toDbDateString(tglProduksi);
    }
    if (idMesin != null) {
      body['idMesin'] = idMesin.toString();
    }
    if (idOperator != null) {
      body['idOperator'] = idOperator.toString();
    }
    if (jam != null) {
      body['jam'] = jam.toString();
    }
    if (shift != null) {
      body['shift'] = shift.toString();
    }
    if (hourStart != null && hourStart.isNotEmpty) {
      body['hourStart'] = _normalizeTime(hourStart);
    }
    if (hourEnd != null && hourEnd.isNotEmpty) {
      body['hourEnd'] = _normalizeTime(hourEnd);
    }
    if (checkBy1 != null) {
      body['checkBy1'] = checkBy1;
    }
    if (checkBy2 != null) {
      body['checkBy2'] = checkBy2;
    }
    if (approveBy != null) {
      body['approveBy'] = approveBy;
    }
    if (jmlhAnggota != null) {
      body['jmlhAnggota'] = jmlhAnggota.toString();
    }
    if (hadir != null) {
      body['hadir'] = hadir.toString();
    }
    if (hourMeter != null) {
      body['hourMeter'] = hourMeter.toString();
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    print('➡️ [PUT] $url');
    print('📦 form body (mixer update): $body');

    late http.Response res;
    try {
      res = await http
          .put(
        url,
        headers: headers,
        body: body,
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengubah mixer produksi');
    } catch (e) {
      print('❌ Request error (mixer update): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      String msg;
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal mengubah mixer produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal mengubah mixer produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header mixer');
    }

    return MixerProduction.fromJson(data);
  }

  // =========================
  //  FETCH BY MESIN + TANGGAL + SHIFT
  //  GET /api/production/mixer?idMesin=&tanggal=&shift=
  // =========================
  Future<List<MixerProduction>> fetchByMesinTanggalShift({
    required int idMesin,
    required DateTime tanggal,
    required int shift,
  }) async {
    final token = await TokenStorage.getToken();
    final dateStr = toDbDateString(tanggal);
    final url = Uri.parse('$_base/api/production/mixer').replace(
      queryParameters: {
        'idMesin': '$idMesin',
        'tanggal': dateStr,
        'shift': '$shift',
      },
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil riwayat mixer produksi');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat riwayat mixer (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = (body['data'] ?? []) as List;
    return list
        .map((e) => MixerProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  //  SPLIT TIME
  //  POST /api/production/mixer/split-time/:idMesin/:tanggal
  //  { hourStart, outputJenisId }
  // =========================
  Future<Map<String, dynamic>> splitTime({
    required int idMesin,
    required DateTime tanggal,
    required String hourStart,
    required int outputJenisId,
  }) async {
    final token = await TokenStorage.getToken();
    final dateStr = toDbDateString(tanggal);
    final url = Uri.parse(
      '$_base/api/production/mixer/split-time/$idMesin/$dateStr',
    );

    String normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final bodyMap = {
      'hourStart': normalizeTime(hourStart),
      'outputJenisId': outputJenisId,
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    print('➡️ [POST] $url');
    print('📦 json body (mixer split-time): $bodyMap');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: json.encode(bodyMap))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout split-time mixer produksi');
    } catch (e) {
      print('❌ Request error (mixer split-time): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      String msg = 'Gagal split-time mixer produksi (${res.statusCode})';
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded['message'] as String?) ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }

    return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  // =========================
  //  DELETE
  //  DELETE /api/production/mixer/:noProduksi
  // =========================
  Future<void> deleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/mixer/$noProduksi');

    print('🗑️ [DELETE] $url');

    late http.Response res;
    try {
      res = await http
          .delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout menghapus mixer produksi');
    } catch (e) {
      print('❌ Request error (mixer delete): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      print('❌ Error body: $bodyText');

      String msg;
      try {
        final decoded = json.decode(bodyText);

        if (decoded is Map<String, dynamic>) {
          msg = (decoded['message'] ??
              decoded['error'] ??
              decoded['msg'] ??
              'Gagal menghapus mixer produksi')
              .toString();
        } else {
          msg = decoded.toString();
        }
      } catch (_) {
        msg = bodyText.isNotEmpty
            ? bodyText
            : 'Gagal menghapus mixer produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }
  }

  // =========================
  //  COMPLETE PRODUKSI
  //  PATCH /api/production/mixer/:noProduksi/complete
  // =========================
  Future<void> completeProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/mixer/$noProduksi/complete');

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout menyelesaikan produksi mixer');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      String msg;
      try {
        final decoded = json.decode(bodyText);
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal menyelesaikan produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal menyelesaikan produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }
  }

  // =========================
  //  BATALKAN COMPLETE PRODUKSI
  //  PATCH /api/production/mixer/:noProduksi/uncomplete
  //  IsComplete 1 -> 0 supaya produksi bisa diedit lagi.
  // =========================
  Future<void> uncompleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/mixer/$noProduksi/uncomplete');

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membatalkan complete produksi mixer');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      String msg;
      try {
        final decoded = json.decode(bodyText);
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal membatalkan complete produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal membatalkan complete produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }
  }
}