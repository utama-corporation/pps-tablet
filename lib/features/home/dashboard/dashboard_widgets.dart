import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pps_tablet/features/production/shared/widgets/production_panel_decoration.dart';

import '../../home/model/dashboard_home.dart';

/// Kartu putih dengan dekorasi panel produksi.
class DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const DashCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: productionPanelDecoration(),
    child: child,
  );
}

class DashIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const DashIconBadge({
    super.key,
    required this.icon,
    this.color = kProductionPrimary,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(icon, size: 19, color: color),
  );
}

/// Pil delta: arah panah + nilai + satuan (% atau pts).
class DashDeltaPill extends StatelessWidget {
  final DashDelta delta;
  const DashDeltaPill(this.delta, {super.key});

  @override
  Widget build(BuildContext context) {
    final up = delta.direction == 'up';
    final down = delta.direction == 'down';
    final color = up
        ? const Color(0xFF0A7349)
        : down
        ? const Color(0xFFB91C1C)
        : const Color(0xFF64748B);
    final icon = up
        ? Icons.arrow_upward_rounded
        : down
        ? Icons.arrow_downward_rounded
        : Icons.trending_flat_rounded;
    final abs = delta.value.abs();
    final text =
        '${NumberFormat('#,##0.#', 'id_ID').format(abs)}${delta.unit == 'pct' ? '%' : ' pts'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris label (muted) + nilai (tebal) rata kanan.
class DashMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const DashMetricRow(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF1A1D23),
          ),
        ),
      ],
    ),
  );
}

/// Kartu abu-abu pengganti selama data pertama dimuat.
class DashSkeletonCard extends StatelessWidget {
  final double height;
  const DashSkeletonCard({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double h) => Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F5),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return SizedBox(
      height: height,
      child: DashCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [bar(36, 36), const SizedBox(width: 10), bar(120, 14)],
            ),
            const SizedBox(height: 16),
            bar(90, 28),
            const SizedBox(height: 10),
            bar(160, 10),
          ],
        ),
      ),
    );
  }
}

/// Kartu domain generik; chip departemen tampil hanya untuk Produksi.
class DashDomainCard extends StatelessWidget {
  final DashDomain domain;
  final VoidCallback? onRetry;

  /// Null = kartu tidak bisa diketuk (tidak ada tujuan / tidak berhak).
  final VoidCallback? onTap;

  /// Aksi chip departemen (key, label); hasil null = chip tidak bisa diketuk.
  final VoidCallback? Function(String key, String label)? onDeptTap;

  const DashDomainCard({
    super.key,
    required this.domain,
    this.onRetry,
    this.onTap,
    this.onDeptTap,
  });

  IconData get _icon => switch (domain.key) {
    'produksi' => Icons.precision_manufacturing_outlined,
    'penjualan' => Icons.local_shipping_outlined,
    'mesin' => Icons.factory_outlined,
    _ => Icons.insights_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (domain.failed) {
      return DashCard(
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB91C1C),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${domain.label}: ${domain.error}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    final primary = domain.primary;
    final card = DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DashIconBadge(icon: _icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  domain.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (domain.delta != null) DashDeltaPill(domain.delta!),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat(
                  '#,##0',
                  'id_ID',
                ).format(_numValue(primary?.value)),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: kProductionPrimary,
                  height: 1,
                ),
              ),
              if (primary != null && primary.unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    primary.unit,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (primary != null) ...[
            const SizedBox(height: 2),
            Text(
              primary.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 12),
          for (final s in domain.secondary)
            DashMetricRow(s.label, _fmt(s.value)),
          if (domain.depts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (key, label, value, today) in domain.depts)
                  _deptChip(key, label, value, today),
              ],
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kProductionRadius),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _deptChip(String key, String label, int value, int today) {
    final tap = onDeptTap?.call(key, label);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: kProductionSurface,
        border: Border.all(color: kProductionBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label · ${_fmt(value)}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          if (today > 0) ...[
            const SizedBox(width: 5),
            Text(
              '+${_fmt(today)} hari ini',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: kProductionOutput,
              ),
            ),
          ],
        ],
      ),
    );
    if (tap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('dash-dept-$key'),
        borderRadius: BorderRadius.circular(8),
        onTap: tap,
        child: chip,
      ),
    );
  }

  String _fmt(dynamic v) => NumberFormat('#,##0', 'id_ID').format(_numValue(v));
  int _numValue(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? 0}') ?? 0;
  }
}
