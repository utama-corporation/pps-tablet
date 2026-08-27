// lib/features/goods_transfer/model/goods_transfer_scanned_label.dart

/// Hasil validasi 1 label yang di-scan/input di layar Create Goods Transfer
/// (dari GET /api/goods-transfer/inspect-label).
class GoodsTransferScannedLabel {
  final String labelCode;
  final String prefix;
  final String? blok;
  final int? idLokasi;
  final int? idWarehouse;
  final String? namaJenis;
  final String? kategori;
  final String? uom;
  final num? qty;
  final num? berat;

  GoodsTransferScannedLabel({
    required this.labelCode,
    required this.prefix,
    this.blok,
    this.idLokasi,
    this.idWarehouse,
    this.namaJenis,
    this.kategori,
    this.uom,
    this.qty,
    this.berat,
  });

  /// true kalau kategori ini diukur dalam pcs (bukan kg/berat) — dipakai
  /// untuk menentukan tampilkan qty atau berat di tile.
  bool get isPcsUom => (uom ?? '').toLowerCase() == 'pcs';

  factory GoodsTransferScannedLabel.fromJson(Map<String, dynamic> json) {
    int? toIntOrNull(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
    num? toNumOrNull(dynamic v) =>
        v == null ? null : (v is num ? v : num.tryParse('$v'));

    return GoodsTransferScannedLabel(
      labelCode: (json['labelCode'] ?? '').toString(),
      prefix: (json['prefix'] ?? '').toString(),
      blok: json['blok']?.toString(),
      idLokasi: toIntOrNull(json['idLokasi']),
      idWarehouse: toIntOrNull(json['idWarehouse']),
      namaJenis: json['namaJenis']?.toString(),
      kategori: json['kategori']?.toString(),
      uom: json['uom']?.toString(),
      qty: toNumOrNull(json['qty']),
      berat: toNumOrNull(json['berat']),
    );
  }
}
