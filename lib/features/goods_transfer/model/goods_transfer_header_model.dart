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

  /// Status pemenuhan turunan yang dihitung backend dari baris permintaan
  /// (_d) vs realisasi scan: OPEN | PARTIAL | SHIPPED | RECEIVED.
  final String fulfillStatus;
  final int totalLines;
  final int completedLines;

  /// Jumlah baris scan (label) yang tercatat & jumlah yang belum diterima.
  final int scanCount;
  final int inTransitCount;

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
    this.fulfillStatus = 'OPEN',
    this.totalLines = 0,
    this.completedLines = 0,
    this.scanCount = 0,
    this.inTransitCount = 0,
  });

  /// Jumlah label yang sudah diterima di tujuan (scan total − yang masih transit).
  int get receivedCount => (scanCount - inTransitCount).clamp(0, scanCount);

  /// true kalau transfer sudah ditandai "Kirim" (atau sudah diterima).
  bool get isShipped =>
      fulfillStatus == 'SHIPPED' || fulfillStatus == 'RECEIVED';

  /// true kalau semua baris permintaan sudah terisi penuh (siap dikirim / dst).
  bool get isFilled =>
      totalLines > 0 && completedLines >= totalLines;

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
      fulfillStatus: (json['FulfillStatus'] ?? 'OPEN').toString(),
      totalLines: toInt(json['TotalLines']),
      completedLines: toInt(json['CompletedLines']),
      scanCount: toInt(json['ScanCount']),
      inTransitCount: toInt(json['InTransitCount']),
    );
  }
}
