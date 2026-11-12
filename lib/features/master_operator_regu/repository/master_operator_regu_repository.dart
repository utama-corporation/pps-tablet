import '../../../core/network/api_client.dart';
import '../../operator/model/operator_model.dart';
import '../../regu/model/regu_model.dart';

/// CRUD Master Operator & Regu.
///
/// Konvensi REST:
/// - Operators: `GET /api/mst-operator?all=1` (daftar + IdBagian/NamaBagianMesin),
///   `GET /api/mst-operator/bagian`, `POST /api/mst-operator`,
///   `PUT /api/mst-operator/:id`, `DELETE /api/mst-operator/:id`,
/// - Regu: `GET/POST/PUT/DELETE /api/mst/regu`
///   (delete lewat query `?idRegu=`).
class MasterOperatorReguRepository {
  const MasterOperatorReguRepository({required this.api});

  final ApiClient api;

  static const operatorPath = '/api/mst-operator';
  static const reguPath = '/api/mst/regu';

  // ── Operator ──────────────────────────────────────────────

  Future<List<MstOperator>> fetchOperators({bool includeDisabled = true}) async {
    final body = await api.getJson(
      operatorPath,
      query: const {'all': '1'},
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) MstOperator.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Dropdown bagian (GET /api/mst-operator/bagian).
  Future<List<OperatorBagian>> fetchBagianOptions() async {
    final body = await api.getJson('$operatorPath/bagian');
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          OperatorBagian.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, dynamic>> createOperator({
    required String namaOperator,
    required int idBagian,
    required bool enable,
  }) => api.postJson(
    operatorPath,
    body: {
      'namaOperator': namaOperator.trim(),
      'idBagian': idBagian,
      'enable': enable ? 1 : 0,
    },
  );

  Future<Map<String, dynamic>> updateOperator({
    required int idOperator,
    required String namaOperator,
    required int idBagian,
    required bool enable,
  }) => api.putJson(
    '$operatorPath/$idOperator',
    body: {
      'namaOperator': namaOperator.trim(),
      'idBagian': idBagian,
      'enable': enable ? 1 : 0,
    },
  );

  Future<void> deleteOperator(int idOperator) async {
    await api.deleteJson('$operatorPath/$idOperator');
  }

  // ── Regu ──────────────────────────────────────────────────

  Future<List<MstRegu>> fetchRegu() async {
    final body = await api.getJson(reguPath);
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) MstRegu.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Detail regu + daftar operator anggotanya (GET /api/mst/regu/:id).
  Future<ReguDetail?> fetchReguDetail(int idRegu) async {
    final body = await api.getJson('$reguPath/$idRegu');
    final data = body['data'];
    if (data is! Map) return null;
    return ReguDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> createRegu({
    required String namaRegu,
    required int idBagian,
    required List<int> operatorIds,
  }) => api.postJson(
    reguPath,
    body: {
      'namaRegu': namaRegu.trim(),
      'idBagian': idBagian,
      'operatorIds': operatorIds,
    },
  );

  Future<Map<String, dynamic>> updateRegu({
    required int idRegu,
    required String namaRegu,
    required int idBagian,
    required List<int> operatorIds,
  }) => api.putJson(
    '$reguPath/$idRegu',
    body: {
      'namaRegu': namaRegu.trim(),
      'idBagian': idBagian,
      'operatorIds': operatorIds,
    },
  );

  Future<void> deleteRegu(int idRegu) async {
    await api.deleteJson('$reguPath/$idRegu');
  }
}
