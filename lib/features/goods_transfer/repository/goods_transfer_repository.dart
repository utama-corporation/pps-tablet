// lib/features/goods_transfer/repository/goods_transfer_repository.dart
import 'package:pps_tablet/core/network/api_client.dart';

import '../model/goods_transfer_header_model.dart';
import '../model/goods_transfer_item_model.dart';

/// Model baru: header + baris permintaan digenerate ERP Ascend. PPS hanya
/// menampilkan dan mencatat realisasi scan label.
class GoodsTransferRepository {
  final ApiClient api;

  GoodsTransferRepository({required this.api});

  static const _base = '/api/goods-transfer';

  /// List semua transaksi Goods Transfer (tanpa filter warehouse).
  Future<List<GoodsTransferHeader>> fetchAll({String? status}) async {
    final body = await api.getJson(
      _base,
      query: {if (status != null) 'status': status},
    );
    final data = body['data'];
    if (data is! List) throw Exception('Format data transfer tidak sesuai');
    return data
        .map((e) => GoodsTransferHeader.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detail: header + baris permintaan (`lines`) + realisasi scan (`scans`).
  Future<GoodsTransferDetail> fetchDetail(String noTransfer) async {
    final body = await api.getJson('$_base/$noTransfer');
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Data transfer tidak ditemukan');
    return GoodsTransferDetail.fromJson(data);
  }

  /// Scan 1 label untuk memenuhi permintaan. Backend memvalidasi
  /// kategori/jenis/kuota/warehouse asal secara transaksional. Kalau pcs
  /// label melebihi sisa kebutuhan, backend TIDAK langsung menolak —
  /// mengembalikan `needsConfirmation: true` di level root. Panggil ulang
  /// dengan [confirmPartial]=true untuk mencatat sisa kebutuhan saja.
  /// Mengembalikan body mentah supaya caller bisa cek `needsConfirmation`.
  Future<Map<String, dynamic>> scan(
    String noTransfer,
    String labelCode, {
    bool confirmPartial = false,
  }) {
    return api.postJson(
      '$_base/$noTransfer/scan',
      body: {'noLabel': labelCode, 'confirmPartial': confirmPartial},
    );
  }

  /// Batalkan 1 baris scan yang belum diterima.
  Future<void> undoScan(int idScan) async {
    await api.deleteJson('$_base/scan/$idScan');
  }

  /// Tandai transfer "Kirim" — hanya boleh kalau semua permintaan sudah
  /// terpenuhi. Backend meng-UPDATE Status jadi SHIPPED dan mengunci scan.
  /// Body `{}` wajib: ApiClient.postJson selalu json.encode body, dan `null`
  /// ditolak express.json().
  Future<void> markKirim(String noTransfer) async {
    await api.postJson('$_base/$noTransfer/kirim', body: const <String, dynamic>{});
  }
}
