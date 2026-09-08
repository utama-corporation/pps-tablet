// lib/features/shared/inject_production/model/inject_production_model.dart

class InjectProduction {
  final String noProduksi;

  final DateTime? tglProduksi;

  final int idMesin;
  final String namaMesin;

  final int? idRegu;
  final String? namaRegu;

  final int idOperator;
  final String namaOperator;

  /// Inject: Jam = INT (hour only)
  final int jam;

  final int shift;

  final String? createBy;
  final String? checkBy1;
  final String? checkBy2;
  final String? approveBy;

  final int jmlhAnggota;
  final int hadir;

  final num? hourMeter;

  final int? idCetakan;
  final String? namaCetakan;
  final int? idWarna;
  final String? namaWarna;

  final bool enableOffset;
  final num? offsetCurrent;
  final num? offsetNext;

  final int? idFurnitureMaterial;
  final String? namaFurnitureMaterial;
  final String? idJenis;
  final String? namaJenis;

  final num? beratProdukHasilTimbang;

  /// ✅ normalized for UI: always "HH:mm" (or null)
  final String? hourStart;
  final String? hourEnd;

  /// date-only (or null)
  final DateTime? lastClosedDate;

  final bool isLocked;
  final bool isComplete;

  final bool isRealtime;
  final String? produksiStatus;

  /// Asal pembuatan produksi (persisted di backend, di-set saat create):
  /// - "realtime" -> input via kartu mesin  -> layar v3
  /// - "backdate" -> input via FAB riwayat  -> layar v1
  /// - null/kosong (data lama) -> default v1
  final String? inputMode;

  final String? outputCategory;
  final List<InjectOutputJenis> outputs;

  const InjectProduction({
    required this.noProduksi,
    required this.tglProduksi,
    required this.idMesin,
    required this.namaMesin,
    this.idRegu,
    this.namaRegu,
    required this.idOperator,
    required this.namaOperator,
    required this.jam,
    required this.shift,
    this.createBy,
    this.checkBy1,
    this.checkBy2,
    this.approveBy,
    required this.jmlhAnggota,
    required this.hadir,
    this.hourMeter,
    this.idCetakan,
    this.namaCetakan,
    this.idWarna,
    this.namaWarna,
    required this.enableOffset,
    this.offsetCurrent,
    this.offsetNext,
    this.idFurnitureMaterial,
    this.namaFurnitureMaterial,
    this.idJenis,
    this.namaJenis,
    this.beratProdukHasilTimbang,
    this.hourStart,
    this.hourEnd,
    this.lastClosedDate,
    required this.isLocked,
    this.isComplete = false,
    this.isRealtime = false,
    this.produksiStatus,
    this.inputMode,
    this.outputCategory,
    this.outputs = const [],
  });

  /// True bila produksi ini dibuat via kartu mesin (input realtime/batch).
  /// Menentukan layar input: realtime -> v3, selain itu (termasuk data lama
  /// tanpa [inputMode]) -> v1.
  bool get isRealtimeInput =>
      inputMode?.toLowerCase().trim() == 'realtime';

  // -------------------- tolerant parsers --------------------

