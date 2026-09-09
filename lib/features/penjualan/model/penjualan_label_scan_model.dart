/// Satu baris label yang berhasil discan untuk memenuhi 1 baris turnover
/// (`PenjualanLine`) — dipakai untuk menampilkan chip nomor label, meniru
/// `ReturV3Turnover.scans` di `retur_v3_turnover.dart`.
class PenjualanLabelScan {
  final int id;
  final String noLabel;

  /// Kode partial (`BL.`/`BC.`) yang dipecah oleh scan ini; `null` berarti
  /// konsumsi 1x-penuh atas label yang belum pernah dipecah. `noLabel`
  /// tetap kode label fisik yang discan operator.
  final String? noPartial;
  final int pcs;
  final DateTime? dateTimeScan;

  const PenjualanLabelScan({
    required this.id,
    required this.noLabel,
    this.noPartial,
    required this.pcs,
    this.dateTimeScan,
  });

  bool get isPartialSplit =>
      noPartial != null && noPartial!.trim().isNotEmpty;

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  factory PenjualanLabelScan.fromJson(Map<String, dynamic> j) {
    return PenjualanLabelScan(
      id: _asInt(j['id'] ?? j['Id']),
      noLabel: (j['noLabel'] ?? j['NoLabel'] ?? '').toString(),
      noPartial: (() {
        final v = j['noPartial'] ?? j['NoPartial'];
        final s = v?.toString().trim() ?? '';
        return s.isEmpty ? null : s;
      })(),
      pcs: _asInt(j['pcs'] ?? j['Pcs']),
      dateTimeScan: _asDateTime(j['dateTimeScan'] ?? j['DateTimeScan']),
    );
  }
}
