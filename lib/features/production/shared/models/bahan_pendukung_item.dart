import '../../../../core/utils/model_helpers.dart';

/// Satu baris hasil lookup label bahan pendukung (`BP.`). Dibuat dari data
/// mentah (row) respons endpoint validate-label — satu label mewakili satu
/// material ([BahanPendukungItem.idCabinetMaterial]) dengan quantity
/// (Qty / QtySisa) yang akan langsung diambil penuh saat scan.
class BahanPendukungItem {
  final String? noBahanPendukung;
  final int? idCabinetMaterial;
  final String? namaJenis;
  final String? namaUom;
  final String? itemCode;
  final num? qty;
  final num? qtySisa;

  const BahanPendukungItem({
    this.noBahanPendukung,
    this.idCabinetMaterial,
    this.namaJenis,
    this.namaUom,
    this.itemCode,
    this.qty,
    this.qtySisa,
  });

  factory BahanPendukungItem.fromJson(Map<String, dynamic> j) =>
      BahanPendukungItem(
        noBahanPendukung: pickS(j, ['NoBahanPendukung', 'noBahanPendukung']),
        idCabinetMaterial: pickI(
          j,
          [
            'IdCabinetMaterial',
            'idCabinetMaterial',
            // Server mengalias-kan kolom ini sebagai "idJenis" pada
            // endpoint inject validate-label (case "BP.").
            'IdJenis',
            'idJenis',
            'Id',
            'id',
          ],
        ),
        namaJenis: pickS(
          j,
          [
            'NamaCabinetMaterial',
            'namaCabinetMaterial',
            'NamaJenis',
            'namaJenis',
            'Nama',
            'nama',
          ],
        ),
        namaUom: pickS(j, ['NamaUOM', 'namaUom']),
        itemCode: pickS(j, ['ItemCode', 'itemCode']),
        qty: pickN(j, ['Qty', 'qty', 'QtySisa', 'qtySisa', 'Pcs', 'pcs', 'Jumlah']),
        qtySisa: pickN(j, ['QtySisa', 'qtySisa']),
      );

  /// Quantity yang diambil penuh dari label (prioritas Qty, fallback QtySisa).
  num get quantity => qty ?? qtySisa ?? 0;
}