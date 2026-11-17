/// Bagian/proses produksi untuk Master Mesin Produksi.
///
/// Id ini dipakai path param `GET /api/mst-mesin/{idBagianMesin}`.
/// Mapping dikonfirmasi pemilik aplikasi (2026-11-10).
class BagianMesin {
  const BagianMesin(this.id, this.label);

  final int id;
  final String label;
}

const masterBagianMesin = <BagianMesin>[
  BagianMesin(2, 'Broker'),
  BagianMesin(3, 'Crusher'),
  BagianMesin(4, 'Inject'),
  BagianMesin(5, 'Mixer'),
  BagianMesin(6, 'Packing'),
  BagianMesin(7, 'Washing'),
  BagianMesin(8, 'Stamping'),
  BagianMesin(9, 'Spanner'),
  BagianMesin(10, 'Pasang Kunci'),
  BagianMesin(11, 'Gilingan'),
];

/// Slug `:type` untuk API `/api/mst-mesin-produksi/{type}` per bagian.
const masterBagianMesinSlug = <int, String>{
  2: 'broker',
  3: 'crusher',
  4: 'inject',
  5: 'mixer',
  6: 'packing',
  7: 'washing',
  8: 'hot-stamping',
  9: 'spanner',
  10: 'pasang-kunci',
  11: 'gilingan',
};

String? bagianMesinSlug(int? id) {
  if (id == null) return null;
  return masterBagianMesinSlug[id];
}

String bagianMesinLabel(int? id) {
  if (id == null) return '—';
  for (final b in masterBagianMesin) {
    if (b.id == id) return b.label;
  }
  return 'Lainnya ($id)';
}
