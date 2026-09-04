import 'package:intl/intl.dart';
import 'bs_v2_label_info.dart';

class BsV2SakItem {
  final int noSak;
  final double berat;

  const BsV2SakItem({required this.noSak, required this.berat});

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory BsV2SakItem.fromJson(Map<String, dynamic> j) {
    return BsV2SakItem(
      noSak: (j['noSak'] is int)
          ? j['noSak'] as int
          : int.tryParse(j['noSak']?.toString() ?? '0') ?? 0,
      berat: _d(j['berat']),
    );
  }

  Map<String, dynamic> toJson() => {'noSak': noSak, 'berat': berat};
}

class BsV2OutputLabel {
  final String? labelCode;
  final String? noBahanBaku;
  final String? noPallet;
  final int idJenis;
  final String namaJenis;
  final double totalBerat;
  final String category;
  final int jumlahSak;
  final List<BsV2SakItem> saks;
  final double? berat;

  /// Berapa kali label ini sudah dicetak (dari HasBeenPrinted di label header).
  final int printCount;

  const BsV2OutputLabel({
    this.labelCode,
    this.noBahanBaku,
    this.noPallet,
    required this.idJenis,
    required this.namaJenis,
    required this.totalBerat,
    required this.category,
    this.jumlahSak = 0,
    this.saks = const [],
    this.berat,
    this.printCount = 0,
  });

  bool get isWashing => category == 'washing';
  bool get isMixer => category == 'mixer';
  bool get isFurnitureWip => category == 'furnitureWip';
  bool get isBarangJadi => category == 'barangJadi';
  bool get isBahanBaku => category == 'bahanBaku';
  bool get isPcsCategory => isFurnitureWip || isBarangJadi;

  static String _s(dynamic v) => v?.toString() ?? '';
  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory BsV2OutputLabel.fromJson(Map<String, dynamic> j) {
    final saksRaw = (j['saks'] ?? []) as List;
    final category = _s(j['category']);
    final isGilingan = category == 'gilingan';
    final isFurnitureWip = category == 'furnitureWip';
    final isBarangJadi = category == 'barangJadi';
    final isBahanBaku = category == 'bahanBaku';
    final isPcsCategory = isFurnitureWip || isBarangJadi;
    final rawNoPallet = j['noPallet'] ?? j['NoPallet'];
    final rawNoBahanBaku = j['noBahanBaku'] ?? j['NoBahanBaku'];
    final noPallet = rawNoPallet == null ? null : _s(rawNoPallet);
    final noBahanBaku = rawNoBahanBaku == null
        ? (noPallet != null && noPallet.contains('-')
              ? noPallet.substring(0, noPallet.lastIndexOf('-'))
              : null)
        : _s(rawNoBahanBaku);
    // labelCode: noPallet, noWashing, noBonggolan, noBroker, noCrusher, noGilingan, noMixer, noFurnitureWIP, noBJ, noBahanBaku, or labelCode
    final labelCode =
        j['labelCode'] ??
        rawNoPallet ??
        j['noWashing'] ??
        j['noBonggolan'] ??
        j['noBroker'] ??
        j['noCrusher'] ??
        j['noGilingan'] ??
        j['noMixer'] ??
        j['noFurnitureWIP'] ??
        j['noBJ'] ??
        rawNoBahanBaku;
    final totalBerat = isPcsCategory
        ? _d(j['pcs'] ?? j['totalPcs'])
        : _d(j['totalBerat'] ?? j['berat']);
    return BsV2OutputLabel(
      labelCode: labelCode == null ? null : _s(labelCode),
      noBahanBaku: isBahanBaku ? noBahanBaku : null,
      noPallet: isBahanBaku ? noPallet : null,
      idJenis: isGilingan
          ? ((j['idGilingan'] is int)
                ? j['idGilingan'] as int
                : int.tryParse(j['idGilingan']?.toString() ?? '0') ?? 0)
          : ((j['idJenis'] is int)
                ? j['idJenis'] as int
                : int.tryParse(j['idJenis']?.toString() ?? '0') ?? 0),
      namaJenis: _s(j['namaJenis']),
      totalBerat: totalBerat,
      category: category,
      jumlahSak: _i(j['jumlahSak']),
      saks: saksRaw
          .map((e) => BsV2SakItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      berat: j['berat'] == null ? null : _d(j['berat']),
      printCount: _i(j['printCount'] ?? j['hasBeenPrinted'] ?? j['HasBeenPrinted']),
    );
  }
}

class BsV2Transaction {
  final String noBongkarSusun;
  final DateTime? tanggal;
  final String? note;
  final String? username;
  final int? idUsername;
  final String? category;
  final List<BsV2LabelInfo> inputs;
  final List<BsV2OutputLabel> outputs;
  // List-response only (not populated in detail response)
  final int? inputLabelCount;
  final int? outputLabelCount;
  final bool? balance;

  const BsV2Transaction({
    required this.noBongkarSusun,
    this.tanggal,
    this.note,
    this.username,
    this.idUsername,
    this.category,
    this.inputs = const [],
    this.outputs = const [],
    this.inputLabelCount,
    this.outputLabelCount,
    this.balance,
  });

  static String _s(dynamic v) => v?.toString() ?? '';
  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory BsV2Transaction.fromJson(Map<String, dynamic> j) {
    // Detail response wraps header fields under 'header' key; list/submit response is flat.
    final header = j['header'] as Map<String, dynamic>?;
    final src = header ?? j;

    final inputsRaw = (j['inputs'] ?? j['Inputs'] ?? []) as List;
    final outputsRaw = (j['outputs'] ?? j['Outputs'] ?? []) as List;
    final noteRaw = src['note'] ?? src['Note'];

    // Derive category from explicit field or first input object
    String categoryRaw = _s(src['category'] ?? src['Category']);
    if (categoryRaw.isEmpty && inputsRaw.isNotEmpty && inputsRaw.first is Map) {
      categoryRaw = _s((inputsRaw.first as Map)['category']);
    }

    // inputs can be List<String> (submit response) or List<Map> (detail response)
    final inputs = inputsRaw.map<BsV2LabelInfo>((e) {
      if (e is String) {
        return BsV2LabelInfo(
          labelCode: e,
          category: categoryRaw,
          idJenis: 0,
          namaJenis: '',
          totalBerat: 0,
        );
      }
      return BsV2LabelInfo.fromJson(Map<String, dynamic>.from(e as Map));
    }).toList();

    return BsV2Transaction(
      noBongkarSusun: _s(src['noBongkarSusun'] ?? src['NoBongkarSusun']),
      tanggal: _dt(src['tanggal'] ?? src['Tanggal']),
      note: noteRaw == null || noteRaw.toString().trim().isEmpty
          ? null
          : _s(noteRaw),
      username: src['username'] != null
          ? _s(src['username'])
          : (src['Username'] != null ? _s(src['Username']) : null),
      idUsername: src['IdUsername'] is int
          ? src['IdUsername'] as int
          : int.tryParse(src['IdUsername']?.toString() ?? ''),
      category: categoryRaw.isEmpty ? null : categoryRaw,
      inputs: inputs,
      outputs: outputsRaw
          .map(
            (e) =>
                BsV2OutputLabel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      inputLabelCount: j['inputLabelCount'] == null
          ? null
          : (j['inputLabelCount'] is int
                ? j['inputLabelCount'] as int
                : int.tryParse(j['inputLabelCount'].toString())),
      outputLabelCount: j['outputLabelCount'] == null
          ? null
          : (j['outputLabelCount'] is int
                ? j['outputLabelCount'] as int
                : int.tryParse(j['outputLabelCount'].toString())),
      balance: j['balance'] == null
          ? null
          : (j['balance'] is bool
                ? j['balance'] as bool
                : j['balance'].toString().toLowerCase() == 'true'),
    );
  }

  String get tanggalText {
    if (tanggal == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tanggal!.toLocal());
  }

  bool get isWashing => category == 'washing';

  String get categoryLabel {
    final cat = category ?? (inputs.isNotEmpty ? inputs.first.category : null);
    switch (cat) {
      case 'washing':
        return 'Washing';
      case 'broker':
        return 'Broker';
      case 'crusher':
        return 'Crusher';
      case 'gilingan':
        return 'Gilingan';
      case 'mixer':
        return 'Mixer';
      case 'furnitureWip':
        return 'Furniture WIP';
      case 'barangJadi':
        return 'Barang Jadi';
      case 'bahanBaku':
        return 'Bahan Baku';
      default:
        return cat != null ? 'Bonggolan' : '-';
    }
  }
}
