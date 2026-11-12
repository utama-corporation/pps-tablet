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
import '../../mesin/model/mesin_model.dart';
import '../model/bagian_mesin.dart';
import '../repository/master_mesin_repository.dart';
import '../view_model/master_mesin_view_model.dart';
import 'mesin_form_dialog.dart';

class MasterMesinScreen extends StatefulWidget {
  const MasterMesinScreen({super.key, this.repository});

  final MasterMesinRepository? repository;

  @override
  State<MasterMesinScreen> createState() => _MasterMesinScreenState();
}

class _MasterMesinScreenState extends State<MasterMesinScreen> {
  late final MasterMesinViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _horizontal = ScrollController();
  final InteractivePopover _popover = InteractivePopover();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    vm = MasterMesinViewModel(
      widget.repository ??
          MasterMesinRepository(api: context.read<ApiClient>()),
    );
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<PermissionViewModel>().can('datamastermesin:read')) {
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
      context.read<PermissionViewModel>().can('datamastermesin:$action');

  Future<void> _openForm({MstMesin? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: MesinFormDialog(viewModel: vm, edit: edit),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Mesin baru berhasil disimpan: $saved'
              : 'Data mesin berhasil diubah: $saved',
        ),
      ),
    );
  }

  void _onRowLongPress(MstMesin mesin, Offset position) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(220.0, 560.0).toDouble();
    _popover.show(
      context: context,
      globalPosition: position,
      child: RowActionPopover(
        title: mesin.enable
            ? mesin.namaMesin
            : '${mesin.namaMesin} (non-aktif)',
        subtitle:
            'ID Mesin: ${mesin.idMesin} · ${mesin.bagian.isNotEmpty ? mesin.bagian : bagianMesinLabel(mesin.idBagianMesin)}',
        icon: Icons.precision_manufacturing_outlined,
        accent: const Color(0xFF0E7490),
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onEdit: () => _openForm(edit: mesin),
        onDelete: () => _confirmDelete(mesin),
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

  Future<void> _confirmDelete(MstMesin mesin) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Mesin',
        message:
            'Hapus mesin ${mesin.namaMesin}? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.delete(mesin.idMesin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesin ${mesin.namaMesin} berhasil dihapus'),
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
    if (!context.watch<PermissionViewModel>().can('datamastermesin:read')) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke Master Mesin Produksi.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<MasterMesinViewModel>(
          builder: (context, vm, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActionBar(vm),
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
                    '${vm.items.length} dari ${vm.totalCount} mesin · Ketuk lama baris untuk opsi',
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

  Widget _buildActionBar(MasterMesinViewModel vm) {
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
                      key: const ValueKey('mesin-search'),
                      focusNode: _searchFocus,
                      controller: _search,
                      onChanged: (v) {
                        setState(() {});
                        vm.setQuery(v);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari mesin…',
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
          const SizedBox(width: 12),
          _buildBagianFilter(vm),
          if (_can('create')) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('mesin-add'),
              onPressed: _openForm,
              icon: const Icon(Icons.precision_manufacturing_outlined),
              label: const Text('Tambah Mesin'),
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

  Widget _buildBagianFilter(MasterMesinViewModel vm) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          key: const ValueKey('mesin-bagian-filter'),
          value: vm.bagianFilter,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.filter_list_rounded, size: 18),
          hint: const Text('Semua Bagian'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Semua Bagian'),
            ),
            for (final b in masterBagianMesin)
              DropdownMenuItem<int?>(value: b.id, child: Text(b.label)),
          ],
          onChanged: vm.setBagianFilter,
        ),
      ),
    );
  }

  Widget _buildTable(MasterMesinViewModel vm) {
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
              Icons.precision_manufacturing_outlined,
              size: 56,
              color: Color(0xFFC1C7D0),
            ),
            const SizedBox(height: 12),
            const Text(
              'Belum ada mesin terdaftar',
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
                label: const Text('Tambah Mesin Pertama'),
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
        final width = constraints.maxWidth < 900 ? 900.0 : constraints.maxWidth;
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
                child: AtlasDataTable<MstMesin>(
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

  static String _fmtNum(num? v) {
    if (v == null) return '—';
    return v % 1 == 0 ? '${v.toInt()}' : v.toString();
  }

  List<AtlasTableColumn<MstMesin>> get _columns => [
    AtlasTableColumn(
      title: 'ID',
      width: 80,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, m, r) => Text(
        '${m.idMesin}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'NAMA MESIN',
      flex: 1,
      cellBuilder: (_, m, r) => Text(
        m.namaMesin.isEmpty ? '—' : m.namaMesin,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'BAGIAN',
      width: 150,
      cellBuilder: (_, m, r) => Text(
        m.bagian.isNotEmpty ? m.bagian : bagianMesinLabel(m.idBagianMesin),
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'KAPASITAS',
      width: 130,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, m, r) => Text(
        _fmtNum(m.kapasitas),
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'UOM',
      width: 90,
      headerAlign: TextAlign.center,
      cellAlignment: Alignment.center,
      cellBuilder: (_, m, r) => Text(
        m.idUom == null ? '—' : '${m.idUom}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'STATUS',
      width: 130,
      showDivider: false,
      cellBuilder: (_, m, r) => Align(
        alignment: Alignment.centerLeft,
        child: _SmallPill(
          label: m.enable ? 'Aktif' : 'Nonaktif',
          fg: m.enable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          bg: m.enable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        ),
      ),
    ),
  ];
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
