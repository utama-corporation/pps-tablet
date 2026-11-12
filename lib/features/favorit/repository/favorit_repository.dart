import '../../../core/network/api_client.dart';
import '../model/favorit_row.dart';

/// Favorit per user — backend `/api/favorit` (token-secured, tanpa permission khusus):
///   GET    /api/favorit                     daftar milik user (urut Urutan, Kode)
///   POST   /api/favorit                     {tipe, kode, komentar?} — idempoten
///   DELETE /api/favorit/:tipe/:kode         hapus entri
///   PUT    /api/favorit/urutan              {items: [{tipe, kode}]} — simpan urutan
class FavoritRepository {
  const FavoritRepository({required this.api});

  final ApiClient api;

  static const path = '/api/favorit';

  Future<List<FavoritRow>> fetchAll() async {
    final body = await api.getJson(path);
    final data = body['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) FavoritRow.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> add({
    required String tipe,
    required String kode,
    String? komentar,
  }) =>
      api.postJson(
        path,
        body: {
          'tipe': tipe,
          'kode': kode,
          if (komentar != null && komentar.trim().isNotEmpty)
            'komentar': komentar.trim(),
        },
      );

  Future<void> remove({required String tipe, required String kode}) =>
      api.deleteJson(
        '$path/${Uri.encodeComponent(tipe)}/${Uri.encodeComponent(kode)}',
      );

  Future<void> reorder(List<FavoritRow> rows) => api.putJson(
    '$path/urutan',
    body: {
      'items': [
        for (final row in rows) {'tipe': row.tipe, 'kode': row.kode},
      ],
    },
  );
}
