// lib/features/shared/gilingan_production/packing_production_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';

import '../model/gilingan_production_model.dart';

class GilinganProductionRepository {
  static const _timeout = Duration(seconds: 25);

  String get _base => ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');

  Map<String, String> _headers(String? token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  // =========================
  //  GILINGAN MESIN LIST
  //  GET /api/mst-mesin/gilingan
  // =========================
  Future<List<GilinganMesinInfo>> fetchGilinganMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/gilingan',
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin gilingan');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin gilingan (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => GilinganMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get GilinganProduksi_h by date
  /// Backend: GET /api/production/gilingan/:date (YYYY-MM-DD)
  Future<List<GilinganProduction>> fetchByDate(DateTime date) async {
    final token = await TokenStorage.getToken();
    final dateDb = toDbDateString(date); // yyyy-MM-dd
    final url = Uri.parse('$_base/api/production/gilingan/$dateDb');

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data gilingan produksi (byDate)');
    } catch (e) {
      print('❌ Request error (gilingan byDate): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in '
        '${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data gilingan produksi (${res.statusCode})',
      );
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => GilinganProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST (mirror Broker)
  //  GET /api/production/gilingan/produksi
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,

    String? search,
    String? noProduksi,
    bool exactNoProduksi = false, // backend sekarang LIKE NoProduksi saja

    int? shift,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? idMesin,
    int? idOperator,
  }) async {
    final token = await TokenStorage.getToken();

    // Prefer explicit noProduksi over generic search
    final String? effectiveSearch =
    (noProduksi != null && noProduksi.trim().isNotEmpty)
        ? noProduksi.trim()
        : (search != null && search.trim().isNotEmpty
        ? search.trim()
        : null);

    // Map dates: if range not provided but single `date` is set, use it for both from/to
    final String? df = dateFrom != null
        ? toDbDateString(dateFrom)
        : (date != null ? toDbDateString(date) : null);

    final String? dt = dateTo != null
        ? toDbDateString(dateTo)
        : (date != null ? toDbDateString(date) : null);

    final qp = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (effectiveSearch != null) 'search': effectiveSearch,
      if (shift != null) 'shift': '$shift',
      if (df != null) 'dateFrom': df,
      if (dt != null) 'dateTo': dt,
      if (idMesin != null) 'idMesin': '$idMesin',
      if (idOperator != null) 'idOperator': '$idOperator',
    };

