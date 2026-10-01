import '../../../../core/utils/model_helpers.dart';

class CabinetMaterialItem {
  // ===== MASTER/STOCK FIELDS (sesuai result SQL stock) =====
  final int? IdCabinetMaterial;
  final String? Nama;
  final String? ItemCode;
  final String? NamaUOM;

  final int? IdWarehouse;
  final String? NamaWarehouse;

  // Isipcs master (dbo.MstCabinetMaterial.PcsPerLabel) — dipakai sebagai
  // acuan qty di form penerimaan bahan pendukung. Null/0 = tidak ada acuan.
  final num? PcsPerLabel;

  // ===== LABEL BAHAN PENDUKUNG (hasil scan BP.) =====
  // Diisi untuk baris existing dari GET inputs (kolom NoBahanPendukung, bisa
  // string dipisah koma atau array) dan kosong untuk baris temp.
  final List<String> noBahanPendukung;

  final DateTime? TglSaldoAwal;

  final num? SaldoAwal;
  final num? PenrmnMaterl;
  final num? BJualMaterl;
  final num? ReturMaterl;
  final num? CabAssblMaterl;
  final num? GoodTrfIn;
  final num? GoodTrfOut;
  final num? InjectProdMaterl;
  final num? AdjInput;
  final num? AdjOutput;
  final num? SaldoAkhir;

  // ===== INPUT QTY (dipakai untuk transaksi / inputs) =====
  // Kita simpan sebagai num? biar aman (kadang backend ngirim int/double)
  final num? Jumlah;

  const CabinetMaterialItem({
    this.IdCabinetMaterial,
    this.Nama,
    this.ItemCode,
    this.NamaUOM,
    this.IdWarehouse,
    this.NamaWarehouse,
    this.PcsPerLabel,
    this.TglSaldoAwal,
    this.noBahanPendukung = const <String>[],
    this.SaldoAwal,
    this.PenrmnMaterl,
    this.BJualMaterl,
    this.ReturMaterl,
    this.CabAssblMaterl,
    this.GoodTrfIn,
    this.GoodTrfOut,
    this.InjectProdMaterl,
    this.AdjInput,
    this.AdjOutput,
    this.SaldoAkhir,
    this.Jumlah,
  });

  // ---------------------------------------------------------------------------
  // ✅ ALIAS GETTERS supaya UI/VM bisa pakai 1 gaya saja
  // ---------------------------------------------------------------------------

  /// untuk payload inputs: idCabinetMaterial
  int? get idCabinetMaterial => IdCabinetMaterial;

  /// untuk display inputs: namaJenis
  String? get namaJenis => Nama;

  /// untuk display inputs: namaUom
  String? get namaUom => NamaUOM;

  /// untuk UI card: pcs (int)
  int? get pcs => (Jumlah == null) ? null : Jumlah!.toInt();

  /// stock (int) kalau kamu mau langsung bandingkan
  int get saldoAkhirInt => (SaldoAkhir ?? 0).toInt();

  // ---------------------------------------------------------------------------
  // ✅ PARSE label Bahan Pendukung (BP.) — tahanan variasi dari backend
  // ---------------------------------------------------------------------------
  static List<String> _parseNoBahanPendukung(dynamic v) {
    if (v == null) return const <String>[];
    if (v is List) {
      return v
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList();
    }
    if (v is String) {
      return v
          .split(RegExp(r'[,;\n]'))
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList();
    }
    return const <String>[];
  }

