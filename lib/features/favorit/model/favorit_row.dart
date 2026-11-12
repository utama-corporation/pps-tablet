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
      v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory FavoritRow.fromJson(Map<String, dynamic> j) => FavoritRow(
    tipe: (j['tipe'] ?? '').toString(),
    kode: (j['kode'] ?? '').toString(),
    urutan: _toInt(j['urutan']),
    komentar: (j['komentar'] ?? '').toString(),
  );
}
