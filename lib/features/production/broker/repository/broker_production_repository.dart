import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../model/broker_inputs_model.dart';
import '../model/broker_production_model.dart';
import 'package:pps_tablet/core/utils/date_formatter.dart';

class BrokerProductionRepository {
  static const _timeout = Duration(seconds: 25);

  // Simple in-memory cache for inputs
  final Map<String, BrokerInputs> _inputsCache = {};

  String get _base => ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');

  Map<String, String> _headers(String? token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  // =========================
  //  BROKER MESIN LIST
  // =========================
  Future<List<BrokerMesinInfo>> fetchBrokerMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/broker',
    );

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin broker');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin broker (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => BrokerMesinInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  // =========================
  //  BY MESIN + TANGGAL + SHIFT
  // =========================
  Future<List<BrokerProduction>> fetchByMesinTanggalShift({
    required int idMesin,
    required DateTime tanggal,
    required int shift,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker').replace(
      queryParameters: {
        'idMesin': '$idMesin',
        'tanggal': toDbDateString(tanggal),
        'shift': '$shift',
      },
    );

    print('➡️ [GET] (riwayat broker) $url');
    final started = DateTime.now();
    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data produksi shift');
    } catch (e) {
      print('❌ Request error (riwayat broker): $e');
      rethrow;
    }
    print(
      '⬅️ [${res.statusCode}] (riwayat broker) in ${DateTime.now().difference(started).inMilliseconds}ms',
    );

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data produksi shift (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;
    return list
        .map((e) => BrokerProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  //  BY MESIN + TANGGAL
  // =========================
  Future<List<BrokerProduction>> fetchByMesinAndDate({
    required int idMesin,
    required DateTime tanggal,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker').replace(
      queryParameters: {
        'idMesin': '$idMesin',
        'tanggal': toDbDateString(tanggal),
      },
    );

    print('➡️ [GET] $url');
    final started = DateTime.now();
    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data broker produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }
    print(
      '⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms',
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data broker produksi (${res.statusCode})',
      );
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;
    return list
        .map((e) => BrokerProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  //  BY DATE (tetap ada)
  // =========================
  Future<List<BrokerProduction>> fetchByDate(DateTime date) async {
    final token = await TokenStorage.getToken();
    final dateDb = toDbDateString(date);
    final url = Uri.parse('$_base/api/production/broker/$dateDb');

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data broker produksi (byDate)');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print(
      '⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms',
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data broker produksi (${res.statusCode})',
      );
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => BrokerProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST (infinite scroll style)
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,

    // Text search for NoProduksi (contains)
    String? search,

    // VM convenience: prefer this if provided; if exactNoProduksi == true we still send as contains
    String? noProduksi,
    bool exactNoProduksi = false, // backend currently does LIKE only
    // Other optional filters (supported by backend)
    int? shift,
    DateTime? date, // legacy single date -> maps to dateFrom/dateTo
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
      if (effectiveSearch != null)
        'search': effectiveSearch, // API searches NoProduksi only
      if (shift != null) 'shift': '$shift',
      if (df != null) 'dateFrom': df,
      if (dt != null) 'dateTo': dt,
      if (idMesin != null) 'idMesin': '$idMesin',
      if (idOperator != null) 'idOperator': '$idOperator',
    };

    final url = Uri.parse(
      '$_base/api/production/broker',
    ).replace(queryParameters: qp);

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil list broker produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print(
      '⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms',
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil list broker produksi (${res.statusCode})',
      );
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => BrokerProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print(
      '✅ Broker parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)',
    );

    return {
      'items': items, // List<BrokerProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  Future<BrokerProduction> fetchOne(String noProduksiValue) async {
    final result = await fetchAll(page: 1, pageSize: 1, noProduksi: noProduksiValue.trim());
    final items = result['items'] as List<BrokerProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noProduksiValue');
    return items.first;
  }

  /// Convenience jika hanya butuh list halaman tertentu
  Future<List<BrokerProduction>> fetchAllList({
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
    return (r['items'] as List<BrokerProduction>);
  }

  // Optional: parse on an isolate for large JSON
  static BrokerInputs _parseInputs(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw FormatException('Response tidak valid: field data kosong');
    }
    return BrokerInputs.fromJson(data);
  }

  // =========================
  //  CREATE (POST)
  // =========================
  Future<BrokerProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required int idOperator,
    required dynamic jam, // int atau 'HH:mm-HH:mm'
    required int shift,
    String? hourStart, // ⬅️ baru
    String? hourEnd, // ⬅️ baru
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
    int? idRegu,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker');

    final tglStr = toDbDateString(tglProduksi);

    // helper kecil biar "08:00" -> "08:00:00"
    String _normalizeTime(String v) {
      final t = v.trim();
      if (t.isEmpty) return t;
      // kalau cuma HH:mm tambahin :00
      if (t.length == 5) {
        return '$t:00';
      }
      return t;
    }

    // 🔴 PENTING: kirim sebagai MAP<String, String>
    final body = <String, String>{
      'tglProduksi': tglStr,
      'idMesin': idMesin.toString(),
      'idOperator': idOperator.toString(),
      'jam': jam.toString(),
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
      if (idRegu != null) 'idRegu': idRegu.toString(),
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    print('➡️ [POST] $url');
    print('📦 form body: $body');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: body)
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat broker produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 201 && res.statusCode != 200) {
      String msg = 'Gagal membuat broker produksi (${res.statusCode})';
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
      throw Exception('Response tidak mengandung data header');
    }

    return BrokerProduction.fromJson(data);
  }

