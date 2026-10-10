import 'package:intl/intl.dart';

import 'sr_v2_label_info.dart';

class SrV2InputLabel {
  final String noBJ;
  final DateTime? dateCreate;
  final int idJenis;
  final String namaJenis;
  final int pcs;
  final String? createBy;
  final String? category;

  /// Qty asli label. Backend mengirim `pcs`; untuk bahan pendukung nilainya
  /// berasal dari `dbo.BahanPendukung.Qty` yang bisa pecahan.
  final double qty;

  const SrV2InputLabel({
    required this.noBJ,
    this.dateCreate,
    required this.idJenis,
    required this.namaJenis,
    required this.pcs,
    this.createBy,
    this.category,
    this.qty = 0,
  });

  static String _s(dynamic v) => v?.toString() ?? '';
  static String _labelCode(Map<String, dynamic> j) {
    return _s(
      j['NoBJ'] ??
          j['noBJ'] ??
          j['NoFurnitureWIP'] ??
          j['noFurnitureWIP'] ??
          j['noFurnitureWip'] ??
          j['NoFurnitureWIPPartial'] ??
          j['noFurnitureWIPPartial'] ??
          j['noFurnitureWipPartial'] ??
          j['NoBahanPendukung'] ??
          j['noBahanPendukung'] ??
          j['noBahanPendukungPartial'] ??
          j['NoReject'] ??
          j['noReject'] ??
          j['labelCode'],
    );
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  factory SrV2InputLabel.fromJson(Map<String, dynamic> j) {
    final rawQty = j['qty'] ?? j['Qty'] ?? j['pcs'] ?? j['Pcs'];
    return SrV2InputLabel(
      noBJ: _labelCode(j),
      dateCreate: j['DateCreate'] != null
          ? DateTime.tryParse(j['DateCreate'].toString())
          : null,
      idJenis: _i(j['idJenis']),
      namaJenis: _s(j['namaJenis']),
      pcs: _i(j['pcs']),
      createBy: j['createBy'] != null
          ? _s(j['createBy'])
          : j['CreateBy'] != null
          ? _s(j['CreateBy'])
          : null,
      category: j['category'] != null ? _s(j['category']) : null,
      qty: _d(rawQty),
    );
  }

  SrV2Category get parsedCategory =>
      SrV2Category.fromRaw(category, labelCode: noBJ);

  bool get isBahanPendukung =>
      parsedCategory == SrV2Category.bahanPendukung;
}

class SrV2OutputLabel {
  final String? noBJ;
  final String? category;
  final int idJenis;
  final String namaJenis;
  final int pcs;
  final double? berat;

  const SrV2OutputLabel({
    this.noBJ,
    this.category,
    required this.idJenis,
    required this.namaJenis,
    required this.pcs,
    this.berat,
  });

  static String _s(dynamic v) => v?.toString() ?? '';
  static String? _labelCode(Map<String, dynamic> j) {
    final value =
        j['NoBJ'] ??
        j['noBJ'] ??
        j['NoFurnitureWIP'] ??
        j['noFurnitureWIP'] ??
        j['noFurnitureWip'] ??
        j['NoFurnitureWIPPartial'] ??
        j['noFurnitureWIPPartial'] ??
        j['noFurnitureWipPartial'] ??
        j['NoReject'] ??
        j['noReject'] ??
        j['labelCode'];
    if (value == null) return null;
    final text = _s(value);
    return text.isEmpty ? null : text;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double? _dOpt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory SrV2OutputLabel.fromJson(Map<String, dynamic> j) {
    return SrV2OutputLabel(
      noBJ: _labelCode(j),
      category: j['category'] != null ? _s(j['category']) : null,
      idJenis: _i(j['idJenis']),
      namaJenis: _s(j['namaJenis']),
      pcs: _i(j['pcs']),
      berat: _dOpt(j['berat']),
    );
  }
}

class SrV2Transaction {
  final String noSortir;
  final DateTime? tanggal;
  final int? idWarehouse;
  final String? namaWarehouse;
  final int? idUsername;
  final String? username;
  final String? category;
  final int? inputLabelCount;
  final int? outputLabelCount;
  final bool? balance;
  final int? totalPcsInput;
  final int? totalPcsOutput;
  final double? totalBeratOutput;
  final List<SrV2InputLabel> inputs;
  final List<SrV2OutputLabel> outputs;

