import 'package:intl/intl.dart';

/// Format angka dengan pemisah ribuan gaya Indonesia.
///
/// Mengikuti locale `id_ID` yang dipakai app: ribuan dipisah titik dan desimal
/// dipisah koma — 1234567.8 → "1.234.567,80".
///
/// [decimals] = jumlah angka desimal yang ditampilkan (dibulatkan, bukan
/// dipangkas); `0` berarti bulat.
String formatThousands(num value, {int decimals = 0}) {
  final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
  return NumberFormat(pattern, 'id_ID').format(value);
}

/// [formatThousands] dengan 2 desimal — dipakai untuk berat (kg).
String formatThousands2(num value) => formatThousands(value, decimals: 2);

/// Format kuantitas PCS (barang dagang & bahan pendukung) TANPA angka di
/// belakang koma — dipakai untuk kuantitas pembelian (`QtyAwal`) dan
/// kuantitas terpakai/sisa (`Qty`) di layar penerimaan.
///
/// Angka desimal DIPOTONG (bukan dibulatkan): 40 → "40", 40.9 → "40".
///
/// Kenapa dipotong dan bukan dibulatkan: pembulatan ke atas membuat sisa
/// 39,5 tampil "40", dan itu berarti over-stok — user di lantai produksi bisa
/// mengambil 40 padahal hanya 39,5 yang tersedia. Pemotongan tidak pernah
/// menampilkan angka yang lebih besar dari kenyataan.
///
/// Pemisah ribuan memakai gaya `id_ID` (titik), jadi 1000 → "1.000".
///
/// Hanya untuk TAMPILAN. Untuk teks yang nanti di-parse atau dikirim balik ke
/// server, pakai [formatPcsQtyInput] — pemisah ribuan di field teks ambigu
/// ("1.000" bisa berarti 1000 atau 1.0).
///
/// Contoh: `40` → "40", `1000` → "1.000", `40.5` → "40", `3999.9` → "3.999".
String formatPcsQty(num value) => formatThousands(_truncatePcs(value));

/// Versi [formatPcsQty] untuk teks input (form) — tanpa pemisah ribuan.
///
/// `double.tryParse("1.000")` menghasilkan `1.0`, bukan `1000`. Kalau field
/// qty diisi "1.000" lalu user mengetiknya sedikit saja, parse-nya meleset
/// dan qty purchasing tersimpan 1, bukan 1000.
String formatPcsQtyInput(num value) => _truncatePcs(value).toString();

int _truncatePcs(num value) {
  if (value is int) return value;
  final d = value.toDouble();
  if (!d.isFinite) return 0;
  return d.truncate();
}
