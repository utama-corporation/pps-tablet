import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/pps_menu_catalog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/view/app_shell.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../../production/shared/widgets/production_panel_decoration.dart';
import '../model/my_work.dart';
import '../repository/my_work_repository.dart';
import '../view_model/my_work_view_model.dart';

/// Workspace & Analytics > My Work: antrian pekerjaan tertunda milik user,
/// pola sama dengan My Work MCS (kotak antrian, daftar, panel detail).
class MyWorkScreen extends StatefulWidget {
  final MyWorkRepository? repository;

  /// Membuka route tujuan di shell; default = ganti layar di navigator shell.
  final void Function(String route, String title)? onOpenRoute;

  /// Cek izin route; default = katalog menu + izin user.
  final bool Function(String route)? canOpenRoute;

  const MyWorkScreen({
    super.key,
    this.repository,
    this.onOpenRoute,
    this.canOpenRoute,
  });

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  late final MyWorkViewModel _vm = MyWorkViewModel(
    repository: widget.repository ?? MyWorkRepository(api: ApiClient()),
  );
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    _search.dispose();
    super.dispose();
  }

  static void _openInShell(String route, String title) {
    AppShell.breadcrumb.value = [BreadcrumbSegment(title)];
    AppShell.currentRoute.value = route;
    AppShell.shellNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      route,
      (_) => false,
    );
  }

  bool _canOpen(String route) {
    final check = widget.canOpenRoute;
    if (check != null) return check(route);
    try {
      final perms = context.read<PermissionViewModel>();
      return PpsMenuCatalog.canOpenRoute(route, perms.can);
    } on ProviderNotFoundException {
      return false;
    }
  }

  /// (route, judul menu) untuk item; null bila tidak ada atau tidak berhak.
  (String, String)? _target(MyWorkItem item) {
    final route = myWorkRouteFor(item.module);
    if (route == null || !_canOpen(route)) return null;
    final title = PpsMenuCatalog.forRoute(route)?.title ?? item.title;
    return (route, title);
  }

  void _open((String, String) target) =>
      (widget.onOpenRoute ?? _openInShell)(target.$1, target.$2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            final wide = MediaQuery.sizeOf(context).width >= 900;
            return RefreshIndicator(
              onRefresh: _vm.refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildQueues(),
                  const SizedBox(height: 16),
                  _buildSearch(),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildList(wide: true)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildDetail()),
                      ],
                    )
                  else
                    _buildList(wide: false),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------- antrian ----------------

  Widget _buildQueues() {
    final summary = _vm.summary;
    if (summary == null) {
      if (_vm.summaryError.isNotEmpty) {
        return _Panel(
          child: _Message(
            icon: Icons.cloud_off_outlined,
            title: 'My Work belum dapat dimuat',
            body: _vm.summaryError,
            action: TextButton.icon(
              onPressed: _vm.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (summary.queues.isEmpty) {
      return const _Panel(
        child: _Message(
          icon: Icons.inbox_outlined,
          title: 'Belum ada antrian untuk Anda',
          body: 'My Work menampilkan pekerjaan dari modul yang Anda punya aksesnya.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final q in summary.queues)
              _QueueTile(
                queue: q,
                selected: q.key == _vm.selectedKey,
                onTap: () => _vm.selectQueue(q.key),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${summary.total} total pekerjaan tertunda di seluruh kategori.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ---------------- pencarian ----------------

  Widget _buildSearch() {
    return _Panel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('my-work-search'),
              controller: _search,
              onChanged: _vm.setSearch,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Cari nomor dokumen, nomor label, atau keterangan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Muat ulang',
            onPressed: _vm.loadingSummary ? null : _vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // ---------------- daftar ----------------

  Widget _buildList({required bool wide}) {
    final queue = _vm.selectedQueue;
    if (queue == null) return const SizedBox.shrink();
    final data = _vm.items;
    Widget body;
    if (data == null && _vm.loadingItems) {
      body = const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_vm.itemsError.isNotEmpty) {
      body = _Message(
        icon: Icons.error_outline,
        title: 'Daftar belum dapat dimuat',
        body: _vm.itemsError,
        action: TextButton.icon(
          onPressed: _vm.loadItems,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba lagi'),
        ),
      );
    } else if (data == null || data.items.isEmpty) {
      body = _Message(
        icon: Icons.inbox_outlined,
        title: 'Tidak ada pekerjaan',
        body: _vm.search.trim().isEmpty
            ? 'Tidak ada pekerjaan di antrian "${queue.label}".'
            : 'Tidak ada hasil untuk "${_vm.search.trim()}".',
      );
    } else {
      body = Column(
        children: [
          for (final item in data.items)
            _ItemTile(
              item: item,
              selected: item.id == _vm.selectedItem?.id,
              onTap: () {
                _vm.selectItem(item);
                if (!wide) _showDetailSheet(item);
              },
            ),
          if (data.total > data.items.length)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Menampilkan ${data.items.length} dari ${data.total}. Persempit dengan pencarian.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
        ],
      );
    }
    return _Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    queue.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_vm.loadingItems && data != null)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          body,
        ],
      ),
    );
  }

  // ---------------- detail ----------------

  Widget _buildDetail() {
    final item = _vm.selectedItem;
    return _Panel(
      child: item == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Pilih salah satu pekerjaan di daftar untuk lihat detailnya.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          : _ItemDetail(
              item: item,
              target: _target(item),
              onOpen: _open,
            ),
    );
  }

  void _showDetailSheet(MyWorkItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: _ItemDetail(
          item: item,
          target: _target(item),
          onOpen: (t) {
            Navigator.of(sheet).pop();
            _open(t);
          },
        ),
      ),
    );
  }
}

// ---------------- widget kecil ----------------

IconData _queueIcon(String key) => switch (key) {
  'produksi_pending' => Icons.pending_actions_outlined,
  'label_unprinted' => Icons.print_outlined,
  'stock_opname' => Icons.fact_check_outlined,
  'spk_open' => Icons.assignment_outlined,
  _ => Icons.checklist_rounded,
};

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: productionPanelDecoration(),
    child: child,
  );
}

class _QueueTile extends StatelessWidget {
  final MyWorkQueue queue;
  final bool selected;
  final VoidCallback onTap;
  const _QueueTile({
    required this.queue,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = queue.count;
    final failed = count == null;
    final busy = (count ?? 0) > 0;
    final accent = failed
        ? const Color(0xFFB91C1C)
        : busy
        ? const Color(0xFFB45309)
        : const Color(0xFF64748B);
    return SizedBox(
      width: 240,
      child: Material(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('my-work-queue-${queue.key}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? kProductionPrimary : const Color(0xFFE2E8F0),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(_queueIcon(queue.key), size: 20, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    queue.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tooltip(
                  message: failed ? queue.error : '',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      failed ? '!' : '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
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

class _ItemTile extends StatelessWidget {
  final MyWorkItem item;
  final bool selected;
  final VoidCallback onTap;
  const _ItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
      child: InkWell(
        key: ValueKey('my-work-item-${item.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.no,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [item.title, item.subtitle]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                item.date,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemDetail extends StatelessWidget {
  final MyWorkItem item;
  final (String, String)? target;
  final void Function((String, String) target) onOpen;
  const _ItemDetail({
    required this.item,
    required this.target,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final t = target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        SelectableText(
          item.no,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        for (final (label, value) in item.meta)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(value, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (t != null)
              FilledButton.icon(
                key: const ValueKey('my-work-open'),
                onPressed: () => onOpen(t),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('Buka ${t.$2}'),
              ),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.no));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text('${item.no} disalin')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Salin nomor'),
            ),
          ],
        ),
      ],
    );
  }
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
