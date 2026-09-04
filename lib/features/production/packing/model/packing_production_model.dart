// lib/features/shared/packing_production/model/packing_production_model.dart
import 'package:intl/intl.dart';

import '../../inject/model/inject_production_model.dart' show MachineStatus;

class PackingProduction {
  final String noPacking;
  final int idMesin;
  final int idOperator;
  final List<int> idOperators;
  final int? idRegu;
  final int? outputJenisId;
  final String? outputJenisNama;

  final String namaMesin;
  final String namaOperator;

  final DateTime? tglProduksi; // backend field: Tanggal
  final int shift;

  /// Backend field "JamKerja"
  final int? jamKerja;

  final String createBy;

  final double? hourMeter;

  final String? checkBy1;
  final String? checkBy2;
  final String? approveBy;

  /// TIME fields "HH:mm"
  final String? hourStart;
  final String? hourEnd;

  // ✅ Tutup transaksi flags (optional from backend)
  final DateTime? lastClosedDate; // date only
  final bool isLocked;
  final bool isComplete;
  final String? produksiStatus;

  const PackingProduction({
    required this.noPacking,
    required this.idMesin,
    required this.idOperator,
    required this.namaMesin,
    required this.namaOperator,
    required this.tglProduksi,
    required this.shift,
    required this.createBy,
    this.idOperators = const [],
    this.idRegu,
    this.outputJenisId,
    this.outputJenisNama,
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

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
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
      return DateFormat('HH:mm').format(v.isUtc ? v : v.toUtc());
    }

    // String: "HH:mm[:ss[.fff]]" atau "1900-01-01T07:30:00.000Z"
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;

      final asDt = DateTime.tryParse(s);
      if (asDt != null) {
        // Backend mengirim time-only sebagai datetime dengan tanggal dummy (1900/1970).
        // Selalu baca jam dari UTC agar tidak terkena konversi timezone.
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

  factory PackingProduction.fromJson(Map<String, dynamic> j) {
    return PackingProduction(
      noPacking: _asString(j['NoPacking']),
      idMesin: _asIntRequired(j['IdMesin']),
      idOperator: _asIntRequired(j['IdOperator']),
      idOperators: (j['IdOperators'] as List<dynamic>? ?? [])
          .map((e) => _asIntRequired(e))
          .toList(),
      idRegu: _asInt(j['IdRegu']),
      outputJenisId: _asInt(j['OutputJenisId']),
      outputJenisNama: j['OutputJenisNama']?.toString(),
      namaMesin: _asString(j['NamaMesin']),
      namaOperator: _asString(j['NamaOperator']),

      // backend packing list pakai 'Tanggal'
      tglProduksi: _asDateTime(j['Tanggal'] ?? j['TglProduksi']),
      shift: _asIntRequired(j['Shift']),
      createBy: _asString(j['CreateBy']),

      checkBy1: (j['CheckBy1'] == null || j['CheckBy1'] == '')
          ? null
          : _asString(j['CheckBy1']),
      checkBy2: (j['CheckBy2'] == null || j['CheckBy2'] == '')
          ? null
          : _asString(j['CheckBy2']),
      approveBy: (j['ApproveBy'] == null || j['ApproveBy'] == '')
          ? null
          : _asString(j['ApproveBy']),

      jamKerja: _asInt(j['JamKerja']),
      hourMeter: _asDouble(j['HourMeter']),
      hourStart: _asTimeHHmm(j['HourStart']),
      hourEnd: _asTimeHHmm(j['HourEnd']),

      // ✅ optional lock flags if backend sends
      lastClosedDate: _asDateTime(j['LastClosedDate']),
      isLocked: _asBool(j['IsLocked']),
      isComplete: _asBool(j['IsComplete']) ||
          j['status']?.toString() == 'complete',
      produksiStatus: j['status']?.toString(),
    );
  }

  /// Default output: list/detail (PascalCase).
  /// For create/update payload: camelCase keys like backend expects.
  Map<String, dynamic> toJson({
    bool asDateOnly = true,
    bool forWritePayload = false,
  }) {
    if (forWritePayload) {
      return {
        'noPacking': noPacking,
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
      'NoPacking': noPacking,
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
      'LastClosedDate': lastClosedDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(lastClosedDate!),
      'IsLocked': isLocked,
    };
  }

  // --- text helpers (same vibe as spanner) ---
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

  PackingProduction copyWith({
    String? noPacking,
    int? idMesin,
    int? idOperator,
    List<int>? idOperators,
    int? idRegu,
    int? outputJenisId,
    String? outputJenisNama,
    String? namaMesin,
    String? namaOperator,
    DateTime? tglProduksi,
    int? shift,
    String? createBy,
    int? jamKerja,
    double? hourMeter,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    String? hourStart,
    String? hourEnd,
    DateTime? lastClosedDate,
    bool? isLocked,
    bool? isComplete,
    String? produksiStatus,
  }) {
    return PackingProduction(
      noPacking: noPacking ?? this.noPacking,
      idMesin: idMesin ?? this.idMesin,
      idOperator: idOperator ?? this.idOperator,
      idOperators: idOperators ?? this.idOperators,
      idRegu: idRegu ?? this.idRegu,
      outputJenisId: outputJenisId ?? this.outputJenisId,
      outputJenisNama: outputJenisNama ?? this.outputJenisNama,
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
    );
  }
}

// ── Mesin Info (from /api/mst-mesin/packing) ─────────────────────────────────

class PackingMesinInfo {
  final int idMesin;
  final String namaMesin;
  final String? bagian;

  final String? noProduksi;
  final DateTime? tglProduksi;
  final int? idRegu;
  final String? namaRegu;
  final int? outputJenisId;
  final String? outputJenisNama;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;
  final MachineStatus machineStatus;

  const PackingMesinInfo({
    required this.idMesin,
    required this.namaMesin,
    this.bagian,
    this.noProduksi,
    this.tglProduksi,
    this.idRegu,
    this.namaRegu,
    this.outputJenisId,
    this.outputJenisNama,
    this.shift,
    this.hourStart,
    this.hourEnd,
    this.machineStatus = MachineStatus.inactive,
  });

  bool get hasProduction => noProduksi != null;
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

  static String? _asTimeHHmm(dynamic v) {
    if (v == null) return null;
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

  factory PackingMesinInfo.fromJson(Map<String, dynamic> j) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    DateTime? asDateTime(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String && v.trim().isNotEmpty) return DateTime.tryParse(v.trim());
      return null;
    }

    return PackingMesinInfo(
      idMesin: asInt(j['IdMesin']) ?? 0,
      namaMesin: j['NamaMesin']?.toString() ?? '',
      bagian: j['Bagian']?.toString(),
      noProduksi: j['NoProduksi']?.toString(),
      tglProduksi: asDateTime(j['TglProduksi']),
      idRegu: asInt(j['IdRegu']),
      namaRegu: j['NamaRegu']?.toString(),
      outputJenisId: asInt(j['OutputJenisId']),
      outputJenisNama: j['OutputJenisNama']?.toString(),
      shift: asInt(j['Shift']),
      hourStart: _asTimeHHmm(j['HourStart']),
      hourEnd: _asTimeHHmm(j['HourEnd']),
      machineStatus: parseStatus(j['status'] ?? j['machineStatus'] ?? j['MachineStatus']),
    );
  }
}
