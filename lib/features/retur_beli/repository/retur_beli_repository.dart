import '../../../core/network/api_client.dart';
import '../model/retur_beli.dart';

/// Retur Beli — backend `/api/retur-beli`:
///   GET    /                      list (search, status, page, pageSize)
///   GET    /label/:noLabel        info label bahan pendukung untuk scan
///   GET    /:no                   header + item
///   POST   /                      {tanggal, idSupplier, keterangan}
///   PUT    /:no                   {tanggal?, idSupplier?, keterangan?}
///   DELETE /:no                   hapus dokumen (qty label dikembalikan)
///   POST   /:no/items             {noLabel, qty?, remark?} (stok berkurang)
///   DELETE /:no/items/:idItem     hapus item (qty label dikembalikan)
///   PATCH  /:no/complete          {penyelesaian: DIGANTI|POTONG_TAGIHAN}
class ReturBeliRepository {
  const ReturBeliRepository({required this.api});

  final ApiClient api;
  static const path = '/api/retur-beli';

  static Map<String, dynamic> _data(Map<String, dynamic> body) {
    final d = body['data'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    throw ApiException(0, 'Format data Retur Beli tidak sesuai.');
  }

  Future<ReturBeliPage> list({
    String search = '',
    String status = '',
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    final body = await api.getJson(
      path,
      query: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status.isNotEmpty) 'status': status,
        if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String().split('T').first,
        if (dateTo != null) 'dateTo': dateTo.toIso8601String().split('T').first,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    final rows = body['data'];
    return ReturBeliPage(
      total: (body['total'] as num?)?.toInt() ?? 0,
      items: [
        if (rows is List)
          for (final r in rows)
            if (r is Map) ReturBeliHeader.fromJson(Map<String, dynamic>.from(r)),
      ],
    );
  }

  Future<ReturBeliDetail> detail(String no) async {
    final d = _data(await api.getJson('$path/${Uri.encodeComponent(no)}'));
    final header = d['header'];
    final items = d['items'];
    return ReturBeliDetail(
      header: ReturBeliHeader.fromJson(
        header is Map ? Map<String, dynamic>.from(header) : const {},
      ),
      items: [
        if (items is List)
          for (final i in items)
            if (i is Map) ReturBeliItem.fromJson(Map<String, dynamic>.from(i)),
      ],
    );
  }

  Future<ReturBeliLabel> lookupLabel(String noLabel) async {
    final d = _data(
      await api.getJson('$path/label/${Uri.encodeComponent(noLabel.trim())}'),
    );
    return ReturBeliLabel.fromJson(d);
  }

  /// Return NoReturBeli baru.
  Future<String> create({
    required String tanggal,
    required int idSupplier,
    String keterangan = '',
  }) async {
    final d = _data(
      await api.postJson(
        path,
        body: {
          'tanggal': tanggal,
          'idSupplier': idSupplier,
          if (keterangan.trim().isNotEmpty) 'keterangan': keterangan.trim(),
        },
      ),
    );
    return '${d['noReturBeli'] ?? ''}';
  }

  Future<void> update(
    String no, {
    String? tanggal,
    int? idSupplier,
    String? keterangan,
  }) async {
    await api.putJson(
      '$path/${Uri.encodeComponent(no)}',
      body: {
        'tanggal': ?tanggal,
        'idSupplier': ?idSupplier,
        'keterangan': ?keterangan,
      },
    );
  }

  Future<void> delete(String no) async {
    await api.deleteJson('$path/${Uri.encodeComponent(no)}');
  }

  /// [qty] null = seluruh sisa label.
  Future<void> addItem(
    String no, {
    required String noLabel,
    num? qty,
    String remark = '',
  }) async {
    await api.postJson(
      '$path/${Uri.encodeComponent(no)}/items',
      body: {
        'noLabel': noLabel.trim(),
        'qty': ?qty,
        if (remark.trim().isNotEmpty) 'remark': remark.trim(),
      },
    );
  }

  Future<void> deleteItem(String no, int idItem) async {
    await api.deleteJson('$path/${Uri.encodeComponent(no)}/items/$idItem');
  }

  Future<void> complete(String no, ReturBeliPenyelesaian penyelesaian) async {
    await api.patchJson(
      '$path/${Uri.encodeComponent(no)}/complete',
      body: {'penyelesaian': penyelesaian.code},
    );
  }
}
