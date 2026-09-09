class ReturV3ScanEntry {
  final int idTurnover;
  final String labelCode;

  /// Kode partial (`BL.`/`BC.`) yang dipecah oleh scan ini; `null` berarti
  /// konsumsi 1x-penuh atas label yang belum pernah dipecah. `labelCode`
  /// tetap kode label fisik yang discan operator.
  final String? noPartial;
  final int pcs;
  final DateTime? dateTimeScan;

  const ReturV3ScanEntry({
    required this.idTurnover,
    required this.labelCode,
    this.noPartial,
    required this.pcs,
    this.dateTimeScan,
  });

  bool get isPartialSplit =>
      noPartial != null && noPartial!.trim().isNotEmpty;

  static String _s(dynamic v) => v?.toString() ?? '';
  static dynamic _pick(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      if (j.containsKey(k) && j[k] != null) return j[k];
    }
    return null;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory ReturV3ScanEntry.fromJson(Map<String, dynamic> j) {
    return ReturV3ScanEntry(
      idTurnover: _i(_pick(j, ['idTurnover', 'IdTurnover'])),
      labelCode: _s(_pick(j, ['labelCode', 'LabelCode'])),
      noPartial: (() {
        final v = _pick(j, ['noPartial', 'NoPartial']);
        final s = v?.toString().trim() ?? '';
        return s.isEmpty ? null : s;
      })(),
      pcs: _i(_pick(j, ['pcs', 'Pcs'])),
      dateTimeScan: (_pick(j, ['dateTimeScan', 'DateTimeScan']) != null)
          ? DateTime.tryParse(
              _pick(j, ['dateTimeScan', 'DateTimeScan']).toString(),
            )
          : null,
    );
  }
}

/// Progress turnover per item retur (dipakai saat statusRetur == DIGANTI):
/// satu baris per item retur yang dipilih (like-for-like) — `pcsAsal` adalah
/// target yang harus dipenuhi lewat scan label, `scannedPcs` total pcs yang
/// sudah discan untuk item ini.
class ReturV3Turnover {
  final int idItem;
  final String kodeKategoriAsal;
  final int idJenisAsal;
  final String? namaJenisAsal;
  final int pcsAsal;
  final int scannedPcs;
  final List<ReturV3ScanEntry> scans;

  const ReturV3Turnover({
    required this.idItem,
    required this.kodeKategoriAsal,
    required this.idJenisAsal,
    this.namaJenisAsal,
    required this.pcsAsal,
    this.scannedPcs = 0,
    this.scans = const [],
  });

  bool get isFulfilled => scannedPcs >= pcsAsal && pcsAsal > 0;
  int get remainingPcs => (pcsAsal - scannedPcs).clamp(0, pcsAsal);

  static String _s(dynamic v) => v?.toString() ?? '';
  static dynamic _pick(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      if (j.containsKey(k) && j[k] != null) return j[k];
    }
    return null;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static List<dynamic> _listFrom(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value;
    return const [];
  }

  factory ReturV3Turnover.fromJson(Map<String, dynamic> j) {
    final scansRaw = _listFrom(_pick(j, ['scans', 'Scans']));
    return ReturV3Turnover(
      idItem: _i(_pick(j, ['idItem', 'IdItem'])),
      kodeKategoriAsal: _s(
        _pick(j, ['kodeKategoriAsal', 'KodeKategoriAsal', 'kodeKategori']),
      ).toLowerCase(),
      idJenisAsal: _i(_pick(j, ['idJenisAsal', 'IdJenisAsal', 'idJenis'])),
      namaJenisAsal: _pick(j, [
        'namaJenisAsal',
        'NamaJenisAsal',
        'namaJenis',
      ])?.toString(),
      pcsAsal: _i(_pick(j, ['pcsAsal', 'PcsAsal', 'pcs'])),
      scannedPcs: _i(_pick(j, ['scannedPcs', 'ScannedPcs'])),
      scans: scansRaw
          .whereType<Map>()
          .map((e) => ReturV3ScanEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
