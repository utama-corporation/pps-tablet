import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok furniture WIP per jenis (IdCabinetWIP) — flat berbasis Pcs
/// (bukan header-detail sak seperti washing/broker). [sakSisa] dipetakan
/// dari `PcsSisa` (net partial) supaya bisa dipakai bersama [StokItemList]
/// yang generik atas [StokItemData]; kolomnya diberi label "PCS" lewat
/// `sakColumnLabel` pada [TypedStokItemSource].
class FurnitureWipStokItem implements StokItemData {
  final int idCabinetWip;
  @override
  final String nama;

  /// Jumlah label (NoFurnitureWIP) yang masih punya sisa Pcs.
  final int labelSisa;

  /// Total Pcs efektif tersisa (net partial, clamp ke 0).
  final int pcsSisa;

  /// Total Berat — tidak dikurangi partial, mengikuti logika label.
  @override
  final double beratSisa;

  /// Tanggal label tertua yang masih ada sisa — absen (null) bila tidak
  /// ada stok.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const FurnitureWipStokItem({
    required this.idCabinetWip,
    required this.nama,
    required this.labelSisa,
    required this.pcsSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  @override
  int get sakSisa => pcsSisa;

  factory FurnitureWipStokItem.fromJson(Map<String, dynamic> j) =>
      FurnitureWipStokItem(
        idCabinetWip: pickI(j, ['IdCabinetWIP', 'idCabinetWip']) ?? 0,
        nama: pickS(j, ['Nama', 'nama']) ?? '',
        labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
        pcsSisa: pickI(j, ['PcsSisa', 'pcsSisa']) ?? 0,
        beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
        dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}
