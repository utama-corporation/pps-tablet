// lib/features/bahan_pendukung/penerimaan/model/penerimaan_bahan_pendukung_model.dart
//
// Mirror response dari backend
// `src/modules/production/penerimaan-bahan-pendukung/*`
// (GET/POST/DELETE /api/penerimaan-bahan-pendukung). Satu baris riwayat =
// satu transaksi penerimaan (NoPenerimaan). Beda dengan Penerimaan Bahan
// Baku: TIDAK ada struktur pallet/sak — tiap barang (item) LANGSUNG jadi
// satu baris dbo.BahanPendukung (IdCabinetMaterial + Qty), dan tidak ada
// split kategori (Pakai/Proses) — satu kategori saja. Tidak ada konsep
// operator di modul ini.
import 'package:intl/intl.dart';

import '../../../production/shared/models/label_usage_status.dart';

class PenerimaanBahanPendukung {
  final String noPenerimaan;
  final DateTime? tglPenerimaan;
  final int idTim;
  final String namaTim;
  final bool isComplete;
  final String? createBy;
  final DateTime? tglComplete;

  final int jumlahItem;
  final double totalQty;

  const PenerimaanBahanPendukung({
    required this.noPenerimaan,
    required this.tglPenerimaan,
    required this.idTim,
    required this.namaTim,
    this.isComplete = false,
    this.createBy,
    this.tglComplete,
    this.jumlahItem = 0,
    this.totalQty = 0,
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

  factory PenerimaanBahanPendukung.fromJson(Map<String, dynamic> j) {
    return PenerimaanBahanPendukung(
      noPenerimaan: _asString(j['NoPenerimaan']),
      tglPenerimaan: _asDateTime(j['TglPenerimaan']),
      idTim: _asInt(j['IdTim']),
      namaTim: _asString(j['NamaTim']),
      isComplete: _asBool(j['IsComplete']),
      createBy: j['CreateBy']?.toString(),
      tglComplete: _asDateTime(j['TglComplete']),
      jumlahItem: _asInt(j['JumlahItem']),
      totalQty: _asDouble(j['TotalQty']),
    );
  }

  String get tglPenerimaanTextShort {
    if (tglPenerimaan == null) return '';
    return DateFormat('dd MMM yyyy', 'id_ID').format(tglPenerimaan!.toLocal());
  }

  String get tglCompleteTextShort {
    if (tglComplete == null) return '';
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(tglComplete!.toLocal());
  }
}

/// Satu baris barang (BahanPendukung) dari sebuah transaksi penerimaan
/// bahan pendukung — hasil join `PenerimaanBahanPendukung_d` +
/// `BahanPendukung` + `MstSupplier` + `MstCabinetMaterial`.
/// `noBahanPendukung` adalah pengenal unik barisnya (PK di tabel
/// BahanPendukung). Nama barang diambil dari cabinet material (FK).
class PenerimaanBahanPendukungItem {
  final String noPenerimaan;
  final String noBahanPendukung;
  final int idSupplier;
  final String namaSupplier;
  final int idCabinetMaterial;
  final String namaBarang;

  /// Qty dari pembelian — kolom `QtyAwal` di dbo.BahanPendukung, BUKAN `Qty`
  /// (stok live yang dipotong konsumsi parsial produksi). Backend sudah
  /// me-alias `Qty` ke `ISNULL(QtyAwal, Qty)` pada response detail. Stok
  /// live tidak pernah ditampilkan di layar penerimaan.
  final double qty;

  /// Stok live (`Qty` di DB). Berbeda dari [qty] kalau label sudah dipotong
  /// oleh konsumsi parsial produksi — BahanPendukung memang bisa sampai
  /// ke kondisi itu (lihat markUsage di produksi-input-mapping.config.js).
  final double qtySisa;
  final String? keterangan;
  final int hasBeenPrinted;

  /// `true` kalau baris ini sudah terpakai di proses lain (DateUsage terisi di
  /// server). Menentukan boleh/tidaknya menu "Ubah Data".
  final bool used;

  const PenerimaanBahanPendukungItem({
    required this.noPenerimaan,
    required this.noBahanPendukung,
    required this.idSupplier,
    required this.namaSupplier,
    required this.idCabinetMaterial,
    required this.namaBarang,
required this.qty,
    this.qtySisa = 0,
    this.keterangan,
    this.hasBeenPrinted = 0,
    this.used = false,
  });

  /// Data label masih boleh diubah selama BELUM dicetak dan BELUM dipakai
  /// (termasuk belum dipakai sebagian). Server enforce hal yang sama
  /// (BP_ALREADY_PRINTED / BP_ALREADY_USED / BP_ALREADY_PARTIAL), check ini
  /// cuma supaya menu tidak pernah menampilkan aksi yang pasti gagal.
  bool get canEdit =>
      hasBeenPrinted <= 0 && usageStatus == LabelUsageStatus.belumDipakai;

  /// Label yang sudah terpakai / habis tidak boleh dihapus — sisa dan
  /// riwayatnya masih tercatat di proses produksi. Server enforce hal yang
  /// sama (BP_ALREADY_USED / BP_ALREADY_PARTIAL).
  ///
  /// Berbeda dengan [canEdit]: label yang sudah dicetak masih BOLEH dihapus,
  /// karena mencetak tidak memindahkan stok.
  bool get canDelete => usageStatus == LabelUsageStatus.belumDipakai;

  /// Badge status pemakaian. [qty] adalah QtyAwal (data pembelian),
  /// [qtySisa] stok live — selisih keduanya menandakan konsumsi parsial.
  LabelUsageStatus get usageStatus {
    if (used) return LabelUsageStatus.habis;
    if ((qty - qtySisa).abs() > 0.000001) return LabelUsageStatus.terpakai;
    return LabelUsageStatus.belumDipakai;
  }

  factory PenerimaanBahanPendukungItem.fromJson(Map<String, dynamic> j) {
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

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1';
      }
      return false;
    }

    return PenerimaanBahanPendukungItem(
      noPenerimaan: j['NoPenerimaan']?.toString() ?? '',
      noBahanPendukung: j['NoBahanPendukung']?.toString() ?? '',
      idSupplier: toInt(j['IdSupplier']),
      namaSupplier: j['NamaSupplier']?.toString() ?? '',
      idCabinetMaterial: toInt(j['IdCabinetMaterial']),
      namaBarang: j['NamaCabinetMaterial']?.toString() ?? '',
      qty: toDouble(j['Qty']),
      // QtySisa = stok live. Kalau server belum mengirimnya (mis. response
      // lama), [qty] dianggap masih utuh supaya badge tidak salah bilang
      // "terpakai".
      qtySisa: j['QtySisa'] == null ? toDouble(j['Qty']) : toDouble(j['QtySisa']),
      keterangan: j['Keterangan']?.toString(),
      hasBeenPrinted: toInt(j['HasBeenPrinted']),
      used: toBool(j['Used']),
    );
  }
}

/// Detail lengkap satu transaksi penerimaan bahan pendukung (GET
/// /:noPenerimaan) — header + seluruh item (barang/label) di dalamnya.
class PenerimaanBahanPendukungDetail {
  final PenerimaanBahanPendukung header;
  final List<PenerimaanBahanPendukungItem> items;

  const PenerimaanBahanPendukungDetail({required this.header, required this.items});

  factory PenerimaanBahanPendukungDetail.fromJson(Map<String, dynamic> j) {
    final itemsRaw = (j['items'] as List?) ?? [];
    return PenerimaanBahanPendukungDetail(
      header: PenerimaanBahanPendukung.fromJson(j),
      items: itemsRaw
          .map((e) => PenerimaanBahanPendukungItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
