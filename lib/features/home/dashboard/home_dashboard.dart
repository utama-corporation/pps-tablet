import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/navigation/pps_menu_catalog.dart';
import '../../../core/network/api_error.dart';
import '../../favorit/favorit_links.dart';
import '../../favorit/model/favorit_row.dart';
import '../../favorit/view_model/favorit_view_model.dart';
import '../../production/shared/widgets/production_panel_decoration.dart';
import '../../report/model/report_item.dart';
import '../../update/model/update_model.dart';
import '../model/dashboard_home.dart';
import '../repository/dashboard_home_repository.dart';
import 'dashboard_header.dart';
import 'dashboard_widgets.dart';

/// Tujuan navigasi saat kartu atau chip dashboard diketuk.
typedef DashOpenRoute = void Function(String route, String title);

/// Isi halaman Dashboard utama: kartu analytics dari `/api/dashboard/home`,
/// di-refresh pull-to-refresh atau tombol muat ulang.
class DashboardBody extends StatefulWidget {
  final DashboardHomeRepository repository;

  /// Null = kartu tidak bisa diketuk.
  final DashOpenRoute? onOpenRoute;

  /// Apakah pengguna boleh membuka route; null = selalu boleh.
  final bool Function(String route)? canOpenRoute;

  /// Identitas untuk kartu sapaan; null = sapaan tanpa nama.
  final Future<DashUser?> Function()? loadUser;

  /// Jumlah hak akses pengguna; null = status akun disembunyikan.
  final int? permissionCount;

  /// Favorit milik pengguna; null = kartu favorit disembunyikan.
  final FavoritViewModel? favorit;

  /// Buka favorit laporan (menu favorit memakai [onOpenRoute]).
  final void Function(ReportItem report)? onOpenReport;

  /// Cek versi baru; null/gagal = banner update tidak tampil.
  final Future<UpdateInfo?> Function()? checkUpdate;

  /// Dipanggil saat tombol "Perbarui" ditekan.
  final void Function(UpdateInfo info)? onUpdate;

  const DashboardBody({
    super.key,
    required this.repository,
    this.onOpenRoute,
    this.canOpenRoute,
    this.loadUser,
    this.permissionCount,
    this.favorit,
    this.onOpenReport,
    this.checkUpdate,
    this.onUpdate,
  });

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  static const _ranges = [7, 14, 30, 90];

  int _range = 7;
  DashHome? _home;
  String _error = '';
  bool _loading = false;

  /// Naik tiap permintaan; jawaban dari permintaan lama diabaikan supaya
  /// data selalu sesuai rentang yang terakhir dipilih.
  int _generation = 0;

  DashUser? _user;
  UpdateInfo? _update;
  bool _updateDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUser();
    _checkUpdate();
    // Selalu ambil favorit terbaru saat dashboard dibuka.
    widget.favorit?.load(fresh: true);
  }

  Future<void> _loadUser() async {
    try {
      final user = await widget.loadUser?.call();
      if (mounted && user != null) setState(() => _user = user);
    } catch (_) {
      // Sapaan tetap tampil tanpa nama.
    }
  }

  Future<void> _checkUpdate() async {
    final check = widget.checkUpdate;
    if (check == null) return;
    try {
      final info = await check();
      if (mounted) setState(() => _update = info);
    } catch (_) {
      // Gagal cek versi tidak boleh mengganggu dashboard.
    }
  }

  /// Tombol muat ulang & tarik-ke-bawah: ringkasan sekaligus favorit.
  Future<void> _refreshAll() => Future.wait([
    _load(),
    if (widget.favorit != null) widget.favorit!.load(fresh: true),
  ]);

  void _openFavorit(FavoritRow row, FavoritMeta meta) {
    final route = meta.menu?.route;
    if (route != null) {
      widget.onOpenRoute?.call(route, meta.title);
    } else if (meta.report != null) {
      widget.onOpenReport?.call(meta.report!);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final range = _range;
    setState(() => _loading = true);
    try {
      final home = await widget.repository.home(range);
      if (!mounted || generation != _generation) return;
      setState(() {
        _home = home;
        _error = '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _setRange(int value) {
    if (value == _range) return;
    setState(() => _range = value);
    _load();
  }

  /// Route tujuan kartu domain; null bila tidak ada atau tidak berhak.
  (String, String)? _domainTarget(DashDomain d) {
    final target = switch (d.detail.isEmpty ? d.key : d.detail) {
      'produksi' => ('/production', 'Proses Produksi'),
      'penjualan' => ('/shell/penjualan', 'Penjualan'),
      'mesin' => ('/master/mesin-produksi', 'Master Mesin Produksi'),
      _ => null,
    };
    return target != null && _allowed(target.$1) ? target : null;
  }

  /// Route proses produksi per departemen, hanya yang terdaftar di katalog.
  (String, String)? _deptTarget(String key, String label) {
    final route = '/production/$key';
    final item = PpsMenuCatalog.forRoute(route);
    if (item == null || !_allowed(route)) return null;
    return (route, item.title.isEmpty ? label : item.title);
  }

  bool _allowed(String route) =>
      widget.onOpenRoute != null && (widget.canOpenRoute?.call(route) ?? true);

  VoidCallback? _opener((String, String)? target) =>
      target == null ? null : () => widget.onOpenRoute!(target.$1, target.$2);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final home = _home;
    // Data lama dari rentang lain diredupkan selama rentang baru dimuat.
    final stale = home != null && home.rangeDays != _range;
    final update = _update;
    return RefreshIndicator(
      color: kProductionPrimary,
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (update != null && (update.forceUpdate || !_updateDismissed)) ...[
            DashUpdateBanner(
              info: update,
              onUpdate: () => widget.onUpdate?.call(update),
              onDismiss: () => setState(() => _updateDismissed = true),
            ),
            const SizedBox(height: 14),
          ],
          _headerRow(now, home, wide),
          const SizedBox(height: 16),
          _rangeBar(home),
          const SizedBox(height: 14),
          if (home == null && _error.isNotEmpty && !_loading)
            _fullErrorCard()
          else if (home == null)
            _skeleton(wide)
          else ...[
            if (_error.isNotEmpty && !_loading) ...[
              _staleErrorBanner(home),
              const SizedBox(height: 12),
            ],
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: stale && _loading ? 0.45 : 1,
              child: _sections(home, wide),
            ),
          ],
        ],
      ),
    );
  }

  /// Sapaan + favorit: berdampingan di layar lebar, bertumpuk di layar sempit.
  Widget _headerRow(DateTime now, DashHome? home, bool wide) {
    final greeting = DashGreetingCard(
      user: _user,
      now: now,
      updatedAt: home?.generatedAt,
      loading: _loading,
      onRefresh: _refreshAll,
      permissionCount: widget.permissionCount,
    );
    final vm = widget.favorit;
    if (vm == null) return greeting;
    final favorites = DashFavoritesCard(
      key: const Key('dash-favorites'),
      vm: vm,
      onOpen: _openFavorit,
      onManage: _allowed('/shell/favorit')
          ? () => widget.onOpenRoute!('/shell/favorit', 'Favorit')
          : null,
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [greeting, const SizedBox(height: 14), favorites],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: greeting),
        const SizedBox(width: 14),
        Expanded(flex: 4, child: favorites),
      ],
    );
  }

  /// Pilihan rentang + keterangan periode data dan pembandingnya.
  Widget _rangeBar(DashHome? home) {
    final short = DateFormat('d MMM', 'id_ID');
    final info = home == null
        ? ''
        : [
            if (home.generatedAt != null)
              'Data per ${DateFormat('HH:mm').format(home.generatedAt!)}',
            if (home.from != null && home.to != null)
              '${short.format(home.from!)} – ${short.format(home.to!)}',
            'dibandingkan ${home.rangeDays} hari sebelumnya',
          ].join(' · ');
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _ranges)
              ChoiceChip(
                key: Key('range-$value'),
                label: Text('$value hari'),
                selected: _range == value,
                onSelected: (_) => _setRange(value),
                selectedColor: kProductionPrimary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _range == value
                      ? kProductionPrimary
                      : const Color(0xFF475569),
                ),
              ),
          ],
        ),
        if (info.isNotEmpty)
          Text(
            info,
            key: const Key('dash-range-info'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
      ],
    );
  }

  Widget _fullErrorCard() => DashCard(
    child: Column(
      children: [
        const SizedBox(height: 8),
        const Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: Color(0xFF94A3B8),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ringkasan dashboard belum dapat dimuat.',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _load, child: const Text('Muat ulang')),
        const SizedBox(height: 8),
      ],
    ),
  );

  /// Muat ulang gagal tapi data sebelumnya masih ada: tetap tampilkan data
  /// itu, dengan keterangan bahwa data tersebut belum diperbarui.
  Widget _staleErrorBanner(DashHome home) {
    final mismatch = home.rangeDays != _range;
    return Container(
      key: const Key('dash-stale-error'),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mismatch
                  ? 'Data $_range hari gagal dimuat ($_error). '
                        'Menampilkan data ${home.rangeDays} hari sebelumnya.'
                  : 'Gagal memperbarui ($_error). Menampilkan data terakhir.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('Coba lagi')),
        ],
      ),
    );
  }

  /// Kerangka abu-abu selama pemuatan pertama, mengikuti tata letak asli.
  Widget _skeleton(bool wide) {
    const small = DashSkeletonCard(height: 150);
    return Column(
      key: const Key('dash-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DashSkeletonCard(height: 190),
        const SizedBox(height: 14),
        if (wide)
          const Row(
            children: [
              Expanded(child: small),
              SizedBox(width: 14),
              Expanded(child: small),
            ],
          )
        else ...const [small, SizedBox(height: 14), small],
        const SizedBox(height: 16),
        const DashSkeletonCard(height: 220),
      ],
    );
  }

  Widget _sections(DashHome home, bool wide) {
    final produksi = _domain(home, 'produksi');
    final penjualan = _domain(home, 'penjualan');
    final mesin = _domain(home, 'mesin');

    Widget card(DashDomain d) => DashDomainCard(
      key: Key('dash-domain-${d.key}'),
      domain: d,
      onRetry: _load,
      onTap: _opener(_domainTarget(d)),
      onDeptTap: (key, label) => _opener(_deptTarget(key, label)),
    );

    final body = <Widget>[];
    if (wide && produksi != null) {
      body.add(card(produksi));
      final row = <Widget>[
        if (penjualan != null) Expanded(child: card(penjualan)),
        if (penjualan != null && mesin != null) const SizedBox(width: 14),
        if (mesin != null) Expanded(child: card(mesin)),
      ];
      if (row.isNotEmpty) {
        body.add(const SizedBox(height: 14));
        body.add(
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: row),
        );
      }
    } else {
      for (final d in [produksi, penjualan, mesin].whereType<DashDomain>()) {
        if (body.isNotEmpty) body.add(const SizedBox(height: 14));
        body.add(card(d));
      }
    }

    if (home.trend != null || home.trendError.isNotEmpty) {
      body.add(const SizedBox(height: 16));
      body.add(const _SectionLabel('Tren dokumen per hari'));
      body.add(const SizedBox(height: 8));
      body.add(_trendCard(home));
    }

    if (home.activity.isNotEmpty) {
      body.add(const SizedBox(height: 16));
      body.add(const _SectionLabel('Aktivitas hari ini'));
      body.add(const SizedBox(height: 8));
      body.add(_activityRow(home, wide));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: body,
    );
  }

  DashDomain? _domain(DashHome home, String key) =>
      home.domains.where((d) => d.key == key).firstOrNull;

  Widget _trendCard(DashHome home) {
    final trend = home.trend;
    if (trend == null) {
      return DashCard(
        child: Text(
          home.trendError.isEmpty ? 'Tren belum tersedia.' : home.trendError,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      );
    }
    if (trend.isEmpty) {
      return const DashCard(
        child: Text(
          'Belum ada data pada rentang ini.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      );
    }
    final peak = trend
        .map((d) => math.max(d.produksi, d.penjualan))
        .fold<double>(0, math.max);
    // Sekitar 4 garis grid berapa pun besarnya angka.
    final yStep = dashNiceStep(peak * 1.15 / 4);
    final maxY = math.max(yStep, (peak * 1.15 / yStep).ceil() * yStep);
    // Maksimal ~8 label tanggal supaya tidak bertumpuk di rentang 30/90 hari.
    final xStep = math.max(1, (trend.length / 8).ceil()).toDouble();
    final spotsProduksi = [
      for (var i = 0; i < trend.length; i++)
        FlSpot(i.toDouble(), trend[i].produksi),
    ];
    final spotsPenjualan = [
      for (var i = 0; i < trend.length; i++)
        FlSpot(i.toDouble(), trend[i].penjualan),
    ];
    return DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DashIconBadge(icon: Icons.show_chart_rounded),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Produksi vs Penjualan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              _legendDot(kProductionPrimary, 'Produksi'),
              const SizedBox(width: 12),
              _legendDot(kProductionOutput, 'Penjualan'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yStep,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: yStep,
                      getTitlesWidget: _gridLabel,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: xStep,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= trend.length) return const SizedBox();
                        final d = trend[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsProduksi,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: kProductionPrimary,
                    barWidth: 2.5,
                    dotData: FlDotData(show: trend.length <= 14),
                    belowBarData: BarAreaData(
                      show: true,
                      color: kProductionPrimary.withValues(alpha: 0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: spotsPenjualan,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: kProductionOutput,
                    barWidth: 2.5,
                    dotData: FlDotData(show: trend.length <= 14),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(DashHome home, bool wide) {
    final cards = [
      for (final item in home.activity) _activityCard(item, _load),
    ];
    if (!wide || cards.length < 2) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    final row = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      if (i > 0) row.add(const SizedBox(width: 12));
      row.add(Expanded(child: cards[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
      ),
    ],
  );

  static Widget _gridLabel(double value, TitleMeta _) => Text(
    NumberFormat.compact(locale: 'id_ID').format(value),
    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
  );
}

/// Langkah sumbu "rapi" (1, 2, 5 × 10ⁿ) yang ≥ [raw]; minimal 1.
double dashNiceStep(double raw) {
  if (raw <= 1) return 1;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
  for (final m in const [1, 2, 5]) {
    final step = m * magnitude;
    if (step >= raw) return step.toDouble();
  }
  return (10 * magnitude).toDouble();
}

Widget _activityCard(DashActivityItem item, VoidCallback onRetry) {
  if (item.error.isNotEmpty) {
    return DashCard(
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFB91C1C),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.label}: ${item.error}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
  final isBs = item.key == 'bongkar_susun';
  final value = item.value;
  return DashCard(
    child: Row(
      children: [
        DashIconBadge(
          icon: isBs ? Icons.inventory_2_outlined : Icons.filter_alt_outlined,
          color: isBs ? kProductionPrimary : const Color(0xFFB91C1C),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              if (value == null)
                const Text(
                  'Belum ada data',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                )
              else
                Text(
                  '${NumberFormat('#,##0', 'id_ID').format(value)} transaksi',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D23),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: Color(0xFF94A3B8),
      letterSpacing: 0.6,
    ),
  );
}
