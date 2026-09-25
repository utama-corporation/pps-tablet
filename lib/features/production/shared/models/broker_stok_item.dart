import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class BrokerStokItem implements StokItemData {
  final int idBroker;
  @override
  final String nama;

  /// Jumlah label (NoBroker) yang masih punya sisa sak.
  final int labelSisa;
  @override
  final int sakSisa;
  @override
  final double beratSisa;

  /// Tanggal item tertua (paling lama mengendap) dalam stok ini — null bila
  /// stok kosong.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const BrokerStokItem({
    required this.idBroker,
    required this.nama,
    required this.labelSisa,
    required this.sakSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  factory BrokerStokItem.fromJson(Map<String, dynamic> j) => BrokerStokItem(
    idBroker: pickI(j, ['IdBroker', 'idBroker', 'id_broker']) ?? 0,
    nama: pickS(j, ['Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa', 'label_sisa']) ?? 0,
    sakSisa: pickI(j, ['SakSisa', 'sakSisa', 'sak_sisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa', 'berat_sisa']) ?? 0,
    dateCreateTertua: pickDT(j, [
      'DateCreateTertua',
      'dateCreateTertua',
      'date_create_tertua',
    ]),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