  Future<BrokerProduction> updateProduksi({
    required String noProduksi, // ← dari URL
    DateTime? tglProduksi,
    int? idMesin,
    int? idOperator,
    dynamic jam, // int atau 'HH:mm-HH:mm'
    int? shift,
    String? hourStart,
    String? hourEnd,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
    int? idRegu,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker/$noProduksi');

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
    if (idRegu != null) {
      body['idRegu'] = idRegu.toString();
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
      res = await http.put(url, headers: headers, body: body).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengubah broker produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200) {
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        final msg = decoded['message'] ?? 'Gagal mengubah broker produksi';
        throw Exception(msg);
      } catch (_) {
        throw Exception('Gagal mengubah broker produksi (${res.statusCode})');
      }
    }

    final decoded = utf8.decode(res.bodyBytes);
    final bodyJson = json.decode(decoded) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Response tidak mengandung data header');
    }

    return BrokerProduction.fromJson(data);
  }

  // =========================
  //  ADD PRODUKSI (SPLIT) — hanya butuh hourStart + outputJenisId
  // =========================
  Future<BrokerProduction> addProduksi({
    required int idMesin,
    required DateTime tanggal,
    required String hourStart,
    required int outputJenisId,
  }) async {
    final token = await TokenStorage.getToken();
    final tanggalStr = toDbDateString(tanggal);
    final url = Uri.parse(
      '$_base/api/production/broker/split-time/$idMesin/$tanggalStr',
    );

    String normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final body = jsonEncode({
      'hourStart': normalizeTime(hourStart),
      'outputJenisId': outputJenisId,
    });

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    print('➡️ [POST] $url');
    print('📦 addProduksi body: $body');

    late http.Response res;
    try {
      res = await http.post(url, headers: headers, body: body).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout tambah produksi broker');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      String msg = 'Gagal tambah produksi (${res.statusCode})';
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          msg = (decoded['message'] ?? msg).toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }

    final bodyJson = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;
    final header = data?['header'] as Map<String, dynamic>?;
    if (header == null) throw Exception('Response tidak mengandung data header');
    return BrokerProduction.fromJson(header);
  }

  // =========================
  //  SPLIT TIME (POST)
  // =========================
  Future<BrokerProduction> splitTime({
    required int idMesin,
    required DateTime tanggal,
    required String newHourStart,
    required String newHourEnd,
  }) async {
    final token = await TokenStorage.getToken();
    final tanggalStr = toDbDateString(tanggal);
    final url = Uri.parse(
      '$_base/api/production/broker/split-time/$idMesin/$tanggalStr',
    );

    String normalizeTime(String v) {
      final t = v.trim();
      if (t.length == 5) return '$t:00';
      return t;
    }

    final body = <String, String>{
      'hourStart': normalizeTime(newHourStart),
      'hourEnd': normalizeTime(newHourEnd),
    };

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    print('➡️ [POST] $url');
    print('📦 split-time body: $body');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: body)
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout split-time broker produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      String msg = 'Gagal membuat produksi baru (${res.statusCode})';
      try {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          msg = (decoded['message'] ?? msg).toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }

    final bodyJson =
        json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final data = bodyJson['data'] as Map<String, dynamic>?;
    final header = data?['header'] as Map<String, dynamic>?;
    if (header == null) {
      throw Exception('Response split-time tidak mengandung data header');
    }
    return BrokerProduction.fromJson(header);
  }

  // =========================
  //  CREATE WITH JENIS BROKER (POST JSON)
  // =========================
  Future<BrokerProduction> createProduksiWithJenis({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int outputJenisId,
    required num jam,
    required int shift,
    String? outputJenisNama,
    String? hourStart,
    String? hourEnd,
    int? hadir,
    int? idRegu,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker');

    String normalizeTime(String v) {
      final t = v.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final bodyMap = <String, dynamic>{
      'tglProduksi': toDbDateString(tglProduksi),
      'idMesin': idMesin,
      'idOperators': idOperators,
      'outputJenisId': outputJenisId,
      'jam': jam,
      'shift': shift,
      if (hourStart != null && hourStart.isNotEmpty) 'hourStart': normalizeTime(hourStart),
      if (hourEnd != null && hourEnd.isNotEmpty) 'hourEnd': normalizeTime(hourEnd),
      if (hadir != null) 'hadir': hadir,
      if (idRegu != null) 'idRegu': idRegu,
    };

    final body = jsonEncode(bodyMap);

    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    print('➡️ [POST] $url');
    print('📦 json body: $body');

    late http.Response res;
    try {
      res = await http
          .post(url, headers: headers, body: body)
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat broker produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 201 && res.statusCode != 200) {
      String msg = 'Gagal membuat broker produksi (${res.statusCode})';
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
      throw Exception('Response tidak mengandung data header');
    }

    // Server doesn't return OutputJenisNama on create — inject from caller.
    if (outputJenisNama != null && data['OutputJenisNama'] == null) {
      data['OutputJenisNama'] = outputJenisNama;
    }

    return BrokerProduction.fromJson(data);
  }

  Future<void> deleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker/$noProduksi');

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
      throw Exception('Timeout menghapus broker produksi');
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
          msg =
              (decoded['message'] ??
                      decoded['error'] ??
                      decoded['msg'] ??
                      'Gagal menghapus broker produksi')
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
        throw Exception('Gagal menghapus broker produksi (${res.statusCode})');
      }
    }

    // kalau sebelumnya kita sudah pernah ambil inputs untuk noProduksi ini, buang dari cache
    _inputsCache.remove(noProduksi);
  }

  // =========================
  //  COMPLETE PRODUKSI
  //  PATCH /api/production/broker/:noProduksi/complete
  // =========================
  Future<void> completeProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker/$noProduksi/complete');

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout menyelesaikan produksi broker');
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
  Future<void> uncompleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/broker/$noProduksi/uncomplete');

    late http.Response res;
    try {
      res = await http.patch(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuka kunci produksi broker');
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
