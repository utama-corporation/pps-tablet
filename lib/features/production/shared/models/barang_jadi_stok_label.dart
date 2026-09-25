import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoBJ) dengan sisa Pcs > 0 untuk satu IdBJ — [sakSisa]
/// dipetakan dari `Pcs`.
class BarangJadiStokLabel implements StokLabelData {
  final String noBJ;
  @override
  final String label;
  final int pcs;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const BarangJadiStokLabel({
    required this.noBJ,
    required this.label,
    required this.pcs,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  @override
  int get sakSisa => pcs;

  factory BarangJadiStokLabel.fromJson(Map<String, dynamic> j) =>
      BarangJadiStokLabel(
        noBJ: pickS(j, ['NoBJ', 'noBJ']) ?? '',
        label: pickS(j, ['Label', 'label']) ?? '',
        pcs: pickI(j, ['Pcs', 'pcs']) ?? 0,
        beratSisa: pickD(j, ['Berat', 'berat']) ?? 0,
        dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}
