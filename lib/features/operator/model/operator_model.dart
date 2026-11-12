class MstOperator {
  final int idOperator;
  final String namaOperator;
  final bool enable;
  final int idBagian;
  final String namaBagianMesin;

  const MstOperator({
    required this.idOperator,
    required this.namaOperator,
    required this.enable,
    this.idBagian = 0,
    this.namaBagianMesin = '',
  });

  factory MstOperator.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    bool _toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'y' || s == 'yes';
      }
      return false;
    }

    return MstOperator(
      idOperator: _toInt(j['IdOperator']),
      namaOperator: (j['NamaOperator'] ?? '') as String,
      enable: _toBool(j['Enable']),
      idBagian: _toInt(j['IdBagian']),
      namaBagianMesin: (j['NamaBagianMesin'] ?? '').toString(),
    );
  }

  String get displayName => enable ? namaOperator : '$namaOperator (non-aktif)';

  String get bagianLabel => namaBagianMesin.trim().isEmpty
      ? (idBagian > 0 ? 'Bagian $idBagian' : '—')
      : namaBagianMesin;

  @override
  String toString() => 'MstOperator($idOperator, $namaOperator)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MstOperator && runtimeType == other.runtimeType && idOperator == other.idOperator;

  @override
  int get hashCode => idOperator.hashCode;
}

/// Opsi dropdown "Bagian" pada form operator (GET /api/mst-operator/bagian).
class OperatorBagian {
  const OperatorBagian({
    required this.idBagianMesin,
    required this.namaBagianMesin,
  });

  final int idBagianMesin;
  final String namaBagianMesin;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory OperatorBagian.fromJson(Map<String, dynamic> j) => OperatorBagian(
        idBagianMesin: _toInt(j['IdBagianMesin']),
        namaBagianMesin: (j['NamaBagianMesin'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OperatorBagian &&
          runtimeType == other.runtimeType &&
          idBagianMesin == other.idBagianMesin;

  @override
  int get hashCode => idBagianMesin.hashCode;
}
