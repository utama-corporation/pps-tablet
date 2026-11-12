import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../profile/view/profil_screen.dart';
import '../../stock_opname_v2/model/so_v2_models.dart';
import '../../stock_opname_v2/view_model/so_v2_my_lokasi_view_model.dart';

class BerandaColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color background = Color(0xFFF7F8FA);
  static const Color ink = Color(0xFF1E293B);
  static const Color slate = Color(0xFF64748B);
  static const Color border = Color(0xFFE7EAF0);
}

// enum _Severity { warning, critical }
//
// extension on _Severity {
//   Color get color {
//     switch (this) {
//       case _Severity.warning:
//         return const Color(0xFFD97706);
//       case _Severity.critical:
//         return const Color(0xFFDC2626);
//     }
//   }
// }

class _ModuleEntry {
  final String route;
  final IconData icon;
  final String label;

  const _ModuleEntry({
    required this.route,
    required this.icon,
    required this.label,
  });
}

const List<_ModuleEntry> _modules = [
  _ModuleEntry(
    route: '/stockopname-v2',
    icon: Icons.inventory_2_outlined,
    label: 'Stock Opname',
  ),
  _ModuleEntry(
    route: '/mapping-v2',
    icon: Icons.map_rounded,
    label: 'Mapping',
  ),
  _ModuleEntry(
    route: '/bj-jual',
    icon: Icons.sell_rounded,
    label: 'Penjualan BJ',
  ),
];

/// Warna pastel tile menu (latar, ikon) bergiliran seperti MCS Mobile.
const List<(Color, Color)> _modulePalettes = [
  (Color(0xFFDDF3EC), Color(0xFF1E8A6A)),
  (Color(0xFFEDE3F3), Color(0xFF7B4FA0)),
  (Color(0xFFDDEBF8), Color(0xFF2F6FB5)),
  (Color(0xFFDDF0EE), Color(0xFF2B8C84)),
  (Color(0xFFF1E5DA), Color(0xFF8A5A2E)),
  (Color(0xFFFBE1E1), Color(0xFFC0453F)),
  (Color(0xFFDDF1F8), Color(0xFF2A93B5)),
  (Color(0xFFFCE4EC), Color(0xFFC2477A)),
];

// class _AlertItem {
//   final String title;
//   final String subtitle;
//   final _Severity severity;
//
//   const _AlertItem({required this.title, required this.subtitle, required this.severity});
// }

// Placeholder values for layout purposes only — not wired to any API yet.
// const List<_AlertItem> _mockAlerts = [
//   _AlertItem(
//     title: '3 sesi Stock Opname menunggu approval',
//     subtitle: 'Gudang A · Rak 04–06',
//     severity: _Severity.warning,
//   ),
//   _AlertItem(
//     title: '12 label belum discan di Gudang C',
//     subtitle: 'Mapping · terakhir update 2 hari lalu',
//     severity: _Severity.critical,
//   ),
// ];

/// Beranda tab: greeting + operational summary + the module menu itself.
/// There is no separate Menu tab — this screen is where modules are
/// opened from.
class BerandaTab extends StatefulWidget {
  const BerandaTab({super.key});

  @override
  State<BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<BerandaTab> {
  late final SoV2MyLokasiViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SoV2MyLokasiViewModel()..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 4) return 'Selamat Malam';
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _openModule(String route) {
    Navigator.pushNamed(context, route);
  }

  Future<void> _refresh() => _viewModel.load();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BerandaColors.background,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SoSummaryStrip(viewModel: _viewModel),
                    const SizedBox(height: 22),
                    _BelumSelesai(
                      viewModel: _viewModel,
                      onOpen: () => _openModule('/stockopname-v2'),
                    ),
                    const SizedBox(height: 26),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        'Menu',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: BerandaColors.ink,
                        ),
                      ),
                    ),
                  // Tile menu ala MCS Mobile: 4 kolom, atas pastel + ikon, bawah judul.
                  LayoutBuilder(
                    builder: (context, box) => GridView.count(
                      key: const Key('mobile-menu-grid'),
                      crossAxisCount: box.maxWidth >= 520 ? 5 : 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: .74,
                      children: [
                        for (var i = 0; i < _modules.length; i++)
                          _ModuleTile(
                            icon: _modules[i].icon,
                            label: _modules[i].label,
                            palette: _modulePalettes[i % _modulePalettes.length],
                            moduleKey: _modules[i].route.substring(1),
                            onTap: () => _openModule(_modules[i].route),
                          ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 20),
                  // _sectionLabel('PERLU DITINDAK'),
                  // const SizedBox(height: 10),
                  // ..._mockAlerts.map(
                  //   (a) => Padding(
                  //     padding: const EdgeInsets.only(bottom: 8),
                  //     child: _AlertRow(
                  //       title: a.title,
                  //       subtitle: a.subtitle,
                  //       color: a.severity.color,
                  //     ),
                  //   ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  // Widget _sectionLabel(String text) {
  //   return Text(
  //     text,
  //     style: const TextStyle(
  //       fontSize: 11,
  //       fontWeight: FontWeight.w800,
  //       color: BerandaColors.slate,
  //       letterSpacing: 1.2,
  //     ),
  //   );
  // }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        color: BerandaColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
                const SizedBox(height: 3),
                const Text(
                  'PPS Mobile',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _NotificationBell(),
          const SizedBox(width: 8),
          const _UserButton(),
        ],
      ),
    );
  }

}

