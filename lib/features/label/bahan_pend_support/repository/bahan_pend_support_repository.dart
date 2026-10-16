// lib/features/label/bahan_pend_support/repository/bahan_pend_support_repository.dart

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/network/api_error.dart';

import '../model/bahan_pend_support_header_model.dart';

/// Repository Label Bahan Pendukung.
///
/// Backend tidak punya endpoint create untuk BP. (label dibuat dari menu
/// Penerimaan Bahan Pendukung), jadi di sini hanya ada list + print + delete.
/// Semua akses lewat [ApiClient] supaya token, decoding, dan normalisasi error
/// konsisten dengan label feature yang lebih baru (broker, reject, packing).
class BahanPendukungRepository {
  final ApiClient api;
  BahanPendukungRepository({ApiClient? api}) : api = api ?? ApiClient();

  static const _base = '/api/labels/bahan-pendukung';

  /// GET /api/labels/bahan-pendukung?page=&limit=&search=&includeUsed=
  Future<Map<String, dynamic>> fetchHeaders({
    int page = 1,
    int limit = 20,
    String search = '',
    bool includeUsed = false,
  }) async {
    final body = await api.getJson(
      _base,
      query: {
        'page': page,
        'limit': limit,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (includeUsed) 'includeUsed': 'true',
      },
    );

    final raw = (body['data'] ?? const []) as List;
    final items = raw
        .map(
          (e) => BahanPendukungHeader.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
    return {
      'items': items,
      'page': meta['page'] ?? page,
      'limit': meta['limit'] ?? limit,
      'total': meta['total'] ?? items.length,
      'totalPages': meta['totalPages'] ?? 1,
    };
  }

  /// PATCH /api/labels/bahan-pendukung/:no/print
  ///
  /// Backend memakai `requirePermission("label_bahanpendukung:update")` untuk
  /// endpoint ini, jadi print ikut memakai hak update.
  Future<int?> markAsPrinted(String noBahanPendukung) async {
    final body = await api.patchJson('$_base/${Uri.encodeComponent(noBahanPendukung)}/print');
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final raw = data['HasBeenPrinted'] ?? data['hasBeenPrinted'];
      if (raw is num) return raw.toInt();
      if (raw != null) return int.tryParse('$raw');
    }
    return null;
  }

  /// DELETE /api/labels/bahan-pendukung/:no
  ///
  /// Backend menolak (HTTP 409) dengan `error.code`:
  ///  - `BP_ALREADY_USED`    → label sudah terpakai penuh
  ///  - `BP_ALREADY_PARTIAL` → Qty sudah terpakai sebagian
  /// Pesan specificserverside sudah diterjemahkan lewat [apiErrorMessage].
  Future<void> deleteLabel(String noBahanPendukung) async {
    await api.deleteJson('$_base/${Uri.encodeComponent(noBahanPendukung)}');
  }
}

/// Pesan error delete yang enak dibaca operator. Dipisah dari repository
/// supaya view (yang punya BuildContext) bisa memanggilnya tanpa membawa
/// ApiException ke widget tree.
String bahanPendukungDeleteErrorMessage(Object error) {
  if (error is ApiException && error.statusCode == 409) {
    return switch (error.errorCode) {
      'BP_ALREADY_USED' =>
        'Label sudah dipakai pada proses produksi sehingga tidak dapat dihapus.',
      'BP_ALREADY_PARTIAL' =>
        'Label sudah dipakai sebagian sehingga tidak dapat dihapus.',
      _ => apiErrorMessage(error),
    };
  }
  return apiErrorMessage(error);
}