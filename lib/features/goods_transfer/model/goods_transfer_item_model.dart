// lib/features/goods_transfer/model/goods_transfer_item_model.dart
//
// Model baru: 1 transfer = header (dari Ascend) + N baris permintaan
// (`GoodsTransferLine`, dari dbo.GoodsTransferItem_d) yang dipenuhi lewat
// scan label fisik. Bentuknya meniru `PenjualanLine` / `PenjualanDetail`.

import 'goods_transfer_label_scan_model.dart';

class GoodsTransferLine {
  final String kodeKategori;
  final int idJenis;
  final String? namaJenis;
  final int pcsRequired;
  final int pcsScanned;
  final bool isComplete;
  final DateTime? dateTimeCreate;
  final List<GoodsTransferLabelScan> scans;

  const GoodsTransferLine({
    required this.kodeKategori,
    required this.idJenis,
    this.namaJenis,
    required this.pcsRequired,
    required this.pcsScanned,
    required this.isComplete,
    this.dateTimeCreate,
    this.scans = const [],
  });

  int get pcsSisa => (pcsRequired - pcsScanned).clamp(0, pcsRequired);

  String get kategoriLabel =>
      kodeKategori == 'furniturewip' ? 'Furniture WIP' : 'Barang Jadi';

  String get prefix => kodeKategori == 'furniturewip' ? 'BB' : 'BA';

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _asBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return false;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  factory GoodsTransferLine.fromJson(Map<String, dynamic> j) {
    final rawScans = j['scans'] ?? j['Scans'];
    final scans = (rawScans is List ? rawScans : <dynamic>[])
        .map((e) =>
            GoodsTransferLabelScan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final pcsRequired = _asInt(j['pcsRequired'] ?? j['PcsRequired'] ?? j['Pcs']);
    final pcsScanned = _asInt(j['pcsScanned'] ?? j['PcsScanned']);

    return GoodsTransferLine(
      kodeKategori: (j['kodeKategori'] ?? j['KodeKategori'] ?? '').toString(),
      idJenis: _asInt(j['idJenis'] ?? j['IdJenis']),
      namaJenis: (j['namaJenis'] ?? j['NamaJenis'])?.toString(),
      pcsRequired: pcsRequired,
      pcsScanned: pcsScanned,
      isComplete: j.containsKey('isComplete') || j.containsKey('IsComplete')
          ? _asBool(j['isComplete'] ?? j['IsComplete'])
          : pcsScanned >= pcsRequired,
      dateTimeCreate: _asDateTime(j['dateTimeCreate'] ?? j['DateTimeCreate']),
      scans: scans,
    );
  }
}

/// Header disimpan sebagai Map mentah supaya detail screen tidak perlu 2x
/// parse berbeda dengan `GoodsTransferHeader` yang dipakai di list.
typedef GoodsTransferHeaderRaw = Map<String, dynamic>;

class GoodsTransferDetail {
  final GoodsTransferHeaderRaw header;
  final List<GoodsTransferLine> lines;
  final List<GoodsTransferLabelScan> scans;

  const GoodsTransferDetail({
    required this.header,
    required this.lines,
    required this.scans,
  });

  bool get allLinesComplete =>
      lines.isNotEmpty && lines.every((l) => l.isComplete);

  factory GoodsTransferDetail.fromJson(Map<String, dynamic> data) {
    final rawLines = data['lines'];
    final lines = (rawLines is List ? rawLines : <dynamic>[])
        .map((e) =>
            GoodsTransferLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final rawScans = data['scans'];
    final scans = (rawScans is List ? rawScans : <dynamic>[])
        .map((e) =>
            GoodsTransferLabelScan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    return GoodsTransferDetail(
      header: data['header'] as Map<String, dynamic>? ?? {},
      lines: lines,
      scans: scans,
    );
  }
}
