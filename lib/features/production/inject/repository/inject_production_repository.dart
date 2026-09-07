import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/network/endpoints.dart';
import 'package:pps_tablet/core/services/token_storage.dart';
import 'package:pps_tablet/core/utils/date_formatter.dart';

import '../model/inject_production_model.dart';
import '../model/furniture_wip_by_inject_production_model.dart';
import '../model/packing_by_inject_production_model.dart';
import '../model/inject_batch_model.dart';
import '../model/inject_qc_model.dart';

class InjectProductionRepository {
  final ApiClient api;

  InjectProductionRepository({ApiClient? apiClient})
    : api = apiClient ?? ApiClient();

  static const _timeout = Duration(seconds: 25);

  /* =============================
   * MESIN LIST
   * GET :7500/api/mst-mesin/inject
   * ============================= */

  Future<List<InjectMesinInfo>> fetchInjectMesin() async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/mst-mesin/inject',
    );

    late http.Response res;
    try {
      res = await http
          .get(url, headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          })
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data mesin inject');
    } catch (e) {
      throw Exception('Gagal terhubung ke server: $e');
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat mesin inject (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes));
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => InjectMesinInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /* =============================
   * GET ALL (PAGED WITH MAP RESULT)
   * GET /api/production/inject
   * ============================= */

  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    int? idMesin,
  }) async {
    final body = await api.getJson(
      '/api/production/inject',
      query: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (idMesin != null) 'idMesin': idMesin.toString(),
      },
    );

    final List dataList = (body['data'] ?? []) as List;
    final items = dataList
        .map((e) => InjectProduction.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = (body['meta'] ?? {}) as Map<String, dynamic>;
    final currentPage = (meta['page'] ?? page) as int;
    final totalPages = (meta['totalPages'] ?? 1) as int;
    final totalData = (body['totalData'] ?? meta['total'] ?? 0) as int;

    return {
      'items': items,
      'page': currentPage,
      'totalPages': totalPages,
      'total': totalData,
    };
  }

  /// Fetch single production header by noProduksi (to get IsRealtime flag).
  Future<InjectProduction?> fetchOneByNoProduksi(String noProduksi) async {
    final result = await fetchAll(
      page: 1,
      pageSize: 1,
      search: noProduksi,
    );
    final items = result['items'] as List<InjectProduction>;
    return items.isNotEmpty ? items.first : null;
  }

  /* =============================
   * GET (BY DATE) - existing
   * ============================= */

  /// 🔹 Fetch InjectProduksi_h by date (YYYY-MM-DD)
  /// Backend: GET /api/production/inject/:date
  Future<List<InjectProduction>> fetchByDate(DateTime date) async {
    final dateDb = toDbDateString(date); // YYYY-MM-DD

    final Map<String, dynamic> body = await api.getJson(
      '/api/production/inject/$dateDb',
    );

    final List list = (body['data'] ?? []) as List;

    return list
        .whereType<Map>()
        .map((e) => InjectProduction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /* =============================
   * GET ALL (PAGED) - new
   * ============================= */

  static List<InjectProduction> _parsePagedList(Map<String, dynamic> body) {
    final data = body['data'];

    if (data == null) return <InjectProduction>[];
    if (data is! List) {
      throw FormatException('Response tidak valid: field data bukan List');
    }

    return data
        .whereType<Map>()
        .map((e) => InjectProduction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /api/production/inject?page=1&pageSize=20&search=S.0000
  ///
  /// Response:
  /// {
  ///   "success": true,
  ///   "totalData": 123,
  ///   "data": [ ... ],
  ///   "meta": { page, pageSize, totalPages, hasNextPage, hasPrevPage, search }
  /// }
  Future<List<InjectProduction>> fetchPaged({
    int page = 1,
    int pageSize = 20,
    String search = '',
  }) async {
    final body = await api.getJson(
      '/api/production/inject',
      query: {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    // parse in isolate (like HotStamp)
    return compute(_parsePagedList, body);
  }

  /* =============================
   * LOOKUP LISTS - existing
   * ============================= */

  /// 🔹 Fetch FurnitureWIP kandidat by NoProduksi Inject
  /// Backend: GET /api/production/inject/furniture-wip/:noProduksi
  Future<FurnitureWipByInjectResult> fetchFurnitureWipByInjectProduction(
    String noProduksi,
  ) async {
    final encodedNo = Uri.encodeComponent(noProduksi);

    try {
      final Map<String, dynamic> body = await api.getJson(
        '/api/production/inject/furniture-wip/$encodedNo',
      );

      // Normal (200 OK)
      return FurnitureWipByInjectResult.fromEnvelope(body);
    } on ApiException catch (e) {
      // ✅ 404 = "tidak ada data", jangan dianggap error
      if (e.statusCode == 404) {
        return const FurnitureWipByInjectResult(
          beratProdukHasilTimbang: null,
          items: <FurnitureWipByInjectItem>[],
        );
      }
      rethrow;
    }
  }

  /// 🔹 Fetch Packing (BarangJadi) kandidat by NoProduksi Inject
  /// Backend: GET /api/production/inject/packing/:noProduksi
  Future<PackingByInjectResult> fetchPackingByInjectProduction(
    String noProduksi,
  ) async {
    final encodedNo = Uri.encodeComponent(noProduksi);

    try {
      final Map<String, dynamic> body = await api.getJson(
        '/api/production/inject/packing/$encodedNo',
      );

      return PackingByInjectResult.fromEnvelope(body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return const PackingByInjectResult(
          beratProdukHasilTimbang: null,
          items: <PackingByInjectItem>[],
        );
      }
      rethrow;
    }
  }

  /* =============================
   * BY MESIN + TANGGAL + SHIFT
   * GET /api/production/inject?idMesin=&tanggal=&shift=
   * ============================= */

  Future<List<InjectProduction>> fetchByMesinTanggalShift({
    required int idMesin,
    required DateTime tanggal,
    required int shift,
  }) async {
    final token = await TokenStorage.getToken();
    final apiBaseUri = Uri.parse(ApiConstants.baseUrl);
    final url = Uri(
      scheme: apiBaseUri.scheme.isEmpty ? 'http' : apiBaseUri.scheme,
      host: apiBaseUri.host,
      port: 7500,
      path: '/api/production/inject',
      queryParameters: {
        'idMesin': '$idMesin',
        'tanggal': toDbDateString(tanggal),
        'shift': '$shift',
      },
    );

    late http.Response res;
    try {
      res = await http
          .get(url, headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          })
          .timeout(_timeout);
    } on TimeoutException {
      throw Exception('Timeout mengambil data produksi shift');
    } catch (e) {
      rethrow;
    }

    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil data produksi shift (${res.statusCode})');
    }

    final body = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .whereType<Map>()
        .map((e) => InjectProduction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /* =============================
   * GET SINGLE
   * GET /api/production/inject/:noProduksi
   * ============================= */

  Future<InjectProduction> fetchOne(String noProduksi) async {
    final no = noProduksi.trim();
    if (no.isEmpty) throw ArgumentError('noProduksi tidak boleh kosong');
    final body = await api.getJson(
      '/api/production/inject',
      query: {'noProduksi': no},
    );
    final data = body['data'];
    if (data is! List || data.isEmpty) {
      throw Exception('Data tidak ditemukan untuk $noProduksi');
    }
    return InjectProduction.fromJson(
      Map<String, dynamic>.from(data.first as Map),
    );
  }

  /* =============================
   * CRUD HEADER (Create / Update / Delete) - new
   * ============================= */

  /// POST /api/production/inject
  ///
  /// payload minimal (contoh):
  /// {
  ///   "tglProduksi":"2026-01-06",
  ///   "idMesin":27,
  ///   "idOperator":61,
  ///   "shift":1,
  ///   "jam":"09:00",
  ///   "hourStart":"09:00",
  ///   "hourEnd":"10:00"
  /// }
  Future<Map<String, dynamic>> createProduksi(
    Map<String, dynamic> payload,
  ) async {
    final path = '/api/production/inject';

    try {
      final body = await api.postJson(path, body: payload);
      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ?? e.message;

      if (e.statusCode == 422) {
        throw Exception(msg.isNotEmpty ? msg : 'Beberapa data tidak valid');
      }
      if (e.statusCode == 400) {
        throw Exception(msg.isNotEmpty ? msg : 'Request tidak valid');
      }

      throw Exception(msg);
    }
  }

  /// PUT /api/production/inject/:noProduksi
  Future<Map<String, dynamic>> updateProduksi(
    String noProduksi,
    Map<String, dynamic> payload,
  ) async {
    final no = noProduksi.trim();
    if (no.isEmpty) throw ArgumentError('noProduksi tidak boleh kosong');

    final path = '/api/production/inject/${Uri.encodeComponent(no)}';

    try {
      final body = await api.putJson(path, body: payload);
      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg =
          (parsed['message'] as String?) ??
          e.message ??
          'Gagal update InjectProduksi (HTTP ${e.statusCode})';

      if (e.statusCode == 422) {
        throw Exception(msg.isNotEmpty ? msg : 'Beberapa data tidak valid');
      }
      if (e.statusCode == 400) {
        throw Exception(msg.isNotEmpty ? msg : 'Request tidak valid');
      }

      throw Exception(msg);
    }
  }

  /// DELETE /api/production/inject/:noProduksi
  Future<Map<String, dynamic>> deleteProduksi(String noProduksi) async {
    final no = noProduksi.trim();
    if (no.isEmpty) throw ArgumentError('noProduksi tidak boleh kosong');

    final path = '/api/production/inject/${Uri.encodeComponent(no)}';

    try {
      final body = await api.deleteJson(path);

      // kalau backend kamu return {success,message} maka body ada isinya
      // kalau kosong pun tidak masalah
      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);

      // 404 -> tetap return untuk UI (warning)
      if (e.statusCode == 404) {
        return parsed;
      }

      final msg =
          (parsed['message'] as String?) ??
          e.message ??
          'Gagal delete InjectProduksi (HTTP ${e.statusCode})';

      if (e.statusCode == 400) {
        throw Exception(msg.isNotEmpty ? msg : 'Request delete tidak valid');
      }

      throw Exception(msg);
    }
  }

  /* =============================
   * SPLIT TIME
   * POST /api/production/inject/split-time/:idMesin/:tgl
   * ============================= */

  Future<Map<String, dynamic>> splitTime({
    required int idMesin,
    required DateTime tglProduksi,
    required String hourStart,
    required int idCetakan,
    required int idWarna,
    int? idFurnitureMaterial,
    Map<String, dynamic>? batch,
  }) async {
    final tgl =
        '${tglProduksi.year.toString().padLeft(4, '0')}-${tglProduksi.month.toString().padLeft(2, '0')}-${tglProduksi.day.toString().padLeft(2, '0')}';
    final path = '/api/production/inject/split-time/$idMesin/$tgl';
    final body = <String, dynamic>{
      'hourStart': hourStart,
      'idCetakan': idCetakan,
      'idWarna': idWarna,
      if (idFurnitureMaterial != null)
        'idFurnitureMaterial': idFurnitureMaterial,
      if (batch != null) 'batch': batch,
    };
    try {
      return await api.postJson(path, body: body);
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          'Gagal split time (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * BATCH - PCS PER LABEL
   * GET /api/production/inject/pcs-per-label/:noProduksi
   * ============================= */

  Future<InjectPcsPerLabelResult> fetchPcsPerLabel(String noProduksi) async {
    final encoded = Uri.encodeComponent(noProduksi.trim());
    final body = await api.getJson(
      '/api/production/inject/pcs-per-label/$encoded',
    );
    return InjectPcsPerLabelResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? {},
    );
  }

  /* =============================
   * BATCH - DISCARD PENDING PCS-PER-LABEL (target awal defisit)
   * POST /api/production/inject/:noProduksi/pcs-per-label/discard
   * ============================= */

  Future<void> discardPcsPerLabelPending({
    required String noProduksi,
    required int idJenis,
  }) async {
    final encoded = Uri.encodeComponent(noProduksi.trim());
    try {
      await api.postJson(
        '/api/production/inject/$encoded/pcs-per-label/discard',
        body: {'idJenis': idJenis},
      );
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg =
          (parsed['message'] as String?) ??
          'Gagal reset target pcs-per-label (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * TERMINATE
   * POST /api/production/inject/:noProduksi/terminate
   * ============================= */

  Future<void> terminate({
    required String noProduksi,
    required String hourStart,
    required String hourEnd,
    double? berat,
    double? cycleTime,
    int? counter,
    required List<Map<String, dynamic>> items,
    int? idBonggolan,
    double? beratBonggolan,
    int? idReject,
    double? beratReject,
  }) async {
    final encoded = Uri.encodeComponent(noProduksi.trim());
    final body = <String, dynamic>{
      'hourStart': hourStart,
      'hourEnd': hourEnd,
      if (berat != null) 'berat': berat,
      if (cycleTime != null) 'cycleTime': cycleTime,
      if (counter != null) 'counter': counter,
      'items': items,
      if (idBonggolan != null && beratBonggolan != null)
        'bonggolan': {'idBonggolan': idBonggolan, 'berat': beratBonggolan},
      if (idReject != null && beratReject != null)
        'reject': {'idReject': idReject, 'berat': beratReject},
    };
    try {
      await api.postJson('/api/production/inject/$encoded/terminate', body: body);
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          'Gagal terminate produksi (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * COMPLETE (request approval)
   * PATCH /api/production/inject/:noProduksi/complete
   * Sekarang mengirim request approval — response { status: "pending_approval" }
   * jika berhasil, atau langsung IsComplete = 1 jika auto-approve.
   * ============================= */

  Future<Map<String, dynamic>> completeProduksi(String noProduksi) async {
    final encoded = Uri.encodeComponent(noProduksi.trim());
    try {
      final body = await api.patchJson(
        '/api/production/inject/$encoded/complete',
      );
      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          'Gagal mengirim permintaan penyelesaian (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * UNCOMPLETE (buka kunci)
   * PATCH /api/production/inject/:noProduksi/uncomplete
   * IsComplete 1 -> 0 supaya produksi bisa diubah lagi.
   * ============================= */

  Future<Map<String, dynamic>> uncompleteProduksi(String noProduksi) async {
    final encoded = Uri.encodeComponent(noProduksi.trim());
    try {
      final body = await api.patchJson(
        '/api/production/inject/$encoded/uncomplete',
      );
      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          'Gagal membuka kunci produksi (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * BATCH - LIST
   * GET /api/production/inject/batch/:noProduksi
   * ============================= */

  Future<List<InjectBatchItem>> fetchBatch(String noProduksi) async {
    final encoded = Uri.encodeComponent(noProduksi.trim());
    try {
      final body = await api.getJson(
        '/api/production/inject/batch/$encoded',
      );
      final data = (body['data'] as List<dynamic>?) ?? [];
      return data
          .whereType<Map>()
          .map((e) => InjectBatchItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  /* =============================
   * BATCH - SUBMIT
   * POST /api/production/inject/batch
   * ============================= */

  Future<InjectBatchSubmitResult> submitBatch(
    Map<String, dynamic> payload,
  ) async {
    try {
      final body = await api.postJson(
        '/api/production/inject/batch',
        body: payload,
      );
      return InjectBatchSubmitResult.fromJson(
        body['data'] as Map<String, dynamic>? ?? {},
      );
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg =
          (parsed['message'] as String?) ??
          'Gagal submit batch (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * QC
   * POST :7500/api/production/inject/qc
   * GET  :7500/api/production/inject/qc/:noProduksi
   * ============================= */

  Future<InjectQcItem> submitQc(Map<String, dynamic> payload) async {
    try {
      final body = await api.postJson(
        '/api/production/inject/qc',
        body: payload,
      );
      return InjectQcItem.fromJson(
        body['data'] as Map<String, dynamic>? ?? {},
      );
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg =
          (parsed['message'] as String?) ??
          'Gagal submit QC (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  Future<InjectQcDetail> fetchQcDetail(String noProduksi) async {
    try {
      final body = await api.getJson(
        '/api/production/inject/qc/$noProduksi',
      );
      final data = body['data'] as Map<String, dynamic>? ?? {};
      return InjectQcDetail.fromJson(data);
    } on ApiException catch (e) {
      throw Exception('Gagal memuat QC (HTTP ${e.statusCode})');
    }
  }

  /// GET :7500/api/production/inject/qc/counter/:idMesin
  ///
  /// Mengambil nilai odometer/counter mesin saat ini. Dipakai sebagai
  /// nilai default sekaligus batas minimum wajib pada field counter QC.
  Future<int?> fetchQcCounter(int idMesin) async {
    try {
      final body = await api.getJson(
        '/api/production/inject/qc/counter/$idMesin',
      );
      final data = body['data'] as Map<String, dynamic>?;
      final raw = data?['counterCurrent'];
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// POST :7500/api/production/inject/qc/counter/:idMesin/reset
  ///
  /// Reset counter/odometer mesin ke 0. Mengembalikan nilai counter terbaru
  /// setelah reset (fallback 0 jika server tidak mengirimkan nilainya).
  Future<int> resetQcCounter(int idMesin) async {
    try {
      final body = await api.postJson(
        '/api/production/inject/qc/counter/$idMesin/reset',
        body: const <String, dynamic>{},
      );
      final data = body['data'] as Map<String, dynamic>?;
      final raw = data?['counterCurrent'];
      if (raw == null) return 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString()) ?? 0;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          'Gagal reset counter mesin (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  Future<InjectQcItem> updateQc(int id, Map<String, dynamic> payload) async {
    try {
      final body = await api.putJson(
        '/api/production/inject/qc/$id',
        body: payload,
      );
      return InjectQcItem.fromJson(body['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      final msg = (e.responseBody?.isNotEmpty == true) ? e.responseBody! : 'Gagal update QC (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * Helpers
   * ============================= */

  Map<String, dynamic> _tryDecodeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'data': decoded};
    } catch (_) {
      return <String, dynamic>{'message': raw};
    }
  }
}
