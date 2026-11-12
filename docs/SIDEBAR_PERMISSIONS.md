# Sidebar dan permission PPS Tablet

Acuan: menu web PPS yang diperiksa pada 9 November 2026.

## Perilaku

- Katalog terpusat berisi 63 entri dengan nama, urutan dan kelompok mengikuti web.
- Seluruh entri memiliki tujuan tablet, termasuk Retur (Old) yang memakai layar Retur v2 existing dan Role (/shell/role).
- Menu, grup, dan section tanpa permission disembunyikan. Dashboard tersedia untuk sesi yang sudah masuk ke AppShell.
- Akses memakai permission yang dikirim backend saat login dan dimuat PermissionViewModel, bukan nama role atau ID kelompok yang ditulis di source. Refresh mengganti daftar grant lama; perubahan role di server berlaku setelah daftar permission dimuat ulang.
- Permission read bersifat eksplisit; create/update/delete tidak menyiratkan read. Global wildcard * mengikuti require-permission.js backend. Wildcard modul seperti label_broker:* tidak dianggap sebagai grant read.
- AppShell memeriksa ulang permission untuk tujuan menu dan alias route legacy. Backend tetap menjadi batas otorisasi API; perubahan ini tidak memberikan grant baru dan tidak mengubah data role.
- Label Bahan Pendukung dan History tetap memakai layar tablet yang sudah berfungsi walaupun tautan web terkait masih #.

## Pemetaan khusus

- Stock: penerimaanbahanbaku:read, sesuai guard pada master-stock API yang dipakai tablet.
- History: label_washing:read, mengikuti guard /api/audit saat ini.
- Good Transfer dan In Transit: goods_transfer:read. Ejaan permission legacy good_transfer/goodtransfer tidak disamakan karena API sekarang memakai goods_transfer.
- Trade-In: retur:read atau barangjadiretur:read, memakai role pembaca retur yang tersedia karena belum ada kode read Trade-In tersendiri pada katalog PPS yang diperiksa.
- SPK monitoring/detail: datamasterplanning:read sebagai pemetaan ke role perencanaan yang sudah ada. Backend SPK saat ini hanya memakai verifyToken, belum requirePermission khusus; lihat SPK_TABLET.md.
- Master memakai kode read spesifik masing-masing endpoint; datamaster:read tidak otomatis memberikan semua akses Master.

## Katalog akses

