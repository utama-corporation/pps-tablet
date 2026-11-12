// lib/features/report/model/report_item.dart
import 'package:flutter/material.dart';

enum ReportKind { pdf, table, link }

/// Definisi field filter satu laporan.
///
/// [type]: 'date' | 'number' | 'select' | 'select-warehouse'.
/// [defaultValue] (untuk date): keyword 'today' | 'month-start' | 'month-end'.
/// [options] untuk select statis (select-warehouse memuat opsi dari API).
class ReportFieldDef {
  const ReportFieldDef(
    this.key,
    this.label,
    this.type, [
    this.defaultValue = '',
    this.options = const [],
  ]);

  final String key;
  final String label;
  final String type;
  final String defaultValue;
  final List<String> options;
}

class ReportItem {
  const ReportItem({
    required this.title,
    required this.icon,
    required this.kind,
    this.path,
    this.route,
    this.fields = const [],
    this.comingSoon = false,
  });

  final String title;
  final IconData icon;
  final ReportKind kind;

  /// Endpoint PDF (`kind == pdf`) atau JSON tabel (`kind == table`).
  final String? path;

  /// Route in-app untuk `kind == link` (mis. '/shell/penerimaan-bahan-baku').
  final String? route;

  final List<ReportFieldDef> fields;

  /// true → tampil dengan badge "Segera", tap tidak melakukan apa-apa.
  final bool comingSoon;

  bool get isWarehouseReport =>
      fields.any((f) => f.type == 'select-warehouse');
}

class ReportKategori {
  const ReportKategori({
    required this.nama,
    required this.slug,
    required this.icon,
    required this.items,
  });

  final String nama;
  final String slug;
  final IconData icon;
  final List<ReportItem> items;
}

// ── Field presets ───────────────────────────────────────────────────────────

const _tglAkhir = ReportFieldDef('tglAkhir', 'Tanggal', 'date', 'today');
const _tglAwal = ReportFieldDef('tglAwal', 'Tanggal Mulai', 'date', 'month-start');
const _tglAkhirRange =
    ReportFieldDef('tglAkhir', 'Tanggal Akhir', 'date', 'today');
const _warehouse = ReportFieldDef(
  'warehouse',
  'Warehouse',
  'select-warehouse',
  'ALL',
);
const _rangeDates = [_tglAwal, _tglAkhirRange];
const _umur = [
  ReportFieldDef('umur1', 'Umur 1 (hari)', 'number', '30'),
  ReportFieldDef('umur2', 'Umur 2 (hari)', 'number', '60'),
  ReportFieldDef('umur3', 'Umur 3 (hari)', 'number', '90'),
  ReportFieldDef('umur4', 'Umur 4 (hari)', 'number', '120'),
  ReportFieldDef('umur5', 'Umur 5 (hari)', 'number', '150'),
];
const _rekapHarianJenis = ReportFieldDef(
  'jenis',
  'Jenis Rekap',
  'select',
  'inject-bj',
  [
    'washing',
    'broker',
    'crusher',
    'gilingan',
    'mixer',
    'inject-bj',
    'inject-fwip',
    'packing',
    'hot-stamping',
    'pasang-kunci',
    'spanner',
  ],
);

// ── Katalog (sama persis dengan /laporan web) ───────────────────────────────

const reportKategoriCatalog = <ReportKategori>[
  ReportKategori(
    nama: 'Bahan Baku',
    slug: 'bahan-baku',
    icon: Icons.warehouse_outlined,
    items: [
      ReportItem(
        title: 'Stok Bahan Baku',
        icon: Icons.warehouse_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/bahan-baku/stok/pdf',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Bahan Baku',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/bahan-baku/mutasi',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Penerimaan Bahan Baku',
        icon: Icons.inventory_outlined,
        kind: ReportKind.link,
        route: '/shell/penerimaan-bahan-baku',
      ),
      ReportItem(
        title: 'Kartu Stok Bahan Baku',
        icon: Icons.credit_card_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/bahan-baku/kartu-stok',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname Bahan Baku',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Bahan Baku',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/bahan-baku/umur',
        fields: _umur,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Washing',
    slug: 'washing',
    icon: Icons.local_laundry_service_outlined,
    items: [
      ReportItem(
        title: 'Stok Washing',
        icon: Icons.local_laundry_service_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/stok/washing/pdf',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Washing',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/washing',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produksi Washing',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produksi/washing',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname Washing',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Washing',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/umur/washing',
        fields: _umur,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Broker',
    slug: 'broker',
    icon: Icons.storefront_outlined,
    items: [
      ReportItem(
        title: 'Stok Broker',
        icon: Icons.storefront_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/stok/broker/pdf',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Broker',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/broker',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produksi Broker',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produksi/broker',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname Broker',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Broker',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/umur/broker',
        fields: _umur,
      ),
      ReportItem(
        title: 'Stok Broker QC',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/broker/stok-qc/pdf',
        fields: [_tglAkhir],
      ),
    ],
  ),
  ReportKategori(
    nama: 'Bonggolan',
    slug: 'bonggolan',
    icon: Icons.recycling_outlined,
    items: [
      ReportItem(
        title: 'Stok Bonggolan',
        icon: Icons.recycling_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/stok/bonggolan',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Stock Opname Bonggolan',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Bonggolan',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/umur/bonggolan',
        fields: _umur,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Crusher',
    slug: 'crusher',
    icon: Icons.hardware_outlined,
    items: [
      ReportItem(
        title: 'Stok Crusher',
        icon: Icons.hardware_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/stok/crusher',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Crusher',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/crusher',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produksi Crusher',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produksi/crusher',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname Crusher',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Crusher',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/umur/crusher',
        fields: _umur,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Gilingan',
    slug: 'gilingan',
    icon: Icons.grass_outlined,
    items: [
      ReportItem(
        title: 'Stok Gilingan',
        icon: Icons.grass_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/stok/gilingan',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Gilingan',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/gilingan',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produksi Gilingan',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produksi/gilingan',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname Gilingan',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Gilingan',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/umur/gilingan',
        fields: _umur,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Mixer',
    slug: 'mixer',
    icon: Icons.blender_outlined,
    items: [
      ReportItem(
        title: 'Stok Mixer (Per Jenis)',
        icon: Icons.blender_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/stok/mixer',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Mixer',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/mixer',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produksi Mixer',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produksi/mixer',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname Mixer',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
      ReportItem(
        title: 'Umur Mixer',
        icon: Icons.hourglass_bottom_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/umur/mixer',
        fields: _umur,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Reject',
    slug: 'reject',
    icon: Icons.remove_circle_outline_rounded,
    items: [
      ReportItem(
        title: 'Stok Reject',
        icon: Icons.remove_circle_outline_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/reject/stok',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Reject',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/reject',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Opname',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.table,
        comingSoon: true,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Furniture WIP',
    slug: 'furniture-wip',
    icon: Icons.chair_outlined,
    items: [
      ReportItem(
        title: 'Stok Furniture WIP',
        icon: Icons.chair_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/stok/furniture-wip',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Furniture WIP',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/furniture-wip',
        fields: _rangeDates,
      ),
    ],
  ),
  ReportKategori(
    nama: 'Barang Jadi',
    slug: 'barang-jadi',
    icon: Icons.inventory_2_outlined,
    items: [
      ReportItem(
        title: 'Stok Barang Jadi',
        icon: Icons.inventory_2_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/stok/barang-jadi',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Mutasi Barang Jadi',
        icon: Icons.swap_vert_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/mutasi/barang-jadi',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Stock Barang Jadi V2',
        icon: Icons.inventory_2_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/barang-jadi/stok-v2/pdf',
        fields: [_tglAkhir],
      ),
    ],
  ),
  ReportKategori(
    nama: 'Barang Dagang',
    slug: 'barang-dagang',
    icon: Icons.local_shipping_outlined,
    items: [
      ReportItem(
        title: 'Laporan Stok Barang Dagang',
        icon: Icons.local_shipping_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/barang-dagang/stok/pdf',
        fields: [_tglAkhir, _warehouse],
      ),
      ReportItem(
        title: 'Stock Barang Dagang V2',
        icon: Icons.local_shipping_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/barang-dagang/stok-v2/pdf',
        fields: [_tglAkhir, _warehouse],
      ),
    ],
  ),
  ReportKategori(
    nama: 'Rekap Produksi',
    slug: 'rekap-produksi',
    icon: Icons.summarize_outlined,
    items: [
      ReportItem(
        title: 'Rekap Washing',
        icon: Icons.local_laundry_service_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/washing',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Broker',
        icon: Icons.storefront_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/broker',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Crusher',
        icon: Icons.hardware_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/crusher',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Gilingan',
        icon: Icons.grass_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/gilingan',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Mixer',
        icon: Icons.blender_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/mixer',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Inject Barang Jadi',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/inject-bj',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Inject FWIP',
        icon: Icons.precision_manufacturing_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/inject-fwip',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Packing',
        icon: Icons.inventory_2_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/packing',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Hot Stamping',
        icon: Icons.local_fire_department_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/hot-stamping',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Pasang Kunci',
        icon: Icons.key_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/pasang-kunci',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Rekap Spanner',
        icon: Icons.build_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap/spanner',
        fields: [_tglAkhir],
      ),
    ],
  ),
  ReportKategori(
    nama: 'Semua Laporan',
    slug: 'semua',
    icon: Icons.all_inclusive_rounded,
    items: [
      ReportItem(
        title: 'Semua Label',
        icon: Icons.label_outline_rounded,
        kind: ReportKind.table,
        path: '/api/laporan/semua-label',
      ),
      ReportItem(
        title: 'Rekap Produksi Harian',
        icon: Icons.calendar_month_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/rekap-harian',
        fields: [_rekapHarianJenis, _tglAkhir],
      ),
      ReportItem(
        title: 'Dashboard Produktifitas',
        icon: Icons.dashboard_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/dashboard-produktifitas',
        fields: [_tglAkhir],
      ),
      ReportItem(
        title: 'Hasil Produksi Barang Jadi',
        icon: Icons.fact_check_outlined,
        kind: ReportKind.pdf,
        path: '/api/laporan/barang-jadi/hasil-produksi/pdf',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produktivitas Washing',
        icon: Icons.speed_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produktivitas/washing',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Produktivitas Broker',
        icon: Icons.speed_outlined,
        kind: ReportKind.table,
        path: '/api/laporan/produktivitas/broker',
        fields: _rangeDates,
      ),
      ReportItem(
        title: 'Laporan Bongkar Susun',
        icon: Icons.swap_horiz_rounded,
        kind: ReportKind.pdf,
        path: '/api/bongkar-susun-v2/laporan/pdf',
        fields: <ReportFieldDef>[
          ReportFieldDef('startDate', 'Tanggal Mulai', 'date', 'month-start'),
          ReportFieldDef('endDate', 'Tanggal Akhir', 'date', 'today'),
        ],
      ),
      ReportItem(
        title: 'Laporan Sortir Reject',
        icon: Icons.remove_circle_outline_rounded,
        kind: ReportKind.pdf,
        path: '/api/sortir-reject-v2/laporan/pdf',
        fields: <ReportFieldDef>[
          ReportFieldDef('startDate', 'Tanggal Mulai', 'date', 'month-start'),
          ReportFieldDef('endDate', 'Tanggal Akhir', 'date', 'today'),
        ],
      ),
    ],
  ),
];

/// Semua laporan (semua grup, termasuk "Semua Laporan" sebagai satu grup).
final reportCatalogFlat = [
  for (final k in reportKategoriCatalog) ...k.items,
];

/// Total laporan di katalog (termasuk "Segera").
int get reportCatalogCount => reportCatalogFlat.length;

/// Section yang tampil untuk [slug]; null/`semua` → semua kategori.
List<ReportKategori> reportSectionsFor(String? slug) {
  if (slug == null) return reportKategoriCatalog;
  return [
    for (final k in reportKategoriCatalog)
      if (k.slug == slug) k,
  ];
}
