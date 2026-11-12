import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/interactive_popover.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/role_models.dart';
import '../repository/role_repository.dart';
import '../view_model/role_view_model.dart';
import '../widgets/role_row_popover.dart';
import 'role_form_dialog.dart';
import 'role_permission_dialog.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key, this.repository});

  final RoleRepository? repository;

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  late final RoleViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _horizontal = ScrollController();
  final InteractivePopover _popover = InteractivePopover();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    vm = RoleViewModel(
      widget.repository ?? RoleRepository(api: context.read<ApiClient>()),
    );
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<PermissionViewModel>().can(
        'datamasterpermissiongroup:read',
      )) {
        return;
      }
      vm.load();
    });
  }

  @override
  void dispose() {
    _popover.dispose();
    _searchFocus.dispose();
    _horizontal.dispose();
    _search.dispose();
    vm.dispose();
    super.dispose();
  }

  bool _can(String action) => context
      .read<PermissionViewModel>()
      .can('datamasterpermissiongroup:$action');

  Future<void> _openForm({RoleGroup? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;

    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: RoleFormDialog(
          repository: vm.repository,
          viewModel: vm,
          permissions: vm.permissions,
          edit: edit,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Role baru berhasil disimpan: $saved'
              : 'Role berhasil diubah: $saved',
        ),
      ),
    );
  }

  Future<void> _openPermissionManager() async {
    await showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: RolePermissionDialog(
          viewModel: vm,
          canCreate: _can('create'),
          canUpdate: _can('update'),
          canDelete: _can('delete'),
        ),
      ),
    );
  }

  void _onItemLongPress(RoleGroup role, Offset globalPosition) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(240.0, 820.0).toDouble();

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: RoleRowPopover(
        role: role,
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onClose: () => _popover.hide(),
        onEdit: () => _openForm(edit: role),
        onDelete: () => _confirmDelete(role),
      ),
      preferAbove: true,
      verticalGap: 8,
      maxHeight: adaptiveMaxHeight,
      backdropOpacity: 0.06,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      startScale: 0.94,
    );
  }

  Future<void> _confirmDelete(RoleGroup role) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Role',
        message:
            'Hapus role ${role.name}? Role yang masih dipakai user tidak dapat dihapus.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await vm.deleteRole(role.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role ${role.name} berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<PermissionViewModel>().can(
      'datamasterpermissiongroup:read',
    )) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke menu Role.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<RoleViewModel>(
          builder: (context, vm, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildTable(vm),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${vm.items.length} dari ${vm.totalCount} role · Ketuk lama baris untuk opsi',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B778C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchFocused
                      ? const Color(0xFF1565C0).withValues(alpha: .5)
                      : Colors.grey.shade300,
                  width: _searchFocused ? 1.6 : 1,
                ),
                boxShadow: _searchFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: .12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Icon(Icons.search, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      focusNode: _searchFocus,
                      controller: _search,
                      onChanged: (v) {
                        setState(() {});
                        vm.setSearch(v);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari ID atau nama role…',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_search.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                        vm.setSearch('');
                        _searchFocus.requestFocus();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _openPermissionManager,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0D47A1),
              side: const BorderSide(color: Color(0xFF0D47A1)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.vpn_key_outlined, size: 18),
            label: const Text('Kelola Permission'),
          ),
          if (_can('create')) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Role Baru'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTable(RoleViewModel vm) {
    if (vm.items.isEmpty && !vm.loading && vm.error.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
              color: Color(0xFFC1C7D0),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada role terdaftar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172B4D),
              ),
            ),
            if (_can('create')) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Role Pertama'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 780 ? 780 : constraints.maxWidth,
            height: constraints.maxHeight,
            child: AtlasDataTable<RoleGroup>(
              columns: _columns,
              items: vm.items,
              isLoading: vm.loading,
              errorMessage: vm.items.isEmpty ? vm.error : '',
              errorBuilder: (message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 36),
                      const SizedBox(height: 8),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: vm.refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              onRowLongPress: _onItemLongPress,
            ),
          ),
        ),
      ),
    );
  }

  List<AtlasTableColumn<RoleGroup>> get _columns => [
    AtlasTableColumn(
      title: 'ID',
      width: 90,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, role, r) => Text(
        '${role.id}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'NAMA ROLE',
      flex: 2,
      cellBuilder: (_, role, r) => Text(
        role.name,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'PERMISSION DIIZINKAN',
      flex: 3,
      cellBuilder: (_, role, r) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: role.allowRatio,
                backgroundColor: const Color(0xFFE9ECEF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00897B)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${role.totalAllow} / ${role.totalPermission}',
            style: TextStyle(fontSize: 13, color: r.textColor),
          ),
        ],
      ),
    ),
  ];
}
