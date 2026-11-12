# Label Barang Dagang tablet

Menu `/label/barang-dagang` kini aktif pada sidebar untuk role dengan `label_barangdagang:read`.

Tampilan disamakan dengan menu Reject (`/label/reject`): Action bar putih (search + toggle `Tampilkan Semua`), tabel infinite-scroll `AtlasPagedDataTable` (kolom NO. LABEL + badge `Terpakai`, NAMA BARANG, SUPPLIER, PENERIMAAN, QTY, SISA, LOKASI, PRINT), tap baris memilih, long-press membuka popover aksi.

- Daftar menggunakan `GET /api/labels/barang-dagang`, dengan infinite scroll, pencarian server dan opsi menyertakan label terpakai.
- Qty memakai `Qty`. Sisa memakai `QtySisa` hasil query backend: untuk `IsPartial = 1`, `Qty - SUM(BarangDagangPartial.Qty)`, minimum nol; selain itu memakai `Qty`. Label `Used` ditampilkan habis dengan sisa nol. Sisa merah saat partial.
- Detail & cetak: popover long-press → `Detail & Cetak` membuka dialog detail (barang, supplier, nomor penerimaan, lokasi, keterangan, status, jumlah cetak). Cetak memerlukan permission `label_barangdagang:update` dan stok yang belum habis. PDF memakai endpoint existing `/api/labels/barang-dagang/:code/pdf`.
- Popover juga menyediakan `History` (audit), `Edit`, `Print`, dan `Delete`.
  - Edit membuka `BarangDagangEditDialog` dan memanggil `PUT /api/labels/barang-dagang/:code` (field: Qty, Keterangan; supplier, barang, blok/lokasi dan IsPartial tidak diubah lewat UI). Hanya bisa bila belum dipakai dan belum pernah dicetak (backend juga menolak dengan 409). Permission `label_barangdagang:update`.
  - Delete memanggil `DELETE /api/labels/barang-dagang/:code` dengan dialog konfirmasi. Hanya bisa bila belum dipakai. Permission `label_barangdagang:delete`.
- Alur cetak memakai dialog bersama, lock cetak dan antrean sinkronisasi existing (`feature: 'barang_dagang'`). Counter dikonfirmasi melalui PATCH `/api/labels/barang-dagang/:code/print` setelah printer melaporkan hasil cetak.
- Label baru tetap dibuat melalui Penerimaan Barang Dagang (tidak ada endpoint create generik di `/api/labels/barang-dagang`), sehingga tidak ada tombol Buat Baru.

Kolom PRINT berbagi widget `LabelPrintCountCell` (`lib/common/widgets/label_print_count_cell.dart`) dengan tabel Reject.

Validasi: `test/barang_dagang_label_test.dart`, `test/pps_menu_permissions_test.dart`, `test/pps_sidebar_test.dart`; analisis file fitur, route dan katalog menu.