    final url =
    Uri.parse('$_base/api/production/gilingan').replace(
      queryParameters: qp,
    );

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil list gilingan produksi');
    } catch (e) {
      print('❌ Request error (gilingan list): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in '
        '${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil list gilingan produksi (${res.statusCode})');
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => GilinganProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print(
        '✅ Gilingan parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items,           // List<GilinganProduction>
      'page': currentPage,      // int
      'totalPages': totalPages, // int
      'total': totalData,       // int
    };
  }

  Future<GilinganProduction> fetchOne(String noProduksi) async {
    final result = await fetchAll(
      page: 1,
      pageSize: 1,
      noProduksi: noProduksi.trim(),
    );
    final items = result['items'] as List<GilinganProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noProduksi');
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<GilinganProduction>> fetchAllList({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
    bool exactNoProduksi = false,
    int? shift,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? idMesin,
    int? idOperator,
  }) async {
    final r = await fetchAll(
      page: page,
      pageSize: pageSize,
      search: search,
      noProduksi: noProduksi,
      exactNoProduksi: exactNoProduksi,
      shift: shift,
      date: date,
      dateFrom: dateFrom,
      dateTo: dateTo,
      idMesin: idMesin,
      idOperator: idOperator,
    );
    return (r['items'] as List<GilinganProduction>);
  }

  // =========================
  //  CREATE (POST)
  //  POST /api/production/gilingan/produksi
  //  TANPA kolom jam
  // =========================
  Future<GilinganProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int shift,
    required double jam,
    int? outputJenisId,
    int? idRegu,
    String? hourStart,
    String? hourEnd,
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/gilingan');

    String normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      return t.length == 5 ? '$t:00' : t;
    }

    final bodyMap = <String, dynamic>{
      'tanggal': toDbDateString(tglProduksi),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'shift': shift,
      'jam': jam,
      if (outputJenisId != null) 'outputJenisId': outputJenisId,
      if (idRegu != null) 'idRegu': idRegu,
      if (hourStart != null && hourStart.isNotEmpty)
        'hourStart': normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty)
        'hourEnd': normalizeTime(hourEnd),
      if (jmlhAnggota != null) 'jmlhAnggota': jmlhAnggota,
      if (hadir != null) 'hadir': hadir,
      if (hourMeter != null) 'hourMeter': hourMeter,
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    print('➡️ [POST] $url');
    print('📦 body (gilingan create): $bodyMap');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: json.encode(bodyMap))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat gilingan produksi');
    } catch (e) {
      print('❌ Request error (gilingan create): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 201 && res.statusCode != 200) {
      String msg;
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal membuat gilingan produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal membuat gilingan produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header gilingan');
    }

    return GilinganProduction.fromJson(data);
  }

  // =========================
  //  UPDATE (PUT)
  //  PUT /api/production/gilingan/produksi/:noProduksi
  //  TANPA jam, partial update (kirim hanya yang diubah)
  // =========================
  Future<GilinganProduction> updateProduksi({
    required String noProduksi,
    DateTime? tglProduksi,
    int? idMesin,
    int? idOperator,
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
    final url =
    Uri.parse('$_base/api/production/gilingan/$noProduksi');

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
    print('📦 form body (gilingan update): $body');

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
      throw Exception('Timeout mengubah gilingan produksi');
    } catch (e) {
      print('❌ Request error (gilingan update): $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      String msg;
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal mengubah gilingan produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal mengubah gilingan produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header gilingan');
    }

    return GilinganProduction.fromJson(data);
  }

  // =========================
  //  DELETE
  //  DELETE /api/production/gilingan/produksi/:noProduksi
  // =========================
  Future<void> deleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url =
    Uri.parse('$_base/api/production/gilingan/$noProduksi');

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
      throw Exception('Timeout menghapus gilingan produksi');
    } catch (e) {
      print('❌ Request error (gilingan delete): $e');
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
              'Gagal menghapus gilingan produksi')
              .toString();
        } else {
          msg = decoded.toString();
        }
      } catch (_) {
        msg = bodyText.isNotEmpty
            ? bodyText
            : 'Gagal menghapus gilingan produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }
  }

  // =========================
  //  COMPLETE PRODUKSI
  //  PATCH /api/production/gilingan/:noProduksi/complete
  // =========================
  Future<void> completeProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/gilingan/$noProduksi/complete');

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout menyelesaikan produksi gilingan');
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

  /// Buka kunci produksi (IsComplete -> 0) supaya bisa diubah lagi.
  Future<void> uncompleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(
      '$_base/api/production/gilingan/$noProduksi/uncomplete',
    );

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuka kunci produksi gilingan');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      String msg;
      try {
        final decoded = json.decode(bodyText);
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal membuka kunci produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal membuka kunci produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }
  }

  // =========================
  //  RIWAYAT PER MESIN/TANGGAL/SHIFT
  //  GET /api/production/gilingan?idMesin=&tanggal=&shift=
  // =========================
  Future<List<GilinganProduction>> fetchByMesinTanggalShift({
    required int idMesin,
    required DateTime tanggal,
    required int shift,
  }) async {
    final token = await TokenStorage.getToken();
    final dateStr =
        '${tanggal.year.toString().padLeft(4, '0')}-'
        '${tanggal.month.toString().padLeft(2, '0')}-'
        '${tanggal.day.toString().padLeft(2, '0')}';
    final url = Uri.parse(
      '$_base/api/production/gilingan?idMesin=$idMesin&tanggal=$dateStr&shift=$shift',
    );

    print('➡️ [GET] $url');
    http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil riwayat gilingan');
    }
    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil riwayat gilingan (HTTP ${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = (body['data'] as List? ?? []);
    return list
        .map((e) => GilinganProduction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
