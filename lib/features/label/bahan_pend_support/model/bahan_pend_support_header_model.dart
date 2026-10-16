// lib/features/label/bahan_pend_support/model/bahan_pend_support_header_model.dart

import 'package:pps_tablet/features/production/shared/models/label_usage_status.dart';

/// Satu baris label Bahan Pendukung (`BP.`) dari endpoint
/// `GET /api/labels/bahan-pendukung`.
///
/// [qty] adalah kolom `dbo.BahanPendukung.Qty` — stok live, yang tampil di
/// kolom QTY. [qtyAwal] adalah kuantitas asli dari pembelian, dipakai hanya
/// untuk menghitung sisa dan status pemakaian.
///
/// PERINGATAN: kolom `IsPartial` di tabel TIDAK bisa dipakai untuk status
/// "terpakai sebagian". Jalur konsumsi parsial produksi
/// (`produksi-upsert-sql.generator.js`) hanya meng-update kolom `Qty` tanpa
/// menyentuh `IsPartial`, jadi nilainya selalu 0 untuk bahan pendukung. Status
/// karena itu disimpulkan dari selisih Qty vs QtyAwal — sama seperti
/// `PenerimaanBahanPendukungItem.usageStatus` di layar Penerimaan.
///
/// Tidak ada tombol create di modul ini: label BP. dibuat melalui
/// "Penerimaan Bahan Pendukung", jadi layar ini hanya browse / print / delete.
class BahanPendukungHeader {
  final String noBahanPendukung;
  final int idSupplier;
  final String? namaSupplier;
  final int idCabinetMaterial;
  final String? namaCabinetMaterial;

  /// Kolom `Qty` di database — stok live. Ini yang ditampilkan di kolom QTY.
  final num? qty;

  /// Kolom `QtyAwal` di database — kuantitas asli pembelian. Null untuk data
  /// lama sebelum kolom ini ada; dianggap sama dengan [qty] supaya status
  /// tidak salah bilang "terpakai sebagian".
  final num? qtyAwal;

  final String? keterangan;
  final int hasBeenPrinted;
  final String? blok;
  final int? idLokasi;
  final String? noPenerimaan;

  /// Terisi backend dari `DateUsage IS NOT NULL` (label sudah terpakai penuh).
  final bool used;

  bool get isPrinted => hasBeenPrinted > 0;

  /// Sisa label: QtyAwal - Qty. Untuk label yang utuh selalu 0.
  num get sisa => (qtyAwal ?? qty ?? 0) - (qty ?? 0);

  /// Status pemakaian, disimpulkan dengan aturan yang sama seperti layar
  /// Penerimaan (lihat komentar kelas).
  LabelUsageStatus get usageStatus {
    if (used) return LabelUsageStatus.habis;
    if (qtyAwal != null && (sisa).abs() > 0.000001) {
      return LabelUsageStatus.terpakai;
    }
    return LabelUsageStatus.belumDipakai;
  }

  bool get isTerpakaiSebagian =>
      usageStatus == LabelUsageStatus.terpakai;

  bool get isFullyUsed => usageStatus == LabelUsageStatus.habis;

  /// Backend menolak hapus kalau label sudah terpakai (penuh maupun sebagian),
  /// jadi tombol delete sebaiknya tidak ditawarkan untuk dua status ini.
  bool get canDelete => usageStatus == LabelUsageStatus.belumDipakai;

  /// "A-01" — lokasi gabungan Blok + IdLokasi, atau "-" kalau keduanya kosong.
  String get lokasi {
    final hasBlok = (blok ?? '').trim().isNotEmpty;
    final hasLokasi = idLokasi != null;
    if (!hasBlok && !hasLokasi) return '-';
    return '${(blok ?? '').trim()}${(idLokasi ?? '').toString().trim()}';
  }

  const BahanPendukungHeader({
    required this.noBahanPendukung,
    this.idSupplier = 0,
    this.namaSupplier,
    this.idCabinetMaterial = 0,
    this.namaCabinetMaterial,
    this.qty,
    this.qtyAwal,
    this.keterangan,
    this.hasBeenPrinted = 0,
    this.blok,
    this.idLokasi,
    this.noPenerimaan,
    this.used = false,
  });

  factory BahanPendukungHeader.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    num? _toNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      if (v is String) return num.tryParse(v);
      return null;
    }

    String? _toStr(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    // Backend bisa kirim 0/1 dari SQL `CAST(... AS bit)` atau boolean JSON.
    bool _toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1';
      }
      return false;
    }

    return BahanPendukungHeader(
      noBahanPendukung: (json['NoBahanPendukung'] ?? '').toString(),
      idSupplier: _toInt(json['IdSupplier']),
      namaSupplier: _toStr(json['NamaSupplier']),
      idCabinetMaterial: _toInt(json['IdCabinetMaterial']),
      namaCabinetMaterial: _toStr(json['NamaCabinetMaterial']),
      qty: _toNum(json['Qty']),
      qtyAwal: _toNum(json['QtyAwal']),
      keterangan: _toStr(json['Keterangan']),
      hasBeenPrinted: _toInt(json['HasBeenPrinted']),
      blok: _toStr(json['Blok']),
      idLokasi: json['IdLokasi'] == null ? null : _toInt(json['IdLokasi']),
      noPenerimaan: _toStr(json['NoPenerimaan']),
      used: _toBool(json['Used']),
    );
  }

  BahanPendukungHeader copyWith({
    int? hasBeenPrinted,
    bool? used,
  }) {
    return BahanPendukungHeader(
      noBahanPendukung: noBahanPendukung,
      idSupplier: idSupplier,
      namaSupplier: namaSupplier,
      idCabinetMaterial: idCabinetMaterial,
      namaCabinetMaterial: namaCabinetMaterial,
      qty: qty,
      qtyAwal: qtyAwal,
      keterangan: keterangan,
      hasBeenPrinted: hasBeenPrinted ?? this.hasBeenPrinted,
      blok: blok,
      idLokasi: idLokasi,
      noPenerimaan: noPenerimaan,
      used: used ?? this.used,
    );
  }
}