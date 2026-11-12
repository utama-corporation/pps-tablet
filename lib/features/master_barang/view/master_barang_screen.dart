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
import '../../../core/view/app_shell.dart';
import '../model/master_barang_models.dart';
import '../repository/master_barang_repository.dart';
import '../view_model/master_barang_view_model.dart';
import 'master_barang_form_dialog.dart';

const _typeIcons = <String, IconData>{
  'bahan-baku': Icons.warehouse_outlined,
  'barang-jadi': Icons.inventory_2_outlined,
  'barang-dagang': Icons.local_shipping_outlined,
  'bonggolan': Icons.recycling_outlined,
  'broker': Icons.storefront_outlined,
  'cabinet-wip': Icons.chair_outlined,
  'cabinet-material': Icons.construction_outlined,
  'crusher': Icons.hardware_outlined,
  'gilingan': Icons.grass_outlined,
  'mixer': Icons.blender_outlined,
  'washing': Icons.local_laundry_service_outlined,
};

const _typeColors = <Color>[
  Color(0xFF0C66E4),
  Color(0xFF15803D),
  Color(0xFFB45309),
  Color(0xFF7C3AED),
  Color(0xFF0E7490),
  Color(0xFFC2410C),
];

IconData _iconFor(String key) => _typeIcons[key] ?? Icons.category_outlined;

Color _colorFor(String key, List<MasterBarangTypeMeta> types) {
  final index = types.indexWhere((t) => t.key == key);
  return _typeColors[(index < 0 ? 0 : index) % _typeColors.length];
}

class MasterBarangScreen extends StatefulWidget {
  const MasterBarangScreen({super.key, this.repository});

  final MasterBarangRepository? repository;

  @override
  State<MasterBarangScreen> createState() => _MasterBarangScreenState();
}

class _MasterBarangScreenState extends State<MasterBarangScreen> {
  late final MasterBarangViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _horizontal = ScrollController();
  final InteractivePopover _popover = InteractivePopover();
  bool _searchFocused = false;
  List<BreadcrumbSegment> _prevBreadcrumb = const [];
  String? _pushedTypeLabel;

