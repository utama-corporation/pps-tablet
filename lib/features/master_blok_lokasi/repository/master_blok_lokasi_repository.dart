import '../../../core/network/api_client.dart';
import '../model/master_blok_lokasi_models.dart';

/// Master Blok & Lokasi — backend `/api/mst-blok-lokasi`:
///   GET    /master                          warehouses + kategoris
///   GET    /blok                            daftar blok (left panel)
///   POST   /blok                            {blok, idWarehouse}
///   PUT    /blok/:blok                      {idWarehouse}
///   DELETE /blok/:blok                      hapus blok + lokasi + jenis (cascade)
///   GET    /lokasi?blok=
///   GET    /lokasi/next-id?blok=
///   POST   /lokasi                          {blok, description, enable}
///   PUT    /lokasi/:blok/:idLokasi          {description, enable}
///   DELETE /lokasi/:blok/:idLokasi          hapus lokasi + jenis (cascade)
///   GET    /jenis?idKategori=               opsi jenis dinamis per kategori
///   GET    /lokasi-jenis?blok=&idLokasi=
///   POST   /lokasi-jenis                    {blok, idLokasi, idKategori, idJenis}
///   DELETE /lokasi-jenis/:blok/:idLokasi/:idKategori/:idJenis
class MasterBlokLokasiRepository {
  const MasterBlokLokasiRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-blok-lokasi';

  Future<BlokMaster> fetchMaster() async {
    final body = await api.getJson('$path/master');
    final data = body['data'];
    if (data is! Map) return const BlokMaster.empty();
    return BlokMaster.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<BlokRow>> fetchBloks() async {
    final body = await api.getJson('$path/blok');
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) BlokRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<BlokRow?> createBlok({
    required String blok,
    required int idWarehouse,
  }) =>
      _blokWrite(api.postJson(
        '$path/blok',
        body: {'blok': blok, 'idWarehouse': idWarehouse},
      ));

  Future<BlokRow?> updateBlok({
    required String blok,
    required int idWarehouse,
  }) =>
      _blokWrite(api.putJson(
        '$path/blok/$blok',
        body: {'idWarehouse': idWarehouse},
      ));

  Future<BlokRow?> _blokWrite(Future<Map<String, dynamic>> future) async {
    final body = await future;
    final data = body['data'];
    if (data is! Map) return null;
    return BlokRow.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteBlok(String blok) async {
    await api.deleteJson('$path/blok/$blok');
  }

  Future<List<LokasiRow>> fetchLokasi(String blok) async {
    final body = await api.getJson('$path/lokasi', query: {'blok': blok});
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) LokasiRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<int> fetchNextIdLokasi(String blok) async {
    final body = await api.getJson('$path/lokasi/next-id', query: {'blok': blok});
    final data = body['data'];
    final nextId = data is Map ? data['nextId'] : null;
    if (nextId is num) return nextId.toInt();
    return int.tryParse('$nextId') ?? 0;
  }

  Future<LokasiRow?> createLokasi({
    required String blok,
    required String description,
    required bool enable,
  }) =>
      _lokasiWrite(api.postJson(
        '$path/lokasi',
        body: {'blok': blok, 'description': description, 'enable': enable},
      ));

  Future<LokasiRow?> updateLokasi({
    required String blok,
    required int idLokasi,
    required String description,
    required bool enable,
  }) =>
      _lokasiWrite(api.putJson(
        '$path/lokasi/$blok/$idLokasi',
        body: {'description': description, 'enable': enable},
      ));

  Future<LokasiRow?> _lokasiWrite(Future<Map<String, dynamic>> future) async {
    final body = await future;
    final data = body['data'];
    if (data is! Map) return null;
    return LokasiRow.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteLokasi({
    required String blok,
    required int idLokasi,
  }) async {
    await api.deleteJson('$path/lokasi/$blok/$idLokasi');
  }

  Future<List<JenisOption>> fetchJenis(int idKategori) async {
    final body = await api.getJson(
      '$path/jenis',
      query: {'idKategori': '$idKategori'},
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) JenisOption.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<List<LokasiJenisRow>> fetchLokasiJenis({
    required String blok,
    required int idLokasi,
  }) async {
    final body = await api.getJson(
      '$path/lokasi-jenis',
      query: {'blok': blok, 'idLokasi': '$idLokasi'},
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          LokasiJenisRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> addLokasiJenis({
    required String blok,
    required int idLokasi,
    required int idKategori,
    required int idJenis,
  }) async {
    await api.postJson(
      '$path/lokasi-jenis',
      body: {
        'blok': blok,
        'idLokasi': idLokasi,
        'idKategori': idKategori,
        'idJenis': idJenis,
      },
    );
  }

  Future<void> removeLokasiJenis({
    required String blok,
    required int idLokasi,
    required int idKategori,
    required int idJenis,
  }) async {
    await api.deleteJson(
      '$path/lokasi-jenis/$blok/$idLokasi/$idKategori/$idJenis',
    );
  }
}
