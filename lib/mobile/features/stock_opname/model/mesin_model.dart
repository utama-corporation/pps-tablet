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
