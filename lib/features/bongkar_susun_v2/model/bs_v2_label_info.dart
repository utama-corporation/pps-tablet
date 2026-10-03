class BsV2LabelSak {
  final int noSak;
  final double berat;
  final bool isPartial;

  const BsV2LabelSak({
    required this.noSak,
    required this.berat,
    this.isPartial = false,
  });

  factory BsV2LabelSak.fromJson(Map<String, dynamic> j) {
    final raw = j['isPartial'];
    final isPartial = raw == true || raw == 1;
    return BsV2LabelSak(
      noSak: j['noSak'] is int
          ? j['noSak'] as int
          : int.tryParse(j['noSak']?.toString() ?? '0') ?? 0,
      berat: j['berat'] is double
          ? j['berat'] as double
          : (j['berat'] is int
                ? (j['berat'] as int).toDouble()
                : double.tryParse(j['berat']?.toString() ?? '0') ?? 0.0),
      isPartial: isPartial,
    );
  }
}

class BsV2LabelInfo {
  final String labelCode;
  final String category; // "washing" | "bonggolan"
  final int idJenis;
  final String namaJenis;
  final double totalBerat;
  final int jumlahSak;
  final List<BsV2LabelSak> saks;
  // bahanBaku only — base number without pallet suffix (e.g. "A.0000002509")
  final String? noBahanBaku;
  final bool isPartial;

  /// Detail bongkar-susun: kode partial (BL.xxxxxxxx) yang dicatat untuk
  /// input ini. Terisi hanya kalau label input sudah pernah dipecah sebelum
  /// dipakai - artinya jumlah pcs yang dipakai = sisa pcs label, bukan pcs
  /// aslinya.
  final String? noPartial;

  /// Detail bongkar-susun: Pcs asli label sebelum dipartial.
  /// Dipakai bersama [totalBerat] (pcs terpakai) untuk menampilkan
  /// "9 / 15 pcs".
  final double? totalPcs;

  const BsV2LabelInfo({
    required this.labelCode,
    required this.category,
    required this.idJenis,
    required this.namaJenis,
    required this.totalBerat,
    this.jumlahSak = 0,
    this.saks = const [],
    this.noBahanBaku,
    this.isPartial = false,
    this.noPartial,
    this.totalPcs,
  });

  bool get isWashing => category == 'washing';
  bool get isBonggolan => category == 'bonggolan';
  bool get isCrusher => category == 'crusher';
  bool get isGilingan => category == 'gilingan';
  bool get isMixer => category == 'mixer';
  bool get isFurnitureWip => category == 'furnitureWip';
  bool get isBarangJadi => category == 'barangJadi';
  bool get isBahanBaku => category == 'bahanBaku';
  bool get isPcsCategory => isFurnitureWip || isBarangJadi;

  static String _s(dynamic v) => v?.toString() ?? '';
  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory BsV2LabelInfo.fromJson(Map<String, dynamic> j) {
    final raw = j['isPartial'];
    final isPartial = raw == true || raw == 1;
    final category = _s(j['category']);
    final isGilingan = category == 'gilingan';
    final isFurnitureWip = category == 'furnitureWip';
    final isBarangJadi = category == 'barangJadi';
    final isBahanBaku = category == 'bahanBaku';
    // GET label info uses 'details' (capitalized NoSak/BeratAct) + sakSisa/beratSisa
    // Detail response uses standard 'saks' (lowercase noSak/berat) + jumlahSak/totalBerat
    final detailsRaw = (j['details'] as List?) ?? [];
    final saksRaw = (j['saks'] as List?) ?? [];
    final bahanBakuSaksRaw = detailsRaw.isNotEmpty ? detailsRaw : saksRaw;
    final activeSaksRaw = isBahanBaku ? bahanBakuSaksRaw : saksRaw;
    return BsV2LabelInfo(
      labelCode: _s(j['labelCode']),
      category: category,
      isPartial: isPartial,
      noPartial: (() {
        final v = _s(j['noPartial'] ?? j['NoPartial']).trim();
        return v.isEmpty ? null : v;
      })(),
      totalPcs: j['totalPcs'] == null ? null : _d(j['totalPcs']),
      idJenis: isGilingan ? _i(j['idGilingan']) : _i(j['idJenis']),
      namaJenis: _s(j['namaJenis']),
      noBahanBaku: isBahanBaku
          ? _s(j['noBahanBaku']).isNotEmpty
              ? _s(j['noBahanBaku'])
              // fallback: derive from labelCode by stripping pallet suffix
              : _s(j['labelCode']).contains('-')
              ? _s(j['labelCode']).substring(
                  0,
                  _s(j['labelCode']).lastIndexOf('-'),
                )
              : null
          : null,
      totalBerat: (isFurnitureWip || isBarangJadi)
          ? _d(j['pcs'])
          : isBahanBaku
          // beratSisa = GET label info format; totalBerat = detail response format
          ? _d(j['beratSisa'] ?? j['totalBerat'] ?? j['berat'])
          : (activeSaksRaw.isNotEmpty)
          ? activeSaksRaw.fold<double>(
              0.0,
              (sum, s) => sum + _d((s as Map)['berat']),
            )
          : _d(j['totalBerat'] ?? j['berat']),
      // sakSisa = GET label info format; jumlahSak = detail response format
      jumlahSak: isBahanBaku
          ? _i(j['sakSisa'] ?? j['jumlahSak'])
          : _i(j['jumlahSak']),
      saks: isBahanBaku
          ? (detailsRaw.isNotEmpty
              // GET label info: capitalized NoSak/BeratAct
              ? detailsRaw
                    .map(
                      (e) => BsV2LabelSak(
                        noSak: _i((e as Map)['NoSak']),
                        berat: _d(e['BeratAct']),
                      ),
                    )
                    .toList()
              // Detail response: standard noSak/berat
              : saksRaw
                    .map(
                      (e) => BsV2LabelSak.fromJson(
                        Map<String, dynamic>.from(e as Map),
                      ),
                    )
                    .toList())
          : activeSaksRaw
              .map(
                (e) =>
                    BsV2LabelSak.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList(),
    );
  }
}
