// lib/features/shared/spanner_production/model/spanner_production_model.dart
import 'package:intl/intl.dart';

import '../../inject/model/inject_production_model.dart' show MachineStatus;

// ─────────────────────────────────────────────────────────────────────────────
// SpannerMesinInfo — untuk panel kiri mesin screen
// Hasil dari GET /api/mst-mesin/spanner
// ─────────────────────────────────────────────────────────────────────────────
class SpannerMesinInfo {
  final int idMesin;
  final String namaMesin;
  final String bagian;
  final String? noProduksi;
  final DateTime? tglProduksi;
  final int? idRegu;
  final String? namaRegu;
  final int? outputJenisId;
  final String? outputJenisNama;
  final List<int> idOperators;
  final String? operators;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;
  final MachineStatus machineStatus;

  bool get hasProduction => noProduksi != null && noProduksi!.isNotEmpty;
  bool get isActive => machineStatus == MachineStatus.active;
  bool get isPending => machineStatus == MachineStatus.pending;

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

  const SpannerMesinInfo({
    required this.idMesin,
    required this.namaMesin,
    required this.bagian,
    this.noProduksi,
    this.tglProduksi,
    this.idRegu,
    this.namaRegu,
    this.outputJenisId,
    this.outputJenisNama,
    this.idOperators = const [],
    this.operators,
    this.shift,
    this.hourStart,
    this.hourEnd,
    this.machineStatus = MachineStatus.inactive,
  });

  static String? _s(dynamic v) {
    final t = v?.toString().trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static int? _i(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v.trim());
    return null;
  }

  static String? _time(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return DateFormat('HH:mm').format(v.toUtc());
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final dt = DateTime.tryParse(s);
      if (dt != null) return DateFormat('HH:mm').format(dt.toUtc());
      final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
      if (m != null) {
        return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!}';
      }
    }
    return null;
  }

  factory SpannerMesinInfo.fromJson(Map<String, dynamic> j) {
    List<int> parseIdOperators(dynamic v) {
      if (v is List) {
        return v
            .map((e) => _i(e))
            .whereType<int>()
            .where((e) => e != 0)
            .toList();
      }
      final single = _i(v);
      return single != null ? [single] : [];
    }

    return SpannerMesinInfo(
      idMesin: _i(j['IdMesin']) ?? 0,
      namaMesin: _s(j['NamaMesin']) ?? '',
      bagian: _s(j['Bagian']) ?? '',
      noProduksi: _s(j['NoProduksi']),
      tglProduksi: _dt(j['TglProduksi']),
      idRegu: _i(j['IdRegu']),
      namaRegu: _s(j['NamaRegu']),
      outputJenisId: _i(j['OutputJenisId']),
      outputJenisNama: _s(j['OutputJenisNama']),
      idOperators: parseIdOperators(j['IdOperators']),
      operators: _s(j['Operators']),
      shift: _i(j['Shift']),
      hourStart: _time(j['HourStart']),
      hourEnd: _time(j['HourEnd']),
      machineStatus: parseStatus(j['status'] ?? j['machineStatus'] ?? j['MachineStatus']),
    );
  }
}

class SpannerProduction {
  final String noProduksi;
  final int idMesin;
  final int idOperator;

  final String namaMesin;
  final String namaOperator;

  final DateTime? tglProduksi;
  final int shift;

  /// Backend field "JamKerja"
  final int? jamKerja;

  final String createBy;

  final int? hourMeter;

  final String? checkBy1;
  final String? checkBy2;
  final String? approveBy;

  /// Jam kerja dalam format "HH:mm"
  final String? hourStart;
  final String? hourEnd;

  // ✅ Tutup transaksi flags (kalau backend kirim)
  final DateTime? lastClosedDate; // date only
  final bool isLocked;
  final bool isComplete;
  final String? produksiStatus;

  // ── New fields (API v2) ─────────────────────────────────────────
  final int? outputJenisId;
  final String? outputJenisNama;
  final int? idRegu;
  final String? namaRegu;
  final List<int> idOperators;

  const SpannerProduction({
    required this.noProduksi,
    required this.idMesin,
    required this.idOperator,
    required this.namaMesin,
    required this.namaOperator,
    required this.tglProduksi,
    required this.shift,
    required this.createBy,
    this.jamKerja,
    this.hourMeter,
    this.checkBy1,
    this.checkBy2,
    this.approveBy,
    this.hourStart,
    this.hourEnd,
    this.lastClosedDate,
    this.isLocked = false,
    this.isComplete = false,
    this.produksiStatus,
    this.outputJenisId,
    this.outputJenisNama,
    this.idRegu,
    this.namaRegu,
    this.idOperators = const [],
  });

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
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
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

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  /// Normalisasi MSSQL TIME ke "HH:mm"
  static String? _asTimeHHmm(dynamic v) {
    if (v == null) return null;

    // TIME kadang dimapping ke DateTime (1900-01-01 + time)
    if (v is DateTime) {
      return DateFormat('HH:mm').format(v.toLocal());
    }

    // String: "HH:mm[:ss[.fff]]" atau "1900-01-01T07:30:00"
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;

      final asDt = DateTime.tryParse(s);
      if (asDt != null) {
        return DateFormat('HH:mm').format(asDt.toLocal());
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

  static List<int> _parseIdOperators(dynamic v) {
    if (v is List) {
      return v
          .map((e) => _asInt(e))
          .whereType<int>()
          .where((e) => e != 0)
          .toList();
    }
    final single = _asInt(v);
    return single != null && single != 0 ? [single] : [];
  }

  factory SpannerProduction.fromJson(Map<String, dynamic> j) {
    return SpannerProduction(
      noProduksi: _asString(j['NoProduksi']),
      idMesin: _asIntRequired(j['IdMesin']),
      idOperator: _asIntRequired(j['IdOperator']),
      namaMesin: _asString(j['NamaMesin']),
      namaOperator: _asString(j['NamaOperator']),

      tglProduksi: _asDateTime(j['Tanggal'] ?? j['TglProduksi']),
      shift: _asIntRequired(j['Shift']),
      createBy: _asString(j['CreateBy']),
      checkBy1: j['CheckBy1'] == null || j['CheckBy1'] == ''
          ? null
          : _asString(j['CheckBy1']),
      checkBy2: j['CheckBy2'] == null || j['CheckBy2'] == ''
          ? null
          : _asString(j['CheckBy2']),
      approveBy: j['ApproveBy'] == null || j['ApproveBy'] == ''
          ? null
          : _asString(j['ApproveBy']),

      jamKerja: _asInt(j['JamKerja']),
      hourMeter: _asInt(j['HourMeter']),
      hourStart: _asTimeHHmm(j['HourStart']),
      hourEnd: _asTimeHHmm(j['HourEnd']),

      lastClosedDate: _asDateTime(j['LastClosedDate']),
      isLocked: _asBool(j['IsLocked']),
      isComplete: _asBool(j['IsComplete']) ||
          j['status']?.toString() == 'complete',
      produksiStatus: j['status']?.toString(),

      outputJenisId: _asInt(j['OutputJenisId']),
      outputJenisNama: j['OutputJenisNama']?.toString().trim().isEmpty ?? true
          ? null
          : j['OutputJenisNama']?.toString(),
      idRegu: _asInt(j['IdRegu']),
      namaRegu: j['NamaRegu']?.toString().trim().isEmpty ?? true
          ? null
          : j['NamaRegu']?.toString(),
      idOperators: _parseIdOperators(j['IdOperators']),
    );
  }

  /// Default: output "format list/detail" (PascalCase).
  /// Untuk create/update endpoint (keys kecil):
  Map<String, dynamic> toJson({
    bool asDateOnly = true,
    bool forWritePayload = false,
  }) {
    if (forWritePayload) {
      return {
        'noProduksi': noProduksi,
        'idMesin': idMesin,
        'idOperator': idOperator,
        'tglProduksi': tglProduksi == null
            ? null
            : (asDateOnly
            ? DateFormat('yyyy-MM-dd').format(tglProduksi!)
            : tglProduksi!.toIso8601String()),
        'shift': shift,
        'jamKerja': jamKerja,
        'checkBy1': checkBy1,
        'checkBy2': checkBy2,
        'approveBy': approveBy,
        'hourMeter': hourMeter,
        'hourStart': hourStart,
        'hourEnd': hourEnd,
      };
    }

    return {
      'NoProduksi': noProduksi,
      'IdMesin': idMesin,
      'IdOperator': idOperator,
      'NamaMesin': namaMesin,
      'NamaOperator': namaOperator,
      'Tanggal': tglProduksi == null
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
      'HourMeter': hourMeter,
      'HourStart': hourStart,
      'HourEnd': hourEnd,
    };
  }

  // --- text helpers (ikut hotstamp) ---
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
        (hourEnd == null || hourEnd!.isEmpty)) {
      return '';
    }
    return '${hourStart ?? '--:--'} - ${hourEnd ?? '--:--'}';
  }

  String get lockInfoText {
    if (!isLocked) return '';
    if (lastClosedDate == null) return 'Locked';
    final d = DateFormat('dd MMM yyyy', 'id_ID').format(lastClosedDate!.toLocal());
    return 'Locked (<= $d)';
  }

  bool get isEditable => !isLocked;

  String get lockStatusMessage {
    if (!isLocked) return 'Dapat diedit';
    if (lastClosedDate != null) {
      final d = DateFormat('dd/MM/yyyy').format(lastClosedDate!.toLocal());
      return 'Terkunci (Transaksi ditutup s/d $d)';
    }
    return 'Terkunci';
  }

  SpannerProduction copyWith({
    String? noProduksi,
    int? idMesin,
    int? idOperator,
    String? namaMesin,
    String? namaOperator,
    DateTime? tglProduksi,
    int? shift,
    String? createBy,
    int? jamKerja,
    int? hourMeter,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    String? hourStart,
    String? hourEnd,
    DateTime? lastClosedDate,
    bool? isLocked,
    bool? isComplete,
    String? produksiStatus,
    int? outputJenisId,
    String? outputJenisNama,
    int? idRegu,
    String? namaRegu,
    List<int>? idOperators,
  }) {
    return SpannerProduction(
      noProduksi: noProduksi ?? this.noProduksi,
      idMesin: idMesin ?? this.idMesin,
      idOperator: idOperator ?? this.idOperator,
      namaMesin: namaMesin ?? this.namaMesin,
      namaOperator: namaOperator ?? this.namaOperator,
      tglProduksi: tglProduksi ?? this.tglProduksi,
      shift: shift ?? this.shift,
      createBy: createBy ?? this.createBy,
      jamKerja: jamKerja ?? this.jamKerja,
      hourMeter: hourMeter ?? this.hourMeter,
      checkBy1: checkBy1 ?? this.checkBy1,
      checkBy2: checkBy2 ?? this.checkBy2,
      approveBy: approveBy ?? this.approveBy,
      hourStart: hourStart ?? this.hourStart,
      hourEnd: hourEnd ?? this.hourEnd,
      lastClosedDate: lastClosedDate ?? this.lastClosedDate,
      isLocked: isLocked ?? this.isLocked,
      isComplete: isComplete ?? this.isComplete,
      produksiStatus: produksiStatus ?? this.produksiStatus,
      outputJenisId: outputJenisId ?? this.outputJenisId,
      outputJenisNama: outputJenisNama ?? this.outputJenisNama,
      idRegu: idRegu ?? this.idRegu,
      namaRegu: namaRegu ?? this.namaRegu,
      idOperators: idOperators ?? this.idOperators,
    );
  }
}
