import '../../../core/network/api_client.dart';
import '../model/master_barang_models.dart';

/// Master Barang — satu modul backend untuk 11 jenis master.
///
///   GET    /api/mst-barang/meta            — types + summary + options
///   GET    /api/mst-barang/:type?search=   — list (semua baris, tanpa paging)
///   POST   /api/mst-barang/:type
///   PUT    /api/mst-barang/:type/:id
///   DELETE /api/mst-barang/:type/:id       — hapus = nonaktifkan (Enable = 0)
class MasterBarangRepository {
  const MasterBarangRepository({required this.api});

  final ApiClient api;

  static const metaPath = '/api/mst-barang/meta';
  static const path = '/api/mst-barang';

  Future<MasterBarangMeta> fetchMeta() async {
    final body = await api.getJson(metaPath);
    return MasterBarangMeta.fromJson(body);
  }

  Future<List<MasterBarangItem>> fetchList(String type, {String? search}) async {
    final body = await api.getJson(
      '$path/${Uri.encodeComponent(type)}',
      query: search != null && search.trim().isNotEmpty
          ? {'search': search.trim()}
          : null,
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) MasterBarangItem(Map<String, dynamic>.from(row)),
    ];
  }

  Future<Map<String, dynamic>> create(
    String type,
    Map<String, dynamic> body,
  ) => api.postJson('$path/${Uri.encodeComponent(type)}', body: body);

  Future<Map<String, dynamic>> update(
    String type,
    int id,
    Map<String, dynamic> body,
  ) => api.putJson('$path/${Uri.encodeComponent(type)}/$id', body: body);

  Future<void> disable(String type, int id) async {
    await api.deleteJson('$path/${Uri.encodeComponent(type)}/$id');
  }
}
