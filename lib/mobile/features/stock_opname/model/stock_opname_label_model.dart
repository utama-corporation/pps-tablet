class StockOpnameLabel {
  final String nomorLabel;
  final String labelType;
  final int jmlhSak;
  final double berat;

  /// tambahan
  final String? blok;     // ex: "A", "F", dst
  final int? idLokasi;    // ex: 1, 2 (boleh null kalau kosong)
  final String? username; // opsional kalau server kirim

  const StockOpnameLabel({
    required this.nomorLabel,
    required this.labelType,
    required this.jmlhSak,
    required this.berat,
    this.blok,
    this.idLokasi,
    this.username,
  });

  /// Getter tampilan gabungan lokasi
  String get displayLokasi {
    if ((blok == null || blok!.isEmpty) && idLokasi == null) return '-';
    if (blok != null && idLokasi != null) return '${blok!}$idLokasi';
    if (blok != null && blok!.isNotEmpty) return blok!;
    return idLokasi?.toString() ?? '-';
  }

  factory StockOpnameLabel.fromJson(Map<String, dynamic> json) {
    // helper ambil string aman dari banyak kemungkinan key
    String _getStr(List<String> keys, {String def = ''}) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return def;
    }

    // helper ambil int dari berbagai tipe
    int _getInt(List<String> keys, {int def = 0}) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is int) return v;
        if (v is num) return v.toInt();
        final parsed = int.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
      return def;
    }

    // helper ambil double dari berbagai tipe
    double _getDouble(List<String> keys, {double def = 0.0}) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        final parsed = double.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
      return def;
    }

    // idLokasi bisa datang sebagai int/string/'','all'
    int? _parseIdLokasiDynamic() {
      final candidates = ['idLokasi', 'IdLokasi', 'idlokasi'];
      for (final k in candidates) {
        if (!json.containsKey(k)) continue;
        final v = json[k];
        if (v == null) return null;
        if (v is int) return v == 0 ? null : v;
        final s = v.toString().trim();
        if (s.isEmpty || s.toLowerCase() == 'all' || s == '0') return null;
        final parsed = int.tryParse(s);
        if (parsed != null) return parsed;
      }
      return null;
    }

    return StockOpnameLabel(
      nomorLabel: _getStr(['nomorLabel', 'NomorLabel']),
      labelType: _getStr(['labelType', 'LabelType', 'labelTypeCode']).toLowerCase(),
      jmlhSak: _getInt(['jmlhSak', 'JmlhSak'], def: 0),
      berat: _getDouble(['berat', 'Berat'], def: 0.0),
      blok: _getStr(['blok', 'Blok'], def: '').isEmpty
          ? null
          : _getStr(['blok', 'Blok']),
      idLokasi: _parseIdLokasiDynamic(),
      username: _getStr(['username', 'Username'], def: '').isEmpty
          ? null
          : _getStr(['username', 'Username']),
    );
  }

  Map<String, dynamic> toJson() => {
    'NomorLabel': nomorLabel,
    'LabelType': labelType,
    'JmlhSak': jmlhSak,
    'Berat': berat,
    // kirim blok & idLokasi konsisten ke backend; kosong = null
    'Blok': blok ?? '',
    'IdLokasi': idLokasi ?? 0,
    if (username != null) 'Username': username,
  };

  StockOpnameLabel copyWith({
    String? nomorLabel,
    String? labelType,
    int? jmlhSak,
    double? berat,
    String? blok,
    int? idLokasi,
    String? username,
  }) {
    return StockOpnameLabel(
      nomorLabel: nomorLabel ?? this.nomorLabel,
      labelType: labelType ?? this.labelType,
      jmlhSak: jmlhSak ?? this.jmlhSak,
      berat: berat ?? this.berat,
      blok: blok ?? this.blok,
      idLokasi: idLokasi ?? this.idLokasi,
      username: username ?? this.username,
    );
  }
}
