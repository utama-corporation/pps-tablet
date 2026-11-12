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

String bagianMesinLabel(int? id) {
  if (id == null) return '—';
  for (final b in masterBagianMesin) {
    if (b.id == id) return b.label;
  }
  return 'Lainnya ($id)';
}
