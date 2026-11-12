import '../../../core/network/api_client.dart';
import '../model/spk_models.dart';

class SpkRepository {
  SpkRepository({required this.api});
  final ApiClient api;
  static const path = '/api/spk-barang-jadi';

  Future<SpkPage<SpkStockItem>> monitoring({
    int page = 1,
    String search = '',
    String status = '',
    String sort = 'barang',
    String dir = 'asc',
  }) async {
    final body = await api.getJson(
      path,
      query: {
        'page': page,
        'pageSize': 20,
        'search': search.trim(),
        'status': status,
        'sort': sort,
        'dir': dir,
      },
    );
    return _page(body, SpkStockItem.fromJson);
  }

  Future<SpkPage<SpkHistoryItem>> history(int id, {int page = 1}) async {
    final body = await api.getJson(
      '$path/history',
      query: {'idBJ': id, 'page': page, 'pageSize': 10},
    );
    return _page(body, SpkHistoryItem.fromJson);
  }

  Future<SpkDocument> detail(String code) async {
    final body = await api.getJson('$path/${Uri.encodeComponent(code)}');
    if (body['data'] is! Map) {
      throw const FormatException('Detail SPK tidak valid.');
    }
    return SpkDocument.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// Creates an SPK. The server sets the date (today), number and snapshot
  /// (stock/min/max/MPQ/recommendation); it returns the full document.
  Future<SpkDocument> create({
    required List<SpkCreateLine> items,
    String notes = '',
  }) async {
    final trimmed = notes.trim();
    final body = await api.postJson(
      path,
      body: {
        'keterangan': trimmed.isEmpty ? null : trimmed,
        'items': [for (final line in items) line.toJson()],
      },
    );
    if (body['data'] is! Map) {
      throw const FormatException('Respons pembuatan SPK tidak valid.');
    }
    return SpkDocument.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  SpkPage<T> _page<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = body['meta'] is Map
        ? Map<String, dynamic>.from(body['meta'] as Map)
        : <String, dynamic>{};
    int count(dynamic value, int fallback, {int minimum = 0}) {
      final n = int.tryParse('$value') ?? fallback;
      return n < minimum ? minimum : n;
    }

    final rows = spkRows(body['data']);
    final summary = meta['summary'] is Map
        ? Map<String, dynamic>.from(meta['summary'] as Map)
        : <String, dynamic>{};
    return SpkPage(
      items: List.unmodifiable(rows.map(parse)),
      page: count(meta['page'], 1, minimum: 1),
      totalPages: count(meta['totalPages'], 1, minimum: 1),
      total: count(body['totalData'], rows.length),
      summary: Map.unmodifiable(
        summary.map((k, v) => MapEntry(k, count(v, 0))),
      ),
    );
  }
}
