class BjJualInputSummary {
  final int barangJadi;
  final int furnitureWip;

  BjJualInputSummary({
    required this.barangJadi,
    required this.furnitureWip,
  });

  factory BjJualInputSummary.fromJson(Map<String, dynamic> json) {
    return BjJualInputSummary(
      barangJadi: json['barangJadi'] ?? 0,
      furnitureWip: json['furnitureWip'] ?? 0,
    );
  }
}

class BarangJadiItem {
  final String noBJ;
  final String? noBJPartial;
  final double berat;
  final int pcs;
  final bool? isPartial;
  final bool? isPartialRow;
  final int idJenis;
  final String namaJenis;
  final String namaUom;
  final String? datetimeInput;

  BarangJadiItem({
    required this.noBJ,
    this.noBJPartial,
    required this.berat,
    required this.pcs,
    this.isPartial,
    this.isPartialRow,
    required this.idJenis,
    required this.namaJenis,
    required this.namaUom,
    this.datetimeInput,
  });

  factory BarangJadiItem.fromJson(Map<String, dynamic> json) {
    return BarangJadiItem(
      noBJ: json['noBJ'] ?? '',
      noBJPartial: json['noBJPartial'],
      berat: (json['berat'] ?? 0).toDouble(),
      pcs: json['pcs'] ?? 0,
      isPartial: json['isPartial'],
      isPartialRow: json['isPartialRow'],
      idJenis: json['idJenis'] ?? 0,
      namaJenis: json['namaJenis'] ?? '-',
      namaUom: json['namaUom'] ?? '-',
      datetimeInput: json['datetimeInput'],
    );
  }
}

class FurnitureWipItem {
  final String noFurnitureWip;
  final double berat;
  final int pcs;
  final bool? isPartial;
  final int idJenis;
  final String namaJenis;
  final String namaUom;
  final String? datetimeInput;

  FurnitureWipItem({
    required this.noFurnitureWip,
    required this.berat,
    required this.pcs,
    this.isPartial,
    required this.idJenis,
    required this.namaJenis,
    required this.namaUom,
    this.datetimeInput,
  });

  factory FurnitureWipItem.fromJson(Map<String, dynamic> json) {
    return FurnitureWipItem(
      noFurnitureWip: json['noFurnitureWip'] ?? '',
      berat: (json['berat'] ?? 0).toDouble(),
      pcs: json['pcs'] ?? 0,
      isPartial: json['isPartial'],
      idJenis: json['idJenis'] ?? 0,
      namaJenis: json['namaJenis'] ?? '-',
      namaUom: json['namaUom'] ?? '-',
      datetimeInput: json['datetimeInput'],
    );
  }
}

class BjJualInputData {
  final List<BarangJadiItem> barangJadi;
  final List<FurnitureWipItem> furnitureWip;
  final BjJualInputSummary summary;

  BjJualInputData({
    required this.barangJadi,
    required this.furnitureWip,
    required this.summary,
  });

  factory BjJualInputData.fromJson(Map<String, dynamic> json) {
    return BjJualInputData(
      barangJadi: (json['barangJadi'] as List<dynamic>? ?? [])
          .map((e) => BarangJadiItem.fromJson(e))
          .toList(),
      furnitureWip: (json['furnitureWip'] as List<dynamic>? ?? [])
          .map((e) => FurnitureWipItem.fromJson(e))
          .toList(),
      summary: BjJualInputSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
    );
  }
}
