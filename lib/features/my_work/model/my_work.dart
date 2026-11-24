/// Model My Work (`/api/my-work`): antrian pekerjaan tertunda milik user.
library;

String _str(dynamic v) => v == null ? '' : '$v'.trim();
int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// Satu antrian (kotak) beserta jumlahnya. [count] null bila gagal dimuat.
class MyWorkQueue {
  final String key, label, error;
  final int? count;
  const MyWorkQueue({
    required this.key,
    required this.label,
    this.count,
    this.error = '',
  });
  MyWorkQueue.fromJson(Map<String, dynamic> raw)
    : key = _str(raw['key']),
      label = _str(raw['label']),
      count = _int(raw['count']),
      error = _str(raw['error']);
}

class MyWorkSummary {
  final int total;
  final List<MyWorkQueue> queues;
  const MyWorkSummary({required this.total, required this.queues});
  MyWorkSummary.fromJson(Map<String, dynamic> raw)
    : total = _int(raw['total']) ?? 0,
      queues = [
        for (final q
            in (raw['queues'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          MyWorkQueue.fromJson(q),
      ];
}

/// Satu pekerjaan di daftar. [module] = kunci layar tujuan (lihat
/// `myWorkRouteFor`).
class MyWorkItem {
  final String id, no, title, subtitle, date, module;
  final List<(String, String)> meta;
  const MyWorkItem({
    required this.id,
    required this.no,
    required this.title,
    this.subtitle = '',
    this.date = '',
    this.module = '',
    this.meta = const [],
  });
  MyWorkItem.fromJson(Map<String, dynamic> raw)
    : id = _str(raw['id']),
      no = _str(raw['no']),
      title = _str(raw['title']),
      subtitle = _str(raw['subtitle']),
      date = _str(raw['date']),
      module = _str(raw['module']),
      meta = [
        for (final m
            in (raw['meta'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          (_str(m['label']), _str(m['value'])),
      ];
}

class MyWorkItems {
  final String key;
  final int total;
  final List<MyWorkItem> items;
  const MyWorkItems({required this.key, required this.total, required this.items});
  MyWorkItems.fromJson(Map<String, dynamic> raw)
    : key = _str(raw['key']),
      total = _int(raw['total']) ?? 0,
      items = [
        for (final i
            in (raw['items'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          MyWorkItem.fromJson(i),
      ];
}

/// Route tablet untuk tiap `module` dari backend. Layar tujuan adalah daftar
/// modulnya (belum deep-link ke dokumen tertentu).
const Map<String, String> kMyWorkRoutes = {
  'washing': '/production/washing',
  'broker': '/production/broker',
  'crusher': '/production/crusher',
  'mixer': '/production/mixer',
  'inject': '/shell/inject',
  'gilingan': '/production/gilingan',
  'hot-stamp': '/shell/hot-stamp',
  'key-fitting': '/shell/key-fitting',
  'spanner': '/shell/spanner',
  'packing': '/shell/packing',
  'label-washing': '/label/washing',
  'label-broker': '/label/broker',
  'label-mixer': '/label/mixer',
  'label-crusher': '/label/crusher',
  'label-gilingan': '/label/gilingan',
  'label-bonggolan': '/label/bonggolan',
  'label-furniture-wip': '/label/furniture_wip',
  'label-packing': '/label/packing',
  'label-reject': '/label/reject',
  'label-barang-dagang': '/label/barang-dagang',
  'label-bahan-pendukung': '/label/bahan-pendukung',
  'stock-opname': '/shell/stock-opname-v2',
  'spk': '/production/spk-barang-jadi',
};

String? myWorkRouteFor(String module) => kMyWorkRoutes[module];
