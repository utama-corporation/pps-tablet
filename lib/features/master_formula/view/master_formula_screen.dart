import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/interactive_popover.dart';
import '../../../common/widgets/row_action_popover.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/master_formula_models.dart';
import '../repository/master_formula_repository.dart';
import '../view_model/master_formula_view_model.dart';
import 'formula_form_dialog.dart';

class MasterFormulaScreen extends StatefulWidget {
  const MasterFormulaScreen({super.key, this.repository});

  final MasterFormulaRepository? repository;

  @override
  State<MasterFormulaScreen> createState() => _MasterFormulaScreenState();
}

class _MasterFormulaScreenState extends State<MasterFormulaScreen> {
  late final MasterFormulaViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _horizontal = ScrollController();
  final InteractivePopover _popover = InteractivePopover();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    vm = MasterFormulaViewModel(
      widget.repository ??
          MasterFormulaRepository(api: context.read<ApiClient>()),
    );
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<PermissionViewModel>().can('masterformulaproduksi:read')) {
        unawaited(vm.load());
      }
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
      context.read<PermissionViewModel>().can('masterformulaproduksi:$action');

  Future<void> _openForm({FormulaListRow? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: FormulaFormDialog(viewModel: vm, edit: edit),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Formula berhasil disimpan: $saved'
              : 'Formula berhasil diubah: $saved',
        ),
      ),
    );
  }

  void _onRowLongPress(FormulaListRow row, Offset position) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(220.0, 560.0).toDouble();
    _popover.show(
      context: context,
      globalPosition: position,
      child: RowActionPopover(
        title: row.displayName,
        subtitle: 'Formula #${row.idFormula} · Kategori: ${row.mainKategori}',
        icon: Icons.science_outlined,
        accent: const Color(0xFF0E7490),
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onEdit: () => _openForm(edit: row),
        onDelete: () => _confirmDelete(row),
        onClose: _popover.hide,
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

  Future<void> _confirmDelete(FormulaListRow row) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Formula',
        message:
            'Hapus formula ${row.displayName}? Seluruh baris Input dan Secondary Output ikut terhapus.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.delete(row.idFormula);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formula ${row.displayName} berhasil dihapus'),
        ),
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
    if (!context.watch<PermissionViewModel>().can('masterformulaproduksi:read')) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke Master Formula.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<MasterFormulaViewModel>(
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
                    '${vm.items.length} dari ${vm.totalCount} formula · Ketuk lama baris untuk opsi',
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
                      key: const ValueKey('formula-search'),
                      focusNode: _searchFocus,
                      controller: _search,
                      onChanged: (v) {
                        setState(() {});
                        vm.setQuery(v);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari formula…',
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
                        vm.setQuery('');
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
              key: const ValueKey('formula-add'),
              onPressed: _openForm,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Tambah Formula'),
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

  Widget _buildTable(MasterFormulaViewModel vm) {
    final items = vm.items;
    if (items.isEmpty && !vm.loading && vm.error.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.science_outlined,
              size: 56,
              color: Color(0xFFC1C7D0),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada formula terdaftar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172B4D),
              ),
            ),
            if (_can('create')) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Formula Pertama'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: RefreshIndicator(
                onRefresh: vm.load,
                child: AtlasDataTable<FormulaListRow>(
                  columns: _columns,
                  items: items,
                  isLoading: vm.loading,
                  errorMessage: items.isEmpty ? vm.error : '',
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
                            onPressed: vm.load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onRowLongPress: _onRowLongPress,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<AtlasTableColumn<FormulaListRow>> get _columns => [
    AtlasTableColumn(
      title: 'KATEGORI',
      width: 180,
      cellBuilder: (_, row, r) => Text(
        row.mainKategori.isEmpty ? '—' : row.mainKategori,
        style: TextStyle(fontSize: 13, color: r.textColor),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'OUTPUT UTAMA',
      flex: 3,
      cellBuilder: (_, row, r) => Text(
        row.mainOutputNama.isEmpty ? '—' : row.mainOutputNama,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'INPUT',
      width: 90,
      headerAlign: TextAlign.center,
      cellAlignment: Alignment.center,
      cellBuilder: (_, row, r) => Text(
        '${row.jumlahInput}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'SECONDARY',
      width: 110,
      headerAlign: TextAlign.center,
      cellAlignment: Alignment.center,
      cellBuilder: (_, row, r) => Text(
        '${row.jumlahSecondary}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'ID',
      width: 70,
      showDivider: false,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, row, r) => Text(
        '#${row.idFormula}',
        style: TextStyle(fontSize: 12, color: r.textColor),
      ),
    ),
  ];
}
