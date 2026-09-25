import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class CrusherStokLabel implements StokLabelData {
  final String noCrusher;
  @override
  final String label;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const CrusherStokLabel({
    required this.noCrusher,
    required this.label,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  /// Stok crusher tidak dihitung per sak, hanya berat.
  @override
  int get sakSisa => 0;

  factory CrusherStokLabel.fromJson(Map<String, dynamic> j) => CrusherStokLabel(
    noCrusher: pickS(j, ['NoCrusher', 'noCrusher']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
