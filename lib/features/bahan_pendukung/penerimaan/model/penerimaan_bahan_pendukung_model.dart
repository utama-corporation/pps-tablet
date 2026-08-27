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
  final double qty;
  final String? keterangan;
  final int hasBeenPrinted;

  const PenerimaanBahanPendukungItem({
    required this.noPenerimaan,
    required this.noBahanPendukung,
    required this.idSupplier,
    required this.namaSupplier,
    required this.idCabinetMaterial,
    required this.namaBarang,
    required this.qty,
    this.keterangan,
    this.hasBeenPrinted = 0,
  });

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

    return PenerimaanBahanPendukungItem(
      noPenerimaan: j['NoPenerimaan']?.toString() ?? '',
      noBahanPendukung: j['NoBahanPendukung']?.toString() ?? '',
      idSupplier: toInt(j['IdSupplier']),
      namaSupplier: j['NamaSupplier']?.toString() ?? '',
      idCabinetMaterial: toInt(j['IdCabinetMaterial']),
      namaBarang: j['NamaCabinetMaterial']?.toString() ?? '',
      qty: toDouble(j['Qty']),
      keterangan: j['Keterangan']?.toString(),
      hasBeenPrinted: toInt(j['HasBeenPrinted']),
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
