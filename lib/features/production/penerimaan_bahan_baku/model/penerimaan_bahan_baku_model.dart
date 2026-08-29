// lib/features/production/penerimaan_bahan_baku/model/penerimaan_bahan_baku_model.dart
//
// Mirror response dari backend `src/modules/production/penerimaan-bahan-baku/*`
// (GET/POST/DELETE /api/penerimaan-bahan-baku). Satu baris riwayat = satu
// transaksi penerimaan (NoPenerimaan) — header disederhanakan (tanpa Shift/
// Jam, mengikuti format Bahan Pendukung/Barang Dagang), yang menghasilkan
// satu NoBahanBaku (label bahan baku) dengan satu atau lebih pallet.
import 'package:intl/intl.dart';

class PenerimaanBahanBaku {
  final String noPenerimaan;
  final DateTime? tglPenerimaan;
  final int idTim;
  final String namaTim;
  final int idSupplier;
  final String namaSupplier;
  final String? noPlat;
  final String? createBy;
  final DateTime? dateTimeCreate;
  final bool isComplete;
  final DateTime? tglComplete;

  final String? noBahanBaku;
  final int jumlahPallet;
  final double totalBerat;

  const PenerimaanBahanBaku({
    required this.noPenerimaan,
    required this.tglPenerimaan,
    required this.idTim,
    required this.namaTim,
    required this.idSupplier,
    required this.namaSupplier,
    this.noPlat,
    this.createBy,
    this.dateTimeCreate,
    this.isComplete = false,
    this.tglComplete,
    this.noBahanBaku,
    this.jumlahPallet = 0,
    this.totalBerat = 0,
  });

  static String _asString(dynamic v) => v?.toString() ?? '';

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  factory PenerimaanBahanBaku.fromJson(Map<String, dynamic> j) {
    return PenerimaanBahanBaku(
      noPenerimaan: _asString(j['NoPenerimaan']),
      tglPenerimaan: _asDateTime(j['TglPenerimaan']),
      idTim: _asInt(j['IdTim']),
      namaTim: _asString(j['NamaTim']),
      idSupplier: _asInt(j['IdSupplier']),
      namaSupplier: _asString(j['NamaSupplier']),
      noPlat: j['NoPlat']?.toString(),
      createBy: j['CreateBy']?.toString(),
      dateTimeCreate: _asDateTime(j['DateTimeCreate']),
      isComplete: _asBool(j['IsComplete']),
      tglComplete: _asDateTime(j['TglComplete']),
      noBahanBaku: j['NoBahanBaku']?.toString(),
      jumlahPallet: _asInt(j['JumlahPallet']),
      totalBerat: _asDouble(j['TotalBerat']),
    );
  }

  String get tglPenerimaanTextShort {
    if (tglPenerimaan == null) return '';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tglPenerimaan!.toLocal());
  }

  String get tglCompleteTextShort {
    if (tglComplete == null) return '';
    return DateFormat(
      'dd MMM yyyy HH:mm',
      'id_ID',
    ).format(tglComplete!.toLocal());
  }

}

/// Satu baris output (label) dari sebuah transaksi penerimaan — hasil join
/// `PenerimaanBahanBakuOutput` + `BahanBakuPallet_h` + `BahanBaku_d`.
class PenerimaanBahanBakuOutput {
  final String noBahanBaku;
  final int noPallet;
  final int noSak;
  final int? idJenisPlastik;
  final String? namaJenisPlastik;
  final double berat;

  const PenerimaanBahanBakuOutput({
    required this.noBahanBaku,
    required this.noPallet,
    required this.noSak,
    this.idJenisPlastik,
    this.namaJenisPlastik,
    required this.berat,
  });

  factory PenerimaanBahanBakuOutput.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return PenerimaanBahanBakuOutput(
      noBahanBaku: j['NoBahanBaku']?.toString() ?? '',
      noPallet: toInt(j['NoPallet']),
      noSak: toInt(j['NoSak']),
      idJenisPlastik: j['IdJenisPlastik'] != null ? toInt(j['IdJenisPlastik']) : null,
      namaJenisPlastik: j['NamaJenisPlastik']?.toString(),
      berat: toDouble(j['Berat']),
    );
  }
}

/// Satu "batch" (NoBahanBaku) di bawah sebuah NoPenerimaan — satu batch =
/// satu panggilan `addPallets()` = satu section (Bahan Baku Pakai ATAU
/// Proses) dengan Supplier/No Plat sendiri. Satu NoPenerimaan bisa punya
/// lebih dari satu batch (satu per section yang diisi).
class PenerimaanBahanBakuBatch {
  final String noBahanBaku;
  final int idSupplier;
  final String namaSupplier;
  final String? noPlat;

  const PenerimaanBahanBakuBatch({
    required this.noBahanBaku,
    required this.idSupplier,
    required this.namaSupplier,
    this.noPlat,
  });

  factory PenerimaanBahanBakuBatch.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return PenerimaanBahanBakuBatch(
      noBahanBaku: j['NoBahanBaku']?.toString() ?? '',
      idSupplier: toInt(j['IdSupplier']),
      namaSupplier: j['NamaSupplier']?.toString() ?? '',
      noPlat: j['NoPlat']?.toString(),
    );
  }
}

/// Detail lengkap satu transaksi penerimaan (GET /:noPenerimaan) — header +
/// batch (Supplier/No Plat per section) + seluruh output (pallet/sak) yang
/// dihasilkan.
class PenerimaanBahanBakuDetail {
  final PenerimaanBahanBaku header;
  final List<PenerimaanBahanBakuBatch> batches;
  final List<PenerimaanBahanBakuOutput> outputs;

  const PenerimaanBahanBakuDetail({
    required this.header,
    required this.batches,
    required this.outputs,
  });

  factory PenerimaanBahanBakuDetail.fromJson(Map<String, dynamic> j) {
    final batchesRaw = (j['batches'] as List?) ?? [];
    final outputsRaw = (j['outputs'] as List?) ?? [];
    return PenerimaanBahanBakuDetail(
      header: PenerimaanBahanBaku.fromJson(j),
      batches: batchesRaw
          .map((e) => PenerimaanBahanBakuBatch.fromJson(e as Map<String, dynamic>))
          .toList(),
      outputs: outputsRaw
          .map((e) => PenerimaanBahanBakuOutput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Group outputs by NoBahanBaku (batch), lalu by NoPallet di dalamnya —
  /// dipakai untuk render 1 section per batch di layar detail.
  Map<String, Map<int, List<PenerimaanBahanBakuOutput>>> get outputsByBatchAndPallet {
    final map = <String, Map<int, List<PenerimaanBahanBakuOutput>>>{};
    for (final o in outputs) {
      final byPallet = map.putIfAbsent(o.noBahanBaku, () => {});
      byPallet.putIfAbsent(o.noPallet, () => []).add(o);
    }
    return map;
  }
}
