import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok inject per jenis — RejectV2 adalah tabel flat (satu baris =
/// satu label, seperti FurnitureWIP), jadi tidak ada kolom sak asli.
/// [labelSisa] dipetakan ke [sakSisa] hanya untuk keperluan cek kosong
/// pada [StokItemList]; kolom hitungan disembunyikan lewat
/// `showSakColumn: false` pada [TypedStokItemSource].
class InjectStokItem implements StokItemData {
  final int idCabinetWIP;
  @override
  final String nama;

  /// Jumlah label (NoReject) yang masih punya sisa berat.
  final int labelSisa;

  @override
  final double beratSisa;

  /// Tanggal label tertua yang masih ada sisa — absen (null) bila tidak
  /// ada stok.
  final DateTime? dateCreateTertua;

  const InjectStokItem({
    required this.idCabinetWIP,
    required this.nama,
    required this.labelSisa,
    required this.beratSisa,
    this.dateCreateTertua,
  });

  @override
  int get sakSisa => labelSisa;

  factory InjectStokItem.fromJson(Map<String, dynamic> j) => InjectStokItem(
    idCabinetWIP: pickI(j, ['IdCabinetWIP', 'idCabinetWIP']) ?? 0,
    nama: pickS(j, ['NamaReject', 'namaReject', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
  );
}
