const String soV2UnknownBlok = 'TIDAK_DIKETAHUI';
const int soV2UnknownLocationId = 0;

class SoV2Lokasi {
  const SoV2Lokasi({
    required this.blok,
    required this.locationId,
    required this.description,
    required this.labelCount,
    required this.scannedCount,
    required this.totalQuantity,
  });

  final String blok;
  final int locationId;
  final String description;
  final int labelCount;
  final int scannedCount;
  final double totalQuantity;

  bool get isUnknown => locationId == soV2UnknownLocationId;
  double get progress => labelCount == 0 ? 0 : scannedCount / labelCount;

  factory SoV2Lokasi.fromJson(Map<String, dynamic> json) {
    return SoV2Lokasi(
      blok: _asString(json['blok']),
      locationId: _asInt(json['locationId'] ?? json['IdLokasi']),
      description: _asString(
        json['description'] ?? json['Description'] ?? json['Keterangan'],
      ),
      labelCount: _asInt(json['labelCount']),
      scannedCount: _asInt(json['scannedCount']),
      totalQuantity: _asDouble(json['totalWeight'] ?? json['totalPcs']),
    );
  }
}

class SoV2MyLokasi {
  const SoV2MyLokasi({
    required this.stockOpnameNo,
    required this.categoryCode,
    required this.location,
  });

  final String stockOpnameNo;
  final String categoryCode;
  final SoV2Lokasi location;

  factory SoV2MyLokasi.fromJson(Map<String, dynamic> json) {
    return SoV2MyLokasi(
      stockOpnameNo: _asString(json['stockOpnameNo']),
      categoryCode: _asString(json['categoryCode']),
      location: SoV2Lokasi.fromJson(json),
    );
  }
}

class SoV2LabelRow {
  const SoV2LabelRow({
    required this.primaryValue,
    required this.isScanned,
    required this.raw,
  });

  static const Set<String> _excludedKeys = {
    'NoSO',
    'isScanned',
    'IdJenisPlastik',
    'IdLokasi',
    'Blok',
    'IdBonggolan',
    'ScannedBlok',
    'ScannedIdLokasi',
    'isLocationMismatch',
  };

  final String primaryValue;
  final bool isScanned;
  final Map<String, dynamic> raw;

  factory SoV2LabelRow.fromJson(Map<String, dynamic> json) {
    final noBahanBaku = json['NoBahanBaku'];
    final noPallet = json['NoPallet'];
    final String primaryValue;
    if (noBahanBaku != null && noPallet != null) {
      // Bahan baku labels share one labelNo across several pallets, so the
      // pallet number is appended to disambiguate them in the label list.
      primaryValue = '${_asString(noBahanBaku)}-${_asString(noPallet)}';
    } else {
      final candidates = json.entries.where(
        (entry) => !_excludedKeys.contains(entry.key),
      );
      final entry = candidates.isEmpty ? json.entries.first : candidates.first;
      primaryValue = _asString(entry.value);
    }
    return SoV2LabelRow(
      primaryValue: primaryValue,
      isScanned: _asBool(json['isScanned']),
      raw: json,
    );
  }

  String? quantityDisplay(String unit) {
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase();
      if (entry.value == null) continue;
      if (key.contains('berat') || key.contains('pcs') || key.contains('qty')) {
        return '${soV2FormatQuantity(entry.value)} $unit';
      }
    }
    return null;
  }
}

class SoV2LabelGroup {
  const SoV2LabelGroup({
    required this.typeId,
    required this.typeName,
    required this.labelCount,
    required this.totalQuantity,
    required this.labels,
  });

  final int? typeId;
  final String typeName;
  final int labelCount;
  final double totalQuantity;
  final List<SoV2LabelRow> labels;

  int get scannedCount => labels.where((label) => label.isScanned).length;

  factory SoV2LabelGroup.fromJson(Map<String, dynamic> json) {
    return SoV2LabelGroup(
      typeId: json['typeId'] == null ? null : _asInt(json['typeId']),
      typeName: _asString(json['typeName']),
      labelCount: _asInt(json['labelCount']),
      totalQuantity: _asDouble(json['totalWeight'] ?? json['totalPcs']),
      labels: _asMapList(json['labels']).map(SoV2LabelRow.fromJson).toList(),
    );
  }
}

class SoV2LabelPage {
  const SoV2LabelPage({
    required this.categoryCode,
    required this.isComplete,
    required this.groups,
    required this.currentPage,
    required this.totalPages,
    required this.totalRecords,
    required this.totalScanned,
    required this.totalQuantity,
  });

  final String categoryCode;
  final bool isComplete;
  final List<SoV2LabelGroup> groups;
  final int currentPage;
  final int totalPages;
  final int totalRecords;
  final int totalScanned;
  final double totalQuantity;

  factory SoV2LabelPage.fromJson(Map<String, dynamic> json) {
    return SoV2LabelPage(
      categoryCode: _asString(json['categoryCode']),
      isComplete: _asBool(json['isComplete']),
      groups: _asMapList(json['data']).map(SoV2LabelGroup.fromJson).toList(),
      currentPage: _asInt(json['currentPage'], fallback: 1),
      totalPages: _asInt(json['totalPages'], fallback: 1),
      totalRecords: _asInt(json['totalRecords']),
      totalScanned: _asInt(json['totalScanned']),
      totalQuantity: _asDouble(json['totalWeight'] ?? json['totalPcs']),
    );
  }
}

String soV2FormatQuantity(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) return '$value';
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

bool _asBool(dynamic value) =>
    value == true || value == 1 || '$value'.toLowerCase() == 'true';

String _asString(dynamic value) => value?.toString() ?? '';

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
