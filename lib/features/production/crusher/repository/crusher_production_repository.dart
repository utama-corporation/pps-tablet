import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import 'package:pps_tablet/core/utils/date_formatter.dart';

import '../model/crusher_production_model.dart';

class CrusherProductionRepository {
  static const _timeout = Duration(seconds: 25);

  // Simple in-memory cache for inputs (if needed later)
  // final Map<String, CrusherInputs> _inputsCache = {};

  String get _base => ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');

  Map<String, String> _headers(String? token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  // =========================
  //  CRUSHER MESIN LIST
  //  GET /api/mst-mesin/crusher
  // =========================
  Future<List<CrusherMesinInfo>> fetchCrusherMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/crusher',
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin crusher');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin crusher (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => CrusherMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  //  BY DATE (untuk dropdown/filter)
  // =========================
  /// Optional: filter by idMesin and/or shift (server supports it)
  Future<List<CrusherProduction>> fetchByDate(
      DateTime date, {
        int? idMesin,
        String? shift,
      }) async {
    final token = await TokenStorage.getToken();
    final dateDb = toDbDateString(date); // YYYY-MM-DD

    // If you mounted under '/api/production/crusher/:date' (recommended):
    var url = Uri.parse('$_base/api/production/crusher/$dateDb');

    // If instead you mounted '/api/crusher/:date', use:
    // var url = Uri.parse('$_base/api/crusher/$dateDb');

    final qp = <String, String>{};
    if (idMesin != null) qp['idMesin'] = '$idMesin';
    if (shift != null && shift.isNotEmpty) qp['shift'] = shift;
    if (qp.isNotEmpty) {
      url = url.replace(queryParameters: qp);
    }

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data crusher produksi (byDate)');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data crusher produksi (${res.statusCode})');
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => CrusherProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST (infinite scroll style)
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,

    // Text search for NoCrusherProduksi (contains)
    String? search,

    // VM convenience: prefer this if provided
    String? noCrusherProduksi,
    bool exactNoCrusherProduksi = false, // backend currently does LIKE only

    // Other optional filters (supported by backend)
    int? shift,
    DateTime? date,               // legacy single date -> maps to dateFrom/dateTo
    DateTime? dateFrom,
    DateTime? dateTo,
    int? idMesin,
    int? idOperator,
  }) async {
    final token = await TokenStorage.getToken();

    // Prefer explicit noCrusherProduksi over generic search
    final String? effectiveSearch = (noCrusherProduksi != null && noCrusherProduksi.trim().isNotEmpty)
        ? noCrusherProduksi.trim()
        : (search != null && search.trim().isNotEmpty ? search.trim() : null);

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
      if (effectiveSearch != null) 'search': effectiveSearch, // API searches NoCrusherProduksi
      if (shift != null) 'shift': '$shift',
      if (df != null) 'dateFrom': df,
      if (dt != null) 'dateTo': dt,
      if (idMesin != null) 'idMesin': '$idMesin',
      if (idOperator != null) 'idOperator': '$idOperator',
    };

    final url = Uri.parse('$_base/api/production/crusher').replace(queryParameters: qp);

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil list crusher produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil list crusher produksi (${res.statusCode})');
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => CrusherProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print('✅ Crusher parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items,           // List<CrusherProduction>
      'page': currentPage,      // int
      'totalPages': totalPages, // int
      'total': totalData,       // int
    };
  }

  Future<CrusherProduction> fetchOne(String noCrusherProduksi) async {
    final result = await fetchAll(
      page: 1,
      pageSize: 1,
      noCrusherProduksi: noCrusherProduksi.trim(),
    );
    final items = result['items'] as List<CrusherProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noCrusherProduksi');
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<CrusherProduction>> fetchAllList({
    required int page,
    int pageSize = 20,
    String? search,
    String? noCrusherProduksi,
    bool exactNoCrusherProduksi = false,
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
      noCrusherProduksi: noCrusherProduksi,
      exactNoCrusherProduksi: exactNoCrusherProduksi,
      shift: shift,
      date: date,
      dateFrom: dateFrom,
      dateTo: dateTo,
      idMesin: idMesin,
      idOperator: idOperator,
    );
    return (r['items'] as List<CrusherProduction>);
  }

// =========================
//  CREATE (POST)
// =========================

  Future<CrusherProduction> createProduksi({
    required DateTime tanggal,
    required int idMesin,
    required List<int> idOperators,
    required int shift,
    required double jam,
    int? outputJenisId,
    int? idRegu,
    String? hourStart,
    String? hourEnd,
    int? hadir,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/crusher');

    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      return t.length == 5 ? '$t:00' : t;
    }

    final bodyMap = <String, dynamic>{
      'tanggal': toDbDateString(tanggal),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'shift': shift,
      'jam': jam,
      if (outputJenisId != null) 'outputJenisId': outputJenisId,
      if (idRegu != null) 'idRegu': idRegu,
      if (hourStart != null && hourStart.isNotEmpty)
        'hourStart': _normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty)
        'hourEnd': _normalizeTime(hourEnd),
      if (hadir != null) 'hadir': hadir,
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    print('➡️ [POST] $url');
    print('📦 body: $bodyMap');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: json.encode(bodyMap))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat crusher produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 201 && res.statusCode != 200) {
      String msg;
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal membuat crusher produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal membuat crusher produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header');
    }

    return CrusherProduction.fromJson(data);
  }

