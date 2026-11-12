class Lokasi {
  final String idLokasi; // simpan sebagai string agar '01' tetap '01' kalau perlu
  final String blok;
  final bool enable;

  const Lokasi({
    required this.idLokasi,
    required this.blok,
    required this.enable,
  });

  /// Normalisasi dari backend:
  /// - IdLokasi: 0/null -> '' (kosong)
  /// - Blok: null -> ''
  factory Lokasi.fromJson(Map<String, dynamic> json) {
    final rawId = json['IdLokasi'];
    final id = (rawId == null || rawId.toString() == '0') ? '' : rawId.toString();
    final blok = (json['Blok'] ?? '').toString();
    final enable = (json['Enable'] ?? 0) == 1 || json['Enable'] == true;

    return Lokasi(idLokasi: id, blok: blok, enable: enable);
  }

  Map<String, dynamic> toJson() => {
    "IdLokasi": (idLokasi.isEmpty ? 0 : idLokasi),
    "Blok": blok,
    "Enable": enable ? 1 : 0,
  };

  /// Label untuk ditampilkan (mis. "A01" atau hanya "A" jika id kosong)
  String get displayText =>
      (blok.isEmpty && idLokasi.isEmpty) ? '-' : (idLokasi.isEmpty ? blok : '$blok$idLokasi');

  /// Key untuk pencarian (lowercase + tanpa spasi/dash)
  String get searchKey =>
      ('$blok$idLokasi').toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');

  /// Bantu dropdown/filter: banyak widget pakai toString() saat search
  @override
  String toString() => '$blok$idLokasi';

  /// Equality penting agar selected value di dropdown tepat (F31 ≠ B31)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Lokasi &&
              runtimeType == other.runtimeType &&
              blok == other.blok &&
              idLokasi == other.idLokasi &&
              enable == other.enable;

  @override
  int get hashCode => Object.hash(blok, idLokasi, enable);

  Lokasi copyWith({String? idLokasi, String? blok, bool? enable}) => Lokasi(
    idLokasi: idLokasi ?? this.idLokasi,
    blok: blok ?? this.blok,
    enable: enable ?? this.enable,
  );

  factory Lokasi.empty() => const Lokasi(idLokasi: '', blok: '', enable: false);

  /// Opsi "Semua" yang konsisten (hindari magic string di banyak tempat)
  factory Lokasi.semua() => const Lokasi(idLokasi: '', blok: '', enable: true);
}
