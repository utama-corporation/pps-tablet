// lib/features/shared/hot_stamp_production/model/hot_stamp_production_model.dart
import 'package:intl/intl.dart';

import '../../inject/model/inject_production_model.dart' show MachineStatus;

class HotStampProduction {
  final String noProduksi;
  final int idMesin;
  final int idOperator;
  final List<int> idOperators;

  final String namaMesin;
  final String namaOperator;

  final int? idRegu;
  final String? namaRegu;

  final int? outputJenisId;
  final String? outputJenisNama;

  final DateTime? tglProduksi;
  final int shift;

  final int? jamKerja;

  final String createBy;

  final int? hourMeter;

  final String? checkBy1;
  final String? checkBy2;
  final String? approveBy;

  final String? hourStart;
  final String? hourEnd;

  final DateTime? lastClosedDate;
  final bool isLocked;
  final bool isComplete;
  final String? produksiStatus;

  const HotStampProduction({
    required this.noProduksi,
    required this.idMesin,
    required this.idOperator,
    this.idOperators = const [],
    required this.namaMesin,
    required this.namaOperator,
    this.idRegu,
    this.namaRegu,
    this.outputJenisId,
    this.outputJenisNama,
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
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    return null;
  }

  /// Normalisasi MSSQL TIME ke "HH:mm"
  static String? _asTimeHHmm(dynamic v) {
    if (v == null) return null;

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;

      // ISO datetime (e.g. "1970-01-01T08:00:00.000Z") — ambil bagian waktu
      // langsung tanpa konversi timezone agar tidak geser karena UTC offset
      final isoTime = RegExp(r'T(\d{2}):(\d{2})').firstMatch(s);
      if (isoTime != null) {
        return '${isoTime.group(1)}:${isoTime.group(2)}';
      }

      // "HH:mm[:ss[.fff]]"
      final hhmm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s);
      if (hhmm != null) {
        return '${hhmm.group(1)!.padLeft(2, '0')}:${hhmm.group(2)}';
      }
    }

    // DateTime object — gunakan UTC agar konsisten dengan ISO string di atas
    if (v is DateTime) {
      return DateFormat('HH:mm').format(v.toUtc());
    }

    return null;
  }

  factory HotStampProduction.fromJson(Map<String, dynamic> j) {
    final rawIdOps = j['IdOperators'] ?? j['idOperators'];
    final List<int> idOperatorsList = rawIdOps is List
        ? rawIdOps.map((e) => _asIntRequired(e)).toList()
        : [];
    final singleId = _asIntRequired(j['IdOperator']);

    return HotStampProduction(
      noProduksi: _asString(j['NoProduksi']),
      idMesin: _asIntRequired(j['IdMesin']),
      idOperator: idOperatorsList.isNotEmpty ? idOperatorsList.first : singleId,
      idOperators: idOperatorsList.isNotEmpty
          ? idOperatorsList
          : (singleId != 0 ? [singleId] : []),
      namaMesin: _asString(j['NamaMesin']),
      namaOperator: _asString(j['NamaOperator'] ?? j['NamaOperators'] ?? ''),
      idRegu: _asInt(j['IdRegu']),
      namaRegu: j['NamaRegu'] == null ||
              _asString(j['NamaRegu']).trim().isEmpty
          ? null
          : _asString(j['NamaRegu']),
      outputJenisId: _asInt(j['OutputJenisId']),
      outputJenisNama: j['OutputJenisNama'] == null ||
              _asString(j['OutputJenisNama']).trim().isEmpty
          ? null
          : _asString(j['OutputJenisNama']),
      tglProduksi: _asDateTime(j['TglProduksi'] ?? j['Tanggal']),
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
    );
  }

  /// Default: output "format list/detail" (PascalCase).
  /// Untuk create/update endpoint yang minta key kecil:
  /// - set `forWritePayload: true` => pakai keys kecil.
  Map<String, dynamic> toJson({
    bool asDateOnly = true,
    bool forWritePayload = false,
  }) {
    if (forWritePayload) {
      return {
        'noProduksi': noProduksi,
        'idMesin': idMesin,
        'idOperator': idOperator,
        'tanggal': tglProduksi == null
            ? null
            : (asDateOnly
            ? DateFormat('yyyy-MM-dd').format(tglProduksi!)
            : tglProduksi!.toIso8601String()),
        'jam': jamKerja,
        'shift': shift,
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
      'HourMeter': hourMeter,
      'HourStart': hourStart,
      'HourEnd': hourEnd,

      // read-only: tidak perlu dikirim balik
      // 'LastClosedDate': lastClosedDate?.toIso8601String(),
      // 'IsLocked': isLocked,
    };
  }

  // --- text helpers ---
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

  /// Info lock untuk UI
  String get lockInfoText {
    if (!isLocked) return '';
    if (lastClosedDate == null) return 'Locked';
    final d = DateFormat('dd MMM yyyy', 'id_ID')
        .format(lastClosedDate!.toLocal());
    return 'Locked (<= $d)';
  }

  /// Check apakah bisa diedit
  bool get isEditable => !isLocked;

  /// Status message lengkap untuk lock
  String get lockStatusMessage {
    if (!isLocked) return 'Dapat diedit';
    if (lastClosedDate != null) {
      final d = DateFormat('dd/MM/yyyy').format(lastClosedDate!.toLocal());
      return 'Terkunci (Transaksi ditutup s/d $d)';
    }
    return 'Terkunci';
  }

  HotStampProduction copyWith({
    String? noProduksi,
    int? idMesin,
    int? idOperator,
    List<int>? idOperators,
    String? namaMesin,
    String? namaOperator,
    int? idRegu,
    String? namaRegu,
    int? outputJenisId,
    String? outputJenisNama,
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
  }) {
    return HotStampProduction(
      noProduksi: noProduksi ?? this.noProduksi,
      idMesin: idMesin ?? this.idMesin,
      idOperator: idOperator ?? this.idOperator,
      idOperators: idOperators ?? this.idOperators,
      namaMesin: namaMesin ?? this.namaMesin,
      namaOperator: namaOperator ?? this.namaOperator,
      idRegu: idRegu ?? this.idRegu,
      namaRegu: namaRegu ?? this.namaRegu,
      outputJenisId: outputJenisId ?? this.outputJenisId,
      outputJenisNama: outputJenisNama ?? this.outputJenisNama,
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

class HotStampProduksiItem {
  final String noProduksi;
  final DateTime? tglProduksi;
  final int? outputJenisId;
  final String? outputJenisNama;
  final List<int> idOperators;
  final String? operators;
  final int? idRegu;
  final String? namaRegu;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;

  const HotStampProduksiItem({
    required this.noProduksi,
    this.tglProduksi,
    this.outputJenisId,
    this.outputJenisNama,
    this.idOperators = const [],
    this.operators,
    this.idRegu,
    this.namaRegu,
    this.shift,
    this.hourStart,
    this.hourEnd,
  });

  int? get idOperator => idOperators.isNotEmpty ? idOperators.first : null;

  factory HotStampProduksiItem.fromJson(Map<String, dynamic> j) {
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
      final dt = DateTime.tryParse(raw);
      if (dt != null) return DateFormat('HH:mm').format(dt.toUtc());
      final parts = raw.split(':');
      if (parts.length < 2) return raw;
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }

    List<int> parseIdOperators(dynamic v) {
      if (v is List) return v.map((e) => i(e) ?? 0).where((e) => e != 0).toList();
      final single = i(v);
      return single != null ? [single] : [];
    }

    return HotStampProduksiItem(
      noProduksi: s(j['NoProduksi']) ?? '',
      tglProduksi: j['TglProduksi'] != null
          ? DateTime.tryParse(j['TglProduksi'].toString())
          : null,
      outputJenisId: i(j['OutputJenisId']),
      outputJenisNama: s(j['OutputJenisNama']),
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

class HotStampMesinInfo {
  final int idMesin;
  final String namaMesin;
  final String bagian;
  final List<HotStampProduksiItem> produksiList;
  final MachineStatus machineStatus;

  bool get hasProduction => produksiList.isNotEmpty;
  bool get isActive => machineStatus == MachineStatus.active;
  bool get isPending => machineStatus == MachineStatus.pending;

  String? get noProduksi =>
      produksiList.isNotEmpty ? produksiList.first.noProduksi : null;
  int? get shift => produksiList.isNotEmpty ? produksiList.first.shift : null;
  String? get hourStart =>
      produksiList.isNotEmpty ? produksiList.first.hourStart : null;
  String? get hourEnd =>
      produksiList.isNotEmpty ? produksiList.first.hourEnd : null;
  String? get namaRegu =>
      produksiList.isNotEmpty ? produksiList.first.namaRegu : null;
  String? get outputJenisNama =>
      produksiList.isNotEmpty ? produksiList.first.outputJenisNama : null;
  int? get outputJenisId =>
      produksiList.isNotEmpty ? produksiList.first.outputJenisId : null;

  const HotStampMesinInfo({
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

  factory HotStampMesinInfo.fromJson(Map<String, dynamic> j) {
    String? s(dynamic v) =>
        v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();
    int? i(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final List<HotStampProduksiItem> items = [];
    if (s(j['NoProduksi']) != null) {
      items.add(HotStampProduksiItem.fromJson(j));
    }

    return HotStampMesinInfo(
      idMesin: i(j['IdMesin']) ?? 0,
      namaMesin: s(j['NamaMesin']) ?? '',
      bagian: s(j['Bagian']) ?? '',
      produksiList: items,
      machineStatus: parseStatus(j['status'] ?? j['machineStatus'] ?? j['MachineStatus']),
    );
  }
}