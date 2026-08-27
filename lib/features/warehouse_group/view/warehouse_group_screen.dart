import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';

import '../model/warehouse_group_model.dart';
import '../repository/warehouse_group_repository.dart';
import '../view_model/warehouse_group_view_model.dart';
import 'widgets/warehouse_group_form_dialog.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kRadius = 12.0;

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_kRadius),
  border: Border.all(color: _kBorder),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ],
);

class WarehouseGroupScreen extends StatelessWidget {
  const WarehouseGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WarehouseGroupViewModel(
        repository: WarehouseGroupRepository(api: ApiClient()),
      )..load(),
      child: const _WarehouseGroupView(),
    );
  }
}

class _WarehouseGroupView extends StatelessWidget {
  const _WarehouseGroupView();

  Future<void> _openForm(BuildContext context, {WarehouseGroup? existing}) async {
    final vm = context.read<WarehouseGroupViewModel>();
    final result = await showDialog<WarehouseGroupFormResult>(
      context: context,
      builder: (_) => WarehouseGroupFormDialog(existing: existing),
    );
    if (result == null) return;

    final err = await vm.saveGroup(
      id: existing?.id,
      namaGroup: result.namaGroup,
      keterangan: result.keterangan,
      aktif: result.aktif,
    );
    if (context.mounted) _toast(context, err ?? 'Group tersimpan', isError: err != null);
  }

  Future<void> _confirmDelete(BuildContext context, WarehouseGroup g) async {
    final vm = context.read<WarehouseGroupViewModel>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus group?'),
        content: Text(
          'Group "${g.namaGroup}" akan dihapus permanen.'
          '${g.warehouseCount > 0 ? '\n\nSaat ini masih dipakai ${g.warehouseCount} warehouse — '
                'lepas dulu semua warehouse dari group ini.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final err = await vm.deleteGroup(g.id);
    if (context.mounted) {
      _toast(context, err ?? 'Group dihapus', isError: err != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WarehouseGroupViewModel>();

    return Scaffold(
      backgroundColor: _kSurface,
      body: Column(
        children: [
          if (vm.busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : vm.error.isNotEmpty
                  ? _ErrorState(message: vm.error, onRetry: vm.load)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 380,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _GroupListPanel(
                                  vm: vm,
                                  onEdit: (g) =>
                                      _openForm(context, existing: g),
                                  onDelete: (g) => _confirmDelete(context, g),
                                ),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: FloatingActionButton.extended(
                                  heroTag: 'warehouse_group_create_fab',
                                  onPressed: () => _openForm(context),
                                  backgroundColor: _kPrimary,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Group'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _WarehouseAssignPanel(vm: vm)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Left: daftar group ─────────────────────────────────────────────────────

class _GroupListPanel extends StatelessWidget {
  final WarehouseGroupViewModel vm;
  final void Function(WarehouseGroup) onEdit;
  final void Function(WarehouseGroup) onDelete;

  const _GroupListPanel({
    required this.vm,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.workspaces_outline,
            title: 'Group Warehouse (Site)',
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: vm.groups.isEmpty
                ? const _EmptyHint(
                    text: 'Belum ada group.\nTambahkan lewat tombol di bawah.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                    itemCount: vm.groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final g = vm.groups[i];
                      return _GroupTile(
                        group: g,
                        onEdit: () => onEdit(g),
                        onDelete: () => onDelete(g),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final WarehouseGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupTile({
    required this.group,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: group.aktif ? Colors.white : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.namaGroup,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!group.aktif) ...[
                      const SizedBox(width: 6),
                      _Chip(text: 'Non-aktif', color: Colors.grey),
                    ],
                  ],
                ),
                if ((group.keterangan ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      group.keterangan!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _Chip(
                    text: '${group.warehouseCount} warehouse',
                    color: group.warehouseCount > 0 ? _kPrimary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Right: assign warehouse → group ───────────────────────────────────────

class _WarehouseAssignPanel extends StatelessWidget {
  final WarehouseGroupViewModel vm;
  const _WarehouseAssignPanel({required this.vm});

  Future<void> _assign(
    BuildContext context,
    WarehouseGroupAssignment w,
    int? idGroup,
  ) async {
    if (w.idWarehouseGroup == idGroup) return;
    final err = await vm.assignWarehouse(
      idWarehouse: w.idWarehouse,
      idWarehouseGroup: idGroup,
    );
    if (context.mounted && err != null) _toast(context, err, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final rows = vm.warehousesSorted;
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            icon: Icons.warehouse_outlined,
            title: 'Warehouse → Group',
            subtitle:
                'Warehouse dalam group yang sama boleh pindah label tanpa Goods Transfer',
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: rows.isEmpty
                ? const _EmptyHint(text: 'Tidak ada data warehouse.')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final w = rows[i];
                      return _WarehouseRow(
                        warehouse: w,
                        groups: vm.activeGroups,
                        onChanged: (idGroup) => _assign(context, w, idGroup),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseRow extends StatelessWidget {
  final WarehouseGroupAssignment warehouse;
  final List<WarehouseGroup> groups;
  final ValueChanged<int?> onChanged;

  const _WarehouseRow({
    required this.warehouse,
    required this.groups,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Kalau warehouse sudah terikat ke group non-aktif, tetap tampilkan opsinya
    // supaya tidak "hilang" dari dropdown.
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('— Tanpa group —'),
      ),
      ...groups.map(
        (g) => DropdownMenuItem<int?>(value: g.id, child: Text(g.namaGroup)),
      ),
      if (warehouse.idWarehouseGroup != null &&
          !groups.any((g) => g.id == warehouse.idWarehouseGroup))
        DropdownMenuItem<int?>(
          value: warehouse.idWarehouseGroup,
          child: Text('${warehouse.namaGroup ?? 'Group'} (non-aktif)'),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    warehouse.namaWarehouse.isEmpty
                        ? 'WH #${warehouse.idWarehouse}'
                        : warehouse.namaWarehouse,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!warehouse.enable) ...[
                  const SizedBox(width: 6),
                  _Chip(text: 'disabled', color: Colors.grey),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              initialValue: warehouse.idWarehouseGroup,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small shared bits ─────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _PanelHeader({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _kPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black45, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 36),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
