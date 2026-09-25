import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class BonggolanStokLabel implements StokLabelData {
  final String noBonggolan;
  @override
  final String label;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const BonggolanStokLabel({
    required this.noBonggolan,
    required this.label,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  /// Stok bonggolan tidak dihitung per sak, hanya berat.
  @override
  int get sakSisa => 0;

  factory BonggolanStokLabel.fromJson(Map<String, dynamic> j) =>
      BonggolanStokLabel(
        noBonggolan: pickS(j, ['NoBonggolan', 'noBonggolan']) ?? '',
        label: pickS(j, ['Label', 'label']) ?? '',
        beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
        dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}
