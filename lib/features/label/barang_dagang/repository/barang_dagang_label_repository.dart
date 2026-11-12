import '../../../../core/network/api_client.dart';
import '../model/barang_dagang_label.dart';

class BarangDagangLabelRepository {
  BarangDagangLabelRepository({required this.api});
  final ApiClient api;
  static const path = '/api/labels/barang-dagang';

  Future<BarangDagangLabelPage> fetchPage({
    int page = 1,
    int limit = 20,
    String search = '',
    bool includeUsed = false,
  }) async {
    final body = await api.getJson(
      path,
      query: {
        'page': page,
        'limit': limit,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (includeUsed) 'includeUsed': 'true',
      },
    );
    final data = body['data'];
    if (data is! List) {
      throw const FormatException('Daftar label Barang Dagang tidak valid.');
    }
    final meta = body['meta'] is Map
        ? Map<String, dynamic>.from(body['meta'] as Map)
        : const <String, dynamic>{};
    int count(String key, int fallback, {int minimum = 0}) {
      final n = int.tryParse('${meta[key]}') ?? fallback;
      return n < minimum ? minimum : n;
    }

    final items = data
        .map(
          (row) =>
              BarangDagangLabel.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    return BarangDagangLabelPage(
      items: List.unmodifiable(items),
      page: count('page', page, minimum: 1),
      totalPages: count('totalPages', 1, minimum: 1),
      total: count('total', items.length),
    );
  }

  Future<Map<String, dynamic>> updateLabel(
    String code,
    Map<String, dynamic> body,
  ) async {
    if (code.trim().isEmpty) {
      throw ArgumentError('NoBarangDagang tidak boleh kosong');
    }
    return api.putJson(
      '$path/${Uri.encodeComponent(code.trim())}',
      body: body,
    );
  }

  Future<Map<String, dynamic>> deleteLabel(String code) async {
    if (code.trim().isEmpty) {
      throw ArgumentError('NoBarangDagang tidak boleh kosong');
    }
    return api.deleteJson(
      '$path/${Uri.encodeComponent(code.trim())}',
    );
  }

  Future<int> markAsPrinted(String code) async {
    final body = await api.patchJson(
      '$path/${Uri.encodeComponent(code)}/print',
    );
    final data = body['data'];
    final count = data is Map
        ? int.tryParse('${data['HasBeenPrinted'] ?? data['hasBeenPrinted']}')
        : null;
    if (count == null || count < 0) {
      throw const FormatException(
        'Konfirmasi cetak belum diterima dari server.',
      );
    }
    return count;
  }
}