| ID menu | Menu | Permission (salah satu) | Route tablet / status |
| --- | --- | --- | --- |
| / | Dashboard | Sesi login | /shell/welcome |
| /label/bahan-baku | Bahan Baku | label_bahanbaku:read | /label/bahan-baku |
| /label/washing | Washing | label_washing:read | /label/washing |
| /label/bonggolan | Bonggolan | label_bonggolan:read | /label/bonggolan |
| /label/broker | Broker | label_broker:read | /label/broker |
| /label/crusher | Crusher | label_crusher:read | /label/crusher |
| /label/furniture-wip | Furniture WIP | label_furniturewip:read | /label/furniture_wip |
| /label/gilingan | Gilingan | label_gilingan:read | /label/gilingan |
| /label/mixer | Mixer | label_mixer:read | /label/mixer |
| /label/packing | Packing | label_barangjadi:read | /label/packing |
| /label/reject | Reject | label_reject:read | /label/reject |
| label.bahan-pendukung | Bahan Pendukung | label_bahanpendukung:read | /label/bahan-pendukung |
| /label/barang-dagang | Barang Dagang | label_barangdagang:read | /label/barang-dagang |
| /bahan-pendukung/penerimaan | Penerimaan Bahan Pendukung | label_bahanpendukung:read | /shell/penerimaan-bahan-pendukung |
| /production/penerimaan-bahan-baku | Penerimaan Bahan Baku | penerimaanbahanbaku:read | /shell/penerimaan-bahan-baku |
| /production/washing | Proses Washing | produksi_washing:read | /production/washing |
| /production/broker | Proses Broker | produksi_broker:read | /production/broker |
| /production/crusher | Proses Crusher | produksi_crusher:read | /production/crusher |
| /production/mixer | Proses Mixer | produksi_mixer:read | /production/mixer |
| /production/inject | Proses Inject | injectproduksi:read | /shell/inject |
| /production/gilingan | Proses Gilingan | produksi_gilingan:read | /production/gilingan |
| /production/stamping | Proses Stamping | hotstamping:read | /shell/hot-stamp |
| /production/pasang-kunci | Proses Pasang Kunci | pasangkunci:read | /shell/key-fitting |
| /production/spanner | Packing Spanner | spanner:read | /shell/spanner |
| /production/packing | Packing | packing:read | /shell/packing |
| /warehouse/penjualan | Penjualan | penjualan:read | /shell/penjualan |
| /warehouse/good-transfer | Good Transfer | goods_transfer:read | /shell/goods-transfer |
| /warehouse/in-transit | In Transit | goods_transfer:read | /shell/in-transit |
| /warehouse/retur-v3 | Retur v3 | retur:read | /shell/retur-v3 |
| /warehouse/retur-old | Retur (Old) | retur_old:read | /shell/retur-v2 |
| /warehouse/trade-in | Penerimaan Trade In | retur:read atau barangjadiretur:read | /shell/trade-in |
| /warehouse/penerimaan-barang-dagang | Penerimaan Barang Dagang | label_barangdagang:read | /shell/penerimaan-barang-dagang |
| /operasional/stock | Stock | penerimaanbahanbaku:read | /shell/stock |
| /operasional/bongkar-susun | Bongkar Susun | bongkarsusun:read | /shell/bongkar-susun |
| /operasional/sortir-reject | Sortir Reject | barangjadisortirreject:read | /shell/sortir-reject |
| /operasional/stock-opname | Stock Opname | stockopname:read | /shell/stock-opname-v2 |
| /operasional/stock-opname-old | Stock Opname (Old) | stockopname:read | /stockopname |
| /production/spk-barang-jadi | SPK Produksi Barang Jadi | datamasterplanning:read | /production/spk-barang-jadi |
| /laporan/bahan-baku | Laporan Â· Bahan Baku | laporan:read | /laporan/bahan-baku |
| /laporan/washing | Laporan Â· Washing | laporan:read | /laporan/washing |
| /laporan/broker | Laporan Â· Broker | laporan:read | /laporan/broker |
| /laporan/bonggolan | Laporan Â· Bonggolan | laporan:read | /laporan/bonggolan |
| /laporan/crusher | Laporan Â· Crusher | laporan:read | /laporan/crusher |
| /laporan/gilingan | Laporan Â· Gilingan | laporan:read | /laporan/gilingan |
| /laporan/mixer | Laporan Â· Mixer | laporan:read | /laporan/mixer |
| /laporan/reject | Laporan Â· Reject | laporan:read | /laporan/reject |
| /laporan/furniture-wip | Laporan Â· Furniture WIP | laporan:read | /laporan/furniture-wip |
| /laporan/barang-jadi | Laporan Â· Barang Jadi | laporan:read | /laporan/barang-jadi |
| /laporan/barang-dagang | Laporan Â· Barang Dagang | laporan:read | /laporan/barang-dagang |
| /laporan/rekap-produksi | Laporan Â· Rekap Produksi | laporan:read | /laporan/rekap-produksi |
| /laporan/semua | Laporan Â· Semua Laporan | laporan:read | /laporan/semua |
| laporan-monitoring.history | History | label_washing:read | /shell/history |
| /mapping | Mapping | mappinglokasi:read | /shell/mapping |
| /master/operator-regu | Master Operator & Regu | datamasteroperator:read | /master/operator-regu |
| /master/mesin-produksi | Master Mesin Produksi | datamastermesin:read | /master/mesin-produksi |
| /master/barang | Master Barang | datamasterbarang:read | /master/barang |
| /master/supplier | Master Supplier | datamastersupplier:read | /master/supplier |
| /master/cetakan | Master Cetakan | datamastercetakan:read | /master/cetakan |
| /master/formula | Master Formula | masterformulaproduksi:read | /master/formula |
| /master/blok-lokasi | Blok & Lokasi | datamasterbloklokasi:read | /master/blok-lokasi |
| /user | User | datamasteruser:read | /shell/user |
| /master/permission-group | Role | datamasterpermissiongroup:read | /shell/role |

## Validasi

- flutter test test/pps_menu_permissions_test.dart test/pps_sidebar_test.dart
- dart analyze lib/core/navigation/pps_menu_catalog.dart lib/core/services/permission_rules.dart lib/core/services/permission_storage.dart lib/core/view_model/permission_view_model.dart lib/features/home/view/widgets/home_sidebar.dart lib/core/view/app_shell.dart test/pps_menu_permissions_test.dart test/pps_sidebar_test.dart
- Skenario: grant kosong, operator washing/mixer, warehouse, master supplier, super-admin, pergantian role, perbedaan read/create, alias route lama, menu nonaktif, urutan web, dan transisi collapsed/expanded.
- Widget diuji pada viewport 1280Ã—800 dan skala teks 1,3. Preview dapat dibuat dengan SIDEBAR_SCREENSHOT_DIR dan SIDEBAR_TEST_FONT_DIR; tanpa opsi tersebut tes tidak memerlukan font host.

Perubahan ini menyiapkan source sidebar dan navigasi. Tidak ada perubahan hak akses database ataupun deployment produksi dalam tahap ini.
