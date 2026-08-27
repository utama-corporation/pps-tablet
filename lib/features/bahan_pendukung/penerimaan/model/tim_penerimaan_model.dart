// lib/features/bahan_pendukung/penerimaan/model/tim_penerimaan_model.dart
//
// Mirror response dari GET /api/penerimaan-bahan-pendukung/tim-status —
// Satu baris = satu tim, digabung dengan info NoPenerimaan yang dibuat
// HARI INI (jika ada). Tim dianggap "aktif" jika ada penerimaan hari ini
// dengan IsComplete = false. Jika penerimaan sudah IsComplete = true,
// tim dianggap "selesai" (tidak aktif).
class TimPenerimaanInfo {
  final int idTim;
  final String namaTim;
  final bool aktif;

  // transaksi penerimaan hari ini (null = tim belum ada transaksi hari ini)
  final String? noPenerimaan;
  final DateTime? tglPenerimaan;
  final bool isComplete;
  final String? createBy;
  final int jumlahItem;

  /// Tim "aktif" = punya penerimaan hari ini yang belum selesai
  bool get isActive => noPenerimaan != null && noPenerimaan!.isNotEmpty && !isComplete;

  const TimPenerimaanInfo({
    required this.idTim,
    required this.namaTim,
    required this.aktif,
    this.noPenerimaan,
    this.tglPenerimaan,
    this.isComplete = false,
    this.createBy,
    this.jumlahItem = 0,
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
      createBy: _s(j['CreateBy']),
      jumlahItem: _i(j['JumlahItem']),
    );
  }
}
