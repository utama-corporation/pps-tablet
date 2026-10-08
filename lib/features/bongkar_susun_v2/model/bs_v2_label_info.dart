import '../utils/bs_v2_category_label.dart';

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
  final String category; // "washing" | "bonggolan" | "reject" | ...
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

  /// Total berat yang sudah tercatat sebagai partial di label aslinya
  /// (produksi / bongkar-susun sebelumnya). Hanya reject yang punya
  /// konsep ini — dipakai untuk menampilkan sisa berat label.
  final double totalPartialBerat;

  /// Berat asli label sebelum dipecah. Dipakai bersama [totalBerat] (berat
  /// terpakai) untuk menampilkan "20,29 / 27,29 kg" pada label reject parsial.
  final double? totalBeratLabel;

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
    this.totalPartialBerat = 0,
    this.totalBeratLabel,
  });

  bool get isWashing => category == 'washing';
  bool get isBonggolan => category == 'bonggolan';
  bool get isCrusher => category == 'crusher';
  bool get isGilingan => category == 'gilingan';
  bool get isMixer => category == 'mixer';
  bool get isFurnitureWip => category == 'furnitureWip';
  bool get isBarangJadi => category == 'barangJadi';
  bool get isBahanBaku => category == 'bahanBaku';
  bool get isReject => category == 'reject';
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
    final labelCode = _s(j['labelCode']);
    final category = bsV2NormalizeCategory(
      _s(j['category']),
      labelCode: labelCode,
    );
    final noRejectPartial = _s(
      j['noRejectPartial'] ?? j['NoRejectPartial'],
    ).trim();
    final raw = j['isPartial'];
    final isPartial = raw == true || raw == 1 || noRejectPartial.isNotEmpty;
    final isGilingan = category == 'gilingan';
    final isFurnitureWip = category == 'furnitureWip';
    final isBarangJadi = category == 'barangJadi';
    final isBahanBaku = category == 'bahanBaku';
    final isReject = category == 'reject';
    // GET label info uses 'details' (capitalized NoSak/BeratAct) + sakSisa/beratSisa
    // Detail response uses standard 'saks' (lowercase noSak/berat) + jumlahSak/totalBerat
    final detailsRaw = (j['details'] as List?) ?? [];
    final saksRaw = (j['saks'] as List?) ?? [];
    final bahanBakuSaksRaw = detailsRaw.isNotEmpty ? detailsRaw : saksRaw;
    final activeSaksRaw = isBahanBaku ? bahanBakuSaksRaw : saksRaw;
    return BsV2LabelInfo(
      labelCode: labelCode,
      category: category,
      isPartial: isPartial,
      noPartial: (() {
        final v = _s(j['noPartial'] ?? j['NoPartial']).trim();
        return v.isEmpty ? null : v;
      })(),
      totalPcs: j['totalPcs'] == null ? null : _d(j['totalPcs']),
      totalPartialBerat: _d(j['totalPartialBerat'] ?? j['TotalPartialBerat']),
      totalBeratLabel: j['totalBeratLabel'] == null
          ? null
          : _d(j['totalBeratLabel']),
      idJenis: isGilingan ? _i(j['idGilingan']) : _i(j['idJenis']),
      namaJenis: _s(j['namaJenis']),
      noBahanBaku: isBahanBaku
          ? _s(j['noBahanBaku']).isNotEmpty
                ? _s(j['noBahanBaku'])
                // fallback: derive from labelCode by stripping pallet suffix
                : labelCode.contains('-')
                ? labelCode.substring(0, labelCode.lastIndexOf('-'))
                : null
          : null,
      totalBerat: (isFurnitureWip || isBarangJadi)
          ? _d(j['pcs'])
          : isBahanBaku
          // beratSisa = GET label info format; totalBerat = detail response format
          ? _d(j['beratSisa'] ?? j['totalBerat'] ?? j['berat'])
          // reject tidak ber-sak: sisa berat di beratAct (label parsial) /
          // beratSisa (GET label info), fallback ke berat total
          : isReject
          ? _d(j['beratAct'] ?? j['beratSisa'] ?? j['berat'] ?? j['totalBerat'])
          : (activeSaksRaw.isNotEmpty)
          ? activeSaksRaw.fold<double>(
              0.0,
              (sum, s) => sum + _d((s as Map)['berat']),
            )
          : _d(j['totalBerat'] ?? j['berat']),
      // sakSisa = GET label info format; jumlahSak = detail response format
      jumlahSak: isReject
          ? 0
          : isBahanBaku
          ? _i(j['sakSisa'] ?? j['jumlahSak'])
          : _i(j['jumlahSak']),
      saks: isReject
          ? const []
          : isBahanBaku
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
