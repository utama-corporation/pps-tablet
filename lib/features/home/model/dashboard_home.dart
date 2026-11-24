num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');
String _str(dynamic v) => v == null ? '' : '$v'.trim();

/// Perubahan terhadap periode pembanding.
class DashDelta {
  final num value;
  final String unit, direction;
  DashDelta(Map<String, dynamic> raw)
    : value = _num(raw['value']) ?? 0,
      unit = _str(raw['unit']),
      direction = _str(raw['direction']);
}

class DashMetric {
  final String label, unit;
  final dynamic value;
  const DashMetric(this.label, this.value, this.unit);
  DashMetric.fromJson(Map<String, dynamic> raw)
    : label = _str(raw['label']),
      value = raw['value'],
      unit = _str(raw['unit']);
}

/// Satu kartu domain (Produksi, Penjualan, Status Mesin).
class DashDomain {
  final String key, label, detail, error;
  final DashMetric? primary;
  final DashDelta? delta;
  final List<DashMetric> secondary;
  final List<(String, String, int, int)> depts;
  const DashDomain({
    required this.key,
    required this.label,
    required this.detail,
    this.primary,
    this.delta,
    this.secondary = const [],
    this.depts = const [],
    this.error = '',
  });
  DashDomain.fromJson(Map<String, dynamic> raw)
    : key = _str(raw['key']),
      label = _str(raw['label']),
      detail = _str(raw['detail']),
      error = _str(raw['error']),
      primary = raw['primary'] is Map<String, dynamic>
          ? DashMetric.fromJson(raw['primary'] as Map<String, dynamic>)
          : null,
      delta = raw['delta'] is Map<String, dynamic>
          ? DashDelta(raw['delta'] as Map<String, dynamic>)
          : null,
      secondary = [
        for (final row
            in (raw['secondary'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          DashMetric.fromJson(row),
      ],
      depts = [
        for (final row
            in (raw['depts'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          (
            _str(row['key']),
            _str(row['label']),
            (_num(row['value']) ?? 0).toInt(),
            (_num(row['today']) ?? 0).toInt(),
          ),
      ];

  bool get failed => error.isNotEmpty;
}

class DashTrendDay {
  final DateTime date;
  final double produksi, penjualan;
  const DashTrendDay(this.date, this.produksi, this.penjualan);
}

class DashActivityItem {
  final String key, label;
  final int? value;
  final String error;
  DashActivityItem(Map<String, dynamic> raw)
    : key = _str(raw['key']),
      label = _str(raw['label']),
      // Null = server tidak mengirim angka; jangan disamakan dengan 0.
      value = _num(raw['value'])?.toInt(),
      error = _str(raw['error']);
}

class DashHome {
  final int rangeDays;
  final DateTime? from, to, generatedAt;
  final List<DashDomain> domains;

  /// Null bila pengguna tidak berhak melihat tren (bukan berarti kosong).
  final List<DashTrendDay>? trend;
  final String trendError;
  final List<DashActivityItem> activity;
  DashHome(Map<String, dynamic> raw)
    : rangeDays = (_num(raw['range_days']) ?? 7).toInt(),
      from = DateTime.tryParse(_str(raw['from'])),
      to = DateTime.tryParse(_str(raw['to'])),
      generatedAt = DateTime.tryParse(_str(raw['generated_at']))?.toLocal(),
      domains = [
        for (final row
            in (raw['domains'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          DashDomain.fromJson(row),
      ],
      trend = raw['trend'] is List
          ? [
              for (final row
                  in (raw['trend'] as List).whereType<Map<String, dynamic>>())
                if (DateTime.tryParse(_str(row['date'])) case final d?)
                  DashTrendDay(
                    d,
                    (_num(row['produksi']) ?? 0).toDouble(),
                    (_num(row['penjualan']) ?? 0).toDouble(),
                  ),
            ]
          : null,
      trendError = _str(raw['trend_error']),
      activity = [
        for (final row
            in (raw['activity'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          DashActivityItem(row),
      ];
}
