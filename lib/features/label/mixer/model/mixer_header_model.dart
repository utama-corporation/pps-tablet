class MixerOutputItem {
  final String noMixer;
  final int hasBeenPrinted;

  const MixerOutputItem({
    required this.noMixer,
    required this.hasBeenPrinted,
  });

  bool get isPrinted => hasBeenPrinted > 0;

  factory MixerOutputItem.fromJson(Map<String, dynamic> json) {
    return MixerOutputItem(
      noMixer: (json['NoMixer'] ?? '').toString(),
      hasBeenPrinted: (json['HasBeenPrinted'] as num?)?.toInt() ?? 0,
    );
  }
}

class MixerHeader {
  final String noMixer; // NoMixer
  final int idMixer; // IdMixer
  final String namaMixer; // NamaMixer (from MstMixer.Jenis)
  final String dateCreate; // DateCreate (string as sent by API)

  /// Server gives 'PASS' / 'HOLD'
  final String statusText; // StatusText
  /// Derived from statusText (PASS=true, HOLD=false, else null)
  final bool? idStatus;

  // Location
  final String? blok; // Blok
  final int? idLokasi; // IdLokasi (INT in DB)

  // Quality / process fields (optional)
  final double? moisture; // Moisture
  final double? maxMeltTemp; // MaxMeltTemp
  final double? minMeltTemp; // MinMeltTemp
  final double? mfi; // MFI
  final double? moisture2; // Moisture2
  final double? moisture3; // Moisture3
  final String? visualNote; // VisualNote

  // ==== OUTPUT GENERIC (baru, mengikuti Furniture WIP) ====
  /// Contoh: 'MIXER_PRODUKSI', 'BONGKAR_SUSUN'
  final String? outputType;

  /// Contoh: 'H.0000012345' atau 'BG.0000000123'
  final String? outputCode;

  /// Contoh: 'MESIN INJECT 09' atau 'Bongkar Susun'
  final String? outputNamaMesin;

  // ==== LEGACY / helper (turunan dari output generic) ====
  /// Kalau outputType == 'MIXER_PRODUKSI' -> sama dengan outputCode, selain itu null.
  final String? noProduksi;

  /// Kalau outputType == 'BONGKAR_SUSUN' -> sama dengan outputCode, selain itu null.
  final String? noBongkarSusun;

  /// Biasanya sama dengan outputNamaMesin (untuk backward compatibility).
  final String? namaMesin;

  // Audit (optional)
  final String? createBy; // CreateBy
  final String? dateTimeCreate; // DateTimeCreate

  final int hasBeenPrinted;
  final bool used;

  bool get isPrinted => hasBeenPrinted > 0;

  const MixerHeader({
    required this.noMixer,
    required this.idMixer,
    required this.namaMixer,
    required this.dateCreate,
    required this.statusText,
    this.idStatus,
    this.blok,
    this.idLokasi,
    this.moisture,
    this.maxMeltTemp,
    this.minMeltTemp,
    this.mfi,
    this.moisture2,
    this.moisture3,
    this.visualNote,
    this.outputType,
    this.outputCode,
    this.outputNamaMesin,
    this.noProduksi,
    this.noBongkarSusun,
    this.namaMesin,
    this.createBy,
    this.dateTimeCreate,
    this.hasBeenPrinted = 0,
    this.used = false,
  });

