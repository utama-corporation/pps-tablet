class InjectPcsPerLabelItem {
  final int idJenis;
  final String namaBarang;
  final int pcsPerLabel;

  /// Target pcs untuk label PERTAMA di noProduksi ini, kalau ada sisa
  /// (defisit) menggantung dari noProduksi sebelumnya di mesin+jenis yang
  /// sama. Null = tidak ada defisit pending, pakai [pcsPerLabel] dari awal.
  final int? pcsPerLabelAwal;

  const InjectPcsPerLabelItem({
    required this.idJenis,
    required this.namaBarang,
    required this.pcsPerLabel,
    this.pcsPerLabelAwal,
  });

  factory InjectPcsPerLabelItem.fromJson(Map<String, dynamic> j) {
    return InjectPcsPerLabelItem(
      idJenis: (j['idJenis'] as num?)?.toInt() ?? 0,
      namaBarang: j['namaBarang']?.toString() ?? '',
      pcsPerLabel: (j['pcsPerLabel'] as num?)?.toInt() ?? 0,
      pcsPerLabelAwal: (j['pcsPerLabelAwal'] as num?)?.toInt(),
    );
  }
}

class InjectPcsPerLabelResult {
  final String outputCategory;
  final List<InjectPcsPerLabelItem> items;
  final int? counterCurrent;
  final double? standarBerat;
  final double? standarCycleTime;

  const InjectPcsPerLabelResult({
    required this.outputCategory,
    required this.items,
    this.counterCurrent,
    this.standarBerat,
    this.standarCycleTime,
  });

  /// Returns pcsPerLabel for a given idJenis, falls back to first item, then 100.
  int pplForJenis(int idJenis) {
    for (final item in items) {
      if (item.idJenis == idJenis) return item.pcsPerLabel.clamp(1, 999999);
    }
    if (items.isNotEmpty) return items.first.pcsPerLabel.clamp(1, 999999);
    return 100;
  }

  /// Map of idJenis -> pcsPerLabel (clamped >= 1).
  Map<int, int> get pplByJenis => {
    for (final i in items) i.idJenis: i.pcsPerLabel.clamp(1, 999999),
  };

  /// Target pcs untuk label pertama di noProduksi ini untuk [idJenis],
  /// kalau ada defisit pending dari noProduksi sebelumnya. Null = tidak ada.
  int? initialPplForJenis(int idJenis) {
    for (final item in items) {
      if (item.idJenis == idJenis) return item.pcsPerLabelAwal;
    }
    return null;
  }

  /// Map of idJenis -> pcsPerLabelAwal, hanya untuk jenis yang punya defisit pending.
  Map<int, int> get initialPplByJenis => {
    for (final i in items)
      if (i.pcsPerLabelAwal != null) i.idJenis: i.pcsPerLabelAwal!,
  };

  factory InjectPcsPerLabelResult.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'] as List<dynamic>? ?? [];
    double? asNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return InjectPcsPerLabelResult(
      outputCategory: j['outputCategory']?.toString() ?? '',
      counterCurrent: (j['counterCurrent'] as num?)?.toInt(),
      standarBerat: asNullableDouble(j['standarBerat']),
      standarCycleTime: asNullableDouble(j['standarCycleTime']),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(InjectPcsPerLabelItem.fromJson)
          .toList(),
    );
  }
}

class InjectBatchLabelItem {
  final String code;
  final String namaJenis;
  final int? pcs;
  final double? berat;
  final int hasBeenPrinted;

  const InjectBatchLabelItem({
    required this.code,
    this.namaJenis = '',
    this.pcs,
    this.berat,
    this.hasBeenPrinted = 0,
  });

  factory InjectBatchLabelItem.fromJson(Map<String, dynamic> j) {
    final code =
        (j['noFurnitureWIP'] ??
                j['noBarangJadi'] ??
                j['noBonggolan'] ??
                j['noReject'] ??
                j['code'] ??
                '')
            .toString();
    return InjectBatchLabelItem(
      code: code,
      namaJenis:
          (j['namaJenis'] ??
                  j['namaBarang'] ??
                  j['namaBonggolan'] ??
                  j['namaReject'])
              ?.toString() ??
          '',
      pcs: (j['pcs'] as num?)?.toInt(),
      berat: (j['berat'] as num?)?.toDouble(),
      hasBeenPrinted: (j['hasBeenPrinted'] as num?)?.toInt() ?? 0,
    );
  }

