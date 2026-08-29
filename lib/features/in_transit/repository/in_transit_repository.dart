// lib/features/in_transit/repository/in_transit_repository.dart
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_header_model.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_item_model.dart';

class InTransitRepository {
  final ApiClient api;

  InTransitRepository({required this.api});

  /// List semua transaksi Goods Transfer — sama dengan menu Goods Transfer,
  /// supaya format & datanya konsisten.
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

  /// Detail: header + baris permintaan (`lines`) + realisasi scan (`scans`).
  Future<GoodsTransferDetail> fetchDetail(String noTransfer) async {
    final body = await api.getJson('/api/goods-transfer/$noTransfer');
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Data transfer tidak ditemukan');
    return GoodsTransferDetail.fromJson(data);
  }

  /// Terima 1 label lewat scan: label akan di-update ke [blokTujuan]/
  /// [idLokasiTujuan], baris scan ditandai RECEIVED, dan label fisik dipindah
  /// ke warehouse tujuan. Backend menentukan transfer mana yang memiliki
  /// label ini lewat baris scan berstatus IN_TRANSIT.
  Future<Map<String, dynamic>> acceptScan({
    required String labelCode,
    required String blokTujuan,
    required int idLokasiTujuan,
  }) async {
    final body = await api.postJson(
      '/api/goods-transfer/accept-scan',
      body: {
        'labelCode': labelCode,
        'blokTujuan': blokTujuan,
        'idLokasiTujuan': idLokasiTujuan,
      },
    );
    return body['data'] as Map<String, dynamic>? ?? {};
  }
}
