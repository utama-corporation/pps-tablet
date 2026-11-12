import 'package:intl/intl.dart';

const spkReadPermission = 'datamasterplanning:read';
const spkStatuses = [
  'PERLU PRODUKSI',
  'STOCK HABIS',
  'MENDEKATI MINIMUM',
  'STOCK AMAN',
];
const spkSorts = {
  'barang': 'Barang',
  'itemCode': 'Item code',
  'stok': 'Stok',
  'min': 'Minimum',
  'max': 'Maksimum',
  'mpq': 'MPQ',
  'qty': 'Qty rekomendasi',
  'status': 'Status',
};

String spkText(Map<String, dynamic> json, String key) =>
    json[key]?.toString().trim() ?? '';
double spkNumber(Map<String, dynamic> json, String key) {
  final n = num.tryParse('${json[key]}')?.toDouble() ?? 0;
  return n.isFinite ? n : 0;
}

String spkQty(num n) => NumberFormat('#,##0.##', 'id_ID').format(n);
String spkDate(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null
      ? (date.isEmpty ? '—' : date)
      : DateFormat('dd/MM/yyyy').format(parsed);
}

String spkDateTime(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date.isEmpty ? '—' : date;
  return DateFormat('dd/MM/yyyy HH:mm').format(parsed.toLocal());
}

/// Parses user qty input. Accepts `1.234,5` (id_ID) or `1234.5`; null if invalid.
double? spkParseQty(String raw) {
  var text = raw.trim().replaceAll(' ', '');
  if (text.isEmpty) return null;
  if (text.contains(',')) {
    text = text.replaceAll('.', '').replaceAll(',', '.');
  }
  final value = double.tryParse(text);
  return value == null || !value.isFinite ? null : value;
}

/// Raw editable text for a qty (no thousand separator, comma decimal).
String spkQtyInput(num n) {
  if (n <= 0) return '';
  final fixed = n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return fixed.replaceAll('.', ',');
}

bool spkHasMaxTwoDecimals(double value) =>
    ((value * 100).roundToDouble() - value * 100).abs() < 1e-6;

/// Same tolerance as the web: qty is a multiple of MPQ, or MPQ is not set.
bool spkIsMpqMultiple(double qty, double mpq) {
  if (mpq <= 0) return true;
  final rest = qty % mpq;
  return rest.abs() < 1e-9 || (rest - mpq).abs() < 1e-9;
}

class SpkStockItem {
  SpkStockItem.fromJson(Map<String, dynamic> json)
    : id = spkNumber(json, 'IdBJ').toInt(),
      code = spkText(json, 'ItemCode'),
      name = spkText(json, 'NamaBJ'),
      uom = spkText(json, 'UOM'),
      status = spkText(json, 'Status'),
      stock = spkNumber(json, 'Stock'),
      min = spkNumber(json, 'MinStock'),
      max = spkNumber(json, 'MaxStock'),
      mpq = spkNumber(json, 'MPQ'),
      recommendation = spkNumber(json, 'QtyRekomendasi') {
    if (id <= 0) {
      throw const FormatException('ID barang SPK tidak valid.');
    }
  }
  final int id;
  final String code, name, uom, status;
  final double stock, min, max, mpq, recommendation;
}

class SpkHistoryItem {
  SpkHistoryItem.fromJson(Map<String, dynamic> json)
    : code = spkText(json, 'NoSPK'),
      date = spkText(json, 'Tanggal'),
      status = spkText(json, 'StatusSPK'),
      lineStatus = spkText(json, 'StatusBaris'),
      qty = spkNumber(json, 'QtySPK'),
      completed = spkNumber(json, 'QtySelesai'),
      stock = spkNumber(json, 'StockSaatSPK'),
      recommendation = spkNumber(json, 'QtyRekomendasi') {
    if (code.isEmpty) {
      throw const FormatException('Nomor SPK tidak valid.');
    }
  }
  final String code, date, status, lineStatus;
  final double qty, completed, stock, recommendation;
}

class SpkLine {
  SpkLine.fromJson(Map<String, dynamic> json)
    : code = spkText(json, 'ItemCode'),
      name = spkText(json, 'NamaBJ'),
      uom = spkText(json, 'UOM'),
      status = spkText(json, 'Status'),
      notes = spkText(json, 'Keterangan'),
      qty = spkNumber(json, 'QtySPK'),
      produced = spkNumber(json, 'QtyProduksi'),
      completed = spkNumber(json, 'QtySelesai'),
      stock = spkNumber(json, 'StockSaatSPK'),
      min = spkNumber(json, 'MinStock'),
      max = spkNumber(json, 'MaxStock'),
      mpq = spkNumber(json, 'MPQ'),
      recommendation = spkNumber(json, 'QtyRekomendasi');
  final String code, name, uom, status, notes;
  final double qty, produced, completed, stock, min, max, mpq, recommendation;
}

class SpkDocument {
  SpkDocument.fromJson(Map<String, dynamic> json)
    : code = spkText(json, 'NoSPK'),
      date = spkText(json, 'Tanggal'),
      status = spkText(json, 'Status'),
      notes = spkText(json, 'Keterangan'),
      createdBy = spkText(json, 'CreatedBy'),
      createdDate = spkText(json, 'CreatedDate'),
      items = List.unmodifiable(spkRows(json['items']).map(SpkLine.fromJson)) {
    if (code.isEmpty) {
      throw const FormatException('Detail SPK tidak valid.');
    }
  }
  final String code, date, status, notes, createdBy, createdDate;
  final List<SpkLine> items;

  double get totalQty => items.fold(0, (sum, line) => sum + line.qty);
  double get totalCompleted =>
      items.fold(0, (sum, line) => sum + line.completed);
}

/// One line of the "Buat SPK" request: `POST /api/spk-barang-jadi`.
class SpkCreateLine {
  const SpkCreateLine({required this.idBJ, required this.qty});
  final int idBJ;
  final double qty;

  Map<String, dynamic> toJson() => {'IdBJ': idBJ, 'QtySPK': qty};
}

List<Map<String, dynamic>> spkRows(dynamic data) {
  if (data is! List) {
    throw const FormatException('Daftar SPK tidak valid.');
  }
  return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

class SpkPage<T> {
  const SpkPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
    this.summary = const {},
  });
  final List<T> items;
  final int page, totalPages, total;
  final Map<String, int> summary;
}
