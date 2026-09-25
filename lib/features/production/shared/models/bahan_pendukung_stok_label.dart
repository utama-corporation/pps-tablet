import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoBahanPendukung) dengan sisa Pcs > 0 untuk satu
/// IdCabinetMaterial. Tidak ada kolom berat — dipakai dengan
/// `showBeratColumn: false`.
class BahanPendukungStokLabel implements StokLabelData {
  final String noBahanPendukung;
  @override
  final String label;
  final int qtySisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const BahanPendukungStokLabel({
    required this.noBahanPendukung,
    required this.label,
    required this.qtySisa,
    this.dateCreate,
    this.lokasi = '',
  });

  @override
  int get sakSisa => qtySisa;

  @override
  double get beratSisa => qtySisa.toDouble();

  factory BahanPendukungStokLabel.fromJson(Map<String, dynamic> j) =>
      BahanPendukungStokLabel(
        noBahanPendukung:
            pickS(
              j,
              [
                'NoBahanPendukung',
                'noBahanPendukung',
                'NamaBahanPendukung',
                'namaBahanPendukung',
              ],
            ) ??
            '',
        label: pickS(j, ['Label', 'label', 'NoLabel', 'noLabel']) ?? '',
        qtySisa: pickI(j, ['QtySisa', 'qtySisa', 'Qty', 'qty']) ?? 0,
        dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
        lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
      );
}