// =========================
//  UPDATE (PUT)
// =========================
  Future<CrusherProduction> updateProduksi({
    required String noCrusherProduksi,     // ← dari URL
    DateTime? tanggal,
    int? idMesin,
    int? idOperator,
    int? jamKerja,
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
    final url = Uri.parse('$_base/api/production/crusher/$noCrusherProduksi');

    // helper sama kayak yang di create
    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      if (t.length == 5) {
        return '$t:00'; // HH:mm -> HH:mm:00
      }
      return t;
    }

    // karena ini UPDATE, semua boleh null → kita kirim hanya yang diisi
    final body = <String, String>{};

    if (tanggal != null) {
      body['tanggal'] = toDbDateString(tanggal);
    }
    if (idMesin != null) {
      body['idMesin'] = idMesin.toString();
    }
    if (idOperator != null) {
      body['idOperator'] = idOperator.toString();
    }
    if (jamKerja != null) {
      body['jamKerja'] = jamKerja.toString();
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
    print('📦 form body: $body');

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
      throw Exception('Timeout mengubah crusher produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      String msg;
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        msg = (decoded is Map ? decoded['message'] : null)?.toString() ??
            'Gagal mengubah crusher produksi (${res.statusCode})';
      } catch (_) {
        msg = 'Gagal mengubah crusher produksi (${res.statusCode})';
      }
      throw Exception(msg);
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header');
    }

    return CrusherProduction.fromJson(data);
  }


// =========================
//  FETCH BY MESIN/TANGGAL/SHIFT (timeline)
// =========================
  /// GET /api/production/crusher?idMesin=&tanggal=&shift=
  Future<List<CrusherProduction>> fetchByMesinTanggalShift({
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
      '$_base/api/production/crusher?idMesin=$idMesin&tanggal=$dateStr&shift=$shift',
    );

    print('➡️ [GET] $url');
    http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil riwayat crusher');
    }
    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil riwayat crusher (HTTP ${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final list = (body['data'] as List? ?? []);
    return list
        .map((e) => CrusherProduction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

// =========================
//  DELETE
// =========================
  Future<void> deleteProduksi(String noCrusherProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/crusher/$noCrusherProduksi');

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
      throw Exception('Timeout menghapus crusher produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      print('❌ Error body: $bodyText');

      try {
        final decoded = json.decode(bodyText);

        String msg;

        if (decoded is Map<String, dynamic>) {
          // coba beberapa kemungkinan key
          msg = (decoded['message'] ??
              decoded['error'] ??
              decoded['msg'] ??
              'Gagal menghapus crusher produksi')
              .toString();
        } else {
          // kalau backend kirim string langsung / array, pakai saja isinya
          msg = decoded.toString();
        }

        throw Exception(msg);
      } catch (e) {
        // kalau JSON.parse gagal total, pakai body apa adanya
        if (bodyText.isNotEmpty) {
          throw Exception(bodyText);
        }
        throw Exception('Gagal menghapus crusher produksi (${res.statusCode})');
      }
    }

    // kalau sebelumnya kita sudah pernah ambil inputs untuk noCrusherProduksi ini,
    // buang dari cache
    // _inputsCache.remove(noCrusherProduksi);
  }

  // =========================
  //  COMPLETE PRODUKSI
  //  PATCH /api/production/crusher/:noCrusherProduksi/complete
  // =========================
  Future<void> completeProduksi(String noCrusherProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(
      '$_base/api/production/crusher/$noCrusherProduksi/complete',
    );

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout menyelesaikan produksi crusher');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      try {
        final decoded = json.decode(bodyText);
        final msg = (decoded is Map ? decoded['message'] : null) ??
            'Gagal menyelesaikan produksi (${res.statusCode})';
        throw Exception(msg);
      } catch (_) {
        throw Exception('Gagal menyelesaikan produksi (${res.statusCode})');
      }
    }
  }

  /// Buka kunci produksi (IsComplete -> 0) supaya bisa diubah lagi.
  Future<void> uncompleteProduksi(String noCrusherProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse(
      '$_base/api/production/crusher/$noCrusherProduksi/uncomplete',
    );

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuka kunci produksi crusher');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      final bodyText = utf8.decode(res.bodyBytes);
      try {
        final decoded = json.decode(bodyText);
        final msg = (decoded is Map ? decoded['message'] : null) ??
            'Gagal membuka kunci produksi (${res.statusCode})';
        throw Exception(msg);
      } catch (_) {
        throw Exception('Gagal membuka kunci produksi (${res.statusCode})');
      }
    }
  }
}