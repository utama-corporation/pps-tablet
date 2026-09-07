// lib/features/shared/washing_production/washing_production_repository.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../model/washing_inputs_model.dart';
import '../model/washing_production_model.dart';
import 'package:pps_tablet/core/utils/date_formatter.dart';

// result dari fetchWashingMesin
typedef WashingMesinResult = ({
  List<WashingMesinInfo> mesinList,
  WashingActiveShift? activeShift,
});

class WashingProductionRepository {
  static const _timeout = Duration(seconds: 25);

  // Simple in-memory cache for inputs
  final Map<String, WashingInputs> _inputsCache = {};

  /// Helper: base URL tanpa trailing slash
  String get _base =>
      ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');

  Map<String, String> _headers(String? token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  // ==========================================
  //  MESIN STATUS (untuk mesin screen baru)
  //  GET /api/mst-mesin/washing
  // ==========================================
  Future<WashingMesinResult> fetchWashingMesin() async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/mst-mesin/washing');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin washing');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data mesin washing (${res.statusCode})');
    }

    final body =
        json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    final List dataList = (body['data'] ?? []) as List;
    final mesinList = dataList
        .map((e) => WashingMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    WashingActiveShift? activeShift;
    final shiftRaw = body['activeShift'] as Map<String, dynamic>?;
    if (shiftRaw != null) {
      activeShift = WashingActiveShift.fromJson(shiftRaw);
    }

    return (mesinList: mesinList, activeShift: activeShift);
  }

  // =========================
  //  BY MESIN + TANGGAL + SHIFT (RIWAYAT)
  // =========================
  Future<List<WashingProduction>> fetchByMesinTanggalShift({
    required int idMesin,
    required DateTime tanggal,
    required int shift,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/washing').replace(
      queryParameters: {
        'idMesin': '$idMesin',
        'tanggal': toDbDateString(tanggal),
        'shift': '$shift',
      },
    );

    print('➡️ [GET] (riwayat washing) $url');
    final started = DateTime.now();
    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data produksi washing shift');
    } catch (e) {
      print('❌ Request error (riwayat washing): $e');
      rethrow;
    }
    print(
      '⬅️ [${res.statusCode}] (riwayat washing) in ${DateTime.now().difference(started).inMilliseconds}ms',
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Gagal mengambil data produksi washing shift (${res.statusCode})',
      );
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;
    return list
        .map((e) => WashingProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================
  //  BY DATE (tetap ada)
  // =========================
  Future<List<WashingProduction>> fetchByDate(DateTime date) async {
    final token = await TokenStorage.getToken();
    final dateDb = toDbDateString(date);
    final url = Uri.parse('$_base/api/production/washing/$dateDb');

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data washing produksi (byDate)');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data washing produksi (${res.statusCode})');
    }

    // Pastikan decoding UTF-8 aman
    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;
    final List list = (body['data'] ?? []) as List;

    return list
        .map((e) => WashingProduction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==========================================
  //  PAGINATED LIST (untuk infinite pagination)
  //  return: { items, page, totalPages, total }
  // ==========================================
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    int? shift,
    DateTime? date,
    int? idMesin,
    DateTime? tanggal,
  }) async {
    final token = await TokenStorage.getToken();

    final qp = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (search != null && search.isNotEmpty) 'search': search,
      if (shift != null) 'shift': '$shift',
      if (date != null) 'date': toDbDateString(date),
      if (idMesin != null) 'idMesin': '$idMesin',
      if (tanggal != null) 'tanggal': toDbDateString(tanggal),
    };

    final url = Uri.parse('$_base/api/production/washing')
        .replace(queryParameters: qp);

    final started = DateTime.now();
    print('➡️ [GET] $url');

    late http.Response res;
    try {
      res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil list washing produksi');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms');

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil list washing produksi (${res.statusCode})');
    }

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded) as Map<String, dynamic>;

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => WashingProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    // Meta (fallback aman jika server tidak kirim sebagian field)
    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    print('✅ Parsed ${items.length} items (page $currentPage/$totalPages, total: $totalData)');

    return {
      'items': items, // List<WashingProduction>
      'page': currentPage, // int
      'totalPages': totalPages, // int
      'total': totalData, // int
    };
  }

  Future<WashingProduction> fetchOne(String noProduksi) async {
    final result = await fetchAll(page: 1, pageSize: 1, search: noProduksi.trim());
    final items = result['items'] as List<WashingProduction>;
    if (items.isEmpty) throw Exception('Data tidak ditemukan untuk $noProduksi');
    return items.first;
  }

  /// Helper kalau hanya butuh list halaman tertentu
  Future<List<WashingProduction>> fetchAllList({
    required int page,
    int pageSize = 20,
    String? search,
    int? shift,
    DateTime? date,
    int? idMesin,
    DateTime? tanggal,
  }) async {
    final r = await fetchAll(
      page: page,
      pageSize: pageSize,
      search: search,
      shift: shift,
      date: date,
      idMesin: idMesin,
      tanggal: tanggal,
    );
    return (r['items'] as List<WashingProduction>);
  }

// ==========================================
//  CREATE (POST /washing)
// ==========================================
  Future<WashingProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    int? outputJenisId,
    /// Bisa int (jam) atau string "HH:mm-HH:mm"
    required dynamic jamKerja,
    required int shift,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
    bool isBlower = false,

    // ⬇️ baru: ikutkan jam mulai & selesai
    String? hourStart,   // format kirim: 'HH:mm:00' atau 'HH:mm'
    String? hourEnd,     // format kirim: 'HH:mm:00' atau 'HH:mm'
    int? idRegu,
  }) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/washing');

    final payload = <String, dynamic>{
      'tglProduksi': toDbDateString(tglProduksi), // 'YYYY-MM-DD'
      'idMesin': idMesin,
      'idOperators': idOperators,
      if (outputJenisId != null) 'outputJenisId': outputJenisId,
      'jamKerja': jamKerja,
      'shift': shift,
      'isBlower': isBlower ? 1 : 0,
      if (checkBy1 != null) 'checkBy1': checkBy1,
      if (checkBy2 != null) 'checkBy2': checkBy2,
      if (approveBy != null) 'approveBy': approveBy,
      if (jmlhAnggota != null) 'jmlhAnggota': jmlhAnggota,
      if (hadir != null) 'hadir': hadir,
      if (hourMeter != null) 'hourMeter': hourMeter,
      if (hourStart != null) 'hourStart': hourStart,
      if (hourEnd != null) 'hourEnd': hourEnd,
      if (idRegu != null) 'idRegu': idRegu,
    };

    final started = DateTime.now();
    print('➡️ [POST] $url');
    print('   payload: $payload');

    late http.Response res;
    try {
      res = await http
          .post(
        url,
        headers: {
          ..._headers(token),
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      )
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuat washing produksi');
    } catch (e) {
      print('❌ Request error (create washing): $e');
      rethrow;
    }

    print(
      '⬅️ [${res.statusCode}] in ${DateTime.now().difference(started).inMilliseconds}ms',
    );

    final decoded = utf8.decode(res.bodyBytes);
    final body = json.decode(decoded);

    if (res.statusCode != 201) {
      // coba ambil pesan error dari body
      if (body is Map && body['message'] != null) {
        throw Exception(body['message'].toString());
      }
      throw Exception('Gagal membuat washing produksi (${res.statusCode})');
    }

    if (body is! Map || body['data'] == null) {
      throw Exception('Response create washing tidak valid');
    }

    final data = body['data'] as Map<String, dynamic>;
    return WashingProduction.fromJson(data);
  }



  Future<WashingProduction> updateProduksi({
    required String noProduksi,     // ← dari URL
    DateTime? tglProduksi,
    int? idMesin,
    int? idOperator,
    dynamic jamKerja,               // int atau 'HH:mm-HH:mm'
    int? shift,
    bool? isBlower,
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
    final url = Uri.parse('$_base/api/production/washing/$noProduksi');

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
    if (jamKerja != null) {
      body['jamKerja'] = jamKerja.toString();
    }
    if (shift != null) {
      body['shift'] = shift.toString();
    }
    if (isBlower != null) {
      body['isBlower'] = isBlower ? '1' : '0';
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
    if (idRegu != null) {
      body['idRegu'] = idRegu.toString();
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

    return WashingProduction.fromJson(data);
  }



  Future<void> deleteProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/washing/$noProduksi');

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
          msg = (decoded['message'] ??
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
  //  PATCH /api/production/washing/:noProduksi/complete
  // =========================
  Future<void> completeProduksi(String noProduksi) async {
    final token = await TokenStorage.getToken();
    final url = Uri.parse('$_base/api/production/washing/$noProduksi/complete');

    late http.Response res;
    try {
      res = await http
          .patch(url, headers: _headers(token))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout menyelesaikan produksi washing');
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
    final url = Uri.parse(
      '$_base/api/production/washing/$noProduksi/uncomplete',
    );

    late http.Response res;
    try {
      res = await http
          .patch(url, headers: _headers(token))
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout membuka kunci produksi washing');
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

  // =========================
  //  ADD PRODUKSI (SPLIT TIME)
  // =========================
  Future<WashingProduction> addProduksi({
    required int idMesin,
    required DateTime tanggal,
    required String hourStart,
    required int outputJenisId,
  }) async {
    final token = await TokenStorage.getToken();
    final tanggalStr = toDbDateString(tanggal);
    final url = Uri.parse(
      '$_base/api/production/washing/split-time/$idMesin/$tanggalStr',
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
    print('📦 addProduksi washing body: $body');

    late http.Response res;
    try {
      res = await http.post(url, headers: headers, body: body).timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout tambah produksi washing');
    } catch (e) {
      print('❌ Request error: $e');
      rethrow;
    }

    print('⬅️ [${res.statusCode}] ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      String msg = 'Gagal tambah produksi washing (${res.statusCode})';
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
    return WashingProduction.fromJson(header);
  }


}
