class LookupOption {
  const LookupOption(this.id, this.name);

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LookupOption && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// Satu baris pemetaan `CetakanWarna_h` hasil join dengan MstCetakan,
/// MstWarna dan MstCabinetMaterial.
class CetakanWarnaMaterialRow {
  const CetakanWarnaMaterialRow({
    required this.idCetakan,
    required this.idWarna,
    required this.idMaterial,
    required this.namaCetakan,
    required this.warna,
    required this.namaMaterial,
  });

  final int idCetakan;
  final int idWarna;

  /// 0 = tanpa material (IdFurnitureMaterial NULL di database).
  final int idMaterial;
  final String namaCetakan;
  final String warna;

  /// String kosong = tanpa material.
  final String namaMaterial;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory CetakanWarnaMaterialRow.fromJson(Map<String, dynamic> j) =>
      CetakanWarnaMaterialRow(
        idCetakan: _toInt(j['IdCetakan']),
        idWarna: _toInt(j['IdWarna']),
        idMaterial: _toInt(j['IdMaterial']),
        namaCetakan: (j['NamaCetakan'] ?? '').toString(),
        warna: (j['Warna'] ?? '').toString(),
        namaMaterial: (j['NamaMaterial'] ?? '').toString(),
      );

  bool get hasMaterial => idMaterial > 0 && namaMaterial.isNotEmpty;

  String get materialLabel => hasMaterial ? namaMaterial : 'Tanpa Material';

  /// Label ringkas untuk notifikasi/popover.
  String get displayName => hasMaterial
      ? '$namaCetakan — $warna — $namaMaterial'
      : '$namaCetakan — $warna';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CetakanWarnaMaterialRow &&
          runtimeType == other.runtimeType &&
          idCetakan == other.idCetakan &&
          idWarna == other.idWarna &&
          idMaterial == other.idMaterial;

  @override
  int get hashCode => Object.hash(idCetakan, idWarna, idMaterial);
}

/// Opsi dropdown untuk form master cetakan.
class MasterCetakanOptions {
  const MasterCetakanOptions({
    required this.cetakan,
    required this.warna,
    required this.barangJadi,
    required this.furnitureWip,
    required this.materials,
  });

  const MasterCetakanOptions.empty()
      : cetakan = const [],
        warna = const [],
        barangJadi = const [],
        furnitureWip = const [],
        materials = const [];

  final List<LookupOption> cetakan;
  final List<LookupOption> warna;
  final List<LookupOption> barangJadi;
  final List<LookupOption> furnitureWip;
  final List<LookupOption> materials;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static List<LookupOption> _parse(
    dynamic raw, {
    required String idKey,
    required String nameKey,
  }) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          LookupOption(
            _toInt(e[idKey]),
            (e[nameKey] ?? '').toString(),
          ),
    ];
  }

  factory MasterCetakanOptions.fromJson(Map<String, dynamic> j) =>
      MasterCetakanOptions(
        cetakan: _parse(j['cetakan'], idKey: 'IdCetakan', nameKey: 'NamaCetakan'),
        warna: _parse(j['warna'], idKey: 'IdWarna', nameKey: 'Warna'),
        barangJadi: _parse(j['barangJadi'], idKey: 'IdBJ', nameKey: 'NamaBJ'),
        furnitureWip: _parse(
          j['furnitureWip'],
          idKey: 'IdCabinetWIP',
          nameKey: 'Nama',
        ),
        materials: _parse(
          j['materials'],
          idKey: 'IdCabinetMaterial',
          nameKey: 'Nama',
        ),
      );
}

/// Detail output sebuah baris cetakan (isi tabel detail).
class CetakanDetail {
  const CetakanDetail({required this.barangJadi, required this.furnitureWip});

  const CetakanDetail.empty()
      : barangJadi = const [],
        furnitureWip = const [];

  final List<LookupOption> barangJadi;
  final List<LookupOption> furnitureWip;

  bool get isFurnitureWip => furnitureWip.isNotEmpty;

  factory CetakanDetail.fromJson(Map<String, dynamic> j) {
    List<LookupOption> parse(dynamic raw, {required String idKey, required String nameKey}) {
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map)
            LookupOption(
              (e[idKey] as num?)?.toInt() ?? int.tryParse('${e[idKey]}') ?? 0,
              (e[nameKey] ?? '').toString(),
            ),
      ];
    }

    return CetakanDetail(
      barangJadi: parse(j['barangJadi'], idKey: 'IdBJ', nameKey: 'NamaBJ'),
      furnitureWip: parse(j['furnitureWip'], idKey: 'IdCabinetWIP', nameKey: 'Nama'),
    );
  }
}
