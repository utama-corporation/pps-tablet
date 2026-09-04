import 'package:intl/intl.dart';

import '../../inject/model/inject_production_model.dart' show MachineStatus;

class BrokerProduction {
  final String noProduksi;
  /// List of operator IDs (multi-operator support)
  final List<int> idOperators;
  final int idMesin;
  final String namaMesin;
  /// Comma-separated operator names e.g. "ABDUL HAKIM, RAMOT"
  final String namaOperators;
  final String? outputJenisNama;
  final int? outputJenisId;
  final DateTime? tglProduksi;
  final int jamKerja;
  final int shift;
  final String createBy;
  final int? jmlhAnggota;
  final int? hadir;
  final int? hourMeter;
  final String? checkBy1;
  final String? checkBy2;
  final String? approveBy;
  final int? idRegu;
  final String? namaRegu;

  // time range
  final String? hourStart; // "HH:mm"
  final String? hourEnd;   // "HH:mm"

  // tutup transaksi flags
  final DateTime? lastClosedDate;
  final bool isLocked;

  // complete status
  final bool isComplete;
  final String? produksiStatus;

  const BrokerProduction({
    required this.noProduksi,
    required this.idOperators,
    required this.idMesin,
    required this.namaMesin,
    required this.namaOperators,
    this.outputJenisNama,
    this.outputJenisId,
    required this.tglProduksi,
    required this.jamKerja,
    required this.shift,
    required this.createBy,
    this.jmlhAnggota,
    this.hadir,
    this.hourMeter,
    this.checkBy1,
    this.checkBy2,
    this.approveBy,
    this.idRegu,
    this.namaRegu,
    this.hourStart,
    this.hourEnd,
    this.lastClosedDate,
    this.isLocked = false,
    this.isComplete = false,
    this.produksiStatus,
  });

  // ── Backward-compat getters ──────────────────────────────────────────────
  /// First operator ID (or 0 if empty). Use `idOperators` for full list.
  int get idOperator => idOperators.isNotEmpty ? idOperators.first : 0;
  /// Comma-separated operator names. Alias for `namaOperators`.
  String get namaOperator => namaOperators;

  // ---------- tolerant parsers ----------
  static String _asString(dynamic v) => v?.toString() ?? '';

