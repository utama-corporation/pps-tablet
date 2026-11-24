/// Model Retur Beli (`/api/retur-beli`): retur barang ke supplier.
/// Tahap 1: label Bahan Pendukung.
library;

String _str(dynamic v) => v == null ? '' : '$v'.trim();
num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');
int _int(dynamic v) => _num(v)?.toInt() ?? 0;

/// Penyelesaian retur: barang diganti supplier atau dipotong dari tagihan.
enum ReturBeliPenyelesaian {
  diganti('DIGANTI', 'Diganti supplier'),
  potongTagihan('POTONG_TAGIHAN', 'Potong tagihan');

  const ReturBeliPenyelesaian(this.code, this.label);
  final String code, label;

  static ReturBeliPenyelesaian? fromCode(String code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return null;
  }
}

class ReturBeliHeader {
  final String noReturBeli, tanggal, namaSupplier, keterangan, status, createBy;
  final int idSupplier, itemCount;
  final num totalQty;
  final ReturBeliPenyelesaian? penyelesaian;

  const ReturBeliHeader({
    required this.noReturBeli,
    required this.tanggal,
    required this.idSupplier,
    this.namaSupplier = '',
    this.keterangan = '',
    this.status = 'OPEN',
    this.penyelesaian,
    this.itemCount = 0,
    this.totalQty = 0,
    this.createBy = '',
  });

  bool get isOpen => status == 'OPEN';

  ReturBeliHeader.fromJson(Map<String, dynamic> j)
    : noReturBeli = _str(j['NoReturBeli']),
      tanggal = _str(j['Tanggal']),
      idSupplier = _int(j['IdSupplier']),
      namaSupplier = _str(j['NmSupplier']),
      keterangan = _str(j['Keterangan']),
      status = _str(j['Status']).isEmpty ? 'OPEN' : _str(j['Status']),
      penyelesaian = ReturBeliPenyelesaian.fromCode(_str(j['Penyelesaian'])),
      itemCount = _int(j['ItemCount']),
      totalQty = _num(j['TotalQty']) ?? 0,
      createBy = _str(j['CreateBy']);
}

class ReturBeliItem {
  final int idItem;
  final String noLabel, namaBarang, itemCode, remark;
  final num qty;
  final num? qtyAwal, sisaLabel;

  const ReturBeliItem({
    required this.idItem,
    required this.noLabel,
    required this.qty,
    this.namaBarang = '',
    this.itemCode = '',
    this.remark = '',
    this.qtyAwal,
    this.sisaLabel,
  });

  ReturBeliItem.fromJson(Map<String, dynamic> j)
    : idItem = _int(j['IdItem']),
      noLabel = _str(j['NoLabel']),
      qty = _num(j['Qty']) ?? 0,
      namaBarang = _str(j['NamaBarang']),
      itemCode = _str(j['ItemCode']),
      remark = _str(j['Remark']),
      qtyAwal = _num(j['QtyAwal']),
      sisaLabel = _num(j['SisaLabel']);
}

class ReturBeliDetail {
  final ReturBeliHeader header;
  final List<ReturBeliItem> items;
  const ReturBeliDetail({required this.header, required this.items});

  num get totalQty => items.fold<num>(0, (s, i) => s + i.qty);
}

/// Info label hasil scan (`GET /api/retur-beli/label/:noLabel`).
class ReturBeliLabel {
  final String noLabel, namaBarang, itemCode, namaSupplier;
  final int idSupplier;
  final num sisa;
  final num? qtyAwal;
  final bool available;

  const ReturBeliLabel({
    required this.noLabel,
    required this.idSupplier,
    required this.sisa,
    this.namaBarang = '',
    this.itemCode = '',
    this.namaSupplier = '',
    this.qtyAwal,
    this.available = true,
  });

  ReturBeliLabel.fromJson(Map<String, dynamic> j)
    : noLabel = _str(j['NoLabel']),
      idSupplier = _int(j['IdSupplier']),
      namaSupplier = _str(j['NmSupplier']),
      namaBarang = _str(j['NamaBarang']),
      itemCode = _str(j['ItemCode']),
      sisa = _num(j['Sisa']) ?? 0,
      qtyAwal = _num(j['QtyAwal']),
      available = j['Available'] == true;
}

class ReturBeliPage {
  final List<ReturBeliHeader> items;
  final int total;
  const ReturBeliPage({required this.items, required this.total});
}
