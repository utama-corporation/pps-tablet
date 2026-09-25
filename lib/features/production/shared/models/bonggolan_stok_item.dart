import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class BonggolanStokItem implements StokItemData {
  final int idBonggolan;
  @override
  final String nama;

  /// Jumlah label (NoBonggolan) yang masih punya sisa berat.
  final int labelSisa;
  @override
  final double beratSisa;

/// Tanggal item tertua (paling lama mengendap) dalam stok ini — null bila
  /// stok kosong.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const BonggolanStokItem({
    required this.idBonggolan,
    required this.nama,
    required this.labelSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  /// Stok bonggolan tidak dihitung per sak, hanya berat.
  @override
  int get sakSisa => 0;

  factory BonggolanStokItem.fromJson(Map<String, dynamic> j) =>
      BonggolanStokItem(
        idBonggolan: pickI(j, ['IdBonggolan', 'idBonggolan']) ?? 0,
        nama: pickS(j, ['NamaBonggolan', 'namaBonggolan', 'Nama', 'nama']) ?? '',
        labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
        beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
        dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}
