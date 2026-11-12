import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/interactive_popover.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../../../common/widgets/row_action_popover.dart';
import '../../operator/model/operator_model.dart';
import '../../regu/model/regu_model.dart';
import '../repository/master_operator_regu_repository.dart';
import '../view_model/master_operator_regu_view_model.dart';
import 'operator_form_dialog.dart';
import 'regu_form_dialog.dart';

class MasterOperatorReguScreen extends StatefulWidget {
  const MasterOperatorReguScreen({super.key, this.repository});

  final MasterOperatorReguRepository? repository;

  @override
  State<MasterOperatorReguScreen> createState() =>
      _MasterOperatorReguScreenState();
}

class _MasterOperatorReguScreenState extends State<MasterOperatorReguScreen>
    with SingleTickerProviderStateMixin {
  late final MasterOperatorReguViewModel vm;
  late final TabController _tabs;
  final TextEditingController _operatorSearch = TextEditingController();
  final TextEditingController _reguSearch = TextEditingController();
  final FocusNode _operatorFocus = FocusNode();
  final FocusNode _reguFocus = FocusNode();
  final ScrollController _operatorHorizontal = ScrollController();
  final ScrollController _reguHorizontal = ScrollController();
  final InteractivePopover _popover = InteractivePopover();
  bool _operatorSearchFocused = false;
  bool _reguSearchFocused = false;

  @override
  void initState() {
    super.initState();
    vm = MasterOperatorReguViewModel(
      widget.repository ??
          MasterOperatorReguRepository(api: context.read<ApiClient>()),
    );
    _tabs = TabController(length: 2, vsync: this);
    _operatorFocus.addListener(() {
      if (mounted) {
        setState(() => _operatorSearchFocused = _operatorFocus.hasFocus);
      }
    });
    _reguFocus.addListener(() {
      if (mounted) {
        setState(() => _reguSearchFocused = _reguFocus.hasFocus);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<PermissionViewModel>().can('datamasteroperator:read')) {
        unawaited(vm.load());
      }
    });
  }

  @override
  void dispose() {
    _popover.dispose();
    _tabs.dispose();
    _operatorFocus.dispose();
    _reguFocus.dispose();
    _operatorHorizontal.dispose();
    _reguHorizontal.dispose();
    _operatorSearch.dispose();
    _reguSearch.dispose();
    vm.dispose();
    super.dispose();
  }

  bool _can(String action) =>
      context.read<PermissionViewModel>().can('datamasteroperator:$action');

  Future<void> _openOperatorForm({MstOperator? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: OperatorFormDialog(viewModel: vm, edit: edit),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Operator baru berhasil disimpan: $saved'
              : 'Data operator berhasil diubah: $saved',
        ),
      ),
    );
  }

  Future<void> _openReguForm({MstRegu? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: ReguFormDialog(viewModel: vm, edit: edit),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Regu baru berhasil disimpan: $saved'
              : 'Data regu berhasil diubah: $saved',
        ),
      ),
    );
  }

  void _showActions({
    required Offset position,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(220.0, 560.0).toDouble();
    _popover.show(
      context: context,
      globalPosition: position,
      child: RowActionPopover(
        title: title,
        subtitle: subtitle,
        icon: icon,
        accent: accent,
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onEdit: onEdit,
        onDelete: onDelete,
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

  void _onOperatorLongPress(MstOperator op, Offset position) {
    _showActions(
      position: position,
      title: op.enable ? op.namaOperator : '${op.namaOperator} (non-aktif)',
      subtitle: 'ID Operator: ${op.idOperator}',
      icon: Icons.person_outline_rounded,
      accent: const Color(0xFF0C66E4),
      onEdit: () => _openOperatorForm(edit: op),
      onDelete: () => _confirmDeleteOperator(op),
    );
  }

  void _onReguLongPress(MstRegu regu, Offset position) {
    _showActions(
      position: position,
      title: regu.namaRegu,
      subtitle: 'ID Bagian: ${regu.idBagian}',
      icon: Icons.groups_outlined,
      accent: const Color(0xFF6D28D9),
      onEdit: () => _openReguForm(edit: regu),
      onDelete: () => _confirmDeleteRegu(regu),
    );
  }

  Future<void> _confirmDeleteOperator(MstOperator op) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Operator',
        message:
            'Hapus operator ${op.namaOperator}? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.deleteOperator(op.idOperator);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operator ${op.namaOperator} berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _confirmDeleteRegu(MstRegu regu) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Regu',
        message:
            'Hapus regu ${regu.namaRegu}? Tindakan ini tidak dapat dibatalkan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.deleteRegu(regu.idRegu);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regu ${regu.namaRegu} berhasil dihapus')),
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
    if (!context.watch<PermissionViewModel>().can('datamasteroperator:read')) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Anda tidak memiliki akses ke Master Operator & Regu.',
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<MasterOperatorReguViewModel>(
          builder: (context, vm, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _operatorTab(vm),
                    _reguTab(vm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDCDFE4))),
      ),
      child: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF0C66E4),
        unselectedLabelColor: const Color(0xFF6B778C),
        indicatorColor: const Color(0xFF0C66E4),
        indicatorWeight: 2.4,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(
            key: ValueKey('master-operator-regu-tab-operator'),
            icon: Icon(Icons.engineering_outlined, size: 18),
            text: 'Operator',
          ),
          Tab(
            key: ValueKey('master-operator-regu-tab-regu'),
            icon: Icon(Icons.groups_outlined, size: 18),
            text: 'Regu',
          ),
        ],
      ),
    );
  }

  Widget _searchBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool focused,
    required String hint,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
    required String clearKey,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused
              ? const Color(0xFF1565C0).withValues(alpha: .5)
              : Colors.grey.shade300,
          width: focused ? 1.6 : 1,
        ),
        boxShadow: focused
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
              focusNode: focusNode,
              controller: controller,
              onChanged: (v) => setState(() => onChanged(v)),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade500),
                isCollapsed: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            IconButton(
              key: ValueKey(clearKey),
              tooltip: 'Hapus pencarian',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                controller.clear();
                setState(onClear);
                focusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _actionBar({
    required Widget searchBox,
    required bool canCreate,
    required String addLabel,
    required IconData addIcon,
    required VoidCallback onAdd,
    required String addKey,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(child: searchBox),
          if (canCreate) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              key: ValueKey(addKey),
              onPressed: onAdd,
              icon: Icon(addIcon),
              label: Text(addLabel),
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

  Widget _errorState(String message, VoidCallback retry) => Center(
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
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  // ── Operator tab ─────────────────────────────────────────

  Widget _operatorTab(MasterOperatorReguViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionBar(
          searchBox: _searchBox(
            controller: _operatorSearch,
            focusNode: _operatorFocus,
            focused: _operatorSearchFocused,
            hint: 'Cari operator…',
            onChanged: vm.setOperatorQuery,
            onClear: () => vm.setOperatorQuery(''),
            clearKey: 'operator-search-clear',
          ),
          canCreate: _can('create'),
          addLabel: 'Tambah Operator',
          addIcon: Icons.person_add_alt_outlined,
          onAdd: _openOperatorForm,
          addKey: 'operator-add',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildOperatorTable(vm),
          ),
        ),
        _footer(
          '${vm.operators.length} dari ${vm.operatorTotal} operator · Ketuk lama baris untuk opsi',
        ),
      ],
    );
  }

  Widget _footer(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF6B778C)),
      ),
    ),
  );

  Widget _buildOperatorTable(MasterOperatorReguViewModel vm) {
    final items = vm.operators;
    if (items.isEmpty && !vm.operatorLoading && vm.operatorError.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.loadOperators,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: _emptyState(
            icon: Icons.engineering_outlined,
            title: 'Belum ada operator terdaftar',
            onAdd: _can('create') ? _openOperatorForm : null,
            addLabel: 'Tambah Operator Pertama',
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 880 ? 880.0 : constraints.maxWidth;
        return Scrollbar(
          controller: _operatorHorizontal,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _operatorHorizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: RefreshIndicator(
                onRefresh: vm.loadOperators,
                child: AtlasDataTable<MstOperator>(
                  columns: _operatorColumns,
                  items: items,
                  isLoading: vm.operatorLoading,
                  errorMessage: items.isEmpty ? vm.operatorError : '',
                  errorBuilder: (message) =>
                      _errorState(message, vm.loadOperators),
                  onRowLongPress: _onOperatorLongPress,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<AtlasTableColumn<MstOperator>> get _operatorColumns => [
    AtlasTableColumn(
      title: 'ID',
      width: 80,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, o, r) => Text(
        '${o.idOperator}',
        style: TextStyle(fontSize: 14, color: r.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'NAMA OPERATOR',
      flex: 1,
      cellBuilder: (_, o, r) => Text(
        o.namaOperator.isEmpty ? '—' : o.namaOperator,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: r.isSelected ? const Color(0xFF0C66E4) : const Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'BAGIAN',
      width: 150,
      cellBuilder: (_, o, r) => Text(
        o.bagianLabel,
        style: TextStyle(fontSize: 13, color: r.textColor),
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
    AtlasTableColumn(
      title: 'STATUS',
      width: 150,
      showDivider: false,
      cellBuilder: (_, o, r) => Align(
        alignment: Alignment.centerLeft,
        child: _SmallPill(
          label: o.enable ? 'Aktif' : 'Nonaktif',
          fg: o.enable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          bg: o.enable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        ),
      ),
    ),
  ];

  // ── Regu tab ─────────────────────────────────────────────

  Widget _reguTab(MasterOperatorReguViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _actionBar(
          searchBox: _searchBox(
            controller: _reguSearch,
            focusNode: _reguFocus,
            focused: _reguSearchFocused,
            hint: 'Cari regu…',
            onChanged: vm.setReguQuery,
            onClear: () => vm.setReguQuery(''),
            clearKey: 'regu-search-clear',
          ),
          canCreate: _can('create'),
          addLabel: 'Tambah Regu',
          addIcon: Icons.group_add_outlined,
          onAdd: _openReguForm,
          addKey: 'regu-add',
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildReguTable(vm),
          ),
        ),
        _footer(
          '${vm.regus.length} dari ${vm.reguTotal} regu · Ketuk lama baris untuk opsi',
        ),
      ],
    );
  }

  Widget _buildReguTable(MasterOperatorReguViewModel vm) {
    final items = vm.regus;
    if (items.isEmpty && !vm.reguLoading && vm.reguError.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.loadRegu,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: _emptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada regu terdaftar',
            onAdd: _can('create') ? _openReguForm : null,
            addLabel: 'Tambah Regu Pertama',
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 900 ? 900.0 : constraints.maxWidth;
        return Scrollbar(
          controller: _reguHorizontal,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _reguHorizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: RefreshIndicator(
                onRefresh: vm.loadRegu,
                child: AtlasDataTable<MstRegu>(
                  columns: _reguColumns,
                  items: items,
                  isLoading: vm.reguLoading,
                  errorMessage: items.isEmpty ? vm.reguError : '',
                  errorBuilder: (message) => _errorState(message, vm.loadRegu),
                  onRowLongPress: _onReguLongPress,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<AtlasTableColumn<MstRegu>> get _reguColumns => [
    AtlasTableColumn(
      title: 'ID',
      width: 80,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, r, s) => Text(
        '${r.idRegu}',
        style: TextStyle(fontSize: 14, color: s.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'NAMA REGU',
      flex: 1,
      cellBuilder: (_, r, s) => Text(
        r.namaRegu.isEmpty ? '—' : r.namaRegu,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'ID BAGIAN',
      width: 120,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, r, s) => Text(
        '${r.idBagian}',
        style: TextStyle(fontSize: 14, color: s.textColor),
      ),
    ),
    AtlasTableColumn(
      title: 'KEPALA REGU',
      width: 240,
      showDivider: false,
      cellBuilder: (_, r, s) {
        final kepala = r.namaKepalaRegu?.trim();
        final label = (kepala != null && kepala.isNotEmpty)
            ? kepala
            : (r.kepalaRegu != null ? 'ID ${r.kepalaRegu}' : '—');
        return Text(
          label,
          style: TextStyle(fontSize: 14, color: s.textColor),
          softWrap: true,
        );
      },
    ),
  ];

  // ── Shared bits ──────────────────────────────────────────

  Widget _emptyState({
    required IconData icon,
    required String title,
    required VoidCallback? onAdd,
    required String addLabel,
  }) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: const Color(0xFFC1C7D0)),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF172B4D),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(addLabel),
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
