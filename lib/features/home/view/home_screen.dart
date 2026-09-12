import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pps_tablet/features/home/model/dashboard_summary.dart';
import 'package:pps_tablet/features/home/repository/dashboard_summary_repository.dart';
import 'package:pps_tablet/features/production/shared/widgets/production_panel_decoration.dart';

/// Lebar minimum absolut sebagai jaring pengaman supaya layout dua panel
/// tidak dipaksakan di layar yang sangat sempit (mis. landscape di HP kecil).
const _kMinWidthForTwoPanel = 640.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<DashboardSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = DashboardSummaryRepository().fetchSummary();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<DashboardSummary>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            final summary = snapshot.data;
            final loading = snapshot.connectionState != ConnectionState.done;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxWidth >= _kMinWidthForTwoPanel;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        today,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: isLandscape
                            ? _LandscapeDashboard(
                                summary: summary,
                                loading: loading,
                              )
                            : _StackedDashboard(
                                summary: summary,
                                loading: loading,
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Layout landscape (dua panel, muat satu layar tanpa scroll) ──────────────

class _LandscapeDashboard extends StatelessWidget {
  final DashboardSummary? summary;
  final bool loading;

  const _LandscapeDashboard({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Panel kiri: chart penjualan + status mesin ───────────────────
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: _SalesChartCard(
                  points: summary?.salesCompleteLast7Days,
                  loading: loading,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                flex: 2,
                child: _MesinStatusCard(
                  active: summary?.activeMachines,
                  pending: summary?.pendingMachines,
                  loading: loading,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // ── Panel kanan: master data (list) + aktivitas hari ini ─────────
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Master Data Aktif'),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _StatRow(
                        icon: Icons.people_alt_outlined,
                        label: 'User Aktif',
                        value: summary?.activeUsers,
                        hasError: !loading && summary?.activeUsers == null,
                        color: kProductionPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _StatRow(
                        icon: Icons.place_outlined,
                        label: 'Lokasi Aktif',
                        value: summary?.activeLocations,
                        hasError:
                            !loading && summary?.activeLocations == null,
                        color: const Color(0xFF6D28D9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _StatRow(
                        icon: Icons.warehouse_outlined,
                        label: 'Warehouse Aktif',
                        value: summary?.activeWarehouses,
                        hasError:
                            !loading && summary?.activeWarehouses == null,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Aktivitas Hari Ini'),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Bongkar Susun',
                        value: summary?.bongkarSusunToday,
                        hasError:
                            !loading && summary?.bongkarSusunToday == null,
                        color: kProductionPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.filter_alt_outlined,
                        label: 'Sortir Reject',
                        value: summary?.sortirRejectToday,
                        hasError:
                            !loading && summary?.sortirRejectToday == null,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Layout fallback (portrait / layar sempit) — vertikal & bisa di-scroll ───

class _StackedDashboard extends StatelessWidget {
  final DashboardSummary? summary;
  final bool loading;

  const _StackedDashboard({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MesinStatusCard(
            active: summary?.activeMachines,
            pending: summary?.pendingMachines,
            loading: loading,
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Master Data Aktif'),
          const SizedBox(height: 10),
          _ResponsiveGrid(
            minItemWidth: 190,
            children: [
              _SummaryCard(
                icon: Icons.people_alt_outlined,
                label: 'User Aktif',
                value: summary?.activeUsers,
                hasError: !loading && summary?.activeUsers == null,
                color: kProductionPrimary,
              ),
              _SummaryCard(
                icon: Icons.place_outlined,
                label: 'Lokasi Aktif',
                value: summary?.activeLocations,
                hasError: !loading && summary?.activeLocations == null,
                color: const Color(0xFF6D28D9),
              ),
              _SummaryCard(
                icon: Icons.warehouse_outlined,
                label: 'Warehouse Aktif',
                value: summary?.activeWarehouses,
                hasError: !loading && summary?.activeWarehouses == null,
                color: const Color(0xFF0F766E),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Aktivitas Hari Ini'),
          const SizedBox(height: 10),
          _ResponsiveGrid(
            minItemWidth: 190,
            children: [
              _SummaryCard(
                icon: Icons.inventory_2_outlined,
                label: 'Bongkar Susun',
                value: summary?.bongkarSusunToday,
                hasError: !loading && summary?.bongkarSusunToday == null,
                color: kProductionPrimary,
              ),
              _SummaryCard(
                icon: Icons.filter_alt_outlined,
                label: 'Sortir Reject',
                value: summary?.sortirRejectToday,
                hasError: !loading && summary?.sortirRejectToday == null,
                color: const Color(0xFFB91C1C),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Penjualan Selesai — 7 Hari Terakhir'),
          const SizedBox(height: 10),
          _SalesChartCard(
            points: summary?.salesCompleteLast7Days,
            loading: loading,
            chartHeight: 160,
          ),
        ],
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.6,
      ),
    );
  }
}

// ── Responsive grid (bungkus GridView agar tinggi mengikuti konten) ─────────

class _ResponsiveGrid extends StatelessWidget {
  final double minItemWidth;
  final List<Widget> children;

  const _ResponsiveGrid({required this.minItemWidth, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / minItemWidth).floor().clamp(
          1,
          children.length,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 96,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

// ── Kartu status mesin (aktif vs pending) ────────────────────────────────────

class _MesinStatusCard extends StatelessWidget {
  final int? active;
  final int? pending;
  final bool loading;

  const _MesinStatusCard({
    required this.active,
    required this.pending,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = kProductionOutput;
    const pendingColor = Color(0xFFB45309);

    final hasError = !loading && active == null && pending == null;
    final a = active ?? 0;
    final p = pending ?? 0;
    final total = a + p;
    final activeRatio = total > 0 ? a / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: productionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: kProductionPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 17,
                  color: kProductionPrimary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Status Mesin Hari Ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D23),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _MesinStatBlock(
                  label: 'Aktif',
                  value: active,
                  color: activeColor,
                  hasError: hasError,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: const Color(0xFFE2E6EA),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _MesinStatBlock(
                  label: 'Pending',
                  value: pending,
                  color: pendingColor,
                  hasError: hasError,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: total > 0
                  ? Row(
                      children: [
                        Expanded(
                          flex: (activeRatio * 1000).round().clamp(1, 999),
                          child: Container(color: activeColor),
                        ),
                        Expanded(
                          flex: ((1 - activeRatio) * 1000).round().clamp(
                            1,
                            999,
                          ),
                          child: Container(color: pendingColor),
                        ),
                      ],
                    )
                  : Container(color: const Color(0xFFE2E6EA)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MesinStatBlock extends StatelessWidget {
  final String label;
  final int? value;
  final Color color;
  final bool hasError;

  const _MesinStatBlock({
    required this.label,
    required this.value,
    required this.color,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        hasError
            ? const Text(
                '-',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                ),
              )
            : value == null
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D23),
                ),
              ),
      ],
    );
  }
}

// ── Kartu metrik sederhana (grid) ─────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool hasError;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hasError,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: productionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          hasError
              ? const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                )
              : value == null
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Baris stat kompak (dipakai di sidebar landscape) ─────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool hasError;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.hasError,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: productionPanelDecoration(),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          hasError
              ? const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9CA3AF),
                  ),
                )
              : value == null
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Kartu chart penjualan selesai (7 hari) ───────────────────────────────────

class _SalesChartCard extends StatelessWidget {
  final List<DailySalesPoint>? points;
  final bool loading;

  /// Kalau di-set, area chart pakai tinggi tetap (dipakai di layout fallback
  /// yang di-scroll). Kalau null, area chart mengisi sisa tinggi kartu lewat
  /// [Expanded] (dipakai di layout landscape yang tingginya sudah dibatasi).
  final double? chartHeight;

  const _SalesChartCard({
    required this.points,
    required this.loading,
    this.chartHeight,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = !loading && points == null;

    final chartArea = hasError
        ? const Center(
            child: Text(
              '-',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
          )
        : points == null
        ? const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : _SalesLineChart(points: points!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: productionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: kProductionPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 17,
                  color: kProductionPrimary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Penjualan Selesai per Hari',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
              ),
              if (points != null)
                Text(
                  'Total ${points!.fold<int>(0, (s, p) => s + p.count)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kProductionPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (chartHeight != null)
            SizedBox(height: chartHeight, child: chartArea)
          else
            Expanded(child: chartArea),
        ],
      ),
    );
  }
}

class _SalesLineChart extends StatelessWidget {
  final List<DailySalesPoint> points;

  const _SalesLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxCount = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final maxY = maxCount == 0 ? 4.0 : (maxCount * 1.25).ceilToDouble();

    return LineChart(
      LineChartData(
        maxY: maxY,
        minY: 0,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFF1F3F5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) return const SizedBox();
                final label = DateFormat(
                  'EEE',
                  'id_ID',
                ).format(points[i].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFF1A1D23),
            getTooltipItems: (spots) => spots.map((spot) {
              final point = points[spot.x.round()];
              final dateLabel = DateFormat(
                'd MMM',
                'id_ID',
              ).format(point.date);
              return LineTooltipItem(
                '$dateLabel\n',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: '${point.count} selesai',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].count.toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            color: kProductionPrimary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                    radius: 3.5,
                    color: kProductionPrimary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: kProductionPrimary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
