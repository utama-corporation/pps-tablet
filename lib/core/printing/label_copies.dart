/// Jumlah rangkap default per jenis label.
///
/// Label Barang Jadi dicetak rangkap dua (permintaan user, 2026-11-23).
/// Operator masih bisa mengubahnya di layar preview cetak; cetak otomatis
/// (tanpa preview) memakai nilai ini apa adanya.
///
/// Rangkap ditentukan dari URL PDF label supaya berlaku di SEMUA titik cetak
/// label BJ (label packing, produksi packing/inject, retur, penjualan, bongkar
/// susun, sortir reject) tanpa tiap layar perlu tahu aturannya, dan supaya
/// batch campuran (mis. BJ + Furniture WIP) hanya menggandakan label BJ.
abstract final class LabelCopies {
  static const barangJadi = 2;

  /// Segmen path endpoint PDF label Barang Jadi (`ApiConstants.packingLabelPdf`).
  static const _barangJadiPath = '/api/labels/packing/';

  /// Rangkap default untuk PDF label di [url].
  static int forPdfUrl(Uri url) =>
      url.path.contains(_barangJadiPath) ? barangJadi : 1;
}
