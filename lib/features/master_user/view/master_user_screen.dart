import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/interactive_popover.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/services/user_session_storage.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/master_user_models.dart';
import '../repository/master_user_repository.dart';
import '../view_model/master_user_view_model.dart';
import '../widgets/user_row_popover.dart';
import 'master_user_form_dialog.dart';

class MasterUserScreen extends StatefulWidget {
  const MasterUserScreen({super.key, this.repository});

  final MasterUserRepository? repository;

  @override
  State<MasterUserScreen> createState() => _MasterUserScreenState();
}

class _MasterUserScreenState extends State<MasterUserScreen> {
  late final MasterUserViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _horizontal = ScrollController();
  final InteractivePopover _popover = InteractivePopover();
  bool _searchFocused = false;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    vm = MasterUserViewModel(
      widget.repository ?? MasterUserRepository(api: context.read<ApiClient>()),
    );
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.read<PermissionViewModel>().can('datamasteruser:read')) {
        return;
      }
      _currentUserId = await UserSessionStorage.getIdUsername();
      await vm.load();
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

  bool _can(String action) =>
      context.read<PermissionViewModel>().can('datamasteruser:$action');

  Future<void> _openForm({MasterUser? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;

    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: MasterUserFormDialog(
          repository: vm.repository,
          viewModel: vm,
          groups: vm.groups,
          edit: edit,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'User baru berhasil disimpan: $saved'
              : 'Data user berhasil diubah: $saved',
        ),
      ),
    );
  }

  Future<void> _onItemLongPress(MasterUser user, Offset globalPosition) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(240.0, 820.0).toDouble();

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: UserRowPopover(
        user: user,
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onClose: () => _popover.hide(),
        onEdit: () => _openForm(edit: user),
        onDelete: () => _confirmDelete(user),
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

  Future<void> _confirmDelete(MasterUser user) async {
    if (!_can('delete')) return;
    if (_currentUserId != null && user.id == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat menghapus akun yang sedang dipakai'),
        ),
      );
      return;
    }

    final nama = user.fullName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus User',
        message:
            'Hapus user ${user.username}${nama.isEmpty ? '' : ' ($nama)'}? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await vm.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${user.username} berhasil dihapus')),
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
    if (!context.watch<PermissionViewModel>().can('datamasteruser:read')) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke menu User.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<MasterUserViewModel>(
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
                    '${vm.items.length} dari ${vm.totalCount} user · Ketuk lama baris untuk opsi',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B778C)),
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
                        hintText: 'Cari username, nama, NIK, role…',
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
          if (_can('create')) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('User Baru'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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

  Widget _buildTable(MasterUserViewModel vm) {
    if (vm.items.isEmpty && !vm.loading && vm.error.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: Color(0xFFC1C7D0),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada user terdaftar',
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
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Tambah User Pertama'),
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
            width: constraints.maxWidth < 1180 ? 1180 : constraints.maxWidth,
            height: constraints.maxHeight,
            child: AtlasDataTable<MasterUser>(
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

  List<AtlasTableColumn<MasterUser>> get _columns => [
    AtlasTableColumn(
      title: 'ID',
      width: 90,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, u, r) => Text(
        '${u.id}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'NAMA DEPAN',
      width: 180,
      cellBuilder: (_, u, r) => Text(
        u.fName.isEmpty ? '—' : u.fName,
        style: TextStyle(fontSize: 14, color: r.textColor),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'NAMA BELAKANG',
      width: 200,
      cellBuilder: (_, u, r) => Text(
        u.lName.isEmpty ? '—' : u.lName,
        style: TextStyle(fontSize: 14, color: r.textColor),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'USERNAME',
      width: 170,
      cellBuilder: (_, u, r) => Text(
        u.username,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'EMPLOYEE ID',
      width: 130,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, u, r) => Text(
        u.employeeId?.toString() ?? '—',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'NIK',
      width: 120,
      cellBuilder: (_, u, r) => Text(
        u.nik.isEmpty ? '—' : u.nik,
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'GROUP',
      flex: 1,
      cellBuilder: (_, u, r) {
        if (u.groupNames.isEmpty) {
          return Text('—', style: TextStyle(color: Colors.grey.shade500));
        }
        final visible = u.groupNames.length > 6
            ? u.groupNames.take(5).toList()
            : u.groupNames;
        final hidden = u.groupNames.length - visible.length;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final group in visible)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C66E4),
                  ),
                ),
              ),
            if (hidden > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$hidden',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF44546F),
                  ),
                ),
              ),
          ],
        );
      },
    ),
    AtlasTableColumn(
      title: 'STATUS',
      width: 130,
      showDivider: false,
      cellBuilder: (_, u, r) => Align(
        alignment: Alignment.centerLeft,
        child: _StatusPill(user: u),
      ),
    ),
  ];
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.user});

  final MasterUser user;

  @override
  Widget build(BuildContext context) {
    final active = user.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active
              ? const Color(0xFF15803D)
              : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}
