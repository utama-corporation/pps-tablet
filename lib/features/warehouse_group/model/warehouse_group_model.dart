// lib/features/warehouse_group/model/warehouse_group_model.dart

int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

bool _toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = '$v'.toLowerCase();
  return s == 'true' || s == '1';
}

/// 1 baris dbo.MstWarehouseGroup — "site" / grup lokasi fisik warehouse.
class WarehouseGroup {
  final int id;
  final String namaGroup;
  final String? keterangan;
  final bool aktif;

  /// Jumlah warehouse yang saat ini terikat ke group ini (dari backend).
  final int warehouseCount;

  WarehouseGroup({
    required this.id,
    required this.namaGroup,
    required this.keterangan,
    required this.aktif,
    required this.warehouseCount,
  });

  factory WarehouseGroup.fromJson(Map<String, dynamic> json) => WarehouseGroup(
    id: _toInt(json['IdWarehouseGroup']),
    namaGroup: (json['NamaGroup'] ?? '').toString(),
    keterangan: json['Keterangan']?.toString(),
    aktif: _toBool(json['Aktif']),
    warehouseCount: _toInt(json['WarehouseCount']),
  );
}

/// 1 warehouse + group-nya saat ini (dari GET /api/mst/warehouse).
class WarehouseGroupAssignment {
  final int idWarehouse;
  final String namaWarehouse;
  final bool enable;
  final int? idWarehouseGroup;
  final String? namaGroup;

  WarehouseGroupAssignment({
    required this.idWarehouse,
    required this.namaWarehouse,
    required this.enable,
    required this.idWarehouseGroup,
    required this.namaGroup,
  });

  factory WarehouseGroupAssignment.fromJson(Map<String, dynamic> json) =>
      WarehouseGroupAssignment(
        idWarehouse: _toInt(json['IdWarehouse']),
        namaWarehouse: (json['NamaWarehouse'] ?? '').toString(),
        enable: json['Enable'] == null ? true : _toBool(json['Enable']),
        idWarehouseGroup: _toIntOrNull(json['IdWarehouseGroup']),
        namaGroup: json['NamaGroup']?.toString(),
      );
}
