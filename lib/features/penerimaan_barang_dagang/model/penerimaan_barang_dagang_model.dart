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
  final double qty;
  final String? keterangan;
  final int hasBeenPrinted;

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
  });

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
