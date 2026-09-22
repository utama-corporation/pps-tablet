import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoInject) dengan sisa berat > 0 untuk satu IdInject.
/// Tidak ada kolom sak/pcs — dipakai dengan `showSakColumn: false`.
class InjectStokLabel implements StokLabelData {
  final String noFurnitureWIP;
  @override
  final String label;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;

  const InjectStokLabel({
    required this.noFurnitureWIP,
    required this.label,
    required this.beratSisa,
    this.dateCreate,
  });

  @override
  int get sakSisa => 0;

  factory InjectStokLabel.fromJson(Map<String, dynamic> j) => InjectStokLabel(
    noFurnitureWIP: pickS(j, ['NoFurnitureWIP', 'noFurnitureWIP']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    beratSisa: pickD(j, ['Berat', 'berat']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
  );
}
