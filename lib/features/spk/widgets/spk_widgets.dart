import 'package:flutter/material.dart';

Widget spkCell(String text) => Text(
  text.isEmpty ? '—' : text,
  style: const TextStyle(fontSize: 14),
  maxLines: 3,
  overflow: TextOverflow.ellipsis,
);

class SpkStatusLozenge extends StatelessWidget {
  const SpkStatusLozenge(this.status, {super.key});
  final String status;

  static (Color fg, Color bg) colorsFor(String status) => switch (status) {
    'STOCK HABIS' => (const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
    'PERLU PRODUKSI' => (const Color(0xFFB45309), const Color(0xFFFEF3C7)),
    'MENDEKATI MINIMUM' => (const Color(0xFFA16207), const Color(0xFFFEF9C3)),
    'STOCK AMAN' ||
    'CLOSED' ||
    'SELESAI' => (const Color(0xFF15803D), const Color(0xFFDCFCE7)),
    _ => (const Color(0xFF1D4ED8), const Color(0xFFDBEAFE)),
  };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsFor(status);
    return Align(
      alignment: Alignment.centerLeft,
      // Shrink-wrap so the lozenge can sit inside Wrap/Row without stretching.
      widthFactor: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.isEmpty ? '—' : status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: 0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Header used by every SPK dialog: icon tile, title, subtitle, close button.
class SpkDialogHeader extends StatelessWidget {
  const SpkDialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.color = const Color(0xFF1D4ED8),
    this.background = const Color(0xFFEFF6FF),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onClose;
  final Color color, background;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: .25)),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF172B4D),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B778C),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
        IconButton(
          tooltip: 'Tutup',
          onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class SpkSectionTitle extends StatelessWidget {
  const SpkSectionTitle({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF44546F)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF172B4D),
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Divider()),
    ],
  );
}

class SpkNotice extends StatelessWidget {
  const SpkNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.message,
  });
  final IconData icon;
  final Color color, background;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: TextStyle(fontSize: 13, color: color)),
        ),
      ],
    ),
  );
}

/// Small uppercase label above a bold value (or a custom [trailing] widget).
class SpkMetaItem extends StatelessWidget {
  const SpkMetaItem({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
    this.large = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;
  final bool large;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Color(0xFF6B778C),
        ),
      ),
      const SizedBox(height: 3),
      trailing ??
          Text(
            value.trim().isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: large ? 18 : 13,
              fontWeight: large ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? const Color(0xFF172B4D),
            ),
          ),
    ],
  );
}

class SpkFailure extends StatelessWidget {
  const SpkFailure(this.message, {super.key, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB91C1C),
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF44546F)),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class SpkEmptyState extends StatelessWidget {
  const SpkEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFFC1C7D0)),
          SizedBox(height: 12),
          Text(
            'Tidak ada barang',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172B4D),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tidak ada barang yang sesuai dengan pencarian atau status ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B778C)),
          ),
        ],
      ),
    ),
  );
}

class SpkPagination extends StatelessWidget {
  const SpkPagination({
    super.key,
    required this.page,
    required this.pages,
    required this.loading,
    required this.onPage,
  });
  final int page, pages;
  final bool loading;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Halaman sebelumnya',
        onPressed: loading || page <= 1 ? null : () => onPage(page - 1),
        icon: const Icon(Icons.chevron_left),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Halaman $page dari $pages',
          style: const TextStyle(fontSize: 13, color: Color(0xFF44546F)),
        ),
      ),
      IconButton(
        tooltip: 'Halaman berikutnya',
        onPressed: loading || page >= pages ? null : () => onPage(page + 1),
        icon: const Icon(Icons.chevron_right),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    ],
  );
}
