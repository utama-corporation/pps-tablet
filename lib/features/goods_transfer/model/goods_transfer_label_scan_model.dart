// lib/features/goods_transfer/model/goods_transfer_label_scan_model.dart

/// Satu baris label fisik yang discan untuk memenuhi 1 baris permintaan
/// (`GoodsTransferLine`) — dari dbo.GoodsTransferItemScan_d.
class GoodsTransferLabelScan {
  final int id;
  final String kodeKategori;
  final int idJenis;
  final String labelCode;
  final int pcs;

  /// false = sudah discan pengirim, belum discan penerima.
  /// true  = sudah discan penerima (label fisik dipindah ke tujuan).
  final bool isReceived;

  /// Blok & lokasi tempat label diletakkan di warehouse tujuan — terisi saat
  /// langkah terima.
  final String? blokTujuan;
  final int? idLokasiTujuan;

  final DateTime? dateTimeScan;
  final DateTime? dateTimeTerima;

  const GoodsTransferLabelScan({
    required this.id,
    required this.kodeKategori,
    required this.idJenis,
    required this.labelCode,
    required this.pcs,
    required this.isReceived,
    this.blokTujuan,
    this.idLokasiTujuan,
    this.dateTimeScan,
    this.dateTimeTerima,
  });

  bool get isInTransit => !isReceived;

  String get prefix => kodeKategori == 'furniturewip' ? 'BB' : 'BA';

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true';
    }
    return false;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  factory GoodsTransferLabelScan.fromJson(Map<String, dynamic> j) {
    return GoodsTransferLabelScan(
      id: _asInt(j['id'] ?? j['IdScan']),
      kodeKategori: (j['kodeKategori'] ?? j['KodeKategori'] ?? '').toString(),
      idJenis: _asInt(j['idJenis'] ?? j['IdJenis']),
      labelCode: (j['labelCode'] ?? j['LabelCode'] ?? '').toString(),
      pcs: _asInt(j['pcs'] ?? j['Pcs']),
      isReceived: _asBool(j['isReceived'] ?? j['IsReceived']),
      blokTujuan: (j['blokTujuan'] ?? j['BlokTujuan'])?.toString(),
      idLokasiTujuan: _asIntOrNull(j['idLokasiTujuan'] ?? j['IdLokasiTujuan']),
      dateTimeScan: _asDateTime(j['dateTimeScan'] ?? j['DateTimeScan']),
      dateTimeTerima: _asDateTime(j['dateTimeTerima'] ?? j['DateTimeTerima']),
    );
  }
}
