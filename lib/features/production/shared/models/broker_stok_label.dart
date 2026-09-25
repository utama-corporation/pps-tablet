import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class BrokerStokLabel implements StokLabelData {
  final String noBroker;
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

  const BrokerStokLabel({
    required this.noBroker,
    required this.label,
    required this.sakSisa,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  factory BrokerStokLabel.fromJson(Map<String, dynamic> j) => BrokerStokLabel(
    noBroker: pickS(j, ['NoBroker', 'noBroker']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    sakSisa: pickI(j, ['SakSisa', 'sakSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