  static String _asString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    return v.toString();
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'y' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'n' || s == 'no') return false;
    }
    return fallback;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    return null;
  }

  /// ✅ normalize many time formats into "HH:mm" for UI + validators
  /// Accepts:
  /// - "08:00"
  /// - "08:00:00"
  /// - ISO "1970-01-01T08:00:00.000Z"
  /// - DateTime
  static String? _asHHmm(dynamic v) {
    if (v == null) return null;

    if (v is DateTime) {
      final hh = v.hour.toString().padLeft(2, '0');
      final mm = v.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final s = v.toString().trim();
    if (s.isEmpty) return null;

    // "08:00"
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(s)) return s;

    // "08:00:00" -> "08:00"
    final m1 = RegExp(r'^(\d{2}:\d{2}):\d{2}$').firstMatch(s);
    if (m1 != null) return m1.group(1)!;

    // ISO "...T08:00:00.000Z" -> "08:00"
    final m2 = RegExp(r'T(\d{2}:\d{2})').firstMatch(s);
    if (m2 != null) return m2.group(1)!;

    // fallback parse DateTime string
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    return null;
  }

  factory InjectProduction.fromJson(Map<String, dynamic> j) {
    return InjectProduction(
      noProduksi: _asString(j['NoProduksi']),
      tglProduksi: _asDateTime(j['TglProduksi']),

      idMesin: _asInt(j['IdMesin']),
      namaMesin: _asString(j['NamaMesin']),

      idRegu: (j['IdRegu'] as num?)?.toInt(),
      namaRegu: j['NamaRegu']?.toString(),
      idOperator: _asInt(j['IdOperator']),
      namaOperator: _asString(j['NamaOperator']),

      jam: _asInt(j['Jam']),
      shift: _asInt(j['Shift']),

      createBy: j['CreateBy']?.toString(),
      checkBy1: j['CheckBy1']?.toString(),
      checkBy2: j['CheckBy2']?.toString(),
      approveBy: j['ApproveBy']?.toString(),

      jmlhAnggota: _asInt(j['JmlhAnggota']),
      hadir: _asInt(j['Hadir']),

      hourMeter: _asNum(j['HourMeter']),
      idCetakan: (j['IdCetakan'] as num?)?.toInt(),
      namaCetakan: j['NamaCetakan']?.toString(),
      idWarna: (j['IdWarna'] as num?)?.toInt(),
      namaWarna: j['Warna']?.toString() ?? j['NamaWarna']?.toString(),

      enableOffset: _asBool(j['EnableOffset'], fallback: false),
      offsetCurrent: _asNum(j['OffsetCurrent']),
      offsetNext: _asNum(j['OffsetNext']),

      idFurnitureMaterial: (j['IdFurnitureMaterial'] as num?)?.toInt(),
      namaFurnitureMaterial: j['NamaFurnitureMaterial']?.toString() ??
          j['NamaFurnitureMat']?.toString(),
      idJenis:
          j['IdJenis']?.toString() ??
          j['idJenis']?.toString() ??
          j['IdFurnitureWIP']?.toString() ??
          j['IdFurnitureWip']?.toString(),
      namaJenis:
          j['NamaJenis']?.toString() ??
          j['namaJenis']?.toString() ??
          j['NamaFurnitureWIP']?.toString() ??
          j['NamaFurnitureWip']?.toString(),
      beratProdukHasilTimbang: _asNum(j['BeratProdukHasilTimbang']),

      // ✅ normalized to "HH:mm"
      hourStart: _asHHmm(j['HourStart']),
      hourEnd: _asHHmm(j['HourEnd']),

      lastClosedDate: _asDateTime(j['LastClosedDate']),
      isLocked: _asBool(j['IsLocked'], fallback: false),
      isComplete: _asBool(j['IsComplete'], fallback: false) ||
          j['status']?.toString() == 'complete',
      isRealtime: j['status']?.toString() == 'current' ||
          j['status']?.toString() == 'pending' ||
          _asBool(j['IsRealtime'], fallback: false),
      produksiStatus: j['status']?.toString(),
      inputMode: j['InputMode']?.toString(),
      outputCategory: j['OutputCategory']?.toString(),
      outputs: (j['Outputs'] as List<dynamic>? ?? [])
          .map((e) => InjectOutputJenis.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'NoProduksi': noProduksi,
      'TglProduksi': tglProduksi?.toIso8601String(),

      'IdMesin': idMesin,
      'NamaMesin': namaMesin,
      'IdOperator': idOperator,
      'NamaOperator': namaOperator,

      'Jam': jam,
      'Shift': shift,

      'CreateBy': createBy,
      'CheckBy1': checkBy1,
      'CheckBy2': checkBy2,
      'ApproveBy': approveBy,

      'JmlhAnggota': jmlhAnggota,
      'Hadir': hadir,

      'HourMeter': hourMeter,
      'IdCetakan': idCetakan,
      'IdWarna': idWarna,

      'EnableOffset': enableOffset,
      'OffsetCurrent': offsetCurrent,
      'OffsetNext': offsetNext,

      'IdFurnitureMaterial': idFurnitureMaterial,
      'IdJenis': idJenis,
      'NamaJenis': namaJenis,
      'BeratProdukHasilTimbang': beratProdukHasilTimbang,

      // ✅ store as HH:mm (UI-friendly); submit layer can convert to HH:mm:ss
      'HourStart': hourStart,
      'HourEnd': hourEnd,

      'LastClosedDate': lastClosedDate?.toIso8601String(),
      'IsLocked': isLocked,
    };
  }

  InjectProduction copyWith({
    String? namaJenis,
    String? namaMesin,
    String? namaCetakan,
    String? namaWarna,
    String? namaFurnitureMaterial,
    String? hourStart,
    String? hourEnd,
  }) {
    return InjectProduction(
      noProduksi: noProduksi,
      tglProduksi: tglProduksi,
      idMesin: idMesin,
      namaMesin: namaMesin ?? this.namaMesin,
      idOperator: idOperator,
      namaOperator: namaOperator,
      jam: jam,
      shift: shift,
      createBy: createBy,
      checkBy1: checkBy1,
      checkBy2: checkBy2,
      approveBy: approveBy,
      jmlhAnggota: jmlhAnggota,
      hadir: hadir,
      hourMeter: hourMeter,
      idCetakan: idCetakan,
      namaCetakan: namaCetakan ?? this.namaCetakan,
      idWarna: idWarna,
      namaWarna: namaWarna ?? this.namaWarna,
      enableOffset: enableOffset,
      offsetCurrent: offsetCurrent,
      offsetNext: offsetNext,
      idFurnitureMaterial: idFurnitureMaterial,
      namaFurnitureMaterial: namaFurnitureMaterial ?? this.namaFurnitureMaterial,
      idJenis: idJenis,
      namaJenis: namaJenis ?? this.namaJenis,
      beratProdukHasilTimbang: beratProdukHasilTimbang,
      hourStart: hourStart ?? this.hourStart,
      hourEnd: hourEnd ?? this.hourEnd,
      lastClosedDate: lastClosedDate,
      isLocked: isLocked,
    );
  }

  /// Optional helper for UI
  String get jamLabel => jam <= 0 ? '-' : '${jam.toString().padLeft(2, '0')}:00';

  bool get hasHourRange =>
      (hourStart != null && hourStart!.trim().isNotEmpty) &&
          (hourEnd != null && hourEnd!.trim().isNotEmpty);
}

