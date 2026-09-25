import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class MixerStokLabel implements StokLabelData {
  final String noMixer;
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

  const MixerStokLabel({
    required this.noMixer,
    required this.label,
    required this.sakSisa,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  factory MixerStokLabel.fromJson(Map<String, dynamic> j) => MixerStokLabel(
    noMixer: pickS(j, ['NoMixer', 'noMixer']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    sakSisa: pickI(j, ['SakSisa', 'sakSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
