import '../../../core/network/api_client.dart';
import '../model/retur_v3_header.dart';
import '../model/retur_v3_item.dart';
import '../model/retur_v3_output.dart';
import '../model/retur_v3_turnover.dart';

/// Wrapper `ApiClient` untuk seluruh endpoint `/api/retur-v3` sesuai
/// kontrak di AGENTS.md. Backend (`src/modules/retur-v3/`) dikerjakan
/// paralel oleh agent lain sehingga bentuk response persisnya belum bisa
/// diverifikasi saat file ini ditulis — semua parsing model di
/// `lib/features/retur_v3/model/` sudah dibuat toleran terhadap variasi
/// key (PascalCase/camelCase) untuk mengurangi risiko mismatch.
class ReturV3Repository {
  final ApiClient _api;

  ReturV3Repository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  static const _base = '/api/retur-v3';

  // ── Header list & CRUD ────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final qp = <String, dynamic>{
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (dateFrom != null)
        'dateFrom': dateFrom.toIso8601String().split('T').first,
      if (dateTo != null) 'dateTo': dateTo.toIso8601String().split('T').first,
    };
    final body = await _api.getJson(_base, query: qp);
    final dataList = (body['data'] ?? []) as List;
    final items = dataList
        .whereType<Map>()
        .map((e) => ReturV3Header.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Backend mengirim total/page/pageSize di level root response
    // (`{success, message, data, total, page, pageSize}`), bukan di
    // dalam `meta` — sebelumnya dibaca dari `body['meta']` yang tidak
    // pernah ada, jadi `total` selalu fallback ke `items.length` dan
    // paging berhenti setelah halaman pertama begitu data > pageSize.
    final total = body['total'] is num
        ? (body['total'] as num).toInt()
        : int.tryParse('${body['total']}') ?? items.length;
    final ps = body['pageSize'] is num
        ? (body['pageSize'] as num).toInt()
        : pageSize;
    final totalPages = ps > 0 ? ((total + ps - 1) ~/ ps) : 1;

    return {
      'items': items,
      'page': page,
      'totalPages': totalPages,
      'total': total,
    };
  }

  Future<Map<String, dynamic>> fetchDetail(String noRetur) async {
    final body = await _api.getJson('$_base/${Uri.encodeComponent(noRetur)}');
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Response tidak mengandung data retur');
    }

    final header = ReturV3Header.fromJson(data);
    final itemsRaw = (data['items'] ?? []) as List? ?? const [];
    final items = itemsRaw
        .whereType<Map>()
        .map((e) => ReturV3Item.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final turnoverRaw = (data['turnover'] ?? data['Turnover']) as List?;
    final turnover = (turnoverRaw ?? const [])
        .whereType<Map>()
        .map((e) => ReturV3Turnover.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final outputsRaw = (data['outputs'] ?? data['Outputs']) as List?;
    final outputs = (outputsRaw ?? const [])
        .whereType<Map>()
        .map((e) => ReturV3Output.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return {
      'header': header,
      'items': items,
      'turnover': turnover,
      'outputs': outputs,
    };
  }

  Future<ReturV3Header> create({
    required DateTime tanggal,
    required int idPembeli,
    String? keterangan,
  }) async {
    final body = await _api.postJson(
      _base,
      body: {
        'tanggal': tanggal.toIso8601String(),
        'idPembeli': idPembeli,
        if (keterangan != null && keterangan.trim().isNotEmpty)
          'keterangan': keterangan.trim(),
      },
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return ReturV3Header.fromJson(data);
  }

  Future<ReturV3Header> update(
    String noRetur, {
    DateTime? tanggal,
    int? idPembeli,
    String? keterangan,
  }) async {
    final body = await _api.putJson(
      '$_base/${Uri.encodeComponent(noRetur)}',
      body: {
        if (tanggal != null) 'tanggal': tanggal.toIso8601String(),
        if (idPembeli != null) 'idPembeli': idPembeli,
        if (keterangan != null) 'keterangan': keterangan.trim(),
      },
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return ReturV3Header.fromJson(data);
  }

  Future<void> delete(String noRetur) async {
    await _api.deleteJson('$_base/${Uri.encodeComponent(noRetur)}');
  }

  // ── Items ────────────────────────────────────────────────────────────

  Future<List<ReturV3Item>> addItems(
    String noRetur,
    List<Map<String, dynamic>> items,
  ) async {
    final body = await _api.postJson(
      '$_base/${Uri.encodeComponent(noRetur)}/items',
      body: {'items': items},
    );
    final data = body['data'] as Map<String, dynamic>?;
    final rawItems = (data?['items'] ?? []) as List? ?? const [];
    return rawItems
        .whereType<Map>()
        .map((e) => ReturV3Item.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ReturV3Item> updateItem(
    String noRetur,
    int idItem, {
    String? kodeKategori,
    int? idJenis,
    int? pcs,
    String? kategoriInput,
  }) async {
    final body = await _api.putJson(
      '$_base/${Uri.encodeComponent(noRetur)}/items/$idItem',
      body: {
        if (kodeKategori != null) 'kodeKategori': kodeKategori,
        if (idJenis != null) 'idJenis': idJenis,
        if (pcs != null) 'pcs': pcs,
        if (kategoriInput != null) 'kategoriInput': kategoriInput,
      },
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return ReturV3Item.fromJson(data);
  }

  Future<void> deleteItem(String noRetur, int idItem) async {
    await _api.deleteJson(
      '$_base/${Uri.encodeComponent(noRetur)}/items/$idItem',
    );
  }

  // ── Decision ─────────────────────────────────────────────────────────

  Future<ReturV3Header> decide(String noRetur, String decision) async {
    final body = await _api.patchJson(
      '$_base/${Uri.encodeComponent(noRetur)}/decision',
      body: {'decision': decision},
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return ReturV3Header.fromJson(data);
  }

  // ── Generate label (TIDAK_DIGANTI) ──────────────────────────────────

  Future<Map<String, dynamic>> generateLabel(
    String noRetur,
    int idItem, {
    double? berat,
    int? idReject,
  }) async {
    final body = await _api.postJson(
      '$_base/${Uri.encodeComponent(noRetur)}/items/$idItem/generate-label',
      body: {
        if (berat != null) 'berat': berat,
        if (idReject != null) 'idReject': idReject,
      },
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return data;
  }

  Future<List<ReturV3Output>> fetchOutputs(String noRetur) async {
    final body = await _api.getJson(
      '$_base/${Uri.encodeComponent(noRetur)}/outputs',
    );
    final dataList = (body['data'] ?? []) as List;
    return dataList
        .whereType<Map>()
        .map((e) => ReturV3Output.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Turnover / scan (DIGANTI) ───────────────────────────────────────

  /// Scan auto-detect: server mencocokkan label yang discan langsung ke item
  /// retur (BJReturV3Item_d) berdasarkan kategori+jenis — satu tombol scan
  /// untuk semua item pada retur ini.
  ///
  /// Kalau pcs label melebihi sisa kebutuhan item, backend TIDAK langsung menolak —
  /// mengembalikan `needsConfirmation: true` (tanpa mengubah data apapun)
  /// supaya UI bisa menawarkan pemecahan (partial). Panggil ulang dengan
  /// [confirmPartial]=true untuk benar-benar mengeksekusi partial. Return
  /// body mentah (bukan cuma `data`) supaya caller bisa cek
  /// `needsConfirmation` di level root — pola sama dengan `PenjualanRepository.scan`.
  Future<Map<String, dynamic>> scanAuto(
    String noRetur,
    String labelCode, {
    bool confirmPartial = false,
  }) async {
    return _api.postJson(
      '$_base/${Uri.encodeComponent(noRetur)}/scan',
      body: {'labelCode': labelCode, 'confirmPartial': confirmPartial},
    );
  }

  Future<void> undoScan(String noRetur, int idTurnover) async {
    await _api.deleteJson(
      '$_base/${Uri.encodeComponent(noRetur)}/turnover/$idTurnover',
    );
  }

  Future<List<ReturV3Turnover>> fetchTurnover(String noRetur) async {
    final body = await _api.getJson(
      '$_base/${Uri.encodeComponent(noRetur)}/turnover',
    );
    final dataList = (body['data'] ?? []) as List;
    return dataList
        .whereType<Map>()
        .map((e) => ReturV3Turnover.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Selesaikan retur (mark complete) ────────────────────────────────

  Future<ReturV3Header> markComplete(String noRetur) async {
    final body = await _api.patchJson(
      '$_base/${Uri.encodeComponent(noRetur)}/complete',
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Response tidak mengandung data');
    return ReturV3Header.fromJson(data);
  }
}
