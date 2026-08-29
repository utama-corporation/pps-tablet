// lib/features/production/penerimaan_bahan_baku/model/tim_penerimaan_bahan_baku_model.dart
//
// Mirror response dari GET /api/penerimaan-bahan-baku/tim-status — analog
// `WashingMesinInfo` (GET /api/mst-mesin/washing): satu baris = satu tim
// (dbo.MstTimPenerimaanBB), digabung dengan info NoPenerimaan yang MASIH
// BERJALAN (IsComplete = 0) jika ada. Tidak ada lagi Shift/Jam — header
// disederhanakan sama seperti Bahan Pendukung/Barang Dagang.
class TimPenerimaanInfo {
  final int idTim;
  final String namaTim;
  final bool aktif;

  // transaksi penerimaan yang masih berjalan (null = tim belum ada
  // transaksi berjalan)
  final String? noPenerimaan;
  final DateTime? tglPenerimaan;
  final bool isComplete;

  /// Tim "aktif" = punya penerimaan berjalan yang belum selesai
  bool get isActive =>
      noPenerimaan != null && noPenerimaan!.isNotEmpty && !isComplete;

  const TimPenerimaanInfo({
    required this.idTim,
    required this.namaTim,
    required this.aktif,
    this.noPenerimaan,
    this.tglPenerimaan,
    this.isComplete = false,
  });

  static String? _s(dynamic v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool _b(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  factory TimPenerimaanInfo.fromJson(Map<String, dynamic> j) {
    return TimPenerimaanInfo(
      idTim: _i(j['IdTim']),
      namaTim: _s(j['NamaTim']) ?? '',
      aktif: _b(j['Aktif']),
      noPenerimaan: _s(j['NoPenerimaan']),
      tglPenerimaan: _dt(j['TglPenerimaan']),
      isComplete: _b(j['IsComplete']),
    );
  }
}
