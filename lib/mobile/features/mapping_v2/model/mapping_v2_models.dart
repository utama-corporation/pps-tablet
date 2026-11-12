class MappingV2Blok {
  const MappingV2Blok({
    required this.blok,
    required this.idWarehouse,
    required this.namaWarehouse,
    required this.totalLokasi,
    required this.totalJenis,
  });

  final String blok;
  final int idWarehouse;
  final String namaWarehouse;
  final int totalLokasi;
  final int totalJenis;

  factory MappingV2Blok.fromJson(Map<String, dynamic> json) {
    return MappingV2Blok(
      blok: _asString(json['Blok']),
      idWarehouse: _asInt(json['IdWarehouse']),
      namaWarehouse: _asString(json['NamaWarehouse']),
      totalLokasi: _asInt(json['TotalLokasi']),
      totalJenis: _asInt(json['TotalJenis']),
    );
  }
}

class MappingV2Jenis {
  const MappingV2Jenis({
    required this.idKategori,
    required this.idJenis,
    required this.kodeKategori,
    required this.namaKategori,
    required this.namaJenis,
    required this.idUOM,
    required this.namaUOM,
  });

  final int idKategori;
  final int idJenis;
  final String kodeKategori;
  final String namaKategori;
  final String namaJenis;
  final int idUOM;
  final String namaUOM;

  factory MappingV2Jenis.fromJson(Map<String, dynamic> json) {
    return MappingV2Jenis(
      idKategori: _asInt(json['IdKategori']),
      idJenis: _asInt(json['IdJenis']),
      kodeKategori: _asString(json['KodeKategori']),
      namaKategori: _asString(json['NamaKategori']),
      namaJenis: _asString(json['NamaJenis']),
      idUOM: _asInt(json['IdUOM']),
      namaUOM: _asString(json['NamaUOM']),
    );
  }
}

class MappingV2Lokasi {
  const MappingV2Lokasi({
    required this.idLokasi,
    required this.blok,
    required this.description,
    required this.enable,
    required this.jenisList,
    required this.totalLabel,
    required this.totalQty,
    required this.totalBerat,
  });

  final int idLokasi;
  final String blok;
  final String? description;
  final bool enable;
  final List<MappingV2Jenis> jenisList;
  final int totalLabel;
  final double totalQty;
  final double totalBerat;

  factory MappingV2Lokasi.fromJson(Map<String, dynamic> json) {
    return MappingV2Lokasi(
      idLokasi: _asInt(json['IdLokasi']),
      blok: _asString(json['Blok']),
      description: _asNullableString(json['Description']),
      enable: _asBool(json['Enable']),
      jenisList: _asMapList(
        json['JenisList'],
      ).map(MappingV2Jenis.fromJson).toList(),
      totalLabel: _asInt(json['TotalLabel']),
      totalQty: _asDouble(json['TotalQty']),
      totalBerat: _asDouble(json['TotalBerat']),
    );
  }
}

class MappingV2Label {
  const MappingV2Label({
    required this.labelCode,
    required this.dateCreate,
    required this.blok,
    required this.idLokasi,
    required this.prefix,
    required this.kategori,
    required this.namaUOM,
    required this.qty,
    required this.berat,
    required this.idJenis,
    required this.namaJenis,
  });

  final String labelCode;
  final DateTime? dateCreate;
  final String blok;
  final int idLokasi;
  final String prefix;
  final String kategori;
  final String namaUOM;
  final double qty;
  final double berat;
  final int idJenis;
  final String namaJenis;

  static const Set<String> _pcsOnlyKategori = {'furniturewip', 'barangjadi'};

  bool get isPcsOnly => _pcsOnlyKategori.contains(
    kategori.toLowerCase().replaceAll(RegExp(r'[\s-]'), ''),
  );

  factory MappingV2Label.fromJson(Map<String, dynamic> json) {
    return MappingV2Label(
      labelCode: _asString(json['LabelCode']),
      dateCreate: DateTime.tryParse(_asString(json['DateCreate'])),
      blok: _asString(json['Blok']),
      idLokasi: _asInt(json['IdLokasi']),
      prefix: _asString(json['Prefix']),
      kategori: _asString(json['Kategori']),
      namaUOM: _asString(json['NamaUOM']),
      qty: _asDouble(json['Qty']),
      berat: _asDouble(json['Berat']),
      idJenis: _asInt(json['IdJenis']),
      namaJenis: _asString(json['NamaJenis']),
    );
  }
}

class MappingV2LabelPage {
  const MappingV2LabelPage({
    required this.items,
    required this.totalData,
    required this.currentPage,
    required this.totalPages,
    required this.perPage,
  });

  final List<MappingV2Label> items;
  final int totalData;
  final int currentPage;
  final int totalPages;
  final int perPage;

  factory MappingV2LabelPage.fromJson(Map<String, dynamic> json) {
    return MappingV2LabelPage(
      items: _asMapList(json['data']).map(MappingV2Label.fromJson).toList(),
      totalData: _asInt(json['totalData']),
      currentPage: _asInt(json['currentPage'], fallback: 1),
      totalPages: _asInt(json['totalPages'], fallback: 1),
      perPage: _asInt(json['perPage'], fallback: 50),
    );
  }
}

class MappingV2UpdateResult {
  const MappingV2UpdateResult({
    required this.message,
    required this.isNoChange,
    required this.labelCode,
    required this.afterBlok,
    required this.afterIdLokasi,
  });

  final String message;
  final bool isNoChange;
  final String labelCode;
  final String afterBlok;
  final int afterIdLokasi;

  factory MappingV2UpdateResult.fromJson(Map<String, dynamic> json) {
    final updated = json['updated'] is Map
        ? Map<String, dynamic>.from(json['updated'] as Map)
        : <String, dynamic>{};
    return MappingV2UpdateResult(
      message: _asString(json['message']),
      isNoChange: _asString(json['code']) == 'NO_CHANGE',
      labelCode: _asString(updated['labelCode']),
      afterBlok: _asString(updated['afterBlok']),
      afterIdLokasi: _asInt(updated['afterIdLokasi']),
    );
  }
}

String mappingV2FormatQuantity(dynamic value) {
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

String? _asNullableString(dynamic value) {
  final result = _asString(value).trim();
  return result.isEmpty || result.toLowerCase() == 'null' ? null : result;
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
