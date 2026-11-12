import 'package:flutter/material.dart';

class BerandaColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color background = Color(0xFFF7F8FA);
  static const Color ink = Color(0xFF1E293B);
  static const Color slate = Color(0xFF64748B);
  static const Color border = Color(0xFFE7EAF0);
}

enum _Severity { warning, critical }

extension on _Severity {
  Color get color {
    switch (this) {
      case _Severity.warning:
        return const Color(0xFFD97706);
      case _Severity.critical:
        return const Color(0xFFDC2626);
    }
  }
}

class _SummaryItem {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({required this.icon, required this.value, required this.label});
}

// Placeholder values for layout purposes only — not wired to any API yet.
const List<_SummaryItem> _mockSummary = [
  _SummaryItem(icon: Icons.inventory_2_outlined, value: '6', label: 'Sesi SO Aktif'),
  _SummaryItem(icon: Icons.map_rounded, value: '184', label: 'Lokasi Dipetakan'),
  _SummaryItem(icon: Icons.pending_actions_rounded, value: '3', label: 'Perlu Ditindak'),
];

class _ModuleEntry {
  final String route;
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _ModuleEntry({
    required this.route,
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
}

const List<_ModuleEntry> _modules = [
  _ModuleEntry(
    route: '/stockopname-v2',
    icon: Icons.inventory_2_outlined,
    label: 'Stock Opname',
    description: 'Hitung & cocokkan stok per lokasi',
    color: BerandaColors.primary,
  ),
  _ModuleEntry(
    route: '/mapping-v2',
    icon: Icons.map_rounded,
    label: 'Mapping',
    description: 'Petakan label ke blok & lokasi',
    color: Color(0xFF0369A1),
  ),
  _ModuleEntry(
    route: '/bj-jual',
    icon: Icons.sell_rounded,
    label: 'Penjualan BJ',
    description: 'Catat penjualan barang jadi',
    color: Color(0xFF92400E),
  ),
];

class _AlertItem {
  final String title;
  final String subtitle;
  final _Severity severity;

  const _AlertItem({required this.title, required this.subtitle, required this.severity});
}

// Placeholder values for layout purposes only — not wired to any API yet.
const List<_AlertItem> _mockAlerts = [
  _AlertItem(
    title: '3 sesi Stock Opname menunggu approval',
    subtitle: 'Gudang A · Rak 04–06',
    severity: _Severity.warning,
  ),
  _AlertItem(
    title: '12 label belum discan di Gudang C',
    subtitle: 'Mapping · terakhir update 2 hari lalu',
    severity: _Severity.critical,
  ),
];

/// Beranda tab: greeting + operational summary + the module menu itself.
/// There is no separate Menu tab — this screen is where modules are
/// opened from.
class BerandaTab extends StatelessWidget {
  const BerandaTab({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _openModule(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BerandaColors.background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SummaryStrip(),
                  const SizedBox(height: 26),
                  _sectionLabel('MODUL'),
                  const SizedBox(height: 10),
                  ..._modules.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModuleTile(
                        icon: m.icon,
                        label: m.label,
                        description: m.description,
                        color: m.color,
                        onTap: () => _openModule(context, m.route),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('PERLU DITINDAK'),
                  const SizedBox(height: 10),
                  ..._mockAlerts.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AlertRow(
                        title: a.title,
                        subtitle: a.subtitle,
                        color: a.severity.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: BerandaColors.slate,
        letterSpacing: 1.2,
      ),
    );
  }

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
          _NotificationBell(),
        ],
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

/// Compact 3-column operational summary. Flat, no cards-within-cards.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BerandaColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          for (var i = 0; i < _mockSummary.length; i++) ...[
            if (i != 0)
              const SizedBox(
                height: 40,
                child: VerticalDivider(width: 1, color: BerandaColors.border),
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(_mockSummary[i].icon, color: BerandaColors.primary, size: 20),
                  const SizedBox(height: 6),
                  Text(
                    _mockSummary[i].value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: BerandaColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mockSummary[i].label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10.5, color: BerandaColors.slate),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BerandaColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: BerandaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: BerandaColors.slate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BerandaColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _AlertRow({required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: BerandaColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: BerandaColors.slate),
          ),
        ],
      ),
    );
  }
}
