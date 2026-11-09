String num2(double? v) => v == null ? '-' : v.toStringAsFixed(2);

/// Bulatkan berat ke 2 desimal (presisi timbangan).
///
/// Perbandingan berat HARUS lewat [beratLebihDari] / [beratKurangDari] agar
/// bebas residu floating-point dari data backend — contoh kasus nyata:
/// sisa label 20kg setelah partial 17.28 dihitung backend sebagai
/// 2.7199999999999989, sehingga input "2.72" (2.7200000000000002) dianggap
/// MELEBIHI berat asli padahal sama.
double round2(num? v) => double.parse((v ?? 0).toStringAsFixed(2));

/// Apakah [v] melebihi [max] (dibandingkan dalam presisi 2 desimal).
bool beratLebihDari(num? v, num? max) => round2(v) > round2(max);

/// Apakah [v] kurang dari [max] (dibandingkan dalam presisi 2 desimal).
bool beratKurangDari(num? v, num? max) => round2(v) < round2(max);

/// Format numerik ringkas: angka bulat tanpa desimal, pecahan maks 2 desimal.
String fmtNum(num? v) {
  if (v == null) return '-';
  if (v % 1 == 0) return v.toInt().toString();
  return v.toStringAsFixed(2);
}