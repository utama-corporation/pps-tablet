import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../common/widgets/atlas_paged_data_table.dart';
import '../../../common/widgets/success_status_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/spk_models.dart';
import '../repository/spk_repository.dart';
import '../view_model/spk_view_model.dart';
import '../widgets/spk_widgets.dart';
import 'spk_create_dialog.dart';
import 'spk_document_dialog.dart';
import 'spk_stock_detail_dialog.dart';

class SpkScreen extends StatefulWidget {
  const SpkScreen({super.key, this.repository});

  final SpkRepository? repository;

  @override
  State<SpkScreen> createState() => _SpkScreenState();
}

class _StatCardSpec {
  const _StatCardSpec({
    required this.label,
    required this.status,
    required this.icon,
    required this.fg,
    required this.bg,
  });

  final String label;
  final String status;
  final IconData icon;
  final Color fg;
  final Color bg;

  int? countFor(Map<String, int> summary) => switch (status) {
    'PERLU PRODUKSI' => summary['perluProduksi'],
    'STOCK HABIS' => summary['stockHabis'],
    'MENDEKATI MINIMUM' => summary['mendekatiMinimum'],
    'STOCK AMAN' => summary['stockAman'],
    _ => null,
  };
}

const _statCards = <_StatCardSpec>[
  _StatCardSpec(
    label: 'PERLU PRODUKSI',
    status: 'PERLU PRODUKSI',
    icon: Icons.precision_manufacturing_outlined,
    fg: Color(0xFFB45309),
    bg: Color(0xFFFEF3C7),
  ),
  _StatCardSpec(
    label: 'STOCK HABIS',
    status: 'STOCK HABIS',
    icon: Icons.remove_circle_outline_rounded,
    fg: Color(0xFFB91C1C),
    bg: Color(0xFFFEE2E2),
  ),
  _StatCardSpec(
    label: 'MENDEKATI MINIMUM',
    status: 'MENDEKATI MINIMUM',
    icon: Icons.warning_amber_rounded,
    fg: Color(0xFFA16207),
    bg: Color(0xFFFEF9C3),
  ),
  _StatCardSpec(
    label: 'STOCK AMAN',
    status: 'STOCK AMAN',
    icon: Icons.check_circle_outline_rounded,
    fg: Color(0xFF15803D),
    bg: Color(0xFFDCFCE7),
  ),
];

class _SpkScreenState extends State<SpkScreen> {
  late final SpkViewModel vm;
  final TextEditingController search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _searchFocused = false;

  bool get canRead =>
      context.read<PermissionViewModel>().can(spkReadPermission);

