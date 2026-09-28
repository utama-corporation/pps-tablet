class BrokerOutputItem {
  final String noBroker;
  final int hasBeenPrinted;

  const BrokerOutputItem({
    required this.noBroker,
    required this.hasBeenPrinted,
  });

  bool get isPrinted => hasBeenPrinted > 0;

  factory BrokerOutputItem.fromJson(Map<String, dynamic> json) {
    return BrokerOutputItem(
      noBroker: (json['NoBroker'] ?? '').toString(),
      hasBeenPrinted: (json['HasBeenPrinted'] as num?)?.toInt() ?? 0,
    );
  }
}

class BrokerHeader {
  final String noBroker; // NoBroker
  final int idJenisPlastik; // IdJenisPlastik
  final String namaJenisPlastik; // NamaJenisPlastik
  final int? idWarehouse; // IdWarehouse
  final String? namaWarehouse; // NamaWarehouse
  final String dateCreate; // DateCreate

  /// Server gives 'PASS'/'HOLD'
  final String statusText; // StatusText
  /// Derived from statusText (PASS=true, HOLD=false, else null)
  final bool? idStatus;

  // Lokasi
  final String? blok; // Blok
  final String? idLokasi; // IdLokasi (keep as String)

  // Quality / notes (optional)
  final double? density;
  final double? moisture;
  final double? maxMeltTemp;
  final double? minMeltTemp;
  final double? mfi;
  final String? visualNote;
  final double? density2;
  final double? density3;
  final double? moisture2;
  final double? moisture3;

  // Quality — tanggal & pelaku
  /// Tanggal QC diisi operator — bisa backdate (tanggal lampau) untuk input
  /// susulan. Null = belum pernah diisi QC.
  final String? dateQc;

  /// Username yang terakhir menyimpan QC.
  final String? qcBy;

  // Produksi / Mesin / Bongkar Susun (from your new joins)
  final String? noProduksi; // NoProduksi (MAX(...) or STRING_AGG result)
  final String? namaMesin; // NamaMesin
  final String?
  noBongkarSusun; // NoBongkarSusun (MAX(...) or STRING_AGG result)

  // Keep optional to avoid breaking other screens
  final String? createBy;
  final String? dateTimeCreate;

  final int hasBeenPrinted;
  final bool used;

  bool get isPrinted => hasBeenPrinted > 0;

  const BrokerHeader({
    required this.noBroker,
    required this.idJenisPlastik,
    required this.namaJenisPlastik,
    required this.idWarehouse,
    required this.namaWarehouse,
    required this.dateCreate,
    required this.statusText,
    this.idStatus,
    this.blok,
    this.idLokasi,
    this.density,
    this.moisture,
    this.maxMeltTemp,
    this.minMeltTemp,
    this.mfi,
    this.visualNote,
    this.density2,
    this.density3,
    this.moisture2,
    this.moisture3,
    this.dateQc,
    this.qcBy,
    this.noProduksi,
    this.namaMesin,
    this.noBongkarSusun,
    this.createBy,
    this.dateTimeCreate,
    this.hasBeenPrinted = 0,
    this.used = false,
  });

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