  @override
  void initState() {
    super.initState();
    vm = MasterBarangViewModel(
      widget.repository ??
          MasterBarangRepository(api: context.read<ApiClient>()),
    );
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<PermissionViewModel>().can('datamasterbarang:read')) {
        unawaited(vm.loadMeta());
      }
    });
  }

  @override
  void dispose() {
    final prev = _prevBreadcrumb;
    final pushedLabel = _pushedTypeLabel;
    if (prev.isNotEmpty && pushedLabel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = AppShell.breadcrumb.value;
        if (current.isNotEmpty && current.last.label == pushedLabel) {
          AppShell.breadcrumb.value = prev;
        }
      });
    }
    _popover.dispose();
    _searchFocus.dispose();
    _horizontal.dispose();
    _search.dispose();
    vm.dispose();
    super.dispose();
  }

  bool _can(String action) =>
      context.read<PermissionViewModel>().can('datamasterbarang:$action');

  void _pushTypeBreadcrumb(String typeLabel) {
    _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
    final prev = _prevBreadcrumb;
    AppShell.breadcrumb.value = [
      for (var i = 0; i < prev.length; i++)
        BreadcrumbSegment(
          prev[i].label,
          // Hanya segmen terakhir (Master Barang) yang bisa di-tap untuk
          // kembali ke layar sebelumnya.
          onTap: i == prev.length - 1 ? () => _backToOverview() : null,
        ),
      BreadcrumbSegment(typeLabel),
    ];
    _pushedTypeLabel = typeLabel;
  }

  void _backToOverview() {
    _search.clear();
    setState(() {});
    if (_prevBreadcrumb.isNotEmpty) {
      AppShell.breadcrumb.value = _prevBreadcrumb;
      _prevBreadcrumb = const [];
    }
    _pushedTypeLabel = null;
    unawaited(vm.selectType(null));
  }

  Future<void> _openForm({MasterBarangItem? edit}) async {
    final type = vm.currentType;
    if (type == null) return;
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: MasterBarangFormDialog(
          viewModel: vm,
          type: type,
          edit: edit,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? '${type.label} baru berhasil disimpan: $saved'
              : '${type.label} berhasil diubah: $saved',
        ),
      ),
    );
  }

  void _onRowLongPress(MasterBarangItem item, Offset position) {
    final type = vm.currentType;
    if (type == null) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(220.0, 560.0).toDouble();
    _popover.show(
      context: context,
      globalPosition: position,
      child: RowActionPopover(
        title: item.nama,
        subtitle: 'ID ${type.label}: ${item.id}',
        icon: _iconFor(type.key),
        accent: _colorFor(type.key, vm.meta?.types ?? const []),
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onEdit: () => _openForm(edit: item),
        onDelete: () => _confirmDisable(item),
        onClose: _popover.hide,
        deleteLabel: 'Nonaktifkan',
        deleteIcon: Icons.block_rounded,
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

  Future<void> _confirmDisable(MasterBarangItem item) async {
    if (!_can('delete')) return;
    final type = vm.currentType!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Nonaktifkan ${type.label}',
        message:
            'Nonaktifkan "${item.nama}"? Item tidak dihapus permanen, hanya ditandai nonaktif.',
        confirmLabel: 'Nonaktifkan',
        confirmIcon: Icons.block_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.disable(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.nama} dinonaktifkan')),
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
    if (!context.watch<PermissionViewModel>().can('datamasterbarang:read')) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke Master Barang.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<MasterBarangViewModel>(
          builder: (context, vm, _) {
            if (vm.metaLoading && vm.meta == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.meta == null) {
              return _errorState(
                vm.metaError.isEmpty ? 'Gagal memuat meta master barang' : vm.metaError,
                vm.loadMeta,
              );
            }
            if (vm.selectedType == null) return _overview(vm);
            return _typeList(vm);
          },
        ),
      ),
    );
  }

  // ── Overview: 11 jenis master ─────────────────────────────

  Widget _overview(MasterBarangViewModel vm) {
    final types = vm.meta!.types;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Kelola master item & jenisnya. Ketuk salah satu untuk membuka daftarnya.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B778C)),
                ),
              ),
              if (vm.metaLoading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: vm.loadMeta,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisExtent: 96,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: types.length,
            itemBuilder: (context, i) {
              final type = types[i];
              final summary = vm.summaryOf(type.key);
              final color = _colorFor(type.key, types);
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: ValueKey('mb-tile-${type.key}'),
                  onTap: () {
                    _search.clear();
                    setState(() {});
                    unawaited(vm.selectType(type.key));
                    _pushTypeBreadcrumb(type.label);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_iconFor(type.key), color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                type.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF172B4D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${summary.aktif} aktif dari ${summary.total}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B778C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFC1C7D0),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ),
      ],
    );
  }

  // ── List per jenis ─────────────────────────────────────────

  Widget _typeList(MasterBarangViewModel vm) {
    final type = vm.currentType!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActionBar(vm, type),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _buildTable(vm, type),
          ),
        ),
        _footer(
          '${vm.items.length} dari ${vm.totalCount} ${type.label.toLowerCase()} · Ketuk lama baris untuk opsi',
        ),
      ],
    );
  }

  Widget _buildActionBar(MasterBarangViewModel vm, MasterBarangTypeMeta type) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                      key: const ValueKey('mb-search'),
                      focusNode: _searchFocus,
                      controller: _search,
                      onChanged: (v) {
                        setState(() {});
                        vm.setQuery(v);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari ${type.label.toLowerCase()}…',
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
              key: const ValueKey('mb-add'),
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
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

  Widget _buildTable(MasterBarangViewModel vm, MasterBarangTypeMeta type) {
    final items = vm.items;
    if (items.isEmpty && !vm.listLoading && vm.listError.isEmpty) {
      return RefreshIndicator(
        onRefresh: vm.loadList,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(type.key), size: 56, color: const Color(0xFFC1C7D0)),
            const SizedBox(height: 12),
            Text(
              'Belum ada ${type.label.toLowerCase()} terdaftar',
              style: const TextStyle(
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
                label: Text('Tambah ${type.label}'),
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

    final listFields = type.fields.where((f) => f.list).toList();
    double fieldWidth(MasterBarangFieldMeta f) => switch (f.kind) {
      'select' => 180,
      'decimal' => 120,
      'int' => 110,
      'bool' => 110,
      _ => 150,
    };
    final minWidth = 70.0 +
        220.0 +
        listFields.fold<double>(0, (sum, f) => sum + fieldWidth(f)) +
        130.0;

    AtlasTableColumn<MasterBarangItem> cellFor(MasterBarangFieldMeta field) {
      return AtlasTableColumn<MasterBarangItem>(
        title: field.label.toUpperCase(),
        width: fieldWidth(field),
        headerAlign: field.kind == 'decimal' || field.kind == 'int'
            ? TextAlign.right
            : TextAlign.left,
        cellAlignment: field.kind == 'decimal' || field.kind == 'int'
            ? Alignment.centerRight
            : (field.kind == 'bool' ? Alignment.center : Alignment.centerLeft),
        cellBuilder: (_, item, rowState) {
          switch (field.kind) {
            case 'decimal':
            case 'int':
              return Text(
                MasterBarangItem.fmtNum(item.fieldNum(field.key)),
                style: TextStyle(fontSize: 13, color: rowState.textColor),
              );
            case 'bool':
              return Text(
                item.fieldBool(field.key) ? 'Ya' : '—',
                style: TextStyle(fontSize: 13, color: rowState.textColor),
              );
            case 'select':
              return Text(
                item.fieldLabel(field.key),
                style: TextStyle(fontSize: 13, color: rowState.textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            default:
              final v = item.field(field.key)?.toString() ?? '';
              return Text(
                v.isEmpty ? '—' : v,
                style: TextStyle(fontSize: 13, color: rowState.textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
          }
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
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
                onRefresh: vm.loadList,
                child: AtlasDataTable<MasterBarangItem>(
                columns: [
                  AtlasTableColumn(
                    title: 'ID',
                    width: 70,
                    headerAlign: TextAlign.right,
                    cellAlignment: Alignment.centerRight,
                    cellBuilder: (_, item, r) => Text(
                      '${item.id}',
                      style: TextStyle(fontSize: 14, color: r.textColor),
                    ),
                  ),
                  AtlasTableColumn(
                    title: type.nameLabel.toUpperCase(),
                    flex: 1,
                    cellBuilder: (_, item, r) => Text(
                      item.nama.isEmpty ? '—' : item.nama,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172B4D),
                      ),
                      softWrap: true,
                    ),
                  ),
                  for (final field in listFields) cellFor(field),
                  AtlasTableColumn(
                    title: 'STATUS',
                    width: 120,
                    showDivider: false,
                    cellBuilder: (_, item, r) => Align(
                      alignment: Alignment.centerLeft,
                      child: _SmallPill(
                        label: item.enable ? 'Aktif' : 'Nonaktif',
                        fg: item.enable
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB91C1C),
                        bg: item.enable
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                      ),
                    ),
                  ),
                ],
                items: items,
                isLoading: vm.listLoading,
                errorMessage: items.isEmpty ? vm.listError : '',
                errorBuilder: (message) => _errorState(message, vm.loadList),
                onRowLongPress: _onRowLongPress,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
