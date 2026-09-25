/// Kontrak minimal yang harus dipenuhi model stok agar bisa ditampilkan
/// oleh [StokItemList] / [StokItemLabelDialog] — dipakai bersama oleh
/// stok bahan baku proses, stok washing, dsb.
abstract class StokItemData {
  String get nama;
  int get sakSisa;
  double get beratSisa;

  /// Lokasi (gabungan Blok+IdLokasi label yang masih sisa, dipisah koma).
  /// Kosong bila proses tidak menyediakan data lokasi.
  String get lokasi => '';
}

/// Kontrak minimal untuk satu baris label/pallet pada dialog rincian stok.
abstract class StokLabelData {
  String get label;
  int get sakSisa;
  double get beratSisa;
  DateTime? get dateCreate;

  /// Lokasi label (Blok+IdLokasi) — kosong bila label tidak punya lokasi.
  String get lokasi => '';
}
