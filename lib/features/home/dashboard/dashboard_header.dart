import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../favorit/favorit_links.dart';
import '../../favorit/model/favorit_row.dart';
import '../../favorit/view_model/favorit_view_model.dart';
import '../../production/shared/widgets/production_panel_decoration.dart';
import '../../update/model/update_model.dart';
import 'dashboard_widgets.dart';

const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _ink = Color(0xFF1A1D23);

/// Identitas pengguna yang login, dari sesi lokal.
class DashUser {
  final String name, group;
  const DashUser(this.name, this.group);
}

String dashGreetingFor(DateTime now) => switch (now.hour) {
  < 11 => 'Selamat pagi,',
  < 15 => 'Selamat siang,',
  < 18 => 'Selamat sore,',
  _ => 'Selamat malam,',
};

/// Sapaan: nama, tanggal & grup, waktu data, tombol muat ulang, status akun.
class DashGreetingCard extends StatelessWidget {
  final DashUser? user;
  final DateTime now;
  final DateTime? updatedAt;
  final bool loading;
  final VoidCallback onRefresh;

  /// Null = tidak diketahui (status akun disembunyikan).
  final int? permissionCount;

  const DashGreetingCard({
    super.key,
    required this.user,
    required this.now,
    required this.updatedAt,
    required this.loading,
    required this.onRefresh,
    this.permissionCount,
  });

  @override
  Widget build(BuildContext context) {
    final group = user?.group.trim() ?? '';
    final count = permissionCount;
    return DashCard(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dashGreetingFor(now),
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 4),
              Text(
                user?.name ?? '…',
                key: const Key('dash-user-name'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kProductionPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now),
                  if (group.isNotEmpty) group,
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    updatedAt == null
                        ? 'Memuat data…'
                        : 'Diperbarui ${DateFormat('HH:mm').format(updatedAt!)}',
                    key: const Key('dash-updated'),
                    style: const TextStyle(fontSize: 11, color: _faint),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      key: const Key('dash-refresh'),
                      tooltip: 'Muat ulang',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: onRefresh,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: kProductionPrimary,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kProductionSurface,
                border: Border.all(color: kProductionBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STATUS AKUN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _faint,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0 ? 'Belum ada hak akses' : '$count hak akses',
                    key: const Key('dash-permissions'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  if (count == 0)
                    const Text(
                      'Hubungi administrator',
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pemberitahuan versi aplikasi baru; wajib = merah dan tidak bisa ditunda.
class DashUpdateBanner extends StatelessWidget {
  final UpdateInfo info;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;
  const DashUpdateBanner({
    super.key,
    required this.info,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final force = info.forceUpdate;
    final color = force ? const Color(0xFFB91C1C) : kProductionPrimary;
    final note = info.changelog
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return Container(
      key: const Key('dash-update-banner'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(kProductionRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  force
                      ? 'Versi ${info.latestVersion} wajib dipasang'
                      : 'Versi ${info.latestVersion} tersedia',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
              ],
            ),
          ),
          if (!force)
            TextButton(
              key: const Key('dash-update-later'),
              onPressed: onDismiss,
              child: const Text('Nanti'),
            ),
          const SizedBox(width: 4),
          FilledButton(
            key: const Key('dash-update-now'),
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: onUpdate,
            child: const Text('Perbarui'),
          ),
        ],
      ),
    );
  }
}

/// Pintasan favorit pengguna (menu & laporan), maksimal [limit] item.
class DashFavoritesCard extends StatelessWidget {
  final FavoritViewModel vm;
  final void Function(FavoritRow row, FavoritMeta meta) onOpen;
  final VoidCallback? onManage;
  final int limit;
  const DashFavoritesCard({
    super.key,
    required this.vm,
    required this.onOpen,
    this.onManage,
    this.limit = 8,
  });

  @override
  Widget build(BuildContext context) => DashCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DashIconBadge(
              icon: Icons.star_rounded,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Favorit',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            if (onManage != null)
              TextButton(
                key: const Key('dash-favorites-manage'),
                onPressed: onManage,
                child: const Text('Kelola'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ListenableBuilder(listenable: vm, builder: (context, _) => _body()),
      ],
    ),
  );

  Widget _body() {
    final rows = vm.rows;
    if (rows.isEmpty) {
      final String text;
      if (vm.loading) {
        return const SizedBox(
          height: 64,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      } else if (vm.error.isNotEmpty) {
        text = 'Favorit belum dapat dimuat. ${vm.error}';
      } else {
        text =
            'Belum ada favorit. Tekan ikon bintang di menu atau laporan '
            'agar muncul di sini.';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          key: const Key('dash-favorites-empty'),
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
      );
    }
    final shown = rows.take(limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final row in shown) _tile(row, favoritMeta(row))],
        ),
        if (rows.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${rows.length - shown.length} favorit lainnya',
              style: const TextStyle(fontSize: 11, color: _faint),
            ),
          ),
      ],
    );
  }

  Widget _tile(FavoritRow row, FavoritMeta meta) {
    final enabled = meta.available;
    return Material(
      color: kProductionSurface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kProductionBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        key: Key('dash-fav-${row.tipe}:${row.kode}'),
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? () => onOpen(row, meta) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  meta.icon,
                  size: 18,
                  color: enabled ? kProductionPrimary : _faint,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        meta.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: enabled ? _ink : _faint,
                        ),
                      ),
                      Text(
                        enabled ? meta.subtitle : 'Belum tersedia di tablet',
                        style: const TextStyle(fontSize: 10.5, color: _faint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
