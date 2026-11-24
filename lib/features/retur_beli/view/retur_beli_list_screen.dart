import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/retur_beli.dart';
import '../repository/retur_beli_repository.dart';
import '../widgets/retur_beli_header_dialog.dart';
import 'retur_beli_detail_screen.dart';

const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kSelectedBg = Color(0xFFE9F2FF);

const _kStatusFilters = <String, String>{
  'OPEN': 'Open',
  'SELESAI': 'Selesai',
};

/// Warehouse > Retur Beli: retur barang ke supplier. Layout master-detail
/// sama dengan Retur v3 — daftar kartu di panel kiri, detail retur yang
/// dipilih langsung tampil di panel kanan.
class ReturBeliListScreen extends StatefulWidget {
  final ReturBeliRepository? repository;

  /// Cek izin; default = [PermissionViewModel]. Untuk test.
  final bool Function(String permission)? can;

  const ReturBeliListScreen({super.key, this.repository, this.can});

  @override
  State<ReturBeliListScreen> createState() => _ReturBeliListScreenState();
}

class _ReturBeliListScreenState extends State<ReturBeliListScreen> {
  static const _pageSize = 30;
  late final ReturBeliRepository _repo =
      widget.repository ?? ReturBeliRepository(api: ApiClient());
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<ReturBeliHeader> _items = [];
  String _status = '';
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String _error = '';
  int _request = 0;
  Timer? _debounce;
  String? _selected;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  bool _can(String p) {
    final check = widget.can;
    if (check != null) return check(p);
    try {
      return context.read<PermissionViewModel>().can(p);
    } on ProviderNotFoundException {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 200 &&
        !_loading &&
        _items.length < _total) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    _items.clear();
    _page = 0;
    _total = 0;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final page = await _repo.list(
        search: _search.text,
        status: _status,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page++;
        _total = page.total;
        _items.addAll(page.items);
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    setState(() {}); // tombol clear
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<void> _create() async {
    final input = await ReturBeliHeaderDialog.show(context);
    if (input == null || !mounted) return;
    try {
      final no = await _repo.create(
        tanggal: input.tanggalYmd,
        idSupplier: input.idSupplier,
        keterangan: input.keterangan,
      );
      if (!mounted) return;
      setState(() => _selected = no);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openFilter() async {
    final result = await showDialog<_FilterResult>(
      context: context,
      builder: (_) => _FilterDialog(
        initialStatus: _status,
        initialDateFrom: _dateFrom,
        initialDateTo: _dateTo,
      ),
    );
    if (result == null) return;
    setState(() {
      _status = result.status;
      _dateFrom = result.dateFrom;
      _dateTo = result.dateTo;
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 400, child: _buildMasterPanel()),
          Container(width: 1, color: _kBorder),
          Expanded(
            child: _selected == null
                ? const _EmptyDetailPlaceholder()
                : ReturBeliDetailScreen(
                    key: ValueKey(_selected),
                    noReturBeli: _selected!,
                    repository: _repo,
                    can: widget.can,
                    embedded: true,
                    onChanged: _reload,
                    onDeleted: () {
                      setState(() => _selected = null);
                      _reload();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterPanel() {
    final canCreate = _can('returbeli:create');
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const ValueKey('rb-create'),
              onPressed: _create,
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              tooltip: 'Buat Retur Beli Baru',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchAndFilterBar(
            controller: _search,
            onChanged: _onSearchChanged,
            onClear: () {
              _search.clear();
              _onSearchChanged('');
            },
            hasActiveFilter:
                _status.isNotEmpty || (_dateFrom != null && _dateTo != null),
            onOpenFilter: _openFilter,
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error.isNotEmpty ? 'Terjadi kesalahan memuat data.' : 'Tidak ada data.',
          ),
        ),
      );
    }
    final hasMore = _items.length < _total;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 88),
        itemCount: _items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final h = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ReturBeliCard(
              header: h,
              selected: h.noReturBeli == _selected,
              onTap: () => setState(() => _selected = h.noReturBeli),
            ),
          );
        },
      ),
    );
  }
}

String formatQty(num v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

// ── Search + filter ─────────────────────────────────────────────────────

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
              key: const ValueKey('rb-search'),
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari no. retur beli / supplier...',
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
                  key: const ValueKey('rb-filter'),
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
  final String status;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const _FilterResult({
    this.status = '',
    this.dateFrom,
    this.dateTo,
  });
}

/// Dialog filter gabungan: status + rentang tanggal, sama persis dengan
/// `_FilterDialog` Retur v3 (chip status, dua kotak tanggal Dari/Sampai,
/// aksi RESET / TERAPKAN).
class _FilterDialog extends StatefulWidget {
  final String initialStatus;
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
  late String _status = widget.initialStatus;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
  }

  static final DateTime _minDate = DateTime(DateTime.now().year - 5);
  static final DateTime _maxDate = DateTime(DateTime.now().year + 1);

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
                    'Filter Retur Beli',
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
              children: [
                _statusChip('', 'Semua'),
                for (final e in _kStatusFilters.entries)
                  _statusChip(e.key, e.value),
              ],
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
                    onPressed: () => Navigator.pop(context, const _FilterResult()),
                    child: const Text('RESET'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const ValueKey('rb-filter-apply'),
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

  Widget _statusChip(String value, String label) {
    final selected = _status == value;
    return ChoiceChip(
      key: ValueKey('rb-filter-${value.isEmpty ? 'ALL' : value}'),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _status = value),
      selectedColor: _kPrimary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? _kPrimary : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

/// Kotak field tanggal ala v3: label kecil di atas + nilai di bawah.
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

// ── Kartu retur beli (item daftar) ──────────────────────────────────────

class _ReturBeliCard extends StatelessWidget {
  final ReturBeliHeader header;
  final bool selected;
  final VoidCallback onTap;

  const _ReturBeliCard({
    required this.header,
    required this.selected,
    required this.onTap,
  });

  /// Sama seperti v3: keterangan jadi judul kartu, fallback keNoReturBeli.
  String get _title {
    final k = header.keterangan.trim();
    return k.isNotEmpty ? k : header.noReturBeli;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('rb-row-${header.noReturBeli}'),
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
                ReturBeliStatusChip(header: header),
              ],
            ),
            if (_title != header.noReturBeli) ...[
              const SizedBox(height: 2),
              Text(
                header.noReturBeli,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    header.namaSupplier.isEmpty ? '-' : header.namaSupplier,
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
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formatDateToShortId(header.tanggal),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 3),
                Text(
                  '${header.itemCount} label · ${formatQty(header.totalQty)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
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

/// Chip status: Open (amber), Diganti (biru), Potong Tagihan (hijau). Gaya
/// sama dengan `_StatusChip` Retur v3.
class ReturBeliStatusChip extends StatelessWidget {
  final ReturBeliHeader header;
  const ReturBeliStatusChip({super.key, required this.header});

  @override
  Widget build(BuildContext context) {
    final (MaterialColor color, String label, IconData icon) = switch (header) {
      ReturBeliHeader(isOpen: true) => (
        Colors.amber,
        'Open',
        Icons.hourglass_top_rounded,
      ),
      ReturBeliHeader(penyelesaian: ReturBeliPenyelesaian.diganti) => (
        Colors.blue,
        'Diganti',
        Icons.autorenew_rounded,
      ),
      _ => (Colors.green, 'Potong Tagihan', Icons.receipt_long_rounded),
    };
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
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Pilih retur beli dari daftar di sebelah kiri',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