  factory InjectBatchLabelItem.codeOnly(String code) =>
      InjectBatchLabelItem(code: code);
}

class InjectBatchLabels {
  final List<InjectBatchLabelItem> furnitureWip;
  final List<InjectBatchLabelItem> barangJadi;
  final List<InjectBatchLabelItem> bonggolan;
  final List<InjectBatchLabelItem> reject;

  const InjectBatchLabels({
    required this.furnitureWip,
    required this.barangJadi,
    required this.bonggolan,
    required this.reject,
  });

  factory InjectBatchLabels.fromJson(Map<String, dynamic> j) {
    List<InjectBatchLabelItem> asList(dynamic v) =>
        (v as List<dynamic>?)?.map((e) {
          if (e is Map<String, dynamic>) {
            return InjectBatchLabelItem.fromJson(e);
          }
          return InjectBatchLabelItem.codeOnly(e.toString());
        }).toList() ??
        [];
    return InjectBatchLabels(
      furnitureWip: asList(j['furnitureWip']),
      barangJadi: asList(j['barangJadi']),
      bonggolan: asList(j['bonggolan']),
      reject: asList(j['reject']),
    );
  }

  static const empty = InjectBatchLabels(
    furnitureWip: [],
    barangJadi: [],
    bonggolan: [],
    reject: [],
  );
}

class InjectBatchJenisItem {
  final int idJenis;
  final String outputCategory;
  final int carryOverIn;
  final int pcsInput;
  final int carryOverOut;

  const InjectBatchJenisItem({
    required this.idJenis,
    required this.outputCategory,
    required this.carryOverIn,
    required this.pcsInput,
    required this.carryOverOut,
  });

  factory InjectBatchJenisItem.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return InjectBatchJenisItem(
      idJenis: asInt(j['idJenis']),
      outputCategory: j['outputCategory']?.toString() ?? '',
      carryOverIn: asInt(j['carryOverIn']),
      pcsInput: asInt(j['pcsInput']),
      carryOverOut: asInt(j['carryOverOut']),
    );
  }
}

class InjectBatchItem {
  final int id;
  final String noProduksi;
  final String hourStart;
  final int carryOverIn;
  final int pcsInput;
  final int carryOverOut;
  final double? berat;
  final double? cycleTime;
  final int? counter;
  final DateTime? dateTimeCreate;
  final String? keterangan;
  final bool isDowntime;
  final InjectBatchLabels labels;
  final List<InjectBatchJenisItem> jenisItems;

  const InjectBatchItem({
    required this.id,
    required this.noProduksi,
    required this.hourStart,
    required this.carryOverIn,
    required this.pcsInput,
    required this.carryOverOut,
    this.berat,
    this.cycleTime,
    this.counter,
    this.dateTimeCreate,
    this.keterangan,
    this.isDowntime = false,
    this.labels = InjectBatchLabels.empty,
    this.jenisItems = const [],
  });

  factory InjectBatchItem.fromJson(Map<String, dynamic> j) {
    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double? asNullableDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? asNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final labelsRaw = j['labels'];
    final labels = labelsRaw is Map<String, dynamic>
        ? InjectBatchLabels.fromJson(labelsRaw)
        : InjectBatchLabels.empty;

    final rawJenisItems = j['items'] as List<dynamic>? ?? [];
    final jenisItems = rawJenisItems
        .whereType<Map<String, dynamic>>()
        .map(InjectBatchJenisItem.fromJson)
        .toList();

    // Derive flat totals from jenisItems if available, else fall back to top-level fields
    final totalCarryIn = jenisItems.isNotEmpty
        ? jenisItems.fold<int>(0, (s, i) => s + i.carryOverIn)
        : asInt(j['carryOverIn']);
    final totalPcsInput = jenisItems.isNotEmpty
        ? jenisItems.fold<int>(0, (s, i) => s + i.pcsInput)
        : asInt(j['pcsInput']);
    final totalCarryOut = jenisItems.isNotEmpty
        ? jenisItems.fold<int>(0, (s, i) => s + i.carryOverOut)
        : asInt(j['carryOverOut']);

    return InjectBatchItem(
      id: asInt(j['id']),
      noProduksi: j['noProduksi']?.toString() ?? '',
      hourStart: j['hourStart']?.toString() ?? '',
      carryOverIn: totalCarryIn,
      pcsInput: totalPcsInput,
      carryOverOut: totalCarryOut,
      berat: asNullableDouble(j['berat']),
      cycleTime: asNullableDouble(j['cycleTime']),
      counter: asNullableInt(j['counter']),
      dateTimeCreate: DateTime.tryParse(
        j['dateTimeCreate']?.toString() ?? '',
      )?.toLocal(),
      keterangan: j['keterangan']?.toString(),
      isDowntime: j['isDowntime'] == true,
      labels: labels,
      jenisItems: jenisItems,
    );
  }
}

class InjectBatchSubmitResult {
  final int batchId;
  final String hourStart;
  final List<InjectBatchLabelItem> furnitureWIP;
  final List<InjectBatchLabelItem> barangJadi;

  /// Semua label sisa akhir shift yang tercipta pada batch ini — satu batch
  /// boleh berisi banyak jenis bonggolan maupun reject.
  final List<InjectBatchLabelItem> bonggolanList;
  final List<InjectBatchLabelItem> rejectList;

  final String? keterangan;
  final bool isDowntime;

  const InjectBatchSubmitResult({
    required this.batchId,
    required this.hourStart,
    required this.furnitureWIP,
    required this.barangJadi,
    this.bonggolanList = const [],
    this.rejectList = const [],
    this.keterangan,
    this.isDowntime = false,
  });

  /// Kode label bonggolan pertama — dipakai untuk backward compatibility.
  InjectBatchLabelItem? get bonggolan =>
      bonggolanList.isEmpty ? null : bonggolanList.first;

  /// Kode label reject pertama — dipakai untuk backward compatibility.
  InjectBatchLabelItem? get reject =>
      rejectList.isEmpty ? null : rejectList.first;

  factory InjectBatchSubmitResult.fromJson(Map<String, dynamic> raw) {
    // Endpoint Returning body lengkap `{ success, message, data: {...} }`,
    // sedangkan isi payload ada di `data`. Kalau `raw` sudah berupa payload
    // langsung (tanpa pembungkus), dipakai apa adanya.
    final j =
        (raw['data'] is Map<String, dynamic>)
            ? (raw['data'] as Map<String, dynamic>)
            : raw;
    final batch = (j['batch'] as Map<String, dynamic>?) ?? {};

    List<InjectBatchLabelItem> parseList(dynamic v) =>
        (v as List<dynamic>?)?.map((e) {
          if (e is Map<String, dynamic>) return InjectBatchLabelItem.fromJson(e);
          return InjectBatchLabelItem.codeOnly(e.toString());
        }).toList() ??
        [];

    InjectBatchLabelItem? parseSingle(dynamic v) {
      if (v == null) return null;
      if (v is Map<String, dynamic>) return InjectBatchLabelItem.fromJson(v);
      final s = v.toString();
      return s.isEmpty ? null : InjectBatchLabelItem.codeOnly(s);
    }

    // Backend lama hanya mengirim key skalar (elemen pertama) — synthesize
    // list satu elemen supaya pemanggil baru tetap bisa membaca.
    List<InjectBatchLabelItem> parseListOrSingle(
      dynamic list,
      dynamic single,
    ) {
      if (list is List && list.isNotEmpty) return parseList(list);
      final item = parseSingle(single);
      return item == null
          ? <InjectBatchLabelItem>[]
          : <InjectBatchLabelItem>[item];
    }

    return InjectBatchSubmitResult(
      batchId: (batch['id'] as num?)?.toInt() ?? 0,
      hourStart: batch['hourStart']?.toString() ?? '',
      furnitureWIP: parseList(j['furnitureWIP']),
      barangJadi: parseList(j['barangJadi']),
      bonggolanList: parseListOrSingle(j['bonggolanList'], j['bonggolan']),
      rejectList: parseListOrSingle(j['rejectList'], j['reject']),
      keterangan: batch['keterangan']?.toString(),
      isDowntime: batch['isDowntime'] == true,
    );
  }
}
