/// Model KPI & Ratio (`/api/kpi`): KPI bulan berjalan s.d. tanggal terpilih.
library;

String _str(dynamic v) => v == null ? '' : '$v'.trim();
num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

class KpiMetric {
  final String key, label, unit;
  final num? value;

  /// 'high' = makin tinggi makin baik, 'low' = makin rendah makin baik.
  final String good;
  const KpiMetric({
    required this.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.good = 'high',
  });
  KpiMetric.fromJson(Map<String, dynamic> raw)
    : key = _str(raw['key']),
      label = _str(raw['label']),
      value = _num(raw['value']),
      unit = _str(raw['unit']),
      good = _str(raw['good']).isEmpty ? 'high' : _str(raw['good']);
}

/// Satu baris per mesin. Kolom yang terisi tergantung KPI-nya.
class KpiRow {
  final String mesin;
  final num? input, output, rendemen, waste, pcs, reject, rejectPer1000, dokumen;
  const KpiRow({
    required this.mesin,
    this.input,
    this.output,
    this.rendemen,
    this.waste,
    this.pcs,
    this.reject,
    this.rejectPer1000,
    this.dokumen,
  });
  KpiRow.fromJson(Map<String, dynamic> raw)
    : mesin = _str(raw['mesin']),
      input = _num(raw['input']),
      output = _num(raw['output']),
      rendemen = _num(raw['rendemen']),
      waste = _num(raw['waste']),
      pcs = _num(raw['pcs']),
      reject = _num(raw['reject']),
      rejectPer1000 = _num(raw['rejectPer1000']),
      dokumen = _num(raw['dokumen']);
}

class KpiBlock {
  final String key, label, unit, error;
  final num? input, output;
  final List<KpiMetric> metrics;
  final List<KpiRow> rows;
  const KpiBlock({
    required this.key,
    required this.label,
    this.unit = '',
    this.error = '',
    this.input,
    this.output,
    this.metrics = const [],
    this.rows = const [],
  });
  KpiBlock.fromJson(Map<String, dynamic> raw)
    : key = _str(raw['key']),
      label = _str(raw['label']),
      unit = _str(raw['unit']),
      error = _str(raw['error']),
      input = _num(raw['input']),
      output = _num(raw['output']),
      metrics = [
        for (final m
            in (raw['metrics'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          KpiMetric.fromJson(m),
      ],
      rows = [
        for (final r
            in (raw['rows'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          KpiRow.fromJson(r),
      ];
}

class KpiResult {
  final String from, to;
  final List<KpiBlock> kpis;
  const KpiResult({required this.from, required this.to, required this.kpis});
  KpiResult.fromJson(Map<String, dynamic> raw)
    : from = _str(raw['from']),
      to = _str(raw['to']),
      kpis = [
        for (final k
            in (raw['kpis'] as List? ?? const [])
                .whereType<Map<String, dynamic>>())
          KpiBlock.fromJson(k),
      ];
}
