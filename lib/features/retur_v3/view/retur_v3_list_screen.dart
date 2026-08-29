import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/retur_v3_header.dart';
import '../repository/retur_v3_repository.dart';
import '../view_model/retur_v3_list_view_model.dart';
import '../widgets/retur_v3_header_form_dialog.dart';
import 'retur_v3_detail_screen.dart';

const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kSelectedBg = Color(0xFFE9F2FF);

const _kStatusFilters = <String, String>{
  'PENDING': 'Pending',
  'DIGANTI': 'Diganti',
  'TIDAK_DIGANTI': 'Tidak Diganti',
};

/// Layout master-detail untuk tablet landscape: daftar retur di panel kiri
/// (kartu, bukan tabel) dan detail nomor retur yang dipilih tampil langsung
/// di panel kanan (tanpa berpindah layar).
class ReturV3ListScreen extends StatefulWidget {
  const ReturV3ListScreen({super.key});

  @override
  State<ReturV3ListScreen> createState() => _ReturV3ListScreenState();
}

class _ReturV3ListScreenState extends State<ReturV3ListScreen> {
  late final ReturV3ListViewModel _listVm;
  final TextEditingController _searchCtl = TextEditingController();
  String? _selectedNoRetur;

  @override
  void initState() {
    super.initState();
    _listVm = ReturV3ListViewModel(repository: ReturV3Repository());
    _listVm.refresh();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _listVm.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<ReturV3Header>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ReturV3HeaderFormDialog(),
    );
    if (created == null || !mounted) return;
    _listVm.refresh();
    setState(() => _selectedNoRetur = created.noRetur);
  }

  void _select(ReturV3Header header) {
    setState(() => _selectedNoRetur = header.noRetur);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReturV3ListViewModel>.value(
      value: _listVm,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 400,
              child: _MasterListPanel(
                searchCtl: _searchCtl,
                onAdd: _openCreateDialog,
                selectedNoRetur: _selectedNoRetur,
                onSelect: _select,
              ),
            ),
            Container(width: 1, color: _kBorder),
            Expanded(
              child: _selectedNoRetur == null
                  ? const _EmptyDetailPlaceholder()
                  : ReturV3DetailScreen(
                      key: ValueKey(_selectedNoRetur),
                      noRetur: _selectedNoRetur!,
                      embedded: true,
                      onHeaderChanged: _listVm.refresh,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Panel kiri: search + filter + daftar kartu ──────────────────────────

class _MasterListPanel extends StatelessWidget {
  final TextEditingController searchCtl;
  final VoidCallback onAdd;
  final String? selectedNoRetur;
  final ValueChanged<ReturV3Header> onSelect;

  const _MasterListPanel({
    required this.searchCtl,
    required this.onAdd,
    required this.selectedNoRetur,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReturV3ListViewModel>();
    final canCreate = context.watch<PermissionViewModel>().can('retur:create');

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: onAdd,
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              tooltip: 'Buat Retur Baru',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchAndFilterBar(
            controller: searchCtl,
            onChanged: vm.setSearchDebounced,
            onClear: () {
              searchCtl.clear();
              vm.clearSearch();
            },
            hasActiveFilter: vm.hasActiveFilter,
            onOpenFilter: () => _openFilterDialog(context, vm),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: PagingListener<int, ReturV3Header>(
              controller: vm.pagingController,
              builder: (context, state, fetchNextPage) {
                return RefreshIndicator(
                  onRefresh: () async => vm.pagingController.refresh(),
                  child: PagedListView<int, ReturV3Header>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 88),
                    builderDelegate: PagedChildBuilderDelegate<ReturV3Header>(
                      itemBuilder: (context, item, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ReturCard(
                          header: item,
                          selected: item.noRetur == selectedNoRetur,
                          onTap: () => onSelect(item),
                        ),
                      ),
                      firstPageProgressIndicatorBuilder: (_) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      newPageProgressIndicatorBuilder: (_) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      firstPageErrorIndicatorBuilder: (_) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Terjadi kesalahan memuat data.'),
                        ),
                      ),
                      noItemsFoundIndicatorBuilder: (_) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Tidak ada data.'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Buka dialog filter gabungan (status + rentang tanggal) dan terapkan
/// hasilnya sekaligus lewat `ReturV3ListViewModel.applyFilters`.
Future<void> _openFilterDialog(
  BuildContext context,
  ReturV3ListViewModel vm,
) async {
  final result = await showDialog<_FilterResult>(
    context: context,
    builder: (_) => _FilterDialog(
      initialStatus: vm.status,
      initialDateFrom: vm.dateFrom,
      initialDateTo: vm.dateTo,
    ),
  );
  if (result == null) return;
  vm.applyFilters(
    status: result.status,
    dateFrom: result.dateFrom,
    dateTo: result.dateTo,
  );
}

class _SearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasActiveFilter;
  final VoidCallback onOpenFilter;

  const _SearchAndFilterBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasActiveFilter,
    required this.onOpenFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari no. retur / pembeli...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: onClear,
                      )
                    : null,
                filled: true,
                fillColor: _kSurface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: hasActiveFilter
                      ? _kPrimary.withValues(alpha: 0.1)
                      : _kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasActiveFilter ? _kPrimary : _kBorder,
                  ),
                ),
                child: IconButton(
                  onPressed: onOpenFilter,
                  tooltip: 'Filter',
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: hasActiveFilter ? _kPrimary : Colors.grey.shade600,
                  ),
                ),
              ),
              if (hasActiveFilter)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterResult {
  final String? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _FilterResult({this.status, this.dateFrom, this.dateTo});
}

/// Dialog filter gabungan: status retur + rentang tanggal dalam satu tempat,
/// dengan aksi "Reset" dan "Terapkan".
class _FilterDialog extends StatefulWidget {
  final String? initialStatus;
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;

  const _FilterDialog({
    required this.initialStatus,
    required this.initialDateFrom,
    required this.initialDateTo,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  String? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
  }

  static final DateTime _minDate = DateTime(DateTime.now().year - 5);
  static final DateTime _maxDate = DateTime(DateTime.now().year + 1);

  // Dua field independen ("Dari" / "Sampai"), masing-masing pakai stock
  // showDatePicker (dialog calendar compact bawaan Material, bukan
  // showDateRangePicker yang tampil fullscreen di layar tablet ini) — pola
  // ini yang dipakai app-app profesional (Booking.com, Google Flights, dst)
  // untuk date-range field: dua kotak terpisah, bukan satu range picker.
  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: _minDate,
      lastDate: _dateTo ?? _maxDate,
      locale: const Locale('id', 'ID'),
      helpText: 'Tanggal Dari',
    );
    if (picked == null) return;
    setState(() {
      _dateFrom = picked;
      if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? _dateFrom ?? DateTime.now(),
      firstDate: _dateFrom ?? _minDate,
      lastDate: _maxDate,
      locale: const Locale('id', 'ID'),
      helpText: 'Tanggal Sampai',
    );
    if (picked == null) return;
    setState(() {
      _dateTo = picked;
      if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateActive = _dateFrom != null && _dateTo != null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter Retur',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Status',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _kStatusFilters.entries
                  .map(
                    (e) => ChoiceChip(
                      label: Text(
                        e.value,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _status == e.key,
                      onSelected: (sel) =>
                          setState(() => _status = sel ? e.key : null),
                      selectedColor: _kPrimary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _status == e.key
                            ? _kPrimary
                            : Colors.grey.shade700,
                        fontWeight: _status == e.key
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            const Text(
              'Tanggal',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _DateFieldBox(
                    label: 'Dari',
                    value: _dateFrom,
                    onTap: _pickFrom,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                Expanded(
                  child: _DateFieldBox(
                    label: 'Sampai',
                    value: _dateTo,
                    onTap: _pickTo,
                  ),
                ),
                if (dateActive) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: Colors.grey.shade500,
                    tooltip: 'Hapus filter tanggal',
                    onPressed: () => setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, const _FilterResult()),
                    child: const Text('RESET'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _FilterResult(
                        status: _status,
                        dateFrom: _dateFrom,
                        dateTo: _dateTo,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('TERAPKAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak field tanggal ala app profesional (Booking.com, Google Flights):
/// label kecil di atas + nilai (atau placeholder) di bawah, dalam satu
/// kotak bordered yang bisa di-tap — bukan tombol icon+text biasa.
class _DateFieldBox extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateFieldBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? _kPrimary.withValues(alpha: 0.04) : _kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: filled ? _kPrimary : _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: filled ? _kPrimary : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: filled ? _kPrimary : Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    filled ? formatDateToShortId(value) : 'Pilih tanggal',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                      color: filled
                          ? const Color(0xFF1A1D23)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kartu retur (item daftar) ────────────────────────────────────────────

class _ReturCard extends StatelessWidget {
  final ReturV3Header header;
  final bool selected;
  final VoidCallback onTap;

  const _ReturCard({
    required this.header,
    required this.selected,
    required this.onTap,
  });

  /// Judul kartu = Keterangan (nomor retur dari ERP). Fallback ke NoRetur PPS.
  String get _title {
    final k = (header.keterangan ?? '').trim();
    return k.isNotEmpty ? k : header.noRetur;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _kSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFF0C66E4)
                          : const Color(0xFF1A1D23),
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: header.statusRetur),
              ],
            ),
            if (_title != header.noRetur) ...[
              const SizedBox(height: 2),
              Text(
                header.noRetur,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    header.namaPembeli ?? '-',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDateToShortId(header.tanggal),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (header.isDiganti) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.sync_alt_rounded,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Turnover ${_percentLabel(header)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: header.isTurnoverFulfilled
                          ? Colors.green.shade700
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _percentLabel(ReturV3Header header) {
    if (header.turnoverTargetPcs <= 0) return '-';
    final pct = (header.turnoverScannedPcs / header.turnoverTargetPcs * 100)
        .clamp(0, 100);
    return '${pct.round()}%';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    MaterialColor color;
    String label;
    IconData icon;
    switch (status.toUpperCase()) {
      case 'DIGANTI':
        color = Colors.blue;
        label = 'Diganti';
        // Ikon sama persis dengan tombol keputusan "Diganti" di layar
        // detail, supaya user langsung asosiasikan badge ini dengan aksi
        // yang menghasilkannya.
        icon = Icons.autorenew_rounded;
        break;
      case 'TIDAK_DIGANTI':
        color = Colors.orange;
        label = 'Tidak Diganti';
        icon = Icons.block_rounded;
        break;
      default:
        color = Colors.amber;
        label = 'Pending';
        icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Panel kanan: placeholder saat belum ada yang dipilih ────────────────

class _EmptyDetailPlaceholder extends StatelessWidget {
  const _EmptyDetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih retur dari daftar di sebelah kiri',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
