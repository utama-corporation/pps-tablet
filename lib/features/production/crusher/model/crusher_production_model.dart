import 'package:intl/intl.dart';

import '../../inject/model/inject_production_model.dart' show MachineStatus;

class CrusherProduction {
  final String noCrusherProduksi;
  final int idOperator;
  final int idMesin;
  final String namaMesin;
  final String namaOperator;
  final DateTime? tanggal;
  final int jamKerja;
  final int shift;
  final String createBy;
  final int? jmlhAnggota;
  final int? hadir;
  final num? hourMeter;
  final String? checkBy1;
  final String? checkBy2;
  final String? approveBy;

  final String? hourStart; // "HH:mm"
  final String? hourEnd;   // "HH:mm"

  /// Comma-separated outputs from subquery: "CR.0001, CR.0002"
  final String? outputNoCrusher;

  final int? outputJenisId;
  final String? outputJenisNama;

  final int? idRegu;
  final String? namaRegu;

  /// ✅ NEW: tutup transaksi flags
  final DateTime? lastClosedDate; // date only
  final bool isLocked;

  // complete status
  final bool isComplete;
  final String? produksiStatus;

  /// Convenience: parsed list of outputs (trimmed)
  List<String> get outputNoCrusherList =>
      (outputNoCrusher ?? '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

  const CrusherProduction({
    required this.noCrusherProduksi,
    required this.idOperator,
    required this.idMesin,
    required this.namaMesin,
    required this.namaOperator,
    required this.tanggal,
    required this.jamKerja,
    required this.shift,
    required this.createBy,
    this.jmlhAnggota,
    this.hadir,
    this.hourMeter,
    this.checkBy1,
    this.checkBy2,
    this.approveBy,
    this.hourStart,
    this.hourEnd,
    this.outputNoCrusher,
    this.outputJenisId,
    this.outputJenisNama,

    this.idRegu,
    this.namaRegu,
    // ✅ NEW
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
    if (v is String) return int.tryParse(v);
    return null;
  }

  static num? _asNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
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
      return DateFormat('HH:mm').format(v.toLocal());
    }

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;

      final asDt = DateTime.tryParse(s);
      if (asDt != null) {
        // Use UTC to avoid timezone shift on epoch-date time-only values
        // e.g. "1970-01-01T16:00:00.000Z" must stay 16:00, not 23:00 (UTC+7)
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

  factory CrusherProduction.fromJson(Map<String, dynamic> j) {
    return CrusherProduction(
      noCrusherProduksi: _asString(j['NoCrusherProduksi']),
      idOperator: _asIntRequired(j['IdOperator']),
      idMesin: _asIntRequired(j['IdMesin']),
      namaMesin: _asString(j['NamaMesin']),
      namaOperator: _asString(j['NamaOperator']),
      tanggal: _asDateTime(j['Tanggal']),
      jamKerja: _asIntRequired(j['JamKerja']),
      shift: _asIntRequired(j['Shift']),
      createBy: _asString(j['CreateBy']),
      checkBy1: (j['CheckBy1'] == null || j['CheckBy1'] == '') ? null : _asString(j['CheckBy1']),
      checkBy2: (j['CheckBy2'] == null || j['CheckBy2'] == '') ? null : _asString(j['CheckBy2']),
      approveBy: (j['ApproveBy'] == null || j['ApproveBy'] == '') ? null : _asString(j['ApproveBy']),
      jmlhAnggota: _asInt(j['JmlhAnggota']),
      hadir: _asInt(j['Hadir']),
      hourMeter: _asNum(j['HourMeter']),
      hourStart: _asTimeHHmm(j['HourStart']),
      hourEnd: _asTimeHHmm(j['HourEnd']),
      outputNoCrusher: (j['OutputNoCrusher'] == null || j['OutputNoCrusher'] == '')
          ? null
          : _asString(j['OutputNoCrusher']),
      outputJenisId: _asInt(j['OutputJenisId']),
      outputJenisNama: (j['OutputJenisNama'] == null || j['OutputJenisNama'] == '')
          ? null
          : _asString(j['OutputJenisNama']),

      idRegu: _asInt(j['IdRegu']),
      namaRegu: j['NamaRegu'] as String?,
      // ✅ NEW: mapping dari backend
      lastClosedDate: _asDateTime(j['LastClosedDate']),
      isLocked: _asBool(j['IsLocked']),
      isComplete: _asBool(j['IsComplete'], fallback: false) ||
          j['status']?.toString() == 'complete',
      produksiStatus: j['status']?.toString() ??
          (_asBool(j['IsComplete'], fallback: false) ? 'complete' : 'pending'),
    );
  }

  Map<String, dynamic> toJson({bool asDateOnly = true}) => {
    'NoCrusherProduksi': noCrusherProduksi,
    'IdOperator': idOperator,
    'IdMesin': idMesin,
    'NamaMesin': namaMesin,
    'NamaOperator': namaOperator,
    'Tanggal': tanggal == null
        ? null
        : (asDateOnly
        ? DateFormat('yyyy-MM-dd').format(tanggal!)
        : tanggal!.toIso8601String()),
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
    'OutputNoCrusher': outputNoCrusher,

    // biasanya read-only, tidak perlu dikirim balik
    // 'LastClosedDate': lastClosedDate?.toIso8601String(),
    // 'IsLocked': isLocked,
  };

  String get tanggalTextShort {
    if (tanggal == null) return '';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tanggal!.toLocal());
  }

  String get tanggalTextFull {
    if (tanggal == null) return '';
    return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(tanggal!.toLocal());
  }

  String get hourRangeText {
    if ((hourStart == null || hourStart!.isEmpty) &&
        (hourEnd == null || hourEnd!.isEmpty)) return '';
    return '${hourStart ?? '--:--'} - ${hourEnd ?? '--:--'}';
  }

  /// Optional: buat label UI
  String get lockInfoText {
    if (!isLocked) return '';
    if (lastClosedDate == null) return 'Locked';
    final d = DateFormat('dd MMM yyyy', 'id_ID').format(lastClosedDate!.toLocal());
    return 'Locked (<= $d)';
  }

  CrusherProduction copyWith({
    String? noCrusherProduksi,
    int? idOperator,
    int? idMesin,
    String? namaMesin,
    String? namaOperator,
    DateTime? tanggal,
    int? jamKerja,
    int? shift,
    String? createBy,
    int? jmlhAnggota,
    int? hadir,
    num? hourMeter,
    String? checkBy1,
    String? checkBy2,
    String? approveBy,
    String? hourStart,
    String? hourEnd,
    String? outputNoCrusher,
    int? outputJenisId,
    String? outputJenisNama,
    int? idRegu,
    String? namaRegu,
    DateTime? lastClosedDate,
    bool? isLocked,
    bool? isComplete,
    String? produksiStatus,
  }) {
    return CrusherProduction(
      noCrusherProduksi: noCrusherProduksi ?? this.noCrusherProduksi,
      idOperator: idOperator ?? this.idOperator,
      idMesin: idMesin ?? this.idMesin,
      namaMesin: namaMesin ?? this.namaMesin,
      namaOperator: namaOperator ?? this.namaOperator,
      tanggal: tanggal ?? this.tanggal,
      jamKerja: jamKerja ?? this.jamKerja,
      shift: shift ?? this.shift,
      createBy: createBy ?? this.createBy,
      jmlhAnggota: jmlhAnggota ?? this.jmlhAnggota,
      hadir: hadir ?? this.hadir,
      hourMeter: hourMeter ?? this.hourMeter,
      checkBy1: checkBy1 ?? this.checkBy1,
      checkBy2: checkBy2 ?? this.checkBy2,
      approveBy: approveBy ?? this.approveBy,
      hourStart: hourStart ?? this.hourStart,
      hourEnd: hourEnd ?? this.hourEnd,
      outputNoCrusher: outputNoCrusher ?? this.outputNoCrusher,
      outputJenisId: outputJenisId ?? this.outputJenisId,
      outputJenisNama: outputJenisNama ?? this.outputJenisNama,
      idRegu: idRegu ?? this.idRegu,
      namaRegu: namaRegu ?? this.namaRegu,
      lastClosedDate: lastClosedDate ?? this.lastClosedDate,
      isLocked: isLocked ?? this.isLocked,
      isComplete: isComplete ?? this.isComplete,
      produksiStatus: produksiStatus ?? this.produksiStatus,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CrusherMesinInfo — untuk panel kiri mesin screen
// ─────────────────────────────────────────────────────────────────────────────
class CrusherMesinInfo {
  final int idMesin;
  final String namaMesin;
  final String bagian;
  final String? noProduksi;
  final DateTime? tglProduksi;
  final int? outputJenisId;
  final String? outputJenisNama;
  final List<int> idOperators;
  final String? operators;
  final String? namaRegu;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;
  final MachineStatus machineStatus;

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

  const CrusherMesinInfo({
    required this.idMesin,
    required this.namaMesin,
    required this.bagian,
    this.noProduksi,
    this.tglProduksi,
    this.outputJenisId,
    this.outputJenisNama,
    this.idOperators = const [],
    this.operators,
    this.namaRegu,
    this.shift,
    this.hourStart,
    this.hourEnd,
    this.machineStatus = MachineStatus.inactive,
  });

  factory CrusherMesinInfo.fromJson(Map<String, dynamic> j) {
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
      final parts = raw.split(':');
      if (parts.length < 2) return raw;
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }

    final List<int> ids = [];
    final raw = j['IdOperators'];
    if (raw is List) {
      for (final x in raw) {
        final n = i(x);
        if (n != null) ids.add(n);
      }
    } else {
      final n = i(raw);
      if (n != null) ids.add(n);
    }

    return CrusherMesinInfo(
      idMesin: i(j['IdMesin']) ?? 0,
      namaMesin: s(j['NamaMesin']) ?? '',
      bagian: s(j['Bagian']) ?? '',
      noProduksi: s(j['NoProduksi']),
      tglProduksi: j['TglProduksi'] == null ? null : DateTime.tryParse(j['TglProduksi'].toString()),
      outputJenisId: i(j['OutputJenisId']),
      outputJenisNama: s(j['OutputJenisNama']),
      idOperators: ids,
      operators: s(j['Operators']),
      namaRegu: s(j['NamaRegu']),
      shift: i(j['Shift']),
      hourStart: timeHHmm(j['HourStart']),
      hourEnd: timeHHmm(j['HourEnd']),
      machineStatus: parseStatus(j['status'] ?? j['machineStatus'] ?? j['MachineStatus']),
    );
  }
}
