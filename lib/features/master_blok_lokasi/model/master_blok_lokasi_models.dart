class BlokRow {
  const BlokRow({
    required this.blok,
    required this.idWarehouse,
    required this.namaWarehouse,
  });

  final String blok;
  final int idWarehouse;
  final String namaWarehouse;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory BlokRow.fromJson(Map<String, dynamic> j) => BlokRow(
    blok: (j['Blok'] ?? '').toString(),
    idWarehouse: _toInt(j['IdWarehouse']),
    namaWarehouse: (j['NamaWarehouse'] ?? '').toString(),
  );
}

class LokasiRow {
  const LokasiRow({
    required this.idLokasi,
    required this.blok,
    required this.description,
    required this.enable,
  });

  final int idLokasi;
  final String blok;
  final String description;
  final bool enable;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory LokasiRow.fromJson(Map<String, dynamic> j) => LokasiRow(
    idLokasi: _toInt(j['IdLokasi']),
    blok: (j['Blok'] ?? '').toString(),
    description: (j['Description'] ?? '').toString(),
    enable: j['Enable'] == true || j['Enable'] == 1 || '${j['Enable']}' == '1',
  );
}

class WarehouseOption {
  const WarehouseOption(this.id, this.nama);

  final int id;
  final String nama;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory WarehouseOption.fromJson(Map<String, dynamic> j) => WarehouseOption(
    _toInt(j['IdWarehouse']),
    (j['NamaWarehouse'] ?? '').toString(),
  );
}

class KategoriKonfig {
  const KategoriKonfig({
    required this.id,
    required this.kode,
    required this.nama,
    required this.tableJenis,
    required this.colIdJenis,
    required this.colNamaJenis,
  });

  final int id;
  final String kode;
  final String nama;
  final String tableJenis;
  final String colIdJenis;
  final String colNamaJenis;

  /// Kategori yang punya konfigurasi master jenis bisa dipakai di
  /// relasi lokasi ↔ jenis.
  bool get hasJenisConfig =>
      tableJenis.trim().isNotEmpty &&
      colIdJenis.trim().isNotEmpty &&
      colNamaJenis.trim().isNotEmpty;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory KategoriKonfig.fromJson(Map<String, dynamic> j) => KategoriKonfig(
    id: _toInt(j['IdKategori']),
    kode: (j['KodeKategori'] ?? '').toString(),
    nama: (j['NamaKategori'] ?? '').toString(),
    tableJenis: (j['NamaTableJenis'] ?? '').toString(),
    colIdJenis: (j['NamaKolomIdJenis'] ?? '').toString(),
    colNamaJenis: (j['NamaKolomNamaJenis'] ?? '').toString(),
  );
}

class JenisOption {
  const JenisOption(this.id, this.nama);

  final int id;
  final String nama;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory JenisOption.fromJson(Map<String, dynamic> j) =>
      JenisOption(_toInt(j['Id']), (j['Nama'] ?? '').toString());
}

class LokasiJenisRow {
  const LokasiJenisRow({
    required this.blok,
    required this.idLokasi,
    required this.idKategori,
    required this.idJenis,
    required this.namaKategori,
    required this.namaJenis,
  });

  final String blok;
  final int idLokasi;
  final int idKategori;
  final int idJenis;
  final String namaKategori;
  final String namaJenis;

  static int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory LokasiJenisRow.fromJson(Map<String, dynamic> j) => LokasiJenisRow(
    blok: (j['Blok'] ?? '').toString(),
    idLokasi: _toInt(j['IdLokasi']),
    idKategori: _toInt(j['IdKategori']),
    idJenis: _toInt(j['IdJenis']),
    namaKategori: (j['NamaKategori'] ?? '').toString(),
    namaJenis: (j['NamaJenis'] ?? '').toString(),
  );
}

class BlokMaster {
  const BlokMaster({required this.warehouses, required this.kategoris});

  const BlokMaster.empty()
      : warehouses = const [],
        kategoris = const [];

  final List<WarehouseOption> warehouses;
  final List<KategoriKonfig> kategoris;

  List<KategoriKonfig> get jenisKategoris =>
      [for (final k in kategoris) if (k.hasJenisConfig) k];

  factory BlokMaster.fromJson(Map<String, dynamic> j) => BlokMaster(
    warehouses: [
      for (final e in (j['warehouses'] as List? ?? const []))
        if (e is Map)
          WarehouseOption.fromJson(Map<String, dynamic>.from(e)),
    ],
    kategoris: [
      for (final e in (j['kategoris'] as List? ?? const []))
        if (e is Map)
          KategoriKonfig.fromJson(Map<String, dynamic>.from(e)),
    ],
  );
}
