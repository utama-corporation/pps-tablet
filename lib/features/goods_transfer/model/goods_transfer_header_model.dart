// lib/features/goods_transfer/model/goods_transfer_header_model.dart

class GoodsTransferHeader {
  final String noTransfer;
  final DateTime? tanggalKirim;
  final int idWarehouseAsal;
  final int idWarehouseTujuan;
  final String? namaWarehouseAsal;
  final String? namaWarehouseTujuan;
  final String? usernameKirim;
  final String status;
  final DateTime? dateTimeKirim;
  final DateTime? dateTimeTerima;
  final String? catatan;
  final String? alasanTolak;
  final int itemCount;

  GoodsTransferHeader({
    required this.noTransfer,
    required this.tanggalKirim,
    required this.idWarehouseAsal,
    required this.idWarehouseTujuan,
    required this.namaWarehouseAsal,
    required this.namaWarehouseTujuan,
    required this.usernameKirim,
    required this.status,
    required this.dateTimeKirim,
    required this.dateTimeTerima,
    required this.catatan,
    required this.alasanTolak,
    required this.itemCount,
  });

  /// Label warehouse asal siap tampil — nama kalau ada, fallback ke "WH #id".
  String get warehouseAsalLabel =>
      (namaWarehouseAsal?.isNotEmpty ?? false)
      ? namaWarehouseAsal!
      : 'WH #$idWarehouseAsal';

  /// Label warehouse tujuan siap tampil — nama kalau ada, fallback ke "WH #id".
  String get warehouseTujuanLabel =>
      (namaWarehouseTujuan?.isNotEmpty ?? false)
      ? namaWarehouseTujuan!
      : 'WH #$idWarehouseTujuan';

  factory GoodsTransferHeader.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    DateTime? toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return GoodsTransferHeader(
      noTransfer: (json['NoTransfer'] ?? '').toString(),
      tanggalKirim: toDate(json['TanggalKirim']),
      idWarehouseAsal: toInt(json['IdWarehouseAsal']),
      idWarehouseTujuan: toInt(json['IdWarehouseTujuan']),
      namaWarehouseAsal: json['NamaWarehouseAsal']?.toString(),
      namaWarehouseTujuan: json['NamaWarehouseTujuan']?.toString(),
      usernameKirim: json['UsernameKirim']?.toString(),
      status: (json['Status'] ?? '').toString(),
      dateTimeKirim: toDate(json['DateTimeKirim']),
      dateTimeTerima: toDate(json['DateTimeTerima']),
      catatan: json['Catatan']?.toString(),
      alasanTolak: json['AlasanTolak']?.toString(),
      itemCount: toInt(json['ItemCount']),
    );
  }
}
