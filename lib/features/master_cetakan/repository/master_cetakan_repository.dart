import '../../../core/network/api_client.dart';
import '../model/master_cetakan_models.dart';

/// Master Cetakan — backend `/api/mst-cetakan` (port dari FrmCetakan.vb):
///   GET    /api/mst-cetakan/warna-material?top=&q=   daftar pemetaan
///   GET    /api/mst-cetakan/warna-material/options   opsi dropdown
///   GET    /api/mst-cetakan/warna-material/detail?idCetakan=&idWarna=&idMaterial=
///   POST   /api/mst-cetakan/warna-material           tambah pemetaan
///   PUT    /api/mst-cetakan/warna-material           ubah pemetaan (oldKey)
///   DELETE /api/mst-cetakan/warna-material?idCetakan=&idWarna=&idMaterial=
///   POST   /api/mst-cetakan/new-cetakan              {namaCetakan}
///   POST   /api/mst-cetakan/new-warna                {warna}
///
/// Aturan dari backend: isi Barang Jadi (maks 1) ATAU Furniture WIP
/// (maks 4), tidak boleh keduanya; keduanya kosong ditolak. Kombinasi
/// cetakan+warna+material yang sama ditolak dengan 409.
class MasterCetakanRepository {
  const MasterCetakanRepository({required this.api});

  final ApiClient api;

  static const path = '/api/mst-cetakan';

  Future<List<CetakanWarnaMaterialRow>> fetchAll({
    String? q,
    int top = 500,
  }) async {
    final body = await api.getJson(
      '$path/warna-material',
      query: {
        'top': '$top',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map)
          CetakanWarnaMaterialRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<MasterCetakanOptions> fetchOptions() async {
    final body = await api.getJson('$path/warna-material/options');
    final data = body['data'];
    if (data is! Map) return const MasterCetakanOptions.empty();
    return MasterCetakanOptions.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CetakanDetail> fetchDetail({
    required int idCetakan,
    required int idWarna,
    required int idMaterial,
  }) async {
    final body = await api.getJson(
      '$path/warna-material/detail',
      query: {
        'idCetakan': '$idCetakan',
        'idWarna': '$idWarna',
        'idMaterial': '$idMaterial',
      },
    );
    final data = body['data'];
    if (data is! Map) return const CetakanDetail.empty();
    return CetakanDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> create({
    required int idCetakan,
    required int idWarna,
    required int idMaterial,
    required List<int> barangJadi,
    required List<int> furnitureWip,
  }) async {
    await api.postJson(
      '$path/warna-material',
      body: {
        'idCetakan': idCetakan,
        'idWarna': idWarna,
        'idMaterial': idMaterial,
        'barangJadi': barangJadi,
        'furnitureWip': furnitureWip,
      },
    );
  }

  Future<void> update({
    required CetakanWarnaMaterialRow oldKey,
    required int idCetakan,
    required int idWarna,
    required int idMaterial,
    required List<int> barangJadi,
    required List<int> furnitureWip,
  }) async {
    await api.putJson(
      '$path/warna-material',
      body: {
        'oldKey': {
          'idCetakan': oldKey.idCetakan,
          'idWarna': oldKey.idWarna,
          'idMaterial': oldKey.idMaterial,
        },
        'idCetakan': idCetakan,
        'idWarna': idWarna,
        'idMaterial': idMaterial,
        'barangJadi': barangJadi,
        'furnitureWip': furnitureWip,
      },
    );
  }

  Future<void> delete({
    required int idCetakan,
    required int idWarna,
    required int idMaterial,
  }) async {
    await api.deleteJson(
      '$path/warna-material',
      query: {
        'idCetakan': '$idCetakan',
        'idWarna': '$idWarna',
        'idMaterial': '$idMaterial',
      },
    );
  }

  Future<LookupOption> createCetakan(String namaCetakan) async {
    final body = await api.postJson(
      '$path/new-cetakan',
      body: {'namaCetakan': namaCetakan.trim()},
    );
    final data = body['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    return LookupOption(
      (map['idCetakan'] as num?)?.toInt() ?? int.tryParse('${map['idCetakan']}') ?? 0,
      (map['namaCetakan'] ?? namaCetakan.trim()).toString(),
    );
  }

  Future<LookupOption> createWarna(String warna) async {
    final body = await api.postJson(
      '$path/new-warna',
      body: {'warna': warna.trim()},
    );
    final data = body['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    return LookupOption(
      (map['idWarna'] as num?)?.toInt() ?? int.tryParse('${map['idWarna']}') ?? 0,
      (map['warna'] ?? warna.trim()).toString(),
    );
  }
}
