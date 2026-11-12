// lib/features/label/model/label_item.dart
class LabelItem {
  final String nomorLabel;
  final String dateCreate; // sudah diformat backend (string)
  final String namaJenis;
  final String kategori;
  final String blok;
  final String idLokasi;

  // ⬇️ tambahan
  final num? qty;       // qty bisa int/double → pakai num
  final double? berat;  // kg

  LabelItem({
    required this.nomorLabel,
    required this.dateCreate,
    required this.namaJenis,
    required this.kategori,
    required this.blok,
    required this.idLokasi,
    this.qty,
    this.berat,
  });

  factory LabelItem.fromJson(Map<String, dynamic> json) {
    // helper konversi aman ke num/double
    num? _toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    // beberapa BE pakai "LabelCode", sebagian "NomorLabel"
    final nomorLabel = (json['LabelCode'] ??
        json['NomorLabel'] ??
        json['nomorLabel'] ??
        '')
        .toString();

    // field lain tetap aman
    final dateCreate = (json['DateCreate'] ?? json['dateCreate'] ?? '').toString();
    final namaJenis = (json['NamaJenis'] ?? json['namaJenis'] ?? '').toString();
    final kategori = (json['Kategori'] ?? json['kategori'] ?? '').toString();
    final blok = (json['Blok'] ?? json['blok'] ?? '').toString();
    final idLokasiValue = json['IdLokasi'] ?? json['idLokasi'];
    final idLokasi = (idLokasiValue == null || idLokasiValue == 0 || idLokasiValue.toString() == '0')
        ? '?'
        : idLokasiValue.toString();

    // Qty dan Berat: dukung berbagai kemungkinan nama kolom
    final qty = _toNum(json['Qty'] ?? json['qty'] ?? json['JmlhSak'] ?? json['JumlahSak']);
    final berat = _toNum(json['Berat'] ?? json['berat'] ?? json['TotalBerat'])?.toDouble();

    return LabelItem(
      nomorLabel: nomorLabel,
      dateCreate: dateCreate,
      namaJenis: namaJenis,
      kategori: kategori,
      blok: blok,
      idLokasi: idLokasi,
      qty: qty,
      berat: berat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'NomorLabel': nomorLabel,
      'DateCreate': dateCreate,
      'NamaJenis': namaJenis,
      'Kategori': kategori,
      'Blok': blok,
      'IdLokasi': idLokasi,
      if (qty != null) 'Qty': qty,
      if (berat != null) 'Berat': berat,
    };
  }

  LabelItem copyWith({
    String? nomorLabel,
    String? dateCreate,
    String? namaJenis,
    String? kategori,
    String? blok,
    String? idLokasi,
    num? qty,
    double? berat,
  }) {
    return LabelItem(
      nomorLabel: nomorLabel ?? this.nomorLabel,
      dateCreate: dateCreate ?? this.dateCreate,
      namaJenis: namaJenis ?? this.namaJenis,
      kategori: kategori ?? this.kategori,
      blok: blok ?? this.blok,
      idLokasi: idLokasi ?? this.idLokasi,
      qty: qty ?? this.qty,
      berat: berat ?? this.berat,
    );
  }
}
