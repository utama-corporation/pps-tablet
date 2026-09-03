import 'package:intl/intl.dart';

/// "2025-10-03T00:00:00.000Z" -> "Jumat, 03 Okt 2025"
String formatDateToFullId(dynamic value) {
  final dt = parseAnyToDateTime(value);
  if (dt == null) return value is String ? value : '';
  return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(dt.toLocal());
}

/// "2025-10-03T00:00:00.000Z" -> "03 Okt 2025"
String formatDateToShortId(dynamic value) {
  final dt = parseAnyToDateTime(value);
  if (dt == null) return value is String ? value : '';
  return DateFormat('dd MMM yyyy', 'id_ID').format(dt.toLocal());
}

/// "2025-10-03T00:00:00.000Z" -> "14:35"
String formatDateToTime(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '';
  try {
    return DateFormat('HH:mm').format(DateTime.parse(isoString).toLocal());
  } catch (_) {
    return isoString;
  }
}

/// PARSER UMUM: ubah String/DateTime ke DateTime? (null-safe)
DateTime? parseAnyToDateTime(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;

    // 1) ISO 8601
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // 2) Coba beberapa pola umum (Indonesia & internasional)
    const patterns = <String>[
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'dd/MM/yyyy',
      'd/M/yyyy',
      'M/d/yyyy',
      'EEEE, dd MMM yyyy', // "Minggu, 05 Okt 2025"
      'dd MMM yyyy', // "05 Okt 2025"
    ];

    for (final p in patterns) {
      try {
        // parseLoose lebih toleran nama hari/bulan lokal
        return DateFormat(p, 'id_ID').parseLoose(s);
      } catch (_) {}
    }
  }

  return null;
}

/// FORMAT KE DB: kembalikan 'yyyy-MM-dd' atau '' bila gagal
String toDbDateString(dynamic value) {
  final dt = parseAnyToDateTime(value);
  if (dt == null) return '';
  return DateFormat('yyyy-MM-dd').format(dt.toLocal());
}
