import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoBJ) dengan sisa Pcs > 0 untuk satu IdBJ.
class PackingStokLabel implements StokLabelData {
  final String noBJ;
  @override
  final String label;

  /// Sisa Pcs efektif (net partial) dari label BarangJadi ini.
  final int pcs;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const PackingStokLabel({
    required this.noBJ,
    required this.label,
    required this.pcs,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  @override
  int get sakSisa => pcs;

  factory PackingStokLabel.fromJson(Map<String, dynamic> j) =>
      PackingStokLabel(
    noBJ: pickS(j, ['NoBJ', 'noBJ']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    pcs: pickI(j, ['Pcs', 'pcs']) ?? 0,
    beratSisa: pickD(j, ['Berat', 'berat']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}