class FormulaKategori {
  const FormulaKategori({
    required this.id,
    required this.kode,
    required this.nama,
    required this.isWaste,
  });

  final int id;
  final String kode;
  final String nama;
  final bool isWaste;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static bool _toBool(dynamic v) => v == true || v == 1 || '$v' == '1' || '$v'.toLowerCase() == 'true';

  factory FormulaKategori.fromJson(Map<String, dynamic> j) => FormulaKategori(
    id: _toInt(j['IdKategori']),
    kode: (j['KodeKategori'] ?? '').toString(),
    nama: (j['NamaKategori'] ?? '').toString(),
    isWaste: _toBool(j['IsWaste']),
  );
}

class FormulaItemOption {
  const FormulaItemOption(this.id, this.nama);

  final int id;
  final String nama;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory FormulaItemOption.fromJson(Map<String, dynamic> j) =>
      FormulaItemOption(_toInt(j['Id']), (j['Nama'] ?? '').toString());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormulaItemOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => nama;
}

/// Satu baris formula pada list (`GET /api/mst-formula`).
class FormulaListRow {
  const FormulaListRow({
    required this.idFormula,
    required this.mainOutputKategoriId,
    required this.mainKategori,
    required this.mainOutputId,
    required this.mainOutputNama,
    required this.jumlahInput,
    required this.jumlahSecondary,
  });

  final int idFormula;
  final int mainOutputKategoriId;
  final String mainKategori;
  final int mainOutputId;
  final String mainOutputNama;
  final int jumlahInput;
  final int jumlahSecondary;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory FormulaListRow.fromJson(Map<String, dynamic> j) => FormulaListRow(
    idFormula: _toInt(j['IdFormula']),
    mainOutputKategoriId: _toInt(j['MainOutputKategoriId']),
    mainKategori: (j['MainKategori'] ?? '').toString(),
    mainOutputId: _toInt(j['MainOutputId']),
    mainOutputNama: (j['MainOutputNama'] ?? '').toString(),
    jumlahInput: _toInt(j['JumlahInput']),
    jumlahSecondary: _toInt(j['JumlahSecondary']),
  );

  String get displayName => mainOutputNama.isEmpty
      ? 'Formula #$idFormula'
      : mainOutputNama;
}

class FormulaDetailRow {
  const FormulaDetailRow({
    required this.kategoriId,
    required this.kategoriNama,
    required this.itemId,
    required this.itemNama,
  });

  final int kategoriId;
  final String kategoriNama;
  final int itemId;
  final String itemNama;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory FormulaDetailRow.fromJson(Map<String, dynamic> j) =>
      FormulaDetailRow(
        kategoriId: _toInt(j['KategoriId']),
        kategoriNama: (j['KategoriNama'] ?? '').toString(),
        itemId: _toInt(j['ItemId']),
        itemNama: (j['ItemNama'] ?? '').toString(),
      );
}

class FormulaDetail {
  const FormulaDetail({
    required this.idFormula,
    required this.mainOutputKategoriId,
    required this.mainKategori,
    required this.mainOutputId,
    required this.mainOutputNama,
    required this.inputs,
    required this.secondarys,
  });

  final int idFormula;
  final int mainOutputKategoriId;
  final String mainKategori;
  final int mainOutputId;
  final String mainOutputNama;
  final List<FormulaDetailRow> inputs;
  final List<FormulaDetailRow> secondarys;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static List<FormulaDetailRow> _rows(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) FormulaDetailRow.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  factory FormulaDetail.fromJson(Map<String, dynamic> j) => FormulaDetail(
    idFormula: _toInt(j['IdFormula']),
    mainOutputKategoriId: _toInt(j['MainOutputKategoriId']),
    mainKategori: (j['MainKategori'] ?? '').toString(),
    mainOutputId: _toInt(j['MainOutputId']),
    mainOutputNama: (j['MainOutputNama'] ?? '').toString(),
    inputs: _rows(j['Inputs']),
    secondarys: _rows(j['Secondarys']),
  );
}
