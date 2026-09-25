import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

class MixerStokItem implements StokItemData {
  final int idMixer;
  @override
  final String nama;

  /// Jumlah label (NoMixer) yang masih punya sisa sak.
  final int labelSisa;
  @override
  final int sakSisa;
  @override
  final double beratSisa;

  /// Tanggal Mixer_h tertua yang masih ada sisa sak — absen (null) bila
  /// tidak ada stok.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const MixerStokItem({
    required this.idMixer,
    required this.nama,
    required this.labelSisa,
    required this.sakSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  factory MixerStokItem.fromJson(Map<String, dynamic> j) => MixerStokItem(
    idMixer: pickI(j, ['IdMixer', 'idMixer']) ?? 0,
    nama: pickS(j, ['Jenis', 'jenis', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    sakSisa: pickI(j, ['SakSisa', 'sakSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
