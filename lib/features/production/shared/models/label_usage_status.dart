// lib/features/production/shared/models/label_usage_status.dart
//
// Status pemakaian satu label penerimaan (barang dagang / bahan pendukung).
//
// Dibedakan tiga kondisi, bukan dua, karena ada kondisi antara yang mudah
// terlewat: Konsumsi PARSIAL di produksi memotong kolom `Qty` (stok live)
// tanpa mengisi `DateUsage`. Jadi `DateUsage IS NULL` saja tidak cukup untuk
// menyatakan label belum dipakai —label yang sudah separuh habis tetap punya
// DateUsage NULL.
//
// Sumber kebenaran per kondisi:
//   belumDipakai — DateUsage NULL dan Qty == QtyAwal (tidak pernah dikurangi)
//   terpakai     — DateUsage NULL dan Qty < QtyAwal (sudah dipotong sebagian,
//                  masih ada sisa; hanya BahanPendukung yang bisa sampai sini)
//   habis        — DateUsage terisi (sudah dipakai penuh)
enum LabelUsageStatus {
  belumDipakai('Belum Dipakai'),
  terpakai('Terpakai'),
  habis('Habis');

  const LabelUsageStatus(this.label);

  /// Teks yang ditampilkan di badge.
  final String label;
}