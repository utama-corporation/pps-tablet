# SPK Produksi Barang Jadi

Tahap daftar dan detail: monitoring stok, filter/pencarian/urutan, detail barang, riwayat per barang dan rincian dokumen SPK. Referensi web diperiksa pada 9 November 2026 di `/production/spk-barang-jadi`.

Tampilan mengikuti tablet existing: latar terang, header ringkas, AtlasDataTable dengan gulir horizontal dan baris yang dapat diketuk, filter di atas daftar. Status memakai teks dan warna; detail panjang dapat digulir. Loading, kosong, gagal/retry dan penolakan akses tersedia. Angka memakai locale Indonesia hingga dua desimal mengikuti Decimal(18,2) backend.

Endpoint existing:
- GET `/api/spk-barang-jadi`: monitoring, query `search`, `status`, `sort`, `dir`, `page`, `pageSize`. Ringkasan berasal dari `meta.summary` dan mencakup seluruh barang sebelum filter, sama dengan backend/web.
- GET `/api/spk-barang-jadi/history`: `idBJ`, `page`, `pageSize`.
- GET `/api/spk-barang-jadi/:noSPK`: header dan items.

Stok, status dan rekomendasi ditampilkan dari server; tidak dihitung ulang di tablet. API monitoring adalah daftar barang, bukan daftar header SPK. Riwayat per barang menyediakan tautan ke detail dokumen.

Sidebar, layar dan dialog menggunakan permission planning existing `datamasterplanning:read`. Backend SPK saat ini hanya memakai verifyToken dan belum mempunyai requirePermission khusus; filter role tablet bukan pengganti otorisasi server. Backend tidak diubah pada tahap ini.

## Seleksi dan Buat SPK (10 November 2026)

Mengikuti web (`SpkWorkspace`): pilih barang lalu "Buat SPK".
- Ketuk baris = pilih/batal pilih (checkbox, latar biru + aksen kiri). Checkbox header memilih semua baris yang sudah dimuat (tristate). Tekan lama = menu (Detail & riwayat, Pilih/Batalkan). Kolom AKSI berisi tombol Detail. Dialog detail barang punya tombol "Pilih untuk Buat SPK"/"Batalkan Pilihan".
- Pilihan disimpan per `IdBJ` di `SpkViewModel` dan tetap ada saat cari/filter/urut/halaman berganti, sampai dibatalkan atau SPK tersimpan. Bar bawah menampilkan jumlah barang dan total qty rekomendasi.
- `SpkCreateDialog`: qty awal = qty rekomendasi; wajib > 0, maks. 2 desimal (Decimal(18,2)); qty bukan kelipatan MPQ hanya peringatan (sama dengan web). Keterangan opsional maks. 255. Baris bisa dihapus dari form (minimal 1).
- POST `/api/spk-barang-jadi` body `{keterangan, items:[{IdBJ, QtySPK}]}`. Tanggal tidak dikirim (server memakai hari ini, sama dengan web); nomor, status OPEN dan snapshot stok/min/max/MPQ/rekomendasi diisi server. Error server ditampilkan di dalam form.
- Setelah sukses: pilihan dikosongkan, daftar dimuat ulang, dialog sukses (No. SPK, tanggal, jumlah barang, total qty) dengan "Lihat SPK" yang membuka detail dari respons POST tanpa GET ulang.
- Detail SPK dirapikan: ringkasan (tanggal, status, jumlah barang, total qty, total selesai, dibuat), keterangan, lalu tabel Atlas per barang (stok saat SPK, rekomendasi, qty SPK, qty produksi, progres selesai, status) dengan gulir horizontal di layar sempit.
- Cetak SPK (ada di web) belum dibuat di tablet.

Izin buat SPK memakai `datamasterplanning:read` yang sama karena backend hanya memeriksa token.
