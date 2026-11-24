import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../production/shared/widgets/production_panel_decoration.dart';
import '../model/kpi.dart';
import '../repository/kpi_repository.dart';

/// Workspace & Analytics > KPI & Ratio: rendemen, waste, dan reject per
/// proses & mesin untuk bulan berjalan s.d. tanggal terpilih.
class KpiScreen extends StatefulWidget {
  final KpiRepository? repository;

  /// Tanggal awal (default hari ini); untuk test.
  final DateTime? initialDate;
  const KpiScreen({super.key, this.repository, this.initialDate});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

/// Catatan sumber/keterbatasan data per KPI, tampil di bawah tabel.
const Map<String, String> _kNotes = {
  'washing': 'Sumber: laporan Produktivitas Washing. Waste = bahan tenggelam.',
  'broker': 'Sumber: laporan Produktivitas Broker.',
  'mixer':
      'Sumber: Dashboard Produktifitas. Rendemen di atas 100% berarti output tercatat lebih besar dari input (mis. bahan tambahan yang tidak tercatat sebagai input).',
  'inject':
      'Berat label hasil inject tidak dicatat, jadi reject dihitung sebagai kg reject per 1.000 pcs hasil. Perbandingan antar mesin bersifat kasar karena berat produk tiap mesin berbeda.',
};

class _KpiScreenState extends State<KpiScreen> {
  late final KpiRepository _repo =
      widget.repository ?? KpiRepository(api: ApiClient());
  late DateTime _date = _dateOnly(widget.initialDate ?? DateTime.now());
  KpiResult? _result;
  String _error = '';
  bool _loading = false;
  int _request = 0;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await _repo.load(_ymd(_date));
      if (!mounted || request != _request) return;
      setState(() => _result = r);
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 3),
      lastDate: _dateOnly(now),
      helpText: 'KPI bulan berjalan s.d. tanggal',
    );
    if (picked == null || picked == _date) return;
    setState(() => _date = picked);
    await _load();
  }

  String _periodLabel() {
    final r = _result;
    if (r == null || r.from.isEmpty) return '';
    final f = DateTime.tryParse(r.from);
    final t = DateTime.tryParse(r.to);
    if (f == null || t == null) return '${r.from} – ${r.to}';
    final fmt = DateFormat('d MMM yyyy');
    return '${DateFormat('d').format(f)} – ${fmt.format(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _header(),
              const SizedBox(height: 16),
              if (r == null && _loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (r == null && _error.isNotEmpty)
                _Panel(
                  child: _Message(
                    icon: Icons.cloud_off_outlined,
                    title: 'KPI belum dapat dimuat',
                    body: _error,
                    action: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ),
                )
              else if (r != null && r.kpis.isEmpty)
                const _Panel(
                  child: _Message(
                    icon: Icons.lock_outline,
                    title: 'Belum ada KPI untuk Anda',
                    body:
                        'KPI tampil untuk proses produksi yang Anda punya aksesnya.',
                  ),
                )
              else if (r != null)
                Opacity(
                  opacity: _loading ? 0.5 : 1,
                  child: Column(
                    children: [
                      for (final k in r.kpis) ...[
                        _KpiCard(block: k, note: _kNotes[k.key]),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.speed_outlined, color: kProductionPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KPI & Ratio — bulan berjalan',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (_periodLabel().isNotEmpty)
                  Text(
                    _periodLabel(),
                    key: const ValueKey('kpi-period'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('kpi-date'),
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(DateFormat('d MMM yyyy').format(_date)),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

// ---------------- kartu per KPI ----------------

final _fmt = NumberFormat('#,##0.##', 'en_US');
String _n(num? v) => v == null ? '-' : _fmt.format(v);
String _withUnit(num? v, String unit) {
  if (v == null) return '-';
  return unit == '%' ? '${_n(v)}%' : '${_n(v)} $unit';
}

class _KpiCard extends StatelessWidget {
  final KpiBlock block;
  final String? note;
  const _KpiCard({required this.block, this.note});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        key: ValueKey('kpi-${block.key}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (block.error.isNotEmpty)
            Text(block.error, style: const TextStyle(color: Color(0xFFB91C1C)))
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final m in block.metrics) _MetricTile(metric: m),
                if (block.input != null)
                  _MetricTile(
                    metric: KpiMetric(
                      key: 'input',
                      label: 'Total input',
                      value: block.input,
                      unit: block.unit,
                      good: '',
                    ),
                  ),
                if (block.output != null && block.key != 'inject')
                  _MetricTile(
                    metric: KpiMetric(
                      key: 'output',
                      label: 'Total output',
                      value: block.output,
                      unit: block.unit,
                      good: '',
                    ),
                  ),
              ],
            ),
            if (block.rows.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MesinTable(block: block),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Belum ada produksi pada periode ini.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
          ],
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(
              note!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final KpiMetric metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final primary = metric.unit == '%' || metric.key == 'reject_per_1000';
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            _withUnit(metric.value, metric.unit),
            style: TextStyle(
              fontSize: primary ? 22 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MesinTable extends StatelessWidget {
  final KpiBlock block;
  const _MesinTable({required this.block});

  @override
  Widget build(BuildContext context) {
    final (cols, cells) = switch (block.key) {
      'inject' => (
        ['Mesin', 'Hasil (pcs)', 'Reject (kg)', 'Reject / 1.000 pcs (kg)', 'Dokumen'],
        (KpiRow r) => [
          r.mesin,
          _n(r.pcs),
          _n(r.reject),
          _n(r.rejectPer1000),
          _n(r.dokumen),
        ],
      ),
      'mixer' => (
        ['Mesin', 'Output (kg)'],
        (KpiRow r) => [r.mesin, _n(r.output)],
      ),
      _ => (
        ['Mesin', 'Input (kg)', 'Output (kg)', 'Rendemen', 'Waste', 'Dokumen'],
        (KpiRow r) => [
          r.mesin,
          _n(r.input),
          _n(r.output),
          _withUnit(r.rendemen, '%'),
          _withUnit(r.waste, '%'),
          _n(r.dokumen),
        ],
      ),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 38,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 40,
        headingTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
        columns: [
          for (var i = 0; i < cols.length; i++)
            DataColumn(label: Text(cols[i]), numeric: i > 0),
        ],
        rows: [
          for (final r in block.rows)
            DataRow(
              cells: [
                for (final c in cells(r))
                  DataCell(Text(c, style: const TextStyle(fontSize: 12.5))),
              ],
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: productionPanelDecoration(),
    child: child,
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Widget? action;
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ],
    ),
  );
}
