class FavoritRow {
  const FavoritRow({
    required this.tipe,
    required this.kode,
    required this.urutan,
    required this.komentar,
  });

  final String tipe; // 'laporan' | 'menu'
  final String kode;
  final int urutan;
  final String komentar;

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('$v'.trim()) ?? 0;

  /// Kolom DB bisa berbeda antar server (mis. CHAR → ada spasi di belakang,
  /// atau alias tidak dipakai → `Tipe`/`Kode`). Nilai dinormalisasi supaya
  /// pencocokan favorit tidak gagal diam-diam.
  static String _text(Map<String, dynamic> j, String key) {
    final upper = key[0].toUpperCase() + key.substring(1);
    return (j[key] ?? j[upper] ?? '').toString().trim();
  }

  factory FavoritRow.fromJson(Map<String, dynamic> j) => FavoritRow(
    tipe: _text(j, 'tipe').toLowerCase(),
    kode: _text(j, 'kode'),
    urutan: _toInt(j['urutan'] ?? j['Urutan']),
    komentar: _text(j, 'komentar'),
  );

  bool matches(String tipe, String kode) =>
      this.tipe == tipe.trim().toLowerCase() && this.kode == kode.trim();
}
