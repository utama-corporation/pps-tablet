import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok barang jadi per jenis — flat berbasis Pcs (bukan header-detail
/// sak), sama pola dengan Furniture WIP. [sakSisa] dipetakan dari `PcsSisa`
/// (net partial) supaya bisa dipakai bersama [StokItemList] yang generik
/// atas [StokItemData]; kolomnya diberi label "PCS" lewat `sakColumnLabel`
/// pada [TypedStokItemSource].
class BarangJadiStokItem implements StokItemData {
  final int idBJ;
  @override
  final String nama;

  /// Jumlah label (NoBJ) yang masih punya sisa Pcs.
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

  const BarangJadiStokItem({
    required this.idBJ,
    required this.nama,
    required this.labelSisa,
    required this.pcsSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  @override
  int get sakSisa => pcsSisa;

  factory BarangJadiStokItem.fromJson(Map<String, dynamic> j) =>
      BarangJadiStokItem(
        idBJ: pickI(j, ['IdBJ', 'idBJ']) ?? 0,
        nama: pickS(j, ['NamaBJ', 'namaBJ', 'Nama', 'nama']) ?? '',
        labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
        pcsSisa: pickI(j, ['PcsSisa', 'pcsSisa']) ?? 0,
        beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
        dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}
