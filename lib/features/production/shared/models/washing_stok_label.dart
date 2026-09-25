import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class WashingStokLabel implements StokLabelData {
  final String noWashing;
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

  const WashingStokLabel({
    required this.noWashing,
    required this.label,
    required this.sakSisa,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  factory WashingStokLabel.fromJson(Map<String, dynamic> j) => WashingStokLabel(
    noWashing: pickS(j, ['NoWashing', 'noWashing']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    sakSisa: pickI(j, ['SakSisa', 'sakSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
