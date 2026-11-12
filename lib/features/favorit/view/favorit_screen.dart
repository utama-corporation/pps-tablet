import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_error.dart';
import '../../../core/navigation/pps_menu_catalog.dart';
import '../../../core/view/app_shell.dart';
import '../../report/model/report_item.dart';
import '../../report/view/report_open_helper.dart';
import '../model/favorit_row.dart';
import '../view_model/favorit_view_model.dart';

/// Layar Favorit — daftar favorit milik user; bisa digeser & dihapus.
class FavoritScreen extends StatefulWidget {
  const FavoritScreen({super.key});

  @override
  State<FavoritScreen> createState() => _FavoritScreenState();
}

class _FavoritScreenState extends State<FavoritScreen> {
  @override
  void initState() {
    super.initState();
    // Muat ulang saat layar dibuka supaya daftar selalu sesuai server.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FavoritViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<FavoritViewModel>(
        builder: (context, vm, _) {
          final rows = vm.rows;
          if (vm.loading && rows.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (vm.error.isNotEmpty && rows.isEmpty) {
            return _message(vm.error, error: true, onRetry: vm.load);
          }
          if (rows.isEmpty) {
            return _message(
              'Belum ada favorit.\nTekan ikon bintang pada menu atau laporan untuk menambahnya.',
              onRetry: vm.load,
            );
          }
          return RefreshIndicator(
            onRefresh: vm.load,
            child: ReorderableListView.builder(
              key: const ValueKey('favorit-list'),
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              onReorderItem: vm.reorder,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return _FavoritTile(
                  key: ValueKey('${row.tipe}:${row.kode}'),
                  row: row,
                  index: index,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _message(
    String text, {
    bool error = false,
    required Future<void> Function() onRetry,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Icon(
                  error
                      ? Icons.error_outline_rounded
                      : Icons.star_border_rounded,
                  size: 44,
                  color: error ? Colors.red.shade300 : const Color(0xFFC1C7D0),
                ),
              ),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: error ? Colors.red.shade700 : const Color(0xFF6B778C),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoritTile extends StatelessWidget {
  const _FavoritTile({super.key, required this.row, required this.index});

  final FavoritRow row;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.read<FavoritViewModel>();
    final meta = _resolveMeta(row);
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(Icons.star_rounded, color: Colors.amber.shade700),
        onTap: vm.busy ? null : () => _open(context, row),
        title: Text(
          meta.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF172B4D),
          ),
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: meta.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.secondary,
                ),
              ),
              if (row.komentar.trim().isNotEmpty)
                TextSpan(
                  text: '\n${row.komentar}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF6B778C),
                  ),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('favorit-delete-${row.tipe}:${row.kode}'),
              tooltip: 'Hapus dari favorit',
              visualDensity: VisualDensity.compact,
              onPressed: vm.busy ? null : () => _confirmRemove(context, vm),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.red.shade700,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Tooltip(
                message: 'Geser untuk mengubah urutan',
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: Color(0xFF6B778C),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _FavoritMeta _resolveMeta(FavoritRow row) {
    if (row.tipe == 'menu') {
      final item = PpsMenuCatalog.forRoute(row.kode);
      if (item != null) {
        return _FavoritMeta(item.title, 'Menu');
      }
      return _FavoritMeta(_fallbackTitle(row.kode), 'Menu');
    }
    final item = _findReport(row.kode);
    if (item != null) {
      return _FavoritMeta(item.title, 'Laporan');
    }
    return _FavoritMeta(_fallbackTitle(row.kode), 'Laporan');
  }

  String _fallbackTitle(String kode) {
    final clean = kode.split('/').where((p) => p.isNotEmpty).toList();
    if (clean.isEmpty) return kode;
    final last = clean.last;
    return last[0].toUpperCase() + last.substring(1).replaceAll('-', ' ');
  }

  Future<void> _confirmRemove(BuildContext context, FavoritViewModel vm) async {
    final meta = _resolveMeta(row);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Favorit'),
        content: Text('Hapus ${meta.title} dari favorit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      await vm.removeItem(row);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus favorit: ${apiErrorMessage(e)}'),
        ),
      );
    }
  }

  Future<void> _open(BuildContext context, FavoritRow row) async {
    if (row.tipe == 'menu') {
      final route = row.kode;
      // Verifikasi route masih terdaftar di katalog; bila tidak, beri tahu.
      if (PpsMenuCatalog.forRoute(route) != null) {
        AppShell.currentRoute.value = route;
        AppShell.shellNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          route,
          (route) => false,
        );
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu ini belum tersedia di tablet.')),
      );
      return;
    }
    final item = _findReport(row.kode);
    if (item == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan ini belum tersedia di tablet.')),
      );
      return;
    }
    await openReportItem(context, item);
  }

  ReportItem? _findReport(String kode) {
    for (final item in reportCatalogFlat) {
      final current = item.path ?? item.route ?? item.title;
      if (current == kode || item.title == kode) return item;
    }
    return null;
  }
}

class _FavoritMeta {
  const _FavoritMeta(this.title, this.subtitle);

  final String title;
  final String subtitle;
}
