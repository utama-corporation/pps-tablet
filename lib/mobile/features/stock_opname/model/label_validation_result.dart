class MesinInfo {
  final String nomor;
  final int idMesin;
  final String namaMesin;
  final int idOperator;
  final String namaOperator;

  MesinInfo({
    required this.nomor,
    required this.idMesin,
    required this.namaMesin,
    required this.idOperator,
    required this.namaOperator,
  });

  factory MesinInfo.fromJson(Map<String, dynamic> json) {
    return MesinInfo(
      nomor: json['Nomor'] ?? '',
      idMesin: json['IdMesin'] ?? 0,
      namaMesin: json['NamaMesin'] ?? '',
      idOperator: json['IdOperator'] ?? 0,
      namaOperator: json['NamaOperator'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Nomor': nomor,
      'IdMesin': idMesin,
      'NamaMesin': namaMesin,
      'IdOperator': idOperator,
      'NamaOperator': namaOperator,
    };
  }
}

class LabelValidationResult {
  final bool success;
  final String message;
  final String label;
  final String labelType;
  final Map<String, dynamic> parsed;
  final String noso;
  final String username;
  final bool isValidFormat;
  final bool isValidCategory;
  final bool isValidWarehouse;
  final bool isDuplicate;
  final bool foundInStockOpname;
  final int? idDiscrepancy;
  final int? idWarehouse;
  final int? jmlhSak;
  final double? berat;
  final String? blok;
  final String? idLokasi;
  final List<MesinInfo> mesinInfo; // <== Tambahan

  LabelValidationResult({
    required this.success,
    required this.message,
    required this.label,
    required this.labelType,
    required this.parsed,
    required this.noso,
    required this.username,
    required this.isValidFormat,
    required this.isValidCategory,
    required this.isValidWarehouse,
    required this.isDuplicate,
    required this.foundInStockOpname,
    this.idDiscrepancy,
    this.idWarehouse,
    this.jmlhSak,
    this.berat,
    this.blok,
    this.idLokasi,
    this.mesinInfo = const [],
  });

  factory LabelValidationResult.fromJson(Map<String, dynamic> json) {
    return LabelValidationResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      label: json['label'] ?? '',
      labelType: json['labelType'] ?? '',
      parsed: Map<String, dynamic>.from(json['parsed'] ?? {}),
      noso: json['noso'] ?? '',
      username: json['username'] ?? '',
      isValidFormat: json['isValidFormat'] ?? false,
      isValidCategory: json['isValidCategory'] ?? false,
      isValidWarehouse: json['isValidWarehouse'] ?? false,
      isDuplicate: json['isDuplicate'] ?? false,
      foundInStockOpname: json['foundInStockOpname'] ?? false,
      idDiscrepancy: json['idDiscrepancy'],
      idWarehouse: json['idWarehouse'],
      jmlhSak: json['jmlhSak'],
      berat: json['berat'] != null ? (json['berat'] as num).toDouble() : null,
      blok: json['blok']?.toString(),
      idLokasi: json['idLokasi']?.toString(),
      mesinInfo: (json['mesinInfo'] as List<dynamic>?)
          ?.map((e) => MesinInfo.fromJson(e))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'label': label,
      'labelType': labelType,
      'parsed': parsed,
      'noso': noso,
      'username': username,
      'isValidFormat': isValidFormat,
      'isValidCategory': isValidCategory,
      'isValidWarehouse': isValidWarehouse,
      'isDuplicate': isDuplicate,
      'foundInStockOpname': foundInStockOpname,
      'idDiscrepancy': idDiscrepancy,
      'idWarehouse': idWarehouse,
      'jmlhSak': jmlhSak,
      'berat': berat,
      'blok': blok,
      'idLokasi': idLokasi,
      'mesinInfo': mesinInfo.map((e) => e.toJson()).toList(),
    };
  }

  bool get hasStockData => jmlhSak != null && berat != null;

  bool get isValid =>
      success && isValidFormat && isValidCategory && isValidWarehouse;

  String get stockInfo => hasStockData
      ? 'Sak: $jmlhSak, Berat: ${berat?.toStringAsFixed(1)} kg, Lokasi: $idLokasi'
      : 'Tidak ada data stock';

  @override
  String toString() {
    return 'LabelValidationResult{'
        'success: $success, '
        'message: $message, '
        'label: $label, '
        'labelType: $labelType, '
        'idDiscrepancy: $idDiscrepancy, '
        'isDuplicate: $isDuplicate, '
        'foundInStockOpname: $foundInStockOpname, '
        'isValidFormat: $isValidFormat, '
        'isValidCategory: $isValidCategory, '
        'isValidWarehouse: $isValidWarehouse, '
        'idWarehouse: $idWarehouse, '
        'jmlhSak: $jmlhSak, '
        'berat: $berat, '
        'blok: $blok, '
        'idLokasi: $idLokasi, '
        'mesinInfo: $mesinInfo'
        '}';
  }
}
