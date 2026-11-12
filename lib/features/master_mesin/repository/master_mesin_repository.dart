import '../../../core/network/api_client.dart';
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';

/// CRUD Master Mesin Produksi.
///
/// List per bagian: `GET /api/mst-mesin/{idBagianMesin}?includeDisabled=1`.
/// Konvensi tulis mengikuti konvensi REST master lain:
/// `POST/PUT /api/mst-mesin`, `DELETE /api/mst-mesin?idMesin=`.
class MasterMesinRepository {
  const MasterMesinRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-mesin';

  /// Ambil mesin untuk satu bagian. Error per bagian dilempar ke pemanggil.
  Future<List<MstMesin>> fetchByBagian(
    int idBagianMesin, {
    bool includeDisabled = true,
  }) async {
    final body = await api.getJson(
      '$path/$idBagianMesin',
      query: includeDisabled ? {'includeDisabled': '1'} : null,
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) MstMesin.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Ambil semua mesin dari seluruh bagian yang diketahui.
  ///
  /// Bagian yang gagal diabaikan (server per bagian bisa error sendirinya);
  /// kalau semuanya gagal, exception dilempar.
  Future<List<MstMesin>> fetchAll({bool includeDisabled = true}) async {
    final results = await Future.wait([
      for (final bagian in masterBagianMesin)
        fetchByBagian(bagian.id, includeDisabled: includeDisabled)
            .then<List<MstMesin>?>((rows) => rows)
            .catchError((_) => null),
    ]);
    if (results.every((r) => r == null)) {
      throw Exception('Gagal mengambil data mesin dari semua bagian');
    }
    final byId = <int, MstMesin>{};
    for (final rows in results) {
      if (rows == null) continue;
      for (final mesin in rows) {
        byId[mesin.idMesin] = mesin;
      }
    }
    final items = byId.values.toList()
      ..sort((a, b) => a.namaMesin.toLowerCase().compareTo(b.namaMesin.toLowerCase()));
    return items;
  }

  Future<Map<String, dynamic>> create({
    required String namaMesin,
    required int idBagianMesin,
    num? kapasitas,
    int? idUom,
    required bool enable,
  }) => api.postJson(
    path,
    body: {
      'NamaMesin': namaMesin,
      'Bagian': bagianMesinLabel(idBagianMesin),
      'IdBagianMesin': idBagianMesin,
      'Kapasitas': kapasitas,
      'IdUOM': idUom,
      'Enable': enable ? 1 : 0,
    },
  );

  Future<Map<String, dynamic>> update({
    required int idMesin,
    required String namaMesin,
    required int idBagianMesin,
    num? kapasitas,
    int? idUom,
    required bool enable,
  }) => api.putJson(
    path,
    body: {
      'IdMesin': idMesin,
      'NamaMesin': namaMesin,
      'Bagian': bagianMesinLabel(idBagianMesin),
      'IdBagianMesin': idBagianMesin,
      'Kapasitas': kapasitas,
      'IdUOM': idUom,
      'Enable': enable ? 1 : 0,
    },
  );

  Future<void> delete(int idMesin) async {
    await api.deleteJson(path, query: {'idMesin': idMesin});
  }
}