  @override
  void initState() {
    super.initState();
    vm = SpkViewModel(
      widget.repository ?? SpkRepository(api: context.read<ApiClient>()),
    );
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (canRead) unawaited(vm.fetchHeaders());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    search.dispose();
    vm.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) unawaited(vm.fetchHeaders(search: value));
    });
  }

  void detail(SpkStockItem item) {
    if (!canRead) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => SpkStockDetailDialog(
          item: item,
          repository: vm.repository,
          selected: vm.isSelected(item),
          onToggleSelection: () => vm.toggleSelection(item),
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    if (!canRead || !vm.hasSelection) return;
    final created = await showDialog<SpkDocument>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SpkCreateDialog(items: vm.selectedItems, repository: vm.repository),
    );
    if (!mounted || created == null) return;
    vm.clearSelection();
    unawaited(vm.refreshCurrent());
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => SuccessStatusDialog(
        title: 'SPK Berhasil Dibuat',
        message: 'Nomor SPK ${created.code}',
        maxWidth: 420,
        extraContent: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 28,
            runSpacing: 8,
            children: [
              SpkMetaItem(label: 'Tanggal', value: spkDate(created.date)),
              SpkMetaItem(label: 'Barang', value: '${created.items.length}'),
              SpkMetaItem(label: 'Total qty', value: spkQty(created.totalQty)),
            ],
          ),
        ),
        actions: [
          StatusAction(
            label: 'Tutup',
            isPrimary: false,
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          StatusAction(
            label: 'Lihat SPK',
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              showDialog<void>(
                context: context,
                builder: (_) => SpkDocumentDialog(
                  code: created.code,
                  repository: vm.repository,
                  initial: created,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _tapSort(String key) {
    if (vm.sort == key) {
      vm.toggleDir();
    } else {
      vm.setSort(key);
    }
  }

  Widget _sortIcon(String key) {
    final active = vm.sort == key;
    if (!active) {
      return Icon(
        Icons.unfold_more_rounded,
        size: 14,
        color: Colors.grey.shade400,
      );
    }
    return Icon(
      vm.dir == 'asc'
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded,
      size: 14,
      color: const Color(0xFF0C66E4),
    );
  }

  List<AtlasTableColumn<SpkStockItem>> _columns(SpkViewModel vm) => [
    AtlasTableColumn(
      title: '',
      width: 56,
      horizontalPadding: 4,
      headerAlign: TextAlign.center,
      cellAlignment: Alignment.center,
      headerTrailing: Tooltip(
        message: 'Pilih semua yang tampil',
        child: Checkbox(
          key: const ValueKey('spk-select-all'),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          tristate: true,
          value: vm.loadedSelectionState,
          onChanged: vm.items.isEmpty
              ? null
              : (_) => vm.setLoadedSelected(vm.loadedSelectionState != true),
        ),
      ),
      cellBuilder: (_, i, r) => Checkbox(
        key: ValueKey('spk-select-${i.id}'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: r.isSelected,
        onChanged: (_) => vm.toggleSelection(i),
      ),
    ),
    AtlasTableColumn(
      title: 'ITEM CODE',
      width: 150,
      onHeaderTap: () => _tapSort('itemCode'),
      headerTrailing: _sortIcon('itemCode'),
      sortActive: vm.sort == 'itemCode',
      cellBuilder: (_, i, r) => Text(
        i.code.isEmpty ? '—' : i.code,
        style: TextStyle(
          fontSize: 14,
          fontWeight: r.isSelected ? FontWeight.w700 : FontWeight.w600,
          color: r.isSelected
              ? const Color(0xFF0C66E4)
              : const Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'BARANG',
      width: 300,
      onHeaderTap: () => _tapSort('barang'),
      headerTrailing: _sortIcon('barang'),
      sortActive: vm.sort == 'barang',
      cellBuilder: (_, i, r) => spkCell(i.name),
    ),
    AtlasTableColumn(
      title: 'UOM',
      width: 70,
      cellBuilder: (_, i, r) => spkCell(i.uom),
    ),
    AtlasTableColumn(
      title: 'STOK',
      width: 95,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      onHeaderTap: () => _tapSort('stok'),
      headerTrailing: _sortIcon('stok'),
      sortActive: vm.sort == 'stok',
      cellBuilder: (_, i, r) => Text(
        spkQty(i.stock),
        style: TextStyle(
          fontSize: 14,
          fontWeight: i.stock <= 0 ? FontWeight.w700 : FontWeight.w500,
          color: i.stock <= 0 ? const Color(0xFFB91C1C) : r.textColor,
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'MIN',
      width: 85,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      onHeaderTap: () => _tapSort('min'),
      headerTrailing: _sortIcon('min'),
      sortActive: vm.sort == 'min',
      cellBuilder: (_, i, r) => spkCell(spkQty(i.min)),
    ),
    AtlasTableColumn(
      title: 'MAX',
      width: 85,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      onHeaderTap: () => _tapSort('max'),
      headerTrailing: _sortIcon('max'),
      sortActive: vm.sort == 'max',
      cellBuilder: (_, i, r) => spkCell(spkQty(i.max)),
    ),
    AtlasTableColumn(
      title: 'MPQ',
      width: 85,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      onHeaderTap: () => _tapSort('mpq'),
      headerTrailing: _sortIcon('mpq'),
      sortActive: vm.sort == 'mpq',
      cellBuilder: (_, i, r) => spkCell(spkQty(i.mpq)),
    ),
    AtlasTableColumn(
      title: 'QTY REKOMENDASI',
      width: 160,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      onHeaderTap: () => _tapSort('qty'),
      headerTrailing: _sortIcon('qty'),
      sortActive: vm.sort == 'qty',
      cellBuilder: (_, i, r) => Text(
        spkQty(i.recommendation),
        style: TextStyle(
          fontSize: 14,
          fontWeight: i.recommendation > 0 ? FontWeight.w700 : FontWeight.w400,
          color: i.recommendation > 0
              ? const Color(0xFFB45309)
              : Colors.grey.shade500,
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'STATUS',
      width: 200,
      onHeaderTap: () => _tapSort('status'),
      headerTrailing: _sortIcon('status'),
      sortActive: vm.sort == 'status',
      cellBuilder: (_, i, r) => SpkStatusLozenge(i.status),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!context.watch<PermissionViewModel>().can(spkReadPermission)) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke SPK Produksi Barang Jadi.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Column(
          children: [
            _buildActionBar(),
            _buildStatCards(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Consumer<SpkViewModel>(
                  builder: (context, vm, _) =>
                      AtlasPagedDataTable<SpkStockItem>(
                        pagingController: vm.pagingController,
                        columns: _columns(vm),
                        selectedPredicate: vm.isSelected,
                        onRowTap: vm.toggleSelection,
                        onRowLongPress: (item, _) => detail(item),
                        noItems: (_) => const SpkEmptyState(),
                        firstPageError: (_) => SpkFailure(
                          vm.errorMessage,
                          retry: vm.refreshCurrent,
                        ),
                      ),
                ),
              ),
            ),
            Consumer<SpkViewModel>(
              builder: (context, vm, _) => vm.hasSelection
                  ? _SelectionBar(
                      count: vm.selectedCount,
                      total: vm.selectedRecommendationTotal,
                      onClear: vm.clearSelection,
                      onCreate: _openCreate,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Menampilkan ${vm.items.length} dari ${vm.totalCount} barang · Ketuk baris untuk memilih barang SPK, tekan lama untuk detail.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B778C),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
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
          // Search box
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
                      controller: search,
                      onChanged: (v) {
                        setState(() {});
                        _onSearchChanged(v);
                      },
                      onSubmitted: (v) {
                        _debounce?.cancel();
                        unawaited(vm.fetchHeaders(search: v));
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari item code atau barang',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  if (search.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _debounce?.cancel();
                        search.clear();
                        setState(() {});
                        _searchFocus.requestFocus();
                        unawaited(vm.fetchHeaders(search: ''));
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Consumer<SpkViewModel>(
      builder: (context, vm, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            for (final (i, card) in _statCards.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: 'Filter: ${card.label}',
                  child: _StatCard(
                    spec: card,
                    count: card.countFor(vm.summary),
                    selected: vm.status == card.status,
                    onTap: () => vm.setStatus(
                      vm.status == card.status ? '' : card.status,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sticky bar shown while rows are selected (mirrors the web selection bar).
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.total,
    required this.onClear,
    required this.onCreate,
  });

  final int count;
  final double total;
  final VoidCallback onClear;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('spk-selection-bar'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF85B8FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.checklist_rounded, color: Color(0xFF0C66E4)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count BARANG DIPILIH',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF0C66E4),
                  ),
                ),
                Text(
                  'Total qty (rekomendasi): ${spkQty(total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF172B4D),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onClear,
            child: const Text('Batalkan Pilihan'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const ValueKey('spk-selection-create'),
            onPressed: onCreate,
            icon: const Icon(Icons.post_add_rounded),
            label: const Text('Buat SPK'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.spec,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _StatCardSpec spec;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? spec.bg : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? spec.fg : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: spec.fg.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : spec.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: spec.fg.withValues(alpha: .25)),
                ),
                child: Icon(spec.icon, size: 18, color: spec.fg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == null ? '—' : '$count',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: selected ? spec.fg : const Color(0xFF172B4D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: selected ? spec.fg : const Color(0xFF6B778C),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 18, color: spec.fg),
            ],
          ),
        ),
      ),
    );
  }
}
