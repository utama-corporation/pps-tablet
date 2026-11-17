/// Opsi UOM dari `GET /api/mst-mesin-produksi/meta` (data.uom),
/// disalin dari tabel `MstUOM`.
class UomOption {
  const UomOption({required this.idUom, required this.namaUom});

  final int idUom;
  final String namaUom;
}
