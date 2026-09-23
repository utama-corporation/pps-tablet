// lib/features/production/hot_stamping/repository/hot_stamping_production_input_repository.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../shared/models/production_label_lookup_result.dart';
import '../../shared/models/cabinet_material_item.dart';
import '../model/hot_stamp_output_model.dart';
import '../model/hot_stamping_inputs_model.dart';

class HotStampingProductionInputRepository {
  final ApiClient api;

  HotStampingProductionInputRepository({ApiClient? apiClient})
      : api = apiClient ?? ApiClient();

  final Map<String, HotStampingInputs> _inputsCache = {};

  // cache master cabinet material per warehouse
  final Map<int, List<CabinetMaterialItem>> _cabinetMasterCache = {};

  /* =============================
   * GET INPUTS
   * ============================= */

  static HotStampingInputs _parseInputs(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw FormatException('Response tidak valid: field data kosong');
    }
    return HotStampingInputs.fromJson(data);
  }

  Future<HotStampingInputs> fetchInputs(
      String noProduksi, {
        bool force = false,
      }) async {
    if (!force && _inputsCache.containsKey(noProduksi)) {
      return _inputsCache[noProduksi]!;
    }

    final path = '/api/production/hot-stamp/$noProduksi/inputs';

    final body = await api.getJson(path);
    final inputs = await compute(_parseInputs, body);

    _inputsCache[noProduksi] = inputs;
    return inputs;
  }

  void invalidateInputs(String noProduksi) => _inputsCache.remove(noProduksi);
  void clearCache() => _inputsCache.clear();

  /* =============================
   * GET MASTER CABINET MATERIALS (MASTER + STOCK)
   * ============================= */

  static List<CabinetMaterialItem> _parseCabinetMaterials(Map<String, dynamic> body) {
    final data = body['data'];

    if (data == null) return <CabinetMaterialItem>[];
    if (data is! List) {
      throw FormatException('Response tidak valid: field data bukan List');
    }

    return data
        .whereType<Map>()
        .map((e) => CabinetMaterialItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /api/production/hot-stamp/cabinet-materials?idWarehouse=5
  Future<List<CabinetMaterialItem>> fetchMasterCabinetMaterials({
    required int idWarehouse,
    bool force = false,
  }) async {
    if (!force && _cabinetMasterCache.containsKey(idWarehouse)) {
      return _cabinetMasterCache[idWarehouse]!;
    }

    final path = '/api/mst-furniture-material/cabinet-materials';

    final body = await api.getJson(path, query: {
      'idWarehouse': idWarehouse.toString(),
    });

    final items = await compute(_parseCabinetMaterials, body);

    _cabinetMasterCache[idWarehouse] = items;
    return items;
  }

  void invalidateCabinetMaster(int idWarehouse) =>
      _cabinetMasterCache.remove(idWarehouse);

  void clearCabinetMasterCache() => _cabinetMasterCache.clear();

  /* =============================
   * VALIDATE / LOOKUP FURNITURE WIP LABEL (optional - keep if still used)
   * ============================= */

  /// GET /api/production/lookup-label/:labelCode
  Future<ProductionLabelLookupResult> lookupFwipLabel(String labelCode) async {
    final code = labelCode.trim();
    if (code.isEmpty) throw ArgumentError('labelCode tidak boleh kosong');

    final path =
        '/api/production/lookup-label/${Uri.encodeComponent(code)}';

    try {
      final body = await api.getJson(path);
      return ProductionLabelLookupResult.success(body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        final parsed = _tryDecodeMap(e.responseBody);
        return ProductionLabelLookupResult.notFound(parsed);
      }

      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          e.message ??
          'Gagal lookup FWIP label (HTTP ${e.statusCode})';
      throw Exception(msg);
    }
  }

  /* =============================
   * POST SUBMIT INPUTS & PARTIALS
   * ============================= */

  /// POST /api/production/hot-stamp/:noProduksi/inputs
  Future<Map<String, dynamic>> submitInputsAndPartials(
      String noProduksi,
      Map<String, dynamic> payload,
      ) async {
    final path = '/api/production/hot-stamp/$noProduksi/inputs';

    try {
      final body = await api.postJson(path, body: payload);

      // setelah submit sukses, invalidate cache inputs agar fetch ulang ambil data terbaru
      invalidateInputs(noProduksi);

      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);
      final msg = (parsed['message'] as String?) ??
          e.message ??
          'Gagal submit inputs (HTTP ${e.statusCode})';

      if (e.statusCode == 422) {
        throw Exception(msg.isNotEmpty ? msg : 'Beberapa data tidak valid');
      }
      if (e.statusCode == 400) {
        throw Exception(msg.isNotEmpty ? msg : 'Request tidak valid');
      }

      throw Exception(msg);
    }
  }

  /* =============================
   * DELETE INPUTS & PARTIALS
   * ============================= */

  /// DELETE /api/production/hot-stamp/:noProduksi/inputs
  Future<Map<String, dynamic>> deleteInputsAndPartials(
      String noProduksi,
      Map<String, dynamic> payload,
      ) async {
    final path = '/api/production/hot-stamp/$noProduksi/inputs';

    try {
      final body = await api.deleteJson(path, body: payload);

      // setelah delete sukses, invalidate cache inputs
      invalidateInputs(noProduksi);

      return body;
    } on ApiException catch (e) {
      final parsed = _tryDecodeMap(e.responseBody);

      // 404 -> tetap return untuk UI (show warning)
      if (e.statusCode == 404) {
        return parsed;
      }

      final msg = (parsed['message'] as String?) ??
          e.message ??
          'Gagal delete inputs (HTTP ${e.statusCode})';

      if (e.statusCode == 400) {
        throw Exception(msg.isNotEmpty ? msg : 'Request delete inputs tidak valid');
      }

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
      return {'data': decoded};
    } catch (_) {
      return <String, dynamic>{'message': raw};
    }
  }

  // ===========================================================================
  // SPLIT TIME (GANTI PRODUKSI)
  // POST /api/production/hot-stamp/split-time/{idMesin}/{tanggal}
  // Body: { "hourStart": "13:35", "outputJenisId": 12 }
  // ===========================================================================
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
    final path = '/api/production/hot-stamp/split-time/$idMesin/$dateStr';
    return api.postJson(path, body: {
      'hourStart': hourStart,
      'outputJenisId': outputJenisId,
    });
  }

  // ===========================================================================
  // OUTPUTS — furniture WIP labels that have been produced
  // GET /api/production/hot-stamp/:noProduksi/outputs/furniture-wip
  // GET /api/production/hot-stamp/:noProduksi/outputs/reject
  // ===========================================================================
  Future<List<HotStampOutput>> fetchOutputs(String noProduksi) async {
    Future<List<HotStampOutput>> loadCategory(
      String path,
      String category,
    ) async {
      try {
        final body = await api.getJson(path);
        final list = (body['data'] as List<dynamic>? ?? []);
        return list
            .map(
              (e) => HotStampOutput.fromJson(
                e as Map<String, dynamic>,
                category: category,
              ),
            )
            .toList();
      } on ApiException catch (e) {
        if (category == 'reject' && e.statusCode == 404) {
          return <HotStampOutput>[];
        }
        rethrow;
      }
    }

    final results = await Future.wait([
      loadCategory(
        '/api/production/hot-stamp/$noProduksi/outputs/furniture-wip',
        'fwip',
      ),
      loadCategory(
        '/api/production/hot-stamp/$noProduksi/outputs/reject',
        'reject',
      ),
    ]);

    return [...results[0], ...results[1]];
  }
}