  static int _asIntRequired(dynamic v, {int fallback = 0}) {
    final r = _asInt(v);
    return r ?? fallback;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static bool _asBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is double) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return fallback;
  }

  // normalize MSSQL TIME to "HH:mm"
  static String? _asTimeHHmm(dynamic v) {
    if (v == null) return null;

    if (v is DateTime) {
      return DateFormat('HH:mm').format(v.isUtc ? v : v.toUtc());
    }

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;

      final asDt = DateTime.tryParse(s);
      if (asDt != null) {
        // Server stores TIME as epoch datetime in UTC (e.g. 1970-01-01T08:00:00.000Z).
        // Always read the UTC hour to avoid timezone shift.
        return DateFormat('HH:mm').format(asDt.toUtc());
      }

      final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
      if (m != null) {
        final hh = m.group(1)!.padLeft(2, '0');
        final mm = m.group(2)!;
        return '$hh:$mm';
      }
    }

    return null;
  }

  factory BrokerProduction.fromJson(Map<String, dynamic> j) {
    return BrokerProduction(
      noProduksi: _asString(j['NoProduksi']),
      idOperators: (j['IdOperators'] as List?)
              ?.map((e) => _asIntRequired(e))
              .toList() ??
          [],
      idMesin: _asIntRequired(j['IdMesin']),
      namaMesin: _asString(j['NamaMesin']),
      namaOperators: _asString(j['NamaOperators']),
      outputJenisNama: (j['OutputJenisNama'] == null || _asString(j['OutputJenisNama']).trim().isEmpty)
          ? null
          : _asString(j['OutputJenisNama']),
      outputJenisId: _asInt(j['OutputJenisId']),
      tglProduksi: _asDateTime(j['TglProduksi']),
      jamKerja: _asIntRequired(j['JamKerja']),
      shift: _asIntRequired(j['Shift']),
      createBy: _asString(j['CreateBy']),
      checkBy1: (j['CheckBy1'] == null || j['CheckBy1'] == '') ? null : _asString(j['CheckBy1']),
      checkBy2: (j['CheckBy2'] == null || j['CheckBy2'] == '') ? null : _asString(j['CheckBy2']),
      approveBy: (j['ApproveBy'] == null || j['ApproveBy'] == '') ? null : _asString(j['ApproveBy']),
      jmlhAnggota: _asInt(j['JmlhAnggota']),
      hadir: _asInt(j['Hadir']),
      hourMeter: _asInt(j['HourMeter']),
      idRegu: _asInt(j['IdRegu']),
      namaRegu: _asString(j['NamaRegu']),
      hourStart: _asTimeHHmm(j['HourStart']),
      hourEnd: _asTimeHHmm(j['HourEnd']),

      lastClosedDate: _asDateTime(j['LastClosedDate']),
      isLocked: _asBool(j['IsLocked']),
      isComplete: _asBool(j['IsComplete'], fallback: false) ||
          j['status']?.toString() == 'complete',
      produksiStatus: j['status']?.toString() ??
          (_asBool(j['IsComplete'], fallback: false) ? 'complete' : 'pending'),
    );
  }

  Map<String, dynamic> toJson({bool asDateOnly = true}) => {
    'NoProduksi': noProduksi,
    'IdOperators': idOperators,
    'IdMesin': idMesin,
    'NamaMesin': namaMesin,
    'NamaOperators': namaOperators,
    'OutputJenisNama': outputJenisNama,
    'TglProduksi': tglProduksi == null
        ? null
        : (asDateOnly
        ? DateFormat('yyyy-MM-dd').format(tglProduksi!)
        : tglProduksi!.toIso8601String()),
    'JamKerja': jamKerja,
    'Shift': shift,
    'CreateBy': createBy,
    'CheckBy1': checkBy1,
    'CheckBy2': checkBy2,
    'ApproveBy': approveBy,
    'JmlhAnggota': jmlhAnggota,
    'Hadir': hadir,
    'HourMeter': hourMeter,
    'HourStart': hourStart,
    'HourEnd': hourEnd,
    'IdRegu': idRegu,
    'NamaRegu': namaRegu,

    // biasanya ini tidak perlu dikirim balik (read-only)
    // 'LastClosedDate': lastClosedDate?.toIso8601String(),
    // 'IsLocked': isLocked,
  };

  String get tglProduksiTextShort {
    if (tglProduksi == null) return '';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tglProduksi!.toLocal());
  }

  String get tglProduksiTextFull {
    if (tglProduksi == null) return '';
    return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tglProduksi!.toLocal());
  }

  String get hourRangeText {
    if ((hourStart == null || hourStart!.isEmpty) &&
        (hourEnd == null || hourEnd!.isEmpty)) return '';
    return '${hourStart ?? '--:--'} - ${hourEnd ?? '--:--'}';
  }

  // ✅ Optional helper untuk UI: tampilkan info lock
  String get lockInfoText {
    if (!isLocked) return '';
    if (lastClosedDate == null) return 'Locked';
    final d = DateFormat('dd MMM yyyy', 'id_ID').format(lastClosedDate!.toLocal());
    return 'Locked (<= $d)';
  }
}

class BrokerProduksiItem {
  final String noProduksi;
  final DateTime? tglProduksi;
  final int? outputJenisId;
  final String? outputJenisNama;
  final String? outputJenisItemCode;
  /// List of operator IDs (multi-operator)
  final List<int> idOperators;
  /// Comma-separated operator names e.g. "ABDUL HAKIM, RAMOT"
  final String? operators;
  final int? idRegu;
  final String? namaRegu;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;

  const BrokerProduksiItem({
    required this.noProduksi,
    this.tglProduksi,
    this.outputJenisId,
    this.outputJenisNama,
    this.outputJenisItemCode,
    this.idOperators = const [],
    this.operators,
    this.idRegu,
    this.namaRegu,
    this.shift,
    this.hourStart,
    this.hourEnd,
  });

  // ── Backward-compat getters ──────────────────────────────────────────────
  int? get idOperator => idOperators.isNotEmpty ? idOperators.first : null;
  String? get operator_ => operators;

  factory BrokerProduksiItem.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) => v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    int? i(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }
    String? timeHHmm(dynamic v) {
      final raw = s(v);
      if (raw == null) return null;
      final parts = raw.split(':');
      if (parts.length < 2) return raw;
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }

    // Parse IdOperators — support both array (new) and single int (legacy)
    List<int> parseIdOperators(dynamic v) {
      if (v is List) return v.map((e) => i(e) ?? 0).where((e) => e != 0).toList();
      final single = i(v);
      return single != null ? [single] : [];
    }

    return BrokerProduksiItem(
      noProduksi: s(j['NoProduksi']) ?? '',
      tglProduksi: j['TglProduksi'] != null ? DateTime.tryParse(j['TglProduksi'].toString()) : null,
      outputJenisId: i(j['OutputJenisId']),
      outputJenisNama: s(j['OutputJenisNama']),
      outputJenisItemCode: s(j['OutputJenisItemCode']),
      idOperators: parseIdOperators(j['IdOperators'] ?? j['IdOperator']),
      operators: s(j['Operators']) ?? s(j['Operator']),
      idRegu: i(j['IdRegu']),
      namaRegu: s(j['NamaRegu']),
      shift: i(j['Shift']),
      hourStart: timeHHmm(j['HourStart']),
      hourEnd: timeHHmm(j['HourEnd']),
    );
  }
}

class BrokerMesinInfo {
  final int idMesin;
  final String namaMesin;
  final String bagian;
  final List<BrokerProduksiItem> produksiList;
  final MachineStatus machineStatus;

  bool get hasProduction => produksiList.isNotEmpty;
  bool get isActive => machineStatus == MachineStatus.active;
  bool get isPending => machineStatus == MachineStatus.pending;

  // backward-compat getters (first item)
  String? get noProduksi => produksiList.isNotEmpty ? produksiList.first.noProduksi : null;
  String? get operator_ => produksiList.isNotEmpty ? produksiList.first.operator_ : null;
  String? get namaRegu => produksiList.isNotEmpty ? produksiList.first.namaRegu : null;
  int? get shift => produksiList.isNotEmpty ? produksiList.first.shift : null;
  String? get hourStart => produksiList.isNotEmpty ? produksiList.first.hourStart : null;
  String? get hourEnd => produksiList.isNotEmpty ? produksiList.first.hourEnd : null;

  const BrokerMesinInfo({
    required this.idMesin,
    required this.namaMesin,
    required this.bagian,
    this.produksiList = const [],
    this.machineStatus = MachineStatus.inactive,
  });

  static MachineStatus parseStatus(dynamic v) {
    switch (v?.toString()) {
      case 'current':
      case 'active':
      case 'aktif':
        return MachineStatus.active;
      case 'pending':
        return MachineStatus.pending;
      default:
        return MachineStatus.inactive;
    }
  }

  factory BrokerMesinInfo.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) => v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    int? i(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    // API now returns flat structure — one item per mesin row.
    // Build a produksiList from the flat fields when NoProduksi is present.
    final List<BrokerProduksiItem> items = [];
    if (s(j['NoProduksi']) != null) {
      items.add(BrokerProduksiItem.fromJson(j));
    }

    return BrokerMesinInfo(
      idMesin: i(j['IdMesin']) ?? 0,
      namaMesin: s(j['NamaMesin']) ?? '',
      bagian: s(j['Bagian']) ?? '',
      produksiList: items,
      machineStatus: parseStatus(j['status'] ?? j['machineStatus'] ?? j['MachineStatus']),
    );
  }
}