class _UserButton extends StatelessWidget {
  const _UserButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: const Key('open-profile'),
        borderRadius: BorderRadius.circular(11),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfilScreen()),
        ),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 19),
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFF87171),
                shape: BoxShape.circle,
                border: Border.all(color: BerandaColors.primary, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact 3-column summary of the user's Stock Opname assignments,
/// sourced from /api/stock-opname-v2/my-lokasi. The view model is owned
/// by the parent (shared with the chart and the checklist).
class _SoSummaryStrip extends StatefulWidget {
  const _SoSummaryStrip({required this.viewModel});

  final SoV2MyLokasiViewModel viewModel;

  @override
  State<_SoSummaryStrip> createState() => _SoSummaryStripState();
}

class _SoSummaryStripState extends State<_SoSummaryStrip> {
  SoV2MyLokasiViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.items.isEmpty) {
      return _card(
        padding: EdgeInsets.zero,
        child: const SizedBox(
          height: 92,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      );
    }
    if (_viewModel.error != null && _viewModel.items.isEmpty) {
      return _card(
        padding: EdgeInsets.zero,
        child: SizedBox(height: 92, child: _errorRow()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(child: _metricsRow(_metrics())),
        const SizedBox(height: 22),
        const Text(
          'PROGRESS PER LOKASI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: BerandaColors.slate,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _card(
          padding: const EdgeInsets.fromLTRB(14, 16, 10, 12),
          child: _viewModel.items.isEmpty
              ? const SizedBox(
                  height: 150,
                  child: Center(
                    child: Text(
                      'Belum ada lokasi ditugaskan',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: BerandaColors.slate,
                      ),
                    ),
                  ),
                )
              : _ProgressBarChart(items: _viewModel.items),
        ),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BerandaColors.border),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
      child: child,
    );
  }

  Widget _errorRow() {
    return InkWell(
      onTap: _viewModel.load,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: BerandaColors.slate,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Gagal memuat ringkasan — tap untuk coba lagi',
              style: const TextStyle(
                fontSize: 12,
                color: BerandaColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsRow(List<({IconData icon, String value, String label})> metrics) {
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i != 0)
            const SizedBox(
              height: 40,
              child: VerticalDivider(width: 1, color: BerandaColors.border),
            ),
          Expanded(
            child: Column(
              children: [
                Icon(metrics[i].icon, color: BerandaColors.primary, size: 20),
                const SizedBox(height: 6),
                Text(
                  metrics[i].value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: BerandaColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metrics[i].label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: BerandaColors.slate,
                  ),
                ),
              ],
              ),
            ),
          ],
        ],
    );
  }

  List<({IconData icon, String value, String label})> _metrics() {
    final items = _viewModel.items;
    final totalLabels = items.fold<int>(
      0,
      (sum, item) => sum + item.location.labelCount,
    );
    final scanned = items.fold<int>(
      0,
      (sum, item) => sum + item.location.scannedCount,
    );
    final progress = totalLabels == 0 ? 0 : (scanned / totalLabels * 100).round();
    return [
      (
        icon: Icons.assignment_outlined,
        value: '${items.length}',
        label: 'Lokasi Ditugaskan',
      ),
      (
        icon: Icons.qr_code_scanner_rounded,
        value: '$scanned',
        label: 'Label Discan',
      ),
      (
        icon: Icons.donut_large_rounded,
        value: '$progress%',
        label: 'Progress Scan',
      ),
    ];
  }

}

/// Checklist of SO assignments whose labels are not fully scanned yet.
/// Hidden when there is nothing pending (or while loading with no data).
class _BelumSelesai extends StatelessWidget {
  const _BelumSelesai({required this.viewModel, required this.onOpen});

  final SoV2MyLokasiViewModel viewModel;
  final VoidCallback onOpen;

