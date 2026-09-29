/// Proses yang punya sumber data stok tersendiri — dipakai bersama oleh
/// [StockSelectionScreen], [StockDetailScreen], dan `stock_totals.dart`.
/// Semua sudah punya repository/model di `lib/features/production/shared/`
/// — tidak ada endpoint baru.
enum StockProsesKey {
  washing,
  broker,
  crusher,
  bonggolan,
  gilingan,
  mixer,
  furnitureWip,
  barangJadi,
  reject,
  bahanBaku,

  bahanBakuProses,
  bahanBakuPakai,
  wipInject,
  wipStamping,
  wipSpanner,
  bahanPendukung,
  barangJadiGrande,
  barangJadiHana,
  barangJadiModelux,
  barangJadiMerona,
  barangJadiMoore,
  barangJadiSekar,
  barangJadiKursi,
  barangJadiEnamel,
}
