/// Kategori input yang dikenali backend `sortir-reject-v2` (lihat
/// `sortir-reject-v2-category-registry.js`). Prefix label: `BA.` barang jadi,
/// `BB.` furniture WIP, `BP.` bahan pendukung.
enum SrV2Category {
  barangJadi,
  furnitureWip,
  bahanPendukung,
  unknown;

  static SrV2Category fromRaw(String? raw, {String? labelCode}) {
    final value = (raw ?? '').trim();
    if (value.isNotEmpty) {
      final key = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      return switch (key) {
        'barangjadi' => SrV2Category.barangJadi,
        'furniturewip' => SrV2Category.furnitureWip,
        'bahanpendukung' => SrV2Category.bahanPendukung,
        _ => SrV2Category.unknown,
      };
    }
    final code = (labelCode ?? '').trim().toUpperCase();
    if (code.startsWith('BA.')) return SrV2Category.barangJadi;
    if (code.startsWith('BB.')) return SrV2Category.furnitureWip;
    if (code.startsWith('BP.')) return SrV2Category.bahanPendukung;
    return SrV2Category.unknown;
  }

  String get label {
    switch (this) {
      case SrV2Category.barangJadi:
        return 'Barang Jadi';
      case SrV2Category.furnitureWip:
        return 'Furniture WIP';
      case SrV2Category.bahanPendukung:
        return 'Bahan Pendukung';
      case SrV2Category.unknown:
        return '-';
    }
  }
}

class SrV2LabelInfo {
  final String labelCode;
  final String category;
  final int idJenis;
  final String namaJenis;
  final int pcs;

  /// Qty asli label. Backend selalu mengirim `pcs`, tetapi untuk bahan
  /// pendukung nilainya berasal dari `dbo.BahanPendukung.Qty` yang bisa
  /// pecahan, jadi disimpan terpisah agar tidak kehilangan desimal.
  final double qty;

  const SrV2LabelInfo({
    required this.labelCode,
    required this.category,
    required this.idJenis,
    required this.namaJenis,
    required this.pcs,
    this.qty = 0,
  });

  static String _s(dynamic v) => v?.toString() ?? '';
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

  /// Backend bisa mengirim kode label dengan awalan field berbeda tiap
  /// sumber (list/detail vs lookup). Tanpa fallback ini, `BP.` tidak terbaca
  /// dan kategori jadi `unknown`, sehingga UI jatuh ke kolom pcs yang 0.
  static String _labelCode(Map<String, dynamic> j) => _s(
    j['labelCode'] ??
        j['LabelCode'] ??
        j['noBJ'] ??
        j['NoBJ'] ??
        j['noFurnitureWIP'] ??
        j['NoFurnitureWIP'] ??
        j['noBahanPendukung'] ??
        j['NoBahanPendukung'] ??
        j['noBahanPendukungPartial'] ??
        j['NoBahanPendukungPartial'],
  );

  factory SrV2LabelInfo.fromJson(Map<String, dynamic> j) {
    final rawQty =
        j['qty'] ??
        j['Qty'] ??
        j['jumlah'] ??
        j['Jumlah'] ??
        j['qtySisa'] ??
        j['QtySisa'] ??
        j['pcs'] ??
        j['Pcs'];
    return SrV2LabelInfo(
      labelCode: _labelCode(j),
      category: _s(j['category'] ?? j['Category']),
      idJenis: _i(j['idJenis'] ?? j['IdJenis']),
      namaJenis: _s(j['namaJenis'] ?? j['NamaJenis'] ?? j['nama']),
      pcs: _i(j['pcs'] ?? j['Pcs']),
      qty: _d(rawQty),
    );
  }

  SrV2Category get parsedCategory =>
      SrV2Category.fromRaw(category, labelCode: labelCode);

  bool get isBahanPendukung =>
      parsedCategory == SrV2Category.bahanPendukung;
}