  static const int _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final pending = viewModel.items
            .where((item) => item.location.labelCount > item.location.scannedCount)
            .toList()
          ..sort((a, b) => a.location.progress.compareTo(b.location.progress));
        if (pending.isEmpty) return const SizedBox.shrink();
        final shown = pending.take(_maxRows).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BELUM SELESAI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: BerandaColors.slate,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in shown) ...[
              _BelumSelesaiRow(item: item, onTap: onOpen),
              const SizedBox(height: 8),
            ],
            if (pending.length > _maxRows)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4),
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    '+${pending.length - _maxRows} lokasi lainnya di Stock Opname',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: BerandaColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BelumSelesaiRow extends StatelessWidget {
  const _BelumSelesaiRow({required this.item, required this.onTap});

  final SoV2MyLokasi item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lokasi = item.location;
    final title = [
      lokasi.blok.trim(),
      lokasi.description.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    final titleText = title.isEmpty ? 'Lokasi #${lokasi.locationId}' : title;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BerandaColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: BerandaColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 18,
                  color: BerandaColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: BerandaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: lokasi.progress == 0 ? 0.001 : lokasi.progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFEDF0F5),
                        color: BerandaColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${lokasi.scannedCount}/${lokasi.labelCount}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: BerandaColors.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar chart comparing total label vs scanned label per lokasi,
/// top-6 by labelCount. Same data source as the summary strip.
class _ProgressBarChart extends StatelessWidget {
  const _ProgressBarChart({required this.items});

  final List<SoV2MyLokasi> items;

  static const int _maxGroups = 6;
  static const Color _totalColor = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort(
      (a, b) => b.location.labelCount.compareTo(a.location.labelCount),
    );
    final shown = sorted.take(_maxGroups).toList();
    final maxLabels = shown.fold<int>(
      0,
      (max, item) => item.location.labelCount > max ? item.location.labelCount : max,
    );
    final maxY = maxLabels == 0 ? 1.0 : (maxLabels / 4).ceil() * 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (var i = 0; i < shown.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: shown[i].location.labelCount.toDouble(),
                        color: _totalColor,
                        width: 7,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                      BarChartRodData(
                        toY: shown[i].location.scannedCount.toDouble(),
                        color: BerandaColors.primary,
                        width: 7,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: const [],
                  ),
              ],
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(strokeWidth: 1, color: BerandaColors.border),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: maxY / 4,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      child: Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: BerandaColors.slate,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= shown.length) {
                        return const SizedBox.shrink();
                      }
                      final lokasi = shown[index].location;
                      final blok = lokasi.blok.trim();
                      final label = blok.isEmpty
                          ? '#${lokasi.locationId}'
                          : (blok.length > 7 ? blok.substring(0, 7) : blok);
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 4,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: BerandaColors.slate,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final lokasi = shown[group.x.toInt()].location;
                    final head = rodIndex == 0
                        ? 'Total: ${lokasi.labelCount}'
                        : 'Discan: ${lokasi.scannedCount}';
                    final detail = [
                      lokasi.blok.trim(),
                      lokasi.description.trim(),
                    ].where((part) => part.isNotEmpty).join(' · ');
                    return BarTooltipItem(
                      detail.isEmpty ? head : '$head\n$detail',
                      const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _LegendDot(color: _totalColor, label: 'Total Label'),
            const SizedBox(width: 16),
            _LegendDot(color: BerandaColors.primary, label: 'Discan'),
            if (sorted.length > _maxGroups) ...[
              const Spacer(),
              Text(
                '6 dari ${sorted.length} lokasi teratas',
                style: const TextStyle(
                  fontSize: 10,
                  color: BerandaColors.slate,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: BerandaColors.slate),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final (Color, Color) palette;
  final String moduleKey;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.palette,
    required this.moduleKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = palette;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shadowColor: Colors.black12,
      child: InkWell(
        key: Key('mobile-module-$moduleKey'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: ColoredBox(
                color: background,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 21, color: foreground),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      color: BerandaColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class _AlertRow extends StatelessWidget {
//   final String title;
//   final String subtitle;
//   final Color color;
//
//   const _AlertRow({required this.title, required this.subtitle, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.06),
//         borderRadius: BorderRadius.circular(12),
//         border: Border(left: BorderSide(color: color, width: 3)),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 12.5,
//               fontWeight: FontWeight.w700,
//               color: BerandaColors.ink,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             subtitle,
//             style: const TextStyle(fontSize: 11, color: BerandaColors.slate),
//           ),
//         ],
//       ),
//     );
//   }
// }
