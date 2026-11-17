import '../../../core/network/api_client.dart';
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';
import '../model/uom_option.dart';

/// CRUD Master Mesin Produksi via `/api/mst-mesin-produksi`.
///
/// List per jenis: `GET /api/mst-mesin-produksi/{type}?search=` — semua baris
/// termasuk nonaktif dikembalikan. Tulis juga per jenis:
/// `POST /api/mst-mesin-produksi/{type}`,
/// `PUT /api/mst-mesin-produksi/{type}/{id}`,
/// `DELETE /api/mst-mesin-produksi/{type}/{id}` (soft delete, Enable = 0).
/// Jenis inject menulis tabel `MstMesinInject`.
class MasterMesinRepository {
  const MasterMesinRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-mesin-produksi';

  /// Ambil mesin untuk satu bagian. Error per bagian dilempar ke pemanggil.
  Future<List<MstMesin>> fetchByBagian(int idBagianMesin) async {
    final slug = bagianMesinSlug(idBagianMesin);
    if (slug == null) {
      throw ArgumentError('Bagian tidak dikenali: $idBagianMesin');
    }
    final body = await api.getJson('$path/$slug');
    final data = body['data'];
    if (data is! List) return const [];
    final label = bagianMesinLabel(idBagianMesin);
    return [
      for (final row in data)
        if (row is Map)
          _fromRow(
            Map<String, dynamic>.from(row),
            idBagianMesin: idBagianMesin,
            bagianLabel: label,
          ),
    ]..sort((a, b) => a.namaMesin.toLowerCase().compareTo(b.namaMesin.toLowerCase()));
  }

  /// Opsi UOM dari `GET /api/mst-mesin-produksi/meta` (permission
  /// `datamastermesin:read`). Error dilempar ke pemanggil.
  Future<List<UomOption>> fetchUomOptions() async {
    final body = await api.getJson('$path/meta');
    final data = body['data'];
    final uom = data is Map ? data['uom'] : null;
    if (uom is! List) return const [];
    final options = <UomOption>[];
    for (final row in uom) {
      if (row is! Map) continue;
      final id = _toNum(row['idUOM'])?.toInt();
      final nama = (row['namaUOM'] ?? '').toString().trim();
      if (id == null || id <= 0 || nama.isEmpty) continue;
      options.add(UomOption(idUom: id, namaUom: nama));
    }
    return options;
  }

  String _pathFor(int idBagianMesin, [int? idMesin]) {
    final slug = bagianMesinSlug(idBagianMesin);
    if (slug == null) {
      throw ArgumentError('Bagian tidak dikenali: $idBagianMesin');
    }
    final base = '$path/$slug';
    return idMesin == null ? base : '$base/$idMesin';
  }

  static num? _toNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim().replaceAll(',', '.'));
    return null;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  static MstMesin _fromRow(
    Map<String, dynamic> row, {
    required int idBagianMesin,
    required String bagianLabel,
  }) {
    final id = _toNum(row['idMesin'])?.toInt() ?? 0;
    final namaUom = (row['namaUOM'] ?? '').toString().trim();
    return MstMesin(
      idMesin: id,
      namaMesin: (row['namaMesin'] ?? '').toString(),
      bagian: bagianLabel,
      enable: _toBool(row['enable']),
      kapasitas: _toNum(row['kapasitas']),
      idUom: _toNum(row['idUOM'])?.toInt(),
      shotWeightPs: _toNum(row['shortWeightPS']),
      klemLebar: _toNum(row['klemLebar']),
      klemPanjang: _toNum(row['klemTinggi']),
      idBagianMesin: idBagianMesin,
      namaUom: namaUom.isEmpty ? null : namaUom,
    );
  }

  Future<Map<String, dynamic>> create({
    required String namaMesin,
    required int idBagianMesin,
    num? kapasitas,
    int? idUom,
    required bool enable,
    num? shortWeightPs,
    num? klemLebar,
    num? klemTinggi,
  }) => api.postJson(
    _pathFor(idBagianMesin),
    body: {
      'namaMesin': namaMesin,
      'kapasitas': kapasitas,
      'idUOM': idUom,
      'enable': enable,
      // Kolom khusus inject — kirim nilai supaya tersimpan (0 bila kosong).
      if (idBagianMesin == 4) ...{
        'shortWeightPS': shortWeightPs ?? 0,
        'klemLebar': klemLebar ?? 0,
        'klemTinggi': klemTinggi ?? 0,
      },
    },
  );

  Future<Map<String, dynamic>> update({
    required int idMesin,
    required String namaMesin,
    required int idBagianMesin,
    num? kapasitas,
    int? idUom,
    required bool enable,
    num? shortWeightPs,
    num? klemLebar,
    num? klemTinggi,
  }) => api.putJson(
    _pathFor(idBagianMesin, idMesin),
    body: {
      'namaMesin': namaMesin,
      'kapasitas': kapasitas,
      'idUOM': idUom,
      'enable': enable,
      // Kolom khusus inject — kirim nilai lama supaya tidak di-nolkan server.
      if (idBagianMesin == 4) ...{
        'shortWeightPS': shortWeightPs ?? 0,
        'klemLebar': klemLebar ?? 0,
        'klemTinggi': klemTinggi ?? 0,
      },
    },
  );

  /// Nonaktifkan (Enable = 0). Bukan hard delete — mesin masih dirujuk
  /// transaksi produksi lama.
  Future<void> delete(int idMesin, {required int idBagianMesin}) async {
    await api.deleteJson(_pathFor(idBagianMesin, idMesin));
  }
}
