// lib/features/penerimaan_barang_dagang/model/penerimaan_barang_dagang_model.dart
//
// Mirror response dari backend
// `src/modules/production/penerimaan-barang-dagang/*`
// (GET/POST/DELETE /api/penerimaan-barang-dagang). Satu baris riwayat =
// satu transaksi penerimaan (NoPenerimaan). Sama seperti Penerimaan Bahan
// Pendukung: TIDAK ada struktur pallet/sak — tiap barang (item) LANGSUNG
// jadi satu baris dbo.BarangDagang (IdBarangDagang + Qty), dan tidak ada
// split kategori. Tidak ada konsep operator di modul ini.
import 'package:intl/intl.dart';

import '../../production/shared/models/label_usage_status.dart';

class PenerimaanBarangDagang {
  final String noPenerimaan;
  final DateTime? tglPenerimaan;
  final int idTim;
  final String namaTim;
  final bool isComplete;
  final String? createBy;
  final DateTime? tglComplete;

  final int jumlahItem;
  final double totalQty;

  const PenerimaanBarangDagang({
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

  factory PenerimaanBarangDagang.fromJson(Map<String, dynamic> j) {
    return PenerimaanBarangDagang(
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
    return DateFormat(
      'dd MMM yyyy HH:mm',
      'id_ID',
    ).format(tglComplete!.toLocal());
  }
}

/// Satu baris barang (BarangDagang) dari sebuah transaksi penerimaan
/// barang dagang — hasil join `PenerimaanBarangDagang_d` + `BarangDagang` +
/// `MstSupplier` + `MstBarangDagang`. `noBarangDagang` adalah pengenal unik
/// barisnya (PK di tabel BarangDagang). Nama barang diambil dari
/// MstBarangDagang (FK).
class PenerimaanBarangDagangItem {
  final String noPenerimaan;
  final String noBarangDagang;
  final int idSupplier;
  final String namaSupplier;
  final int idBarangDagang;
  final String namaBarang;

  /// Kuantitas label (PCS) — kolom `Qty` di dbo.BarangDagang. Tidak ada
  /// pemisahan qty pembelian vs sisa stok: tidak ada alur yang memotong
  /// Qty untuk barang dagang.
  final double qty;
  final String? keterangan;
  final int hasBeenPrinted;

  /// `true` kalau baris ini sudah terpakai di proses lain (DateUsage terisi di
  /// server). Menentukan boleh/tidaknya menu "Ubah Data".
  final bool used;

  const PenerimaanBarangDagangItem({
    required this.noPenerimaan,
    required this.noBarangDagang,
    required this.idSupplier,
    required this.namaSupplier,
    required this.idBarangDagang,
    required this.namaBarang,
    required this.qty,
    this.keterangan,
    this.hasBeenPrinted = 0,
    this.used = false,
  });

  /// Data label masih boleh diubah selama BELUM dicetak dan BELUM dipakai.
  /// Server enforce hal yang sama (BD_ALREADY_PRINTED / BD_ALREADY_USED),
  /// check ini cuma supaya menu tidak pernah menampilkan aksi yang pasti gagal.
  bool get canEdit => hasBeenPrinted <= 0 && !used;

  /// Label yang sudah dipakai tidak boleh dihapus — riwayatnya masih tercatat
  /// di proses produksi. Server enforce hal yang sama (BD_ALREADY_USED).
  ///
  /// Berbeda dengan [canEdit]: label yang sudah dicetak masih BOLEH dihapus,
  /// karena mencetak tidak memindahkan stok.
  bool get canDelete => !used;

  /// Badge status pemakaian. Barang dagang tidak punya konsumsi parsial —
  /// `Qty` tidak pernah dipotong sebelum `DateUsage` terisi — jadi hanya ada
  /// dua kondisi: sudah dipakai penuh atau belum.
  LabelUsageStatus get usageStatus =>
      used ? LabelUsageStatus.habis : LabelUsageStatus.belumDipakai;

  factory PenerimaanBarangDagangItem.fromJson(Map<String, dynamic> j) {
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

    return PenerimaanBarangDagangItem(
      noPenerimaan: j['NoPenerimaan']?.toString() ?? '',
      noBarangDagang: j['NoBarangDagang']?.toString() ?? '',
      idSupplier: toInt(j['IdSupplier']),
      namaSupplier: j['NamaSupplier']?.toString() ?? '',
      idBarangDagang: toInt(j['IdBarangDagang']),
      namaBarang: j['NamaBarangDagang']?.toString() ?? '',
      qty: toDouble(j['Qty']),
      keterangan: j['Keterangan']?.toString(),
      hasBeenPrinted: toInt(j['HasBeenPrinted']),
      used: toBool(j['Used']),
    );
  }
}

/// Detail lengkap satu transaksi penerimaan barang dagang (GET
/// /:noPenerimaan) — header + seluruh item (barang/label) di dalamnya.
class PenerimaanBarangDagangDetail {
  final PenerimaanBarangDagang header;
  final List<PenerimaanBarangDagangItem> items;

  const PenerimaanBarangDagangDetail({
    required this.header,
    required this.items,
  });

  factory PenerimaanBarangDagangDetail.fromJson(Map<String, dynamic> j) {
    final itemsRaw = (j['items'] as List?) ?? [];
    return PenerimaanBarangDagangDetail(
      header: PenerimaanBarangDagang.fromJson(j),
      items: itemsRaw
          .map(
            (e) => PenerimaanBarangDagangItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
