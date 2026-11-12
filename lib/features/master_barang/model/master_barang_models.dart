/// Meta-driven models untuk Master Barang — dibangun dari response
/// `GET /api/mst-barang/meta` (11 jenis master, satu konfigurasi per jenis).
///
/// Backend whitelist tabel & kolom — app hanya mengirim field sesuai meta.
class MasterBarangFieldMeta {
  const MasterBarangFieldMeta({
    required this.key,
    required this.label,
    required this.kind,
    this.source,
    this.dependsOn,
    this.required = false,
    this.maxLength,
    this.list = false,
    this.defaultValue,
  });

  final String key;
  final String label;

  /// `text` | `int` | `decimal` | `bool` | `select`
  final String kind;
  final String? source;
  final String? dependsOn;
  final bool required;
  final int? maxLength;
  final bool list;
  final Object? defaultValue;

  factory MasterBarangFieldMeta.fromJson(Map<String, dynamic> j) =>
      MasterBarangFieldMeta(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        kind: (j['kind'] ?? 'text').toString(),
        source: j['source']?.toString(),
        dependsOn: j['dependsOn']?.toString(),
        required: j['required'] == true,
        maxLength: j['maxLength'] is num ? (j['maxLength'] as num).toInt() : null,
        list: j['list'] == true,
        defaultValue: j['default'],
      );
}

class MasterBarangTypeMeta {
  const MasterBarangTypeMeta({
    required this.key,
    required this.label,
    required this.nameLabel,
    required this.fields,
  });

  final String key;
  final String label;
  final String nameLabel;
  final List<MasterBarangFieldMeta> fields;

  bool get hasItemCode => fields.any((f) => f.key == 'itemCode');

  factory MasterBarangTypeMeta.fromJson(Map<String, dynamic> j) =>
      MasterBarangTypeMeta(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        nameLabel: (j['nameLabel'] ?? 'Nama').toString(),
        fields: [
          for (final f in (j['fields'] as List? ?? const []))
            if (f is Map)
              MasterBarangFieldMeta.fromJson(Map<String, dynamic>.from(f)),
        ],
      );
}

class MasterBarangOption {
  const MasterBarangOption({required this.id, required this.label, this.parentId});

  final int id;
  final String label;

  /// `SubTipe` only — idBJType yang menaunginya.
  final int? parentId;

  factory MasterBarangOption.fromJson(Map<String, dynamic> j) =>
      MasterBarangOption(
        id: (j['id'] as num?)?.toInt() ??
            int.tryParse(j['id']?.toString() ?? '') ??
            0,
        label: (j['label'] ?? j['nama'] ?? '').toString(),
        parentId: (j['parentId'] as num?)?.toInt() ??
            int.tryParse(j['parentId']?.toString() ?? ''),
      );
}

class MasterBarangSummary {
  const MasterBarangSummary({required this.total, required this.aktif});

  final int total;
  final int aktif;

  factory MasterBarangSummary.fromJson(Map<String, dynamic> j) =>
      MasterBarangSummary(
        total: (j['total'] as num?)?.toInt() ??
            int.tryParse(j['total']?.toString() ?? '') ??
            0,
        aktif: (j['aktif'] as num?)?.toInt() ??
            int.tryParse(j['aktif']?.toString() ?? '') ??
            0,
      );
}

class MasterBarangMeta {
  const MasterBarangMeta({
    required this.types,
    required this.summary,
    required this.options,
  });

  final List<MasterBarangTypeMeta> types;
  final Map<String, MasterBarangSummary> summary;
  final Map<String, List<MasterBarangOption>> options;

  MasterBarangTypeMeta? typeFor(String key) {
    for (final t in types) {
      if (t.key == key) return t;
    }
    return null;
  }

  List<MasterBarangOption> optionsFor(String source, {int? parentId}) {
    final all = options[source] ?? const <MasterBarangOption>[];
    if (parentId == null) return all;
    return [
      for (final o in all)
        if (o.parentId == null || o.parentId == parentId) o,
    ];
  }

  factory MasterBarangMeta.fromJson(Map<String, dynamic> j) {
    final data = (j['data'] is Map)
        ? Map<String, dynamic>.from(j['data'] as Map)
        : j;
    final types = <MasterBarangTypeMeta>[
      for (final t in (data['types'] as List? ?? const []))
        if (t is Map) MasterBarangTypeMeta.fromJson(Map<String, dynamic>.from(t)),
    ];
    final summary = <String, MasterBarangSummary>{};
    for (final s in (data['summary'] as List? ?? const [])) {
      if (s is Map) {
        final map = Map<String, dynamic>.from(s);
        final key = (map['key'] ?? map['tipe'] ?? '').toString();
        if (key.isNotEmpty) summary[key] = MasterBarangSummary.fromJson(map);
      }
    }
    final options = <String, List<MasterBarangOption>>{};
    final rawOptions = data['options'];
    if (rawOptions is Map) {
      rawOptions.forEach((name, list) {
        options[name.toString()] = [
          for (final o in (list as List? ?? const []))
            if (o is Map) MasterBarangOption.fromJson(Map<String, dynamic>.from(o)),
        ];
      });
    }
    return MasterBarangMeta(types: types, summary: summary, options: options);
  }
}

/// Satu baris pada list — kolom dinamis sesuai meta jenis.
class MasterBarangItem {
  const MasterBarangItem(this.raw);

  final Map<String, dynamic> raw;

  int get id => (raw['id'] as num?)?.toInt() ??
      int.tryParse(raw['id']?.toString() ?? '') ??
      0;

  String get nama => (raw['nama'] ?? '').toString();

  bool get enable => _toBool(raw['enable'], fallback: true);

  static bool _toBool(dynamic v, {bool fallback = false}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'y';
  }

  dynamic field(String key) => raw[key];

  /// Nilai tampil untuk kind select: `${key}Label` dari join backend.
  String fieldLabel(String key) {
    final label = raw['${key}Label'];
    if (label != null && label.toString().trim().isNotEmpty) {
      return label.toString();
    }
    final v = raw[key];
    return v == null ? '—' : v.toString();
  }

  bool fieldBool(String key) => _toBool(raw[key]);

  num fieldNum(String key) {
    final v = raw[key];
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String fmtNum(num? v) {
    if (v == null) return '—';
    return v % 1 == 0 ? '${v.toInt()}' : v.toString();
  }
}
