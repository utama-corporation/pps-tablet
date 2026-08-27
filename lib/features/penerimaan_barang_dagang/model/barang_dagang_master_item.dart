// lib/features/penerimaan_barang_dagang/model/barang_dagang_master_item.dart
//
// Mirror response dari GET /api/mst-barang-dagang — master jenis barang
// dagang (dbo.MstBarangDagang join MstUOM), dipakai sebagai dropdown "nama
// barang" saat tambah item penerimaan. Beda dengan CabinetMaterialItem
// (dipakai bahan pendukung): tidak ada ledger stok per warehouse di sini,
// MstBarangDagang bukan tabel yang di-scope per gudang.
class BarangDagangMasterItem {
  final int idBarangDagang;
  final String namaBarangDagang;
  final double? beratSTD;
  final bool enable;
  final int? idUOM;
  final String? namaUOM;
  final String? itemCode;
  final int? pcsPerLabel;

  const BarangDagangMasterItem({
    required this.idBarangDagang,
    required this.namaBarangDagang,
    this.beratSTD,
    this.enable = true,
    this.idUOM,
    this.namaUOM,
    this.itemCode,
    this.pcsPerLabel,
  });

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return true;
  }

  factory BarangDagangMasterItem.fromJson(Map<String, dynamic> j) {
    return BarangDagangMasterItem(
      idBarangDagang: _asInt(j['IdBarangDagang']),
      namaBarangDagang: j['NamaBarangDagang']?.toString() ?? '',
      beratSTD: _asDoubleOrNull(j['BeratSTD']),
      enable: _asBool(j['Enable']),
      idUOM: _asIntOrNull(j['IdUOM']),
      namaUOM: j['NamaUOM']?.toString(),
      itemCode: j['ItemCode']?.toString(),
      pcsPerLabel: _asIntOrNull(j['PcsPerLabel']),
    );
  }
}
