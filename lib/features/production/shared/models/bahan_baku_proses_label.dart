import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class BahanBakuProsesLabel implements StokLabelData {
  final String noBahanBaku;
  final int noPallet;
  @override
  final String label;
  @override
  final int sakSisa;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const BahanBakuProsesLabel({
    required this.noBahanBaku,
    required this.noPallet,
    required this.label,
    required this.sakSisa,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  factory BahanBakuProsesLabel.fromJson(Map<String, dynamic> j) =>
      BahanBakuProsesLabel(
        noBahanBaku: pickS(j, ['NoBahanBaku', 'noBahanBaku']) ?? '',
        noPallet: pickI(j, ['NoPallet', 'noPallet']) ?? 0,
        label: pickS(j, ['Label', 'label']) ?? '',
        sakSisa: pickI(j, ['SakSisa', 'sakSisa']) ?? 0,
        beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
        dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}
