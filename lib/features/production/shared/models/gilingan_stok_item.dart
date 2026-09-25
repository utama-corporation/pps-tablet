import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok gilingan per jenis — Gilingan adalah tabel flat (satu baris =
/// satu label, seperti Crusher/Bonggolan/Reject), net dari GilinganPartial.
class GilinganStokItem implements StokItemData {
  final int idGilingan;
  @override
  final String nama;

  /// Jumlah label (NoGilingan) yang masih punya sisa berat.
  final int labelSisa;
  @override
  final double beratSisa;

  /// Tanggal item tertua (paling lama mengendap) dalam stok ini — null bila
  /// stok kosong.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const GilinganStokItem({
    required this.idGilingan,
    required this.nama,
    required this.labelSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  /// Stok gilingan tidak dihitung per sak, hanya berat.
  @override
  int get sakSisa => 0;

  factory GilinganStokItem.fromJson(Map<String, dynamic> j) => GilinganStokItem(
    idGilingan: pickI(j, ['IdGilingan', 'idGilingan']) ?? 0,
    nama: pickS(j, ['NamaGilingan', 'namaGilingan', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