  const SrV2Transaction({
    required this.noSortir,
    this.tanggal,
    this.idWarehouse,
    this.namaWarehouse,
    this.idUsername,
    this.username,
    this.category,
    this.inputLabelCount,
    this.outputLabelCount,
    this.balance,
    this.totalPcsInput,
    this.totalPcsOutput,
    this.totalBeratOutput,
    this.inputs = const [],
    this.outputs = const [],
  });

  static String _s(dynamic v) => v?.toString() ?? '';
  static int? _iOpt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _dOpt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }

  static List<dynamic> _listFrom(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value;
    return const [];
  }

  static List<Map<String, dynamic>> _outputRows(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (value is Map) {
      final rows = <Map<String, dynamic>>[];
      for (final entry in value.entries) {
        final category = entry.key.toString();
        final items = _listFrom(entry.value);
        for (final item in items) {
          final row = Map<String, dynamic>.from(item as Map);
          row.putIfAbsent('category', () => category);
          rows.add(row);
        }
      }
      return rows;
    }
    return const [];
  }

  factory SrV2Transaction.fromJson(Map<String, dynamic> j) {
    final inputsRaw = _listFrom(j['inputs'] ?? j['Inputs']);
    final outputsRaw = _outputRows(j['outputs'] ?? j['Outputs']);

    final inputs = inputsRaw.map<SrV2InputLabel>((e) {
      if (e is String) {
        return SrV2InputLabel(noBJ: e, idJenis: 0, namaJenis: '', pcs: 0);
      }
      return SrV2InputLabel.fromJson(Map<String, dynamic>.from(e as Map));
    }).toList();

    final outputs = outputsRaw.map(SrV2OutputLabel.fromJson).toList();

    bool? balance;
    if (j['balance'] != null) {
      balance = j['balance'] is bool
          ? j['balance'] as bool
          : j['balance'].toString().toLowerCase() == 'true';
    }

    return SrV2Transaction(
      noSortir: _s(j['noBJSortir'] ?? j['NoBJSortir']),
      tanggal: (j['tglBJSortir'] ?? j['TglBJSortir']) != null
          ? DateTime.tryParse((j['tglBJSortir'] ?? j['TglBJSortir']).toString())
          : null,
      idWarehouse: _iOpt(j['idWarehouse'] ?? j['IdWarehouse']),
      namaWarehouse: j['namaWarehouse'] != null
          ? _s(j['namaWarehouse'])
          : j['NamaWarehouse'] != null
          ? _s(j['NamaWarehouse'])
          : null,
      idUsername: _iOpt(j['idUsername'] ?? j['IdUsername']),
      username: j['username'] != null
          ? _s(j['username'])
          : j['Username'] != null
          ? _s(j['Username'])
          : null,
      category: j['category'] != null ? _s(j['category']) : null,
      inputLabelCount: _iOpt(j['inputLabelCount']),
      outputLabelCount: _iOpt(j['outputLabelCount']),
      balance: balance,
      totalPcsInput: _iOpt(j['totalPcsInput']),
      totalPcsOutput: _iOpt(j['totalPcsOutput']),
      totalBeratOutput: _dOpt(j['totalBeratOutput']),
      inputs: inputs,
      outputs: outputs,
    );
  }

  String get tanggalText {
    if (tanggal == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tanggal!.toLocal());
  }

  SrV2Category get parsedCategory => SrV2Category.fromRaw(category);

  bool get isBahanPendukung =>
      parsedCategory == SrV2Category.bahanPendukung;
}