  // ---- helpers ----
  static bool? _statusToBool(String? s) {
    if (s == null) return null;
    final v = s.trim().toUpperCase();
    if (v == 'PASS') return true;
    if (v == 'HOLD') return false;
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory MixerHeader.fromJson(Map<String, dynamic> json) {
    final statusText = json['StatusText']?.toString() ?? '';

    // ===== Baca field output baru (generic) =====
    final rawOutputType = json['OutputType']?.toString();
    final rawOutputCode = json['OutputCode']?.toString();
    final rawOutputNamaMesin = json['OutputNamaMesin']?.toString();

    // ===== Fallback ke field lama kalau server belum lengkap =====
    final legacyNoProduksi = json['NoProduksi']?.toString();
    final legacyNoBongkarSusun = json['NoBongkarSusun']?.toString();
    final legacyNamaMesin = json['NamaMesin']?.toString();

    // OutputType final:
    final effOutputType =
        rawOutputType ??
        (legacyNoProduksi != null
            ? 'MIXER_PRODUKSI'
            : legacyNoBongkarSusun != null
            ? 'BONGKAR_SUSUN'
            : null);

    // OutputCode final:
    final effOutputCode =
        rawOutputCode ?? legacyNoProduksi ?? legacyNoBongkarSusun;

    // OutputNamaMesin final:
    final effOutputNamaMesin =
        rawOutputNamaMesin ??
        (effOutputType == 'BONGKAR_SUSUN' ? 'Bongkar Susun' : legacyNamaMesin);

    // Derived legacy fields:
    final effNoProduksi = effOutputType == 'MIXER_PRODUKSI'
        ? effOutputCode
        : null;
    final effNoBongkarSusun = effOutputType == 'BONGKAR_SUSUN'
        ? effOutputCode
        : null;

    return MixerHeader(
      noMixer: json['NoMixer']?.toString() ?? '',
      idMixer: _toInt(json['IdMixer']),
      // make sure your SQL aliases MstMixer.Jenis AS NamaMixer
      namaMixer: json['NamaMixer']?.toString() ?? '',
      dateCreate: json['DateCreate']?.toString() ?? '',
      statusText: statusText,
      idStatus: _statusToBool(statusText),

      blok: json['Blok']?.toString(),
      idLokasi: _toIntOrNull(json['IdLokasi']),

      moisture: _toDouble(json['Moisture']),
      maxMeltTemp: _toDouble(json['MaxMeltTemp']),
      minMeltTemp: _toDouble(json['MinMeltTemp']),
      mfi: _toDouble(json['MFI']),
      moisture2: _toDouble(json['Moisture2']),
      moisture3: _toDouble(json['Moisture3']),
      visualNote: json['VisualNote']?.toString(),

      // generic output
      outputType: effOutputType,
      outputCode: effOutputCode,
      outputNamaMesin: effOutputNamaMesin,

      // legacy helpers
      noProduksi: effNoProduksi,
      noBongkarSusun: effNoBongkarSusun,
      namaMesin: effOutputNamaMesin,

      createBy: json['CreateBy']?.toString(),
      dateTimeCreate: json['DateTimeCreate']?.toString(),
      hasBeenPrinted: (json['HasBeenPrinted'] as num?)?.toInt() ?? 0,
      used: json['Used'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'NoMixer': noMixer,
    'IdMixer': idMixer,
    'NamaMixer': namaMixer,
    'DateCreate': dateCreate,
    'StatusText': statusText,
    'IdStatus': idStatus, // derived

    'Blok': blok,
    'IdLokasi': idLokasi,

    'Moisture': moisture,
    'MaxMeltTemp': maxMeltTemp,
    'MinMeltTemp': minMeltTemp,
    'MFI': mfi,
    'Moisture2': moisture2,
    'Moisture3': moisture3,
    'VisualNote': visualNote,

    // Generic output (utama)
    'OutputType': outputType,
    'OutputCode': outputCode,
    'OutputNamaMesin': outputNamaMesin,

    // Legacy fields (kalau mau tetap kirim)
    'NoProduksi': noProduksi,
    'NoBongkarSusun': noBongkarSusun,
    'NamaMesin': namaMesin,

    'CreateBy': createBy,
    'DateTimeCreate': dateTimeCreate,
    'HasBeenPrinted': hasBeenPrinted,
    'Used': used,
  };

  MixerHeader copyWith({
    String? noMixer,
    int? idMixer,
    String? namaMixer,
    String? dateCreate,
    String? statusText,
    bool? idStatus,
    String? blok,
    int? idLokasi,
    double? moisture,
    double? maxMeltTemp,
    double? minMeltTemp,
    double? mfi,
    double? moisture2,
    double? moisture3,
    String? visualNote,
    String? outputType,
    String? outputCode,
    String? outputNamaMesin,
    String? noProduksi,
    String? noBongkarSusun,
    String? namaMesin,
    String? createBy,
    String? dateTimeCreate,
    int? hasBeenPrinted,
    bool? used,
  }) {
    return MixerHeader(
      noMixer: noMixer ?? this.noMixer,
      idMixer: idMixer ?? this.idMixer,
      namaMixer: namaMixer ?? this.namaMixer,
      dateCreate: dateCreate ?? this.dateCreate,
      statusText: statusText ?? this.statusText,
      idStatus: idStatus ?? this.idStatus,
      blok: blok ?? this.blok,
      idLokasi: idLokasi ?? this.idLokasi,
      moisture: moisture ?? this.moisture,
      maxMeltTemp: maxMeltTemp ?? this.maxMeltTemp,
      minMeltTemp: minMeltTemp ?? this.minMeltTemp,
      mfi: mfi ?? this.mfi,
      moisture2: moisture2 ?? this.moisture2,
      moisture3: moisture3 ?? this.moisture3,
      visualNote: visualNote ?? this.visualNote,
      outputType: outputType ?? this.outputType,
      outputCode: outputCode ?? this.outputCode,
      outputNamaMesin: outputNamaMesin ?? this.outputNamaMesin,
      noProduksi: noProduksi ?? this.noProduksi,
      noBongkarSusun: noBongkarSusun ?? this.noBongkarSusun,
      namaMesin: namaMesin ?? this.namaMesin,
      createBy: createBy ?? this.createBy,
      dateTimeCreate: dateTimeCreate ?? this.dateTimeCreate,
      hasBeenPrinted: hasBeenPrinted ?? this.hasBeenPrinted,
      used: used ?? this.used,
    );
  }
}
