String num2(double? v) => v == null ? '-' : v.toStringAsFixed(2);

/// Format numerik ringkas: angka bulat tanpa desimal, pecahan maks 2 desimal.
String fmtNum(num? v) {
  if (v == null) return '-';
  if (v % 1 == 0) return v.toInt().toString();
  return v.toStringAsFixed(2);
}