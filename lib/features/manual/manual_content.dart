import 'package:flutter/material.dart';

/// Kunci menu Manual di katalog sidebar (Workspace & Analytics).
const manualMenuKey = 'workspace.manual';

/// Satu langkah bernomor. [path] tampil sebagai lencana jalur menu.
class ManualStep {
  final String title, text;
  final String? path;
  const ManualStep(this.title, this.text, {this.path});
}

/// Satu bagian bernomor dalam satu area.
class ManualSection {
  final String id, title, description;
  final IconData icon;
  final List<ManualStep> steps;
  final List<String> notes;

  /// Route katalog yang dibuka tombol "Buka ..."; null bila tidak ada tombol.
  final String? openRoute;
  final String? openLabel;

  const ManualSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.steps = const [],
    this.notes = const [],
    this.openRoute,
    this.openLabel,
  });

  /// Teks yang dicari: judul, deskripsi, langkah, jalur menu, dan catatan.
  String get searchText => [
    title,
    description,
    for (final s in steps) ...[s.title, s.text, ?s.path],
    ...notes,
  ].join(' ').toLowerCase();
}

class ManualArea {
  final String key, label, tagline;
  final List<ManualSection> sections;
  const ManualArea(this.key, this.label, this.tagline, this.sections);
}

/// Isi Manual PPS. Langkah ditulis dari layar tablet (nama menu dan tombol
/// apa adanya). Aturan lapangan yang belum pasti sengaja tidak ditulis.
const ppsManualAreas = [
  ManualArea('workspace', 'Workspace', 'Ruang kerja harian: tugas, ringkasan, laporan, dan angka KPI.', [
    ManualSection(
      id: 'ws-my-work',
      title: '1. My Work',
      description: 'Daftar pekerjaan yang perlu ditindaklanjuti, sesuai hak akses Anda.',
      icon: Icons.checklist_rounded,
      steps: [
        ManualStep(
          'Buka My Work',
          'Angka pada menu My Work menunjukkan jumlah pekerjaan. Buka dari sidebar Workspace & Analytics > My Work.',
          path: 'Workspace & Analytics > My Work',
        ),
        ManualStep(
          'Pilih kategori',
          'Pilih salah satu kotak antrian, misalnya produksi tertunda, label belum dicetak, stock opname, atau SPK terbuka. Angka di kotak menunjukkan jumlah item.',
        ),
        ManualStep(
          'Cari dokumen',
          'Ketik nomor dokumen, nomor label, atau keterangan pada kolom pencarian untuk mempersempit daftar.',
        ),
        ManualStep(
          'Tindak lanjuti',
          'Ketuk baris untuk melihat detail, lalu tekan "Buka <modul>" untuk membuka menu tujuan dengan nomor dokumen tersebut.',
        ),
      ],
      notes: [
        'Kategori yang tampil mengikuti hak akses; item hilang dengan sendirinya setelah diselesaikan di modulnya.',
      ],
      openRoute: '/shell/my-work',
      openLabel: 'Buka My Work',
    ),
    ManualSection(
      id: 'ws-dashboard',
      title: '2. Dashboard',
      description: 'Membaca kartu ringkasan, tren, aktivitas, dan favorit.',
      icon: Icons.dashboard_outlined,
      steps: [
        ManualStep(
          'Pilih rentang',
          'Gunakan pilihan rentang di bagian atas untuk mengubah periode ringkasan. Angka dibandingkan dengan rentang sebelumnya.',
          path: 'Workspace & Analytics > Dashboards',
        ),
        ManualStep(
          'Baca kartu dan grafik',
          'Kartu domain menampilkan angka utama dan perubahan terhadap periode sebelumnya. Grafik menunjukkan tren harian; ketuk kartu untuk membuka modulnya.',
        ),
        ManualStep(
          'Buka favorit',
          'Kartu Favorit menampilkan menu dan laporan yang ditandai bintang. Ketuk untuk membukanya, atau kelola dari menu Favorit di beranda ponsel.',
        ),
      ],
      notes: [
        'Bagian dashboard yang tampil menyesuaikan hak akses; tanggal pembaruan data ditampilkan di header.',
      ],
      openRoute: '/shell/welcome',
      openLabel: 'Buka Dashboard',
    ),
    ManualSection(
      id: 'ws-reports',
      title: '3. Reports dan Favorit',
      description: 'Mencari laporan, mengisi filter, dan menyimpan laporan favorit.',
      icon: Icons.bar_chart_outlined,
      steps: [
        ManualStep(
          'Pilih kategori laporan',
          'Buka Reports lalu pilih kategorinya, misalnya Bahan Baku, Washing, atau Rekap Produksi.',
          path: 'Workspace & Analytics > Reports',
        ),
        ManualStep(
          'Cari dan buka laporan',
          'Gunakan kolom pencarian, pilih laporan, isi filter yang diminta, lalu tekan Buka PDF untuk melihat atau mencetaknya.',
        ),
        ManualStep(
          'Simpan sebagai favorit',
          'Tekan ikon bintang pada laporan atau menu agar tampil di kartu Favorit pada Dashboard.',
        ),
      ],
      openRoute: '/laporan/semua',
      openLabel: 'Buka Semua Laporan',
    ),
    ManualSection(
      id: 'ws-kpi',
      title: '4. KPI & Ratio',
      description: 'Rendemen, waste, dan reject per proses beserta mesinnya.',
      icon: Icons.speed_outlined,
      steps: [
        ManualStep(
          'Tentukan tanggal',
          'Halaman menampilkan KPI bulan berjalan s.d. tanggal terpilih. Gunakan tombol tanggal untuk mengubahnya, lalu tekan muat ulang bila perlu.',
          path: 'Workspace & Analytics > KPI & Ratio',
        ),
        ManualStep(
          'Baca metrik',
          'Setiap proses menampilkan metrik utama, total input/output, dan tabel per mesin. Angka di atas 100% pada rendemen berarti output tercatat lebih besar dari input.',
        ),
        ManualStep(
          'Perhatikan catatan sumber',
          'Catatan di bawah setiap kartu menjelaskan sumber data dan keterbatasan perbandingan antar mesin.',
        ),
      ],
      notes: [
        'Hanya proses yang Anda punya aksesnya yang menampilkan KPI.',
      ],
      openRoute: '/shell/kpi',
      openLabel: 'Buka KPI & Ratio',
    ),
    ManualSection(
      id: 'ws-audit',
      title: '5. Audit Timeline',
      description: 'Menelusuri jejak perubahan pada transaksi label.',
      icon: Icons.history,
      steps: [
        ManualStep(
          'Buka Audit Timeline',
          'Buka dari sidebar Workspace & Analytics > Governance > Audit Timeline.',
          path: 'Workspace & Analytics > Governance > Audit Timeline',
        ),
        ManualStep(
          'Telusuri kejadian',
          'Gunakan daftar untuk melihat aktivitas beserta waktu dan pelakunya. Persempit dengan pencarian bila tersedia.',
        ),
      ],
      notes: [
        'Menu ini hanya tampil untuk user dengan izin baca label washing.',
      ],
      openRoute: '/shell/history',
      openLabel: 'Buka Audit Timeline',
    ),
  ]),
  ManualArea('label', 'Label', 'Satu label, satu identitas barang, dari bahan baku sampai barang dagang.', [
    ManualSection(
      id: 'label-buat',
      title: '1. Membuat label',
      description: 'Mulai dari pemindaian kode, lengkapi data, lalu simpan label.',
      icon: Icons.label_outlined,
      steps: [
        ManualStep(
          'Pilih jenis label',
          'Buka sidebar Label lalu pilih jenis yang dibutuhkan, misalnya Bahan Baku, Washing, Broker, atau Barang Dagang.',
          path: 'Label > <jenis label>',
        ),
        ManualStep(
          'Scan atau ketik kode',
          'Gunakan tab Scan untuk memindai QR/barcode dengan kamera, atau tab Manual untuk mengetik kode sesuai petunjuk pada kolom isian.',
        ),
        ManualStep(
          'Lengkapi form',
          'Periksa data yang terisi otomatis, lalu lengkapi field yang masih kosong sesuai jenis label.',
        ),
        ManualStep(
          'Simpan dan cetak',
          'Tekan Simpan. Pilih printer bila diminta, lalu cetak label dari daftar atau dari dialog cetak.',
        ),
      ],
      notes: [
        'Kode yang tidak dikenal akan ditolak; periksa kembali ejaan bila memakai input manual.',
      ],
      openRoute: '/label/bahan-baku',
      openLabel: 'Buka Label Bahan Baku',
    ),
    ManualSection(
      id: 'label-cetak',
      title: '2. Mencari dan mencetak ulang label',
      description: 'Temukan label yang sudah ada lalu cetak ulang.',
      icon: Icons.print_outlined,
      steps: [
        ManualStep(
          'Buka daftar label',
          'Pilih jenis label pada sidebar, lalu cari berdasarkan nomor label pada kolom pencarian.',
          path: 'Label > Barang Dagang',
        ),
        ManualStep(
          'Buka detail',
          'Ketuk baris label untuk melihat header dan detailnya sebelum mencetak.',
        ),
        ManualStep(
          'Cetak ulang',
          'Tekan Cetak, pilih printer yang tersedia, lalu konfirmasi jumlah salinan.',
        ),
      ],
      notes: [
        'Cetak ulang untuk label rusak atau hilang; hindari pencetakan ganda yang tidak perlu.',
      ],
      openRoute: '/label/barang-dagang',
      openLabel: 'Buka Barang Dagang',
    ),
    ManualSection(
      id: 'label-pendukung',
      title: '3. Label Bahan Pendukung',
      description: 'Label bahan pendukung dan penerimaannya.',
      icon: Icons.science_outlined,
      steps: [
        ManualStep(
          'Buat label bahan pendukung',
          'Buka Label > Bahan Pendukung, scan atau ketik kode bahan, lalu isi data yang diminta.',
          path: 'Label > Bahan Pendukung',
        ),
        ManualStep(
          'Catat penerimaan',
          'Buka Penerimaan Bahan Pendukung untuk mencatat barang datang. Pilih material dari daftar, isi keterangan, lalu simpan.',
          path: 'Bahan Pendukung > Penerimaan Bahan Pendukung',
        ),
      ],
      openRoute: '/label/bahan-pendukung',
      openLabel: 'Buka Bahan Pendukung',
    ),
  ]),
  ManualArea('produksi', 'Produksi', 'Pilih mesin, buat produksi, lalu catat input, output, dan reject.', [
    ManualSection(
      id: 'prod-mulai',
      title: '1. Memulai produksi di mesin',
      description: 'Berlaku untuk Washing, Broker, Crusher, Mixer, Gilingan, Inject, dan proses hilir.',
      icon: Icons.precision_manufacturing_outlined,
      steps: [
        ManualStep(
          'Pilih proses',
          'Buka sidebar Proses Produksi lalu pilih proses yang dijalankan.',
          path: 'Proses Produksi > Washing & Broker > Proses Washing',
        ),
        ManualStep(
          'Pilih mesin',
          'Daftar mesin menampilkan mesin yang tersedia. Ketuk mesin untuk membuka produksinya.',
        ),
        ManualStep(
          'Buat produksi',
          'Isi tanggal, shift, operator, dan jam kerja lalu simpan. Nomor produksi dibuat otomatis.',
        ),
      ],
      notes: [
        'Menu produksi hanya tampil sesuai hak akses Anda.',
      ],
      openRoute: '/production/washing',
      openLabel: 'Buka Proses Washing',
    ),
    ManualSection(
      id: 'prod-input',
      title: '2. Input, output, dan reject',
      description: 'Scan label bahan, simpan input, lalu catat hasil dan reject.',
      icon: Icons.qr_code_scanner_rounded,
      steps: [
        ManualStep(
          'Scan label input',
          'Pada bagian Input tekan Scan atau ketik nomor label. Label yang discan masuk sebagai input sementara.',
        ),
        ManualStep(
          'Simpan input',
          'Periksa total input lalu tekan Simpan Input. Gunakan Batalkan bila salah scan.',
        ),
        ManualStep(
          'Tambah bahan pendukung',
          'Untuk proses tertentu, tambahkan bahan pendukung dari hasil scan atau pilihan daftar sebelum menyimpan.',
        ),
        ManualStep(
          'Catat output dan reject',
          'Tambahkan label pada bagian Output, catat reject bila ada, lalu tekan Cetak untuk label hasil.',
        ),
      ],
      notes: [
        'Input masih sementara sampai tombol Simpan Input ditekan.',
      ],
      openRoute: '/shell/inject',
      openLabel: 'Buka Proses Inject',
    ),
    ManualSection(
      id: 'prod-laporan',
      title: '3. Laporan produksi',
      description: 'Mencetak rekap produksi dan laporan per proses.',
      icon: Icons.summarize_outlined,
      steps: [
        ManualStep(
          'Buka laporan',
          'Pilih kategori Rekap Produksi pada sidebar Reports, atau tekan tombol Cetak laporan pada layar produksi.',
          path: 'Workspace & Analytics > Reports > Rekap Produksi',
        ),
        ManualStep(
          'Isi filter',
          'Tentukan rentang tanggal atau proses, lalu pilih laporan yang ingin dicetak.',
        ),
      ],
      openRoute: '/laporan/rekap-produksi',
      openLabel: 'Buka Rekap Produksi',
    ),
    ManualSection(
      id: 'prod-spk',
      title: '4. SPK Produksi',
      description: 'Melihat dan mengelola Surat Perintah Kerja barang jadi.',
      icon: Icons.assignment_outlined,
      steps: [
        ManualStep(
          'Buka SPK',
          'Buka menu SPK Produksi Barang Jadi dari sidebar.',
          path: 'SPK > SPK Produksi Barang Jadi',
        ),
        ManualStep(
          'Periksa data',
          'Lihat daftar SPK, buka detailnya, lalu gunakan tombol yang tersedia untuk mengubah atau mencetak sesuai hak akses.',
        ),
      ],
      notes: [
        'SPK dengan target terlewat juga muncul di My Work.',
      ],
      openRoute: '/production/spk-barang-jadi',
      openLabel: 'Buka SPK',
    ),
  ]),
  ManualArea('gudang', 'Gudang & Operasional', 'Pergerakan barang, stok, dan lokasi label.', [
    ManualSection(
      id: 'gudang-jual',
      title: '1. Penjualan',
      description: 'Catat penjualan dan cetak dokumennya.',
      icon: Icons.point_of_sale_outlined,
      steps: [
        ManualStep(
          'Buka daftar penjualan',
          'Buka sidebar Proses Produksi > Warehouse > Penjualan.',
          path: 'Proses Produksi > Warehouse > Penjualan',
        ),
        ManualStep(
          'Buat transaksi',
          'Tekan tambah, scan atau ketik label yang dijual, lalu lengkapi data transaksi.',
        ),
        ManualStep(
          'Simpan dan cetak',
          'Periksa daftar item lalu simpan. Buka detail transaksi untuk mencetak dokumen atau labelnya.',
        ),
      ],
      openRoute: '/shell/penjualan',
      openLabel: 'Buka Penjualan',
    ),
    ManualSection(
      id: 'gudang-transfer',
      title: '2. Good Transfer dan In Transit',
      description: 'Memindahkan barang antar gudang dan memantau perjalanannya.',
      icon: Icons.local_shipping_outlined,
      steps: [
        ManualStep(
          'Buat good transfer',
          'Buka Good Transfer, buat transfer baru, lalu scan label yang dipindahkan.',
          path: 'Proses Produksi > Warehouse > Good Transfer',
        ),
        ManualStep(
          'Simpan pengiriman',
          'Periksa daftar label lalu simpan. Dokumen transfer dapat dicetak dari detailnya.',
        ),
        ManualStep(
          'Pantau in transit',
          'Buka In Transit untuk melihat barang yang masih dalam perjalanan.',
          path: 'Proses Produksi > Warehouse > In Transit',
        ),
      ],
      openRoute: '/shell/goods-transfer',
      openLabel: 'Buka Good Transfer',
    ),
    ManualSection(
      id: 'gudang-retur',
      title: '3. Retur',
      description: 'Catat barang yang kembali dari pelanggan atau proses.',
      icon: Icons.assignment_return_rounded,
      steps: [
        ManualStep(
          'Buka daftar retur',
          'Pilih Retur v3 pada sidebar Warehouse.',
          path: 'Proses Produksi > Warehouse > Retur v3',
        ),
        ManualStep(
          'Buat retur',
          'Buat dokumen baru, scan label yang diretur, lalu isi alasan dan data pendukung.',
        ),
        ManualStep(
          'Periksa hasil',
          'Buka detail untuk melihat item, mencetak dokumen, atau melihat label yang sudah dibuat.',
        ),
      ],
      openRoute: '/shell/retur-v3',
      openLabel: 'Buka Retur v3',
    ),
    ManualSection(
      id: 'gudang-stock',
      title: '4. Stock dan Stock Opname',
      description: 'Lihat saldo dan selisihkan dengan hasil hitung fisik.',
      icon: Icons.assessment_outlined,
      steps: [
        ManualStep(
          'Lihat stock',
          'Buka Operasional > Stock, lalu pilih gudang atau kategori untuk melihat saldo.',
          path: 'Operasional > Stock',
        ),
        ManualStep(
          'Buat jadwal SO',
          'Buka Operasional > Stock Opname, pilih kategori, lalu buat jadwal baru bila belum ada.',
          path: 'Operasional > Stock Opname',
        ),
        ManualStep(
          'Isi hasil fisik',
          'Pilih lokasi, scan label atau isi jumlah fisik, lalu simpan.',
        ),
        ManualStep(
          'Cetak hasil',
          'Buka detail stock opname untuk mencetak laporan hasil perhitungan.',
        ),
      ],
      notes: [
        'Angka sistem dibekukan saat stock opname dibuat.',
      ],
      openRoute: '/shell/stock-opname-v2',
      openLabel: 'Buka Stock Opname',
    ),
    ManualSection(
      id: 'gudang-mapping',
      title: '5. Mapping Lokasi',
      description: 'Lihat isi lokasi dan pindahkan label antar lokasi.',
      icon: Icons.map_outlined,
      steps: [
        ManualStep(
          'Lihat isi lokasi',
          'Buka Monitoring > Mapping. Cari blok atau lokasi untuk melihat label di dalamnya.',
          path: 'Monitoring > Mapping',
        ),
        ManualStep(
          'Pindahkan label',
          'Pada tampilan ponsel, buka lokasi tujuan, tekan Scan QR, lalu pindai label yang dipindahkan.',
        ),
        ManualStep(
          'Simpan perpindahan',
          'Periksa daftar hasil scan lalu tekan Simpan sebelum meninggalkan halaman.',
        ),
      ],
      openRoute: '/shell/mapping',
      openLabel: 'Buka Mapping',
    ),
    ManualSection(
      id: 'gudang-bongkar',
      title: '6. Bongkar Susun dan Sortir Reject',
      description: 'Catat perubahan susunan dan barang yang disortir.',
      icon: Icons.layers_outlined,
      steps: [
        ManualStep(
          'Buat dokumen',
          'Buka Operasional > Bongkar Susun atau Sortir Reject, lalu buat dokumen baru.',
          path: 'Operasional > Bongkar Susun',
        ),
        ManualStep(
          'Scan label',
          'Scan atau ketik kode label sesuai petunjuk pada layar, lalu periksa daftar yang terkumpul.',
        ),
        ManualStep(
          'Simpan dan lihat detail',
          'Tekan Simpan, lalu buka detail dokumen untuk melihat hasil dan mencetaknya.',
        ),
      ],
      openRoute: '/shell/bongkar-susun',
      openLabel: 'Buka Bongkar Susun',
    ),
  ]),
  ManualArea('master', 'Master & Sistem', 'Data dasar dan hak akses yang dipakai seluruh modul.', [
    ManualSection(
      id: 'master-data',
      title: '1. Master Data',
      description: 'Kelola data barang, mesin, supplier, dan data dasar lainnya.',
      icon: Icons.inventory_2_outlined,
      steps: [
        ManualStep(
          'Pilih master',
          'Buka seksi Master pada sidebar, lalu pilih data yang akan dikelola, misalnya Master Barang.',
          path: 'Master > SDM & Produksi > Master Barang',
        ),
        ManualStep(
          'Cari dan ubah',
          'Gunakan pencarian untuk menemukan data, lalu tekan baris untuk melihat atau mengubahnya.',
        ),
        ManualStep(
          'Tambah data',
          'Tekan Tambah, isi field yang wajib, lalu simpan. Perubahan yang belum disimpan akan dibuang bila Anda keluar.',
        ),
      ],
      notes: [
        'Menu master hanya tampil bila Anda memiliki izin baca yang sesuai.',
      ],
      openRoute: '/master/barang',
      openLabel: 'Buka Master Barang',
    ),
    ManualSection(
      id: 'master-user',
      title: '2. User dan Role',
      description: 'Kelola akun pengguna dan hak aksesnya.',
      icon: Icons.admin_panel_settings_outlined,
      steps: [
        ManualStep(
          'Buka pengaturan',
          'Buka System > User untuk mengelola akun, atau System > Role untuk mengelola grup izin.',
          path: 'System > User',
        ),
        ManualStep(
          'Ubah pengguna',
          'Cari pengguna, lalu ubah data atau izinnya. Simpan perubahan agar berlaku pada login berikutnya.',
        ),
      ],
      notes: [
        'Menu ini terbatas untuk pengguna dengan izin pengelolaan user dan role.',
      ],
      openRoute: '/shell/user',
      openLabel: 'Buka User',
    ),
  ]),
];
