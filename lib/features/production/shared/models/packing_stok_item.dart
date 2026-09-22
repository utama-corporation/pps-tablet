import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Sisa stok packing per jenis — RejectV2 adalah tabel flat (satu baris =
/// satu label, seperti FurnitureWIP), jadi tidak ada kolom sak asli.
/// [labelSisa] dipetakan ke [sakSisa] hanya untuk keperluan cek kosong
/// pada [StokItemList]; kolom hitungan disembunyikan lewat
/// `showSakColumn: false` pada [TypedStokItemSource].
class PackingStokItem implements StokItemData {
  final int idBJ;
  final String namaBJ;

  @override
  String get nama => namaBJ;

  /// Jumlah label (NoReject) yang masih punya sisa berat.
  final int labelSisa;

  @override
  final double beratSisa;

  /// Tanggal label tertua yang masih ada sisa — absen (null) bila tidak
  /// ada stok.
  final DateTime? dateCreateTertua;

  const PackingStokItem({
    required this.idBJ,
    required this.namaBJ,
    required this.labelSisa,
    required this.beratSisa,
    this.dateCreateTertua,
  });

  @override
  int get sakSisa => labelSisa;

  factory PackingStokItem.fromJson(Map<String, dynamic> j) => PackingStokItem(
    idBJ: pickI(j, ['IdBJ', 'idBJ']) ?? 0,
    namaBJ: pickS(j, ['NamaBJ', 'namaBJ', 'Nama', 'nama']) ?? '',
    labelSisa: pickI(j, ['LabelSisa', 'labelSisa']) ?? 0,
    beratSisa: pickD(j, ['BeratSisa', 'beratSisa']) ?? 0,
    dateCreateTertua: pickDT(j, ['DateCreateTertua', 'dateCreateTertua']),
  );
}