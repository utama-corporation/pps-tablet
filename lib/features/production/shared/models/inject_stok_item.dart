import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok inject per jenis — RejectV2 adalah tabel flat (satu baris =
/// satu label, seperti FurnitureWIP), jadi tidak ada kolom sak asli.
/// [labelSisa] dipetakan ke Pcs via `PcsSisa` (net partial); kolom berat
/// disembunyikan lewat `showBeratColumn: false` pada [TypedStokItemSource].
class InjectStokItem implements StokItemData {
  final int idCabinetWIP;
  @override
  final String nama;

  /// Jumlah label (NoReject) yang masih punya sisa berat.
  final int labelSisa;

  /// Total Pcs efektif tersisa (net partial, clamp ke 0).
  final int pcsSisa;

  @override
  final double beratSisa;

  /// Tanggal label tertua yang masih ada sisa — absen (null) bila tidak
  /// ada stok.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const InjectStokItem({
    required this.idCabinetWIP,
    required this.nama,
    required this.labelSisa,
    required this.pcsSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  @override
  int get sakSisa => pcsSisa;

  factory InjectStokItem.fromJson(Map<String, dynamic> j) => InjectStokItem(
    idCabinetWIP: pickI(j, ['IdCabinetWIP', 'idCabinetWIP']) ?? 0,
    nama: pickS(j, ['NamaReject', 'namaReject', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    pcsSisa: pickI(j, ['PcsSisa', 'pcsSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
