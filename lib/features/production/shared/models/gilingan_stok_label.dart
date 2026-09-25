import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoGilingan) dengan sisa berat > 0 untuk satu IdGilingan.
/// Tidak ada kolom sak — dipakai dengan `showSakColumn: false`.
class GilinganStokLabel implements StokLabelData {
  final String noGilingan;
  @override
  final String label;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const GilinganStokLabel({
    required this.noGilingan,
    required this.label,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  @override
  int get sakSisa => 0;

  factory GilinganStokLabel.fromJson(Map<String, dynamic> j) => GilinganStokLabel(
    noGilingan: pickS(j, ['NoGilingan', 'noGilingan']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    beratSisa: pickD(j, ['Berat', 'berat']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
