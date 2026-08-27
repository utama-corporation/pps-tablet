// lib/features/goods_transfer/model/goods_transfer_item_model.dart

class GoodsTransferItem {
  final int idTransferItem;
  final String noTransfer;
  final String labelCode;
  final String prefixKategori;
  final String? blokAsal;
  final int? idLokasiAsal;
  final String? blokTujuan;
  final int? idLokasiTujuan;
  final String statusItem;
  final String? namaJenis;
  final String? kategori;
  final String? uom;
  final num? qty;
  final num? berat;

  GoodsTransferItem({
    required this.idTransferItem,
    required this.noTransfer,
    required this.labelCode,
    required this.prefixKategori,
    required this.blokAsal,
    required this.idLokasiAsal,
    required this.blokTujuan,
    required this.idLokasiTujuan,
    required this.statusItem,
    this.namaJenis,
    this.kategori,
    this.uom,
    this.qty,
    this.berat,
  });

  /// true kalau kategori ini diukur dalam pcs (bukan kg/berat).
  bool get isPcsUom => (uom ?? '').toLowerCase() == 'pcs';

  factory GoodsTransferItem.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    int? toIntOrNull(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    num? toNumOrNull(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse('$v'));

    return GoodsTransferItem(
      idTransferItem: toInt(json['IdTransferItem']),
      noTransfer: (json['NoTransfer'] ?? '').toString(),
      labelCode: (json['LabelCode'] ?? '').toString(),
      prefixKategori: (json['PrefixKategori'] ?? '').toString(),
      blokAsal: json['BlokAsal']?.toString(),
      idLokasiAsal: toIntOrNull(json['IdLokasiAsal']),
      blokTujuan: json['BlokTujuan']?.toString(),
      idLokasiTujuan: toIntOrNull(json['IdLokasiTujuan']),
      statusItem: (json['StatusItem'] ?? '').toString(),
      namaJenis: json['NamaJenis']?.toString(),
      kategori: json['Kategori']?.toString(),
      uom: json['Uom']?.toString(),
      qty: toNumOrNull(json['Qty']),
      berat: toNumOrNull(json['Berat']),
    );
  }
}

class GoodsTransferDetail {
  final GoodsTransferHeaderRaw header;
  final List<GoodsTransferItem> items;

  GoodsTransferDetail({required this.header, required this.items});
}

/// Header mentah (Map) supaya detail screen tidak perlu 2x parse berbeda
/// dengan [GoodsTransferHeader] yang dipakai di list.
typedef GoodsTransferHeaderRaw = Map<String, dynamic>;
