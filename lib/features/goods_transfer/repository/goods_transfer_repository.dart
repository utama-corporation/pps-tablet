// lib/features/goods_transfer/repository/goods_transfer_repository.dart
import 'package:pps_tablet/core/network/api_client.dart';

import '../model/goods_transfer_header_model.dart';
import '../model/goods_transfer_item_model.dart';
import '../model/goods_transfer_scanned_label.dart';

class GoodsTransferRepository {
  final ApiClient api;

  GoodsTransferRepository({required this.api});

  /// Validasi 1 label sebelum ditambahkan ke daftar transfer: mengecek label
  /// dikenali, belum terpakai, tidak sedang IN_TRANSIT, dan bloknya saat ini
  /// memang milik [idWarehouseAsal]. Melempar [ApiException] kalau gagal.
  Future<GoodsTransferScannedLabel> inspectLabel({
    required String labelCode,
    required int idWarehouseAsal,
  }) async {
    final body = await api.getJson(
      '/api/goods-transfer/inspect-label',
      query: {
        'labelCode': labelCode,
        'idWarehouseAsal': idWarehouseAsal.toString(),
      },
    );
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Data label tidak ditemukan');
    return GoodsTransferScannedLabel.fromJson(data);
  }

  /// List semua transaksi Goods Transfer (tanpa filter warehouse) — dipakai di
  /// menu utama Goods Transfer, karena warehouse asal ditentukan saat create,
  /// bukan sebagai filter di layar ini.
  Future<List<GoodsTransferHeader>> fetchAll({String? status}) async {
    final body = await api.getJson(
      '/api/goods-transfer',
      query: {if (status != null) 'status': status},
    );
    final data = body['data'];
    if (data is! List) throw Exception('Format data transfer tidak sesuai');
    return data
        .map((e) => GoodsTransferHeader.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GoodsTransferDetail> fetchDetail(String noTransfer) async {
    final body = await api.getJson('/api/goods-transfer/$noTransfer');
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Data transfer tidak ditemukan');

    final rawItems = data['items'];
    final items = (rawItems is List ? rawItems : <dynamic>[])
        .map((e) => GoodsTransferItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return GoodsTransferDetail(
      header: data['header'] as Map<String, dynamic>? ?? {},
      items: items,
    );
  }

  Future<String> createTransfer({
    required int idWarehouseAsal,
    required int idWarehouseTujuan,
    required List<String> labelCodes,
    DateTime? tanggalKirim,
    String? catatan,
  }) async {
    final body = await api.postJson(
      '/api/goods-transfer',
      body: {
        'idWarehouseAsal': idWarehouseAsal,
        'idWarehouseTujuan': idWarehouseTujuan,
        'labelCodes': labelCodes,
        if (tanggalKirim != null)
          'tanggalKirim': tanggalKirim.toIso8601String(),
        if (catatan != null && catatan.trim().isNotEmpty) 'catatan': catatan,
      },
    );
    final data = body['data'] as Map<String, dynamic>?;
    return (data?['noTransfer'] ?? '').toString();
  }

  Future<void> cancelTransfer(String noTransfer) async {
    await api.postJson('/api/goods-transfer/$noTransfer/cancel');
  }
}
