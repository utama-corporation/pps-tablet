class MstMesin {
  final int idMesin;
  final String namaMesin;
  final String bagian;
  final int? defaultOperatorId; // ⬅️ was String?
  final bool enable;
  final num? kapasitas;
  final int? idUom;
  final num? shotWeightPs;
  final num? klemLebar;
  final num? klemPanjang;
  final int? idBagianMesin;
  final num? target;
  final String? namaUom;

  const MstMesin({
    required this.idMesin,
    required this.namaMesin,
    required this.bagian,
    this.defaultOperatorId,
    required this.enable,
    this.kapasitas,
    this.idUom,
    this.shotWeightPs,
    this.klemLebar,
    this.klemPanjang,
    this.idBagianMesin,
    this.target,
    this.namaUom,
  });

  bool get isActive => enable == true;
  String get displayName => isActive ? namaMesin : '$namaMesin (non-aktif)';

  factory MstMesin.fromJson(Map<String, dynamic> j) {
    int? _toIntN(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    String? _toStr(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    int _toInt(dynamic v) => _toIntN(v) ?? 0;

    num? _toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    bool _toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == 'true' || s == '1' || s == 'y' || s == 'yes';
      }
      return false;
    }

    return MstMesin(
      idMesin: _toInt(j['IdMesin']),
      namaMesin: (j['NamaMesin'] ?? '') as String,
      bagian: (j['Bagian'] ?? '') as String,
      defaultOperatorId: _toIntN(j['DefaultOperator']), // ⬅️ parse as int?
      enable: _toBool(j['Enable']),
      kapasitas: _toNum(j['Kapasitas']),
      idUom: _toIntN(j['IdUOM']),
      shotWeightPs: _toNum(j['ShotWeightPS']),
      klemLebar: _toNum(j['KlemLebar']),
      klemPanjang: _toNum(j['KlemPanjang']),
      idBagianMesin: _toIntN(j['IdBagianMesin']),
      target: _toNum(j['Target']),
      namaUom: _toStr(j['NamaUOM'] ?? j['namaUOM']),
    );
  }

  Map<String, dynamic> toJson() => {
    'IdMesin': idMesin,
    'NamaMesin': namaMesin,
    'Bagian': bagian,
    'DefaultOperator': defaultOperatorId, // ⬅️ keep same key
    'Enable': enable ? 1 : 0,
    'Kapasitas': kapasitas,
    'IdUOM': idUom,
    'ShotWeightPS': shotWeightPs,
    'KlemLebar': klemLebar,
    'KlemPanjang': klemPanjang,
    'IdBagianMesin': idBagianMesin,
    'Target': target,
    'NamaUOM': namaUom,
  };

  MstMesin copyWith({
    int? idMesin,
    String? namaMesin,
    String? bagian,
    int? defaultOperatorId,
    bool? enable,
    num? kapasitas,
    int? idUom,
    num? shotWeightPs,
    num? klemLebar,
    num? klemPanjang,
    int? idBagianMesin,
    num? target,
    String? namaUom,
  }) {
    return MstMesin(
      idMesin: idMesin ?? this.idMesin,
      namaMesin: namaMesin ?? this.namaMesin,
      bagian: bagian ?? this.bagian,
      defaultOperatorId: defaultOperatorId ?? this.defaultOperatorId,
      enable: enable ?? this.enable,
      kapasitas: kapasitas ?? this.kapasitas,
      idUom: idUom ?? this.idUom,
      shotWeightPs: shotWeightPs ?? this.shotWeightPs,
      klemLebar: klemLebar ?? this.klemLebar,
      klemPanjang: klemPanjang ?? this.klemPanjang,
      idBagianMesin: idBagianMesin ?? this.idBagianMesin,
      target: target ?? this.target,
      namaUom: namaUom ?? this.namaUom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MstMesin && runtimeType == other.runtimeType && idMesin == other.idMesin;

  @override
  int get hashCode => idMesin.hashCode;
}
