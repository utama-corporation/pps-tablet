import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class CrusherStokItem implements StokItemData {
  final int idCrusher;
  @override
  final String nama;

  /// Jumlah label (NoCrusher) yang masih punya sisa berat.
  final int labelSisa;
  @override
  final double beratSisa;

  /// Tanggal item tertua (paling lama mengendap) dalam stok ini — null bila
  /// stok kosong.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const CrusherStokItem({
    required this.idCrusher,
    required this.nama,
    required this.labelSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  /// Stok crusher tidak dihitung per sak, hanya berat.
  @override
  int get sakSisa => 0;

  factory CrusherStokItem.fromJson(Map<String, dynamic> j) => CrusherStokItem(
    idCrusher: pickI(j, ['IdCrusher', 'idCrusher']) ?? 0,
    nama: pickS(j, ['NamaCrusher', 'namaCrusher', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
