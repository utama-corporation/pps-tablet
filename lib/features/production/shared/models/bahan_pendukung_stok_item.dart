import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok bahan pendukung per jenis — berbasis Pcs (QtySisa), bukan
/// berat. [sakSisa] dipetakan dari [qtySisa] supaya bisa dipakai bersama
/// [StokItemList] yang generik atas [StokItemData]; kolomnya diberi label
/// "PCS" lewat `sakColumnLabel` pada [TypedStokItemSource] dan kolom berat
/// disembunyikan (`showBeratColumn: false`).
class BahanPendukungStokItem implements StokItemData {
  final int idCabinetMaterial;
  @override
  final String nama;
  final String itemCode;
  final String namaUom;

  /// Jumlah label (NoBahanPendukung) yang masih punya sisa.
  final int labelSisa;

  /// Total Pcs (QtySisa) tersisa.
  final int qtySisa;

  /// Lokasi material (Blok+IdLokasi) pada label yang masih sisa.
  @override
  final String lokasi;

  const BahanPendukungStokItem({
    required this.idCabinetMaterial,
    required this.nama,
    required this.itemCode,
    required this.namaUom,
    required this.labelSisa,
    required this.qtySisa,
    this.lokasi = '',
  });

  @override
  int get sakSisa => qtySisa;

  @override
  double get beratSisa => qtySisa.toDouble();

  factory BahanPendukungStokItem.fromJson(Map<String, dynamic> j) =>
      BahanPendukungStokItem(
        idCabinetMaterial:
            pickI(j, ['IdCabinetMaterial', 'idCabinetMaterial']) ?? 0,
        nama: pickS(
              j,
              ['NamaCabinetMaterial', 'namaCabinetMaterial', 'Nama', 'nama'],
            ) ??
            '',
        itemCode: pickS(j, ['ItemCode', 'itemCode']) ?? '',
        namaUom: pickS(j, ['NamaUOM', 'namaUom']) ?? '',
        labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
        qtySisa: pickI(j, ['QtySisa', 'qtySisa']) ?? 0,
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}