// ── Mesin-screen models (endpoint: GET /api/mst-mesin/inject) ──────────────

class InjectOutputJenis {
  final int idJenis;
  final String namaJenis;
  final String outputCategory;

  const InjectOutputJenis({
    required this.idJenis,
    required this.namaJenis,
    this.outputCategory = 'furniturewip',
  });

  factory InjectOutputJenis.fromJson(Map<String, dynamic> j) =>
      InjectOutputJenis(
        idJenis: (j['idJenis'] as num?)?.toInt() ?? 0,
        namaJenis: j['namaJenis']?.toString() ?? '',
        outputCategory: j['outputCategory']?.toString() ?? 'furniturewip',
      );
}

class InjectProduksiItem {
  final String noProduksi;
  final DateTime? tglProduksi;
  final int? idRegu;
  final String? namaRegu;
  final int? idCetakan;
  final String? namaCetakan;
  final int? idWarna;
  final String? warna;
  final int? idFurnitureMaterial;
  final String? namaFurnitureMaterial;
  final List<int> idOperators;
  final String? operators;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;
  final String? outputCategory;
  final List<InjectOutputJenis> outputs;
  final bool isLocked;
  final bool isRealtime;

  const InjectProduksiItem({
    required this.noProduksi,
    this.tglProduksi,
    this.idRegu,
    this.namaRegu,
    this.idCetakan,
    this.namaCetakan,
    this.idWarna,
    this.warna,
    this.idFurnitureMaterial,
    this.namaFurnitureMaterial,
    this.idOperators = const [],
    this.operators,
    this.shift,
    this.hourStart,
    this.hourEnd,
    this.outputCategory,
    this.outputs = const [],
    this.isLocked = false,
    this.isRealtime = false,
  });

  int? get idOperator => idOperators.isNotEmpty ? idOperators.first : null;

  factory InjectProduksiItem.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) =>
        v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    int? i(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }
    String? timeHHmm(dynamic v) {
      final raw = s(v);
      if (raw == null) return null;
      final isoTime = RegExp(r'T(\d{2}):(\d{2})').firstMatch(raw);
      if (isoTime != null) return '${isoTime.group(1)}:${isoTime.group(2)}';
      final parts = raw.split(':');
      if (parts.length < 2) return raw;
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }

    List<int> parseIdOperators(dynamic v) {
      if (v is List) return v.map((e) => i(e) ?? 0).where((e) => e != 0).toList();
      final single = i(v);
      return single != null ? [single] : [];
    }

    return InjectProduksiItem(
      noProduksi: s(j['NoProduksi']) ?? '',
      tglProduksi: j['TglProduksi'] != null
          ? DateTime.tryParse(j['TglProduksi'].toString())
          : null,
      idRegu: i(j['IdRegu']),
      namaRegu: s(j['NamaRegu']),
      idCetakan: i(j['IdCetakan']),
      namaCetakan: s(j['NamaCetakan']),
      idWarna: i(j['IdWarna']),
      warna: s(j['Warna']),
      idFurnitureMaterial: i(j['IdFurnitureMaterial']),
      namaFurnitureMaterial: s(j['NamaFurnitureMaterial']),
      idOperators: parseIdOperators(j['IdOperators'] ?? j['IdOperator']),
      operators: s(j['Operators']) ?? s(j['Operator']),
      shift: i(j['Shift']),
      hourStart: timeHHmm(j['HourStart']),
      hourEnd: timeHHmm(j['HourEnd']),
      outputCategory: s(j['OutputCategory']),
      outputs: (j['Outputs'] as List<dynamic>? ?? [])
          .map((e) => InjectOutputJenis.fromJson(e as Map<String, dynamic>))
          .toList(),
      isLocked: j['IsLocked'] == true || j['IsLocked'] == 1,
      isRealtime: j['status']?.toString() == 'current' ||
          j['IsRealtime'] == true ||
          j['IsRealtime'] == 1,
    );
  }
}

enum MachineStatus { active, pending, inactive }

class InjectMesinInfo {
  final int idMesin;
  final String namaMesin;
  final String bagian;
  final List<InjectProduksiItem> produksiList;
  final MachineStatus machineStatus;

  bool get isActive => machineStatus == MachineStatus.active;
  bool get isPending => machineStatus == MachineStatus.pending;
  bool get hasProduction => produksiList.isNotEmpty;

  String? get noProduksi =>
      produksiList.isNotEmpty ? produksiList.first.noProduksi : null;
  int? get shift => produksiList.isNotEmpty ? produksiList.first.shift : null;
  String? get hourStart =>
      produksiList.isNotEmpty ? produksiList.first.hourStart : null;
  String? get hourEnd =>
      produksiList.isNotEmpty ? produksiList.first.hourEnd : null;
  String? get namaRegu =>
      produksiList.isNotEmpty ? produksiList.first.namaRegu : null;
  String? get namaCetakan =>
      produksiList.isNotEmpty ? produksiList.first.namaCetakan : null;
  String? get outputCategory =>
      produksiList.isNotEmpty ? produksiList.first.outputCategory : null;
  List<InjectOutputJenis> get outputs =>
      produksiList.isNotEmpty ? produksiList.first.outputs : const [];

  const InjectMesinInfo({
    required this.idMesin,
    required this.namaMesin,
    required this.bagian,
    this.produksiList = const [],
    this.machineStatus = MachineStatus.inactive,
  });

  factory InjectMesinInfo.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) =>
        v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    int? i(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    MachineStatus parseStatus(dynamic v) {
      switch (v?.toString()) {
        case 'current':
        case 'active':
        case 'aktif':
          return MachineStatus.active;
        case 'pending': return MachineStatus.pending;
        default: return MachineStatus.inactive;
      }
    }

    final List<InjectProduksiItem> items = [];
    if (s(j['NoProduksi']) != null) {
      items.add(InjectProduksiItem.fromJson(j));
    }

    return InjectMesinInfo(
      idMesin: i(j['IdMesin']) ?? 0,
      namaMesin: s(j['NamaMesin']) ?? '',
      bagian: s(j['Bagian']) ?? '',
      produksiList: items,
      machineStatus: parseStatus(j['status'] ?? j['machineStatus']),
    );
  }
}
