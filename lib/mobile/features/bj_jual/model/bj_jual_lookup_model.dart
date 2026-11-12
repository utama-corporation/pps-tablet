class LookupLabelResult {
  final bool success;
  final String message;
  final String tableName;
  final int totalRecords;
  final List<LookupLabelItem> data;

  LookupLabelResult({
    required this.success,
    required this.message,
    required this.tableName,
    required this.totalRecords,
    required this.data,
  });

  factory LookupLabelResult.fromJson(Map<String, dynamic> json) {
    return LookupLabelResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      tableName: json['tableName'] ?? '',
      totalRecords: json['totalRecords'] ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => LookupLabelItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LookupLabelItem {
  final String noLabel;
  final int idJenis;
  final String namaJenis;
  final int pcs;
  final double berat;
  final bool isPartial;
  final String? blok;
  final int? idLokasi;
  final int? idWarehouse;
  final String? createBy;
  final String tableName;

  LookupLabelItem({
    required this.noLabel,
    required this.idJenis,
    required this.namaJenis,
    required this.pcs,
    required this.berat,
    required this.isPartial,
    this.blok,
    this.idLokasi,
    this.idWarehouse,
    this.createBy,
    required this.tableName,
  });

  factory LookupLabelItem.fromJson(Map<String, dynamic> json,
      {String tableName = ''}) {
    // Support both BarangJadi (noBJ) and FurnitureWIP (noFurnitureWip / noFurnitureWIP)
    final noLabel =
        (json['noBJ'] ?? json['noFurnitureWip'] ?? json['noFurnitureWIP'] ?? '') as String;
    return LookupLabelItem(
      noLabel: noLabel,
      idJenis: json['idJenis'] ?? 0,
      namaJenis: json['namaJenis'] ?? '-',
      pcs: json['pcs'] ?? 0,
      berat: (json['berat'] ?? 0).toDouble(),
      isPartial: json['isPartial'] ?? false,
      blok: json['blok'],
      idLokasi: json['idLokasi'],
      idWarehouse: json['idWarehouse'],
      createBy: json['createBy'],
      tableName: tableName,
    );
  }
}
