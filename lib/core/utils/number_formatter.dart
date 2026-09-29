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