  /// String kosong / "null" dari API diperlakukan sebagai null.
  static String? _toStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  factory BrokerHeader.fromJson(Map<String, dynamic> json) {
    final statusText = json['StatusText']?.toString() ?? '';
    return BrokerHeader(
      noBroker: json['NoBroker']?.toString() ?? '',
      idJenisPlastik: _toInt(json['IdJenisPlastik']),
      namaJenisPlastik: json['NamaJenisPlastik']?.toString() ?? '',
      idWarehouse: _toInt(json['IdWarehouse']),
      namaWarehouse: json['NamaWarehouse']?.toString() ?? '',
      dateCreate: json['DateCreate']?.toString() ?? '',
      statusText: statusText,
      idStatus: _statusToBool(statusText),

      blok: json['Blok']?.toString(),
      idLokasi: json['IdLokasi']?.toString(),

      density: _toDouble(json['Density']),
      moisture: _toDouble(json['Moisture']),
      maxMeltTemp: _toDouble(json['MaxMeltTemp']),
      minMeltTemp: _toDouble(json['MinMeltTemp']),
      mfi: _toDouble(json['MFI']),
      visualNote: json['VisualNote']?.toString(),
      density2: _toDouble(json['Density2']),
      density3: _toDouble(json['Density3']),
      moisture2: _toDouble(json['Moisture2']),
      moisture3: _toDouble(json['Moisture3']),
      dateQc: _toStringOrNull(json['DateQc']),
      qcBy: _toStringOrNull(json['QcBy'] ?? json['UpdateByQc']),

      // ⬇️ fields dari service baru
      noProduksi: json['NoProduksi']?.toString(),
      namaMesin: json['NamaMesin']?.toString(),
      noBongkarSusun: json['NoBongkarSusun']?.toString(),

      createBy: json['CreateBy']?.toString(),
      dateTimeCreate: json['DateTimeCreate']?.toString(),
      hasBeenPrinted: (json['HasBeenPrinted'] as num?)?.toInt() ?? 0,
      used: json['Used'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'NoBroker': noBroker,
    'IdJenisPlastik': idJenisPlastik,
    'NamaJenisPlastik': namaJenisPlastik,
    'IdWarehouse': idWarehouse,
    'NamaWarehouse': namaWarehouse,
    'DateCreate': dateCreate,
    'StatusText': statusText,
    'IdStatus': idStatus, // derived, optional

    'Blok': blok,
    'IdLokasi': idLokasi,

    'Density': density,
    'Moisture': moisture,
    'MaxMeltTemp': maxMeltTemp,
    'MinMeltTemp': minMeltTemp,
    'MFI': mfi,
    'VisualNote': visualNote,
    'Density2': density2,
    'Density3': density3,
    'Moisture2': moisture2,
    'Moisture3': moisture3,
    'DateQc': dateQc,
    'QcBy': qcBy,

    // ⬇️ ikutkan jika perlu dikirim balik
    'NoProduksi': noProduksi,
    'NamaMesin': namaMesin,
    'NoBongkarSusun': noBongkarSusun,

    'CreateBy': createBy,
    'DateTimeCreate': dateTimeCreate,
    'HasBeenPrinted': hasBeenPrinted,
    'Used': used,
  };

  BrokerHeader copyWith({
    String? noBroker,
    int? idJenisPlastik,
    String? namaJenisPlastik,
    int? idWarehouse,
    String? namaWarehouse,
    String? dateCreate,
    String? statusText,
    bool? idStatus,
    String? blok,
    String? idLokasi,
    double? density,
    double? moisture,
    double? maxMeltTemp,
    double? minMeltTemp,
    double? mfi,
    String? visualNote,
    double? density2,
    double? density3,
    double? moisture2,
    double? moisture3,
    String? dateQc,
    String? qcBy,
    String? noProduksi,
    String? namaMesin,
    String? noBongkarSusun,
    String? createBy,
    String? dateTimeCreate,
    int? hasBeenPrinted,
    bool? used,
  }) {
    return BrokerHeader(
      noBroker: noBroker ?? this.noBroker,
      idJenisPlastik: idJenisPlastik ?? this.idJenisPlastik,
      namaJenisPlastik: namaJenisPlastik ?? this.namaJenisPlastik,
      idWarehouse: idWarehouse ?? this.idWarehouse,
      namaWarehouse: namaWarehouse ?? this.namaWarehouse,
      dateCreate: dateCreate ?? this.dateCreate,
      statusText: statusText ?? this.statusText,
      idStatus: idStatus ?? this.idStatus,
      blok: blok ?? this.blok,
      idLokasi: idLokasi ?? this.idLokasi,
      density: density ?? this.density,
      moisture: moisture ?? this.moisture,
      maxMeltTemp: maxMeltTemp ?? this.maxMeltTemp,
      minMeltTemp: minMeltTemp ?? this.minMeltTemp,
      mfi: mfi ?? this.mfi,
      visualNote: visualNote ?? this.visualNote,
      density2: density2 ?? this.density2,
      density3: density3 ?? this.density3,
      moisture2: moisture2 ?? this.moisture2,
      moisture3: moisture3 ?? this.moisture3,
      dateQc: dateQc ?? this.dateQc,
      qcBy: qcBy ?? this.qcBy,
      noProduksi: noProduksi ?? this.noProduksi,
      namaMesin: namaMesin ?? this.namaMesin,
      noBongkarSusun: noBongkarSusun ?? this.noBongkarSusun,
      createBy: createBy ?? this.createBy,
      dateTimeCreate: dateTimeCreate ?? this.dateTimeCreate,
      hasBeenPrinted: hasBeenPrinted ?? this.hasBeenPrinted,
      used: used ?? this.used,
    );
  }

  /// Patch nilai QC di tengah list (realtime / optimistic update).
  /// Semua argumen nullable: null berarti "kosongkan nilai ini", bukan
  /// "jangan diubah" — dipakai untuk menyamakan baris dengan payload
  /// socket yang berisi nilai QC lengkap.
  BrokerHeader withQc({
    double? density,
    double? density2,
    double? density3,
    double? moisture,
    double? moisture2,
    double? moisture3,
    double? maxMeltTemp,
    double? minMeltTemp,
    double? mfi,
    String? visualNote,
    String? dateQc,
    String? qcBy,
  }) {
    return BrokerHeader(
      noBroker: noBroker,
      idJenisPlastik: idJenisPlastik,
      namaJenisPlastik: namaJenisPlastik,
      idWarehouse: idWarehouse,
      namaWarehouse: namaWarehouse,
      dateCreate: dateCreate,
      statusText: statusText,
      idStatus: idStatus,
      blok: blok,
      idLokasi: idLokasi,
      density: density,
      moisture: moisture,
      maxMeltTemp: maxMeltTemp,
      minMeltTemp: minMeltTemp,
      mfi: mfi,
      visualNote: visualNote,
      density2: density2,
      density3: density3,
      moisture2: moisture2,
      moisture3: moisture3,
      dateQc: _toStringOrNull(dateQc),
      qcBy: _toStringOrNull(qcBy),
      noProduksi: noProduksi,
      namaMesin: namaMesin,
      noBongkarSusun: noBongkarSusun,
      createBy: createBy,
      dateTimeCreate: dateTimeCreate,
      hasBeenPrinted: hasBeenPrinted,
      used: used,
    );
  }
}
