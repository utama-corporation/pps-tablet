import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok reject per jenis — RejectV2 adalah tabel flat (satu baris =
/// satu label, seperti FurnitureWIP), jadi tidak ada kolom sak asli.
/// [labelSisa] dipetakan ke [sakSisa] hanya untuk keperluan cek kosong
/// pada [StokItemList]; kolom hitungan disembunyikan lewat
/// `showSakColumn: false` pada [TypedStokItemSource].
class RejectStokItem implements StokItemData {
  final int idReject;
  @override
  final String nama;

  /// Jumlah label (NoReject) yang masih punya sisa berat.
  final int labelSisa;

  @override
  final double beratSisa;

  /// Tanggal label tertua yang masih ada sisa — absen (null) bila tidak
  /// ada stok.
  final DateTime? dateCreateTertua;

  @override
  final String lokasi;

  const RejectStokItem({
    required this.idReject,
    required this.nama,
    required this.labelSisa,
    required this.beratSisa,
    this.dateCreateTertua,
    this.lokasi = '',
  });

  @override
  int get sakSisa => labelSisa;

  factory RejectStokItem.fromJson(Map<String, dynamic> j) => RejectStokItem(
    idReject: pickI(j, ['IdReject', 'idReject']) ?? 0,
    nama: pickS(j, ['NamaReject', 'namaReject', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
