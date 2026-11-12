import '../../operator/model/operator_model.dart';

class ReguDetail extends MstRegu {
  final List<MstOperator> operators;

  const ReguDetail({
    required super.idRegu,
    required super.idBagian,
    required super.namaRegu,
    super.kepalaRegu,
    super.namaKepalaRegu,
    super.namaBagianMesin,
    super.jumlahOperator,
    this.operators = const [],
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  factory ReguDetail.fromJson(Map<String, dynamic> json) {
    final rawOperators = json['operators'];
    return ReguDetail(
      idRegu: _toInt(json['IdRegu']),
      idBagian: _toInt(json['IdBagian']),
      namaRegu: (json['NamaRegu'] ?? '').toString(),
      kepalaRegu: json['KepalaRegu'] != null
          ? _toInt(json['KepalaRegu'])
          : null,
      namaKepalaRegu: json['NamaKepalaRegu']?.toString(),
      namaBagianMesin: (json['NamaBagianMesin'] ?? '').toString(),
      jumlahOperator: _toInt(json['JumlahOperator']),
      operators: [
        for (final row in (rawOperators is List ? rawOperators : const []))
          if (row is Map)
            MstOperator.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}

class MstRegu {
  final int idRegu;
  final int idBagian;
  final String namaRegu;
  final int? kepalaRegu;
  final String? namaKepalaRegu;
  final String namaBagianMesin;
  final int jumlahOperator;

  const MstRegu({
    required this.idRegu,
    required this.idBagian,
    required this.namaRegu,
    this.kepalaRegu,
    this.namaKepalaRegu,
    this.namaBagianMesin = '',
    this.jumlahOperator = 0,
  });

  factory MstRegu.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    final idRegu = toInt(json['IdRegu']);
    final idBagian = toInt(json['IdBagian']);

    return MstRegu(
      idRegu: idRegu,
      idBagian: idBagian,
      namaRegu: (json['NamaRegu'] ?? '').toString(),
      kepalaRegu: json['KepalaRegu'] != null
          ? toInt(json['KepalaRegu'])
          : null,
      namaKepalaRegu: json['NamaKepalaRegu']?.toString(),
      namaBagianMesin: (json['NamaBagianMesin'] ?? '').toString(),
      jumlahOperator: toInt(json['JumlahOperator']),
    );
  }

  String get bagianLabel => namaBagianMesin.trim().isEmpty
      ? (idBagian > 0 ? 'Bagian $idBagian' : 'â€”')
      : namaBagianMesin;

  String get displayName {
    if (namaKepalaRegu != null && namaKepalaRegu!.isNotEmpty) {
      return '$namaRegu - $namaKepalaRegu';
    }
    return namaRegu;
  }

  @override
  String toString() => 'MstRegu($idRegu, $namaRegu)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MstRegu &&
          runtimeType == other.runtimeType &&
          idRegu == other.idRegu;

  @override
  int get hashCode => idRegu.hashCode;
}
