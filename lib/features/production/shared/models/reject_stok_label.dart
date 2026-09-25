import '../../../../core/utils/model_helpers.dart';
import 'stok_item_data.dart';

/// Satu baris label (NoReject) dengan sisa berat > 0 untuk satu IdReject.
/// Tidak ada kolom sak/pcs — dipakai dengan `showSakColumn: false`.
class RejectStokLabel implements StokLabelData {
  final String noReject;
  @override
  final String label;
  @override
  final double beratSisa;
  @override
  final DateTime? dateCreate;
  @override
  final String lokasi;

  const RejectStokLabel({
    required this.noReject,
    required this.label,
    required this.beratSisa,
    this.dateCreate,
    this.lokasi = '',
  });

  @override
  int get sakSisa => 0;

  factory RejectStokLabel.fromJson(Map<String, dynamic> j) => RejectStokLabel(
    noReject: pickS(j, ['NoReject', 'noReject']) ?? '',
    label: pickS(j, ['Label', 'label']) ?? '',
    beratSisa: pickD(j, ['Berat', 'berat']) ?? 0,
    dateCreate: pickDT(j, ['DateCreate', 'dateCreate']),
    lokasi: pickS(j, ['Lokasi', 'lokasi']) ?? '',
  );
}
