import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoInject) dengan sisa berat > 0 untuk satu IdInject.
/// Tidak ada kolom sak/pcs — dipakai dengan `showSakColumn: false`.
class PackingStokLabel implements StokLabelData {
  final String noBJ;
  @override
  final String label;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;

  const PackingStokLabel({
    required this.noBJ,
    required this.label,
    required this.beratSisa,
    this.dateCreate,
  });

  @override
  int get sakSisa => 0;

  factory PackingStokLabel.fromJson(Map<String, dynamic> j) =>
      PackingStokLabel(
    noBJ: pickS(j, ['NoBJ', 'noBJ']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    beratSisa: pickD(j, ['Berat', 'berat']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
  );
}