  // ---------------------------------------------------------------------------
  // ✅ FROM JSON TOLERANT (MASTER + INPUTS)
  // ---------------------------------------------------------------------------
  factory CabinetMaterialItem.fromJson(Map<String, dynamic> j) {
    // SUPPORT dua gaya:
    // - MASTER: IdCabinetMaterial, Nama, NamaUOM, SaldoAkhir, ...
    // - INPUTS: idCabinetMaterial, pcs, namaJenis, namaUom

    final id = pickI(j, ['IdCabinetMaterial', 'idCabinetMaterial']);

    // nama: bisa dari master "Nama" atau inputs "namaJenis"
    final nama = pickS(j, ['Nama', 'namaJenis']);

    // uom: bisa dari master "NamaUOM" atau inputs "namaUom"
    final uom = pickS(j, ['NamaUOM', 'namaUom']);

    // jumlah/pcs: bisa "Jumlah" / "Pcs" / "pcs"
    final qty = pickN(j, ['Jumlah', 'Pcs', 'pcs']);

    return CabinetMaterialItem(
      IdCabinetMaterial: id,
      Nama: nama,
      ItemCode: pickS(j, ['ItemCode', 'itemCode']),
      NamaUOM: uom,

      IdWarehouse: pickI(j, ['IdWarehouse', 'idWarehouse']),
      NamaWarehouse: pickS(j, ['NamaWarehouse', 'namaWarehouse']),
      PcsPerLabel: pickN(j, ['PcsPerLabel', 'pcsPerLabel']),
      TglSaldoAwal: pickDT(j, ['TglSaldoAwal', 'tglSaldoAwal']),
      noBahanPendukung: _parseNoBahanPendukung(
        j['noBahanPendukung'] ?? j['NoBahanPendukung'],
      ),

      SaldoAwal: pickN(j, ['SaldoAwal', 'saldoAwal']),
      PenrmnMaterl: pickN(j, ['PenrmnMaterl', 'penrmnMaterl']),
      BJualMaterl: pickN(j, ['BJualMaterl', 'bJualMaterl']),
      ReturMaterl: pickN(j, ['ReturMaterl', 'returMaterl']),
      CabAssblMaterl: pickN(j, ['CabAssblMaterl', 'cabAssblMaterl']),
      GoodTrfIn: pickN(j, ['GoodTrfIn', 'goodTrfIn']),
      GoodTrfOut: pickN(j, ['GoodTrfOut', 'goodTrfOut']),
      InjectProdMaterl: pickN(j, ['InjectProdMaterl', 'injectProdMaterl']),
      AdjInput: pickN(j, ['AdjInput', 'adjInput']),
      AdjOutput: pickN(j, ['AdjOutput', 'adjOutput']),
      SaldoAkhir: pickN(j, ['SaldoAkhir', 'saldoAkhir']),

      Jumlah: qty,
    );
  }

  CabinetMaterialItem copyWith({
    int? IdCabinetMaterial,
    String? Nama,
    String? ItemCode,
    String? NamaUOM,
    int? IdWarehouse,
    String? NamaWarehouse,
    num? PcsPerLabel,
    DateTime? TglSaldoAwal,
    List<String>? noBahanPendukung,
    num? SaldoAwal,
    num? PenrmnMaterl,
    num? BJualMaterl,
    num? ReturMaterl,
    num? CabAssblMaterl,
    num? GoodTrfIn,
    num? GoodTrfOut,
    num? InjectProdMaterl,
    num? AdjInput,
    num? AdjOutput,
    num? SaldoAkhir,
    num? Jumlah,
  }) {
    return CabinetMaterialItem(
      IdCabinetMaterial: IdCabinetMaterial ?? this.IdCabinetMaterial,
      Nama: Nama ?? this.Nama,
      ItemCode: ItemCode ?? this.ItemCode,
      NamaUOM: NamaUOM ?? this.NamaUOM,
      IdWarehouse: IdWarehouse ?? this.IdWarehouse,
      NamaWarehouse: NamaWarehouse ?? this.NamaWarehouse,
      PcsPerLabel: PcsPerLabel ?? this.PcsPerLabel,
      TglSaldoAwal: TglSaldoAwal ?? this.TglSaldoAwal,
      noBahanPendukung: noBahanPendukung ?? this.noBahanPendukung,
      SaldoAwal: SaldoAwal ?? this.SaldoAwal,
      PenrmnMaterl: PenrmnMaterl ?? this.PenrmnMaterl,
      BJualMaterl: BJualMaterl ?? this.BJualMaterl,
      ReturMaterl: ReturMaterl ?? this.ReturMaterl,
      CabAssblMaterl: CabAssblMaterl ?? this.CabAssblMaterl,
      GoodTrfIn: GoodTrfIn ?? this.GoodTrfIn,
      GoodTrfOut: GoodTrfOut ?? this.GoodTrfOut,
      InjectProdMaterl: InjectProdMaterl ?? this.InjectProdMaterl,
      AdjInput: AdjInput ?? this.AdjInput,
      AdjOutput: AdjOutput ?? this.AdjOutput,
      SaldoAkhir: SaldoAkhir ?? this.SaldoAkhir,
      Jumlah: Jumlah ?? this.Jumlah,
    );
  }

  String toDebugString() {
    final n = Nama ?? '-';
    final u = NamaUOM ?? '-';
    final s = SaldoAkhir ?? 0;
    final j = Jumlah ?? 0;
    return '[CAB_MAT] $n • Jumlah=$j $u • SaldoAkhir=$s $u';
  }
}
