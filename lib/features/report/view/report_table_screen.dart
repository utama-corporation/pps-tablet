// lib/features/report/view/report_table_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/atlas_data_table.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/view/app_shell.dart';
import '../model/report_item.dart';
import '../view_model/report_table_view_model.dart';
import '../widgets/report_filter_dialog.dart';
import 'report_excel_exporter.dart';

class ReportTableScreen extends StatefulWidget {
  const ReportTableScreen({super.key, required this.item});

  final ReportItem item;

  @override
  State<ReportTableScreen> createState() => _ReportTableScreenState();
}

class _ReportTableScreenState extends State<ReportTableScreen> {
  late final ReportTableViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _horizontal = ScrollController();
  final Map<String, TextEditingController> _numberControllers = {};
  final Map<String, String> _values = {};
  bool _searchFocused = false;
  bool _exporting = false;
  List<String> _warehouseOptions = const ['ALL'];
  List<BreadcrumbSegment> _prevBreadcrumb = const [];

  @override
  void initState() {
    super.initState();
    AppShell.currentReport.value =
        widget.item.path ?? widget.item.route ?? widget.item.title;
    vm = ReportTableViewModel(api: context.read<ApiClient>());
    for (final field in widget.item.fields) {
      _values[field.key] = defaultFieldValue(field);
      if (field.type == 'number') {
        _numberControllers[field.key] =
            TextEditingController(text: _values[field.key]);
      }
    }
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prevBreadcrumb = List<BreadcrumbSegment>.from(AppShell.breadcrumb.value);
      final prev = _prevBreadcrumb;
      AppShell.breadcrumb.value = [
        ...prev.map(
          (s) => BreadcrumbSegment(
            s.label,
            onTap: () {
              AppShell.breadcrumb.value = prev;
              AppShell.shellNavigatorKey.currentState?.pop();
            },
          ),
        ),
        BreadcrumbSegment(widget.item.title),
      ];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.item.isWarehouseReport) {
        final opts = await _loadWarehouseOptions();
        if (mounted) setState(() => _warehouseOptions = opts);
      }
      await _reload();
    });
  }

  @override
  void dispose() {
    AppShell.currentReport.value = null;
    final prev = _prevBreadcrumb;
    final title = widget.item.title;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = AppShell.breadcrumb.value;
      if (current.isNotEmpty && current.last.label == title) {
        AppShell.breadcrumb.value = prev;
      }
    });
    _searchFocus.dispose();
    _horizontal.dispose();
    _search.dispose();
    for (final controller in _numberControllers.values) {
      controller.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  Future<List<String>> _loadWarehouseOptions() async {
    try {
      final body =
          await context.read<ApiClient>().getJson('/api/laporan/warehouse-options');
      final options = body['options'];
      if (options is List) {
        return [
          'ALL',
          for (final v in options)
            if (v != null &&
                v.toString().trim().isNotEmpty &&
                v.toString() != 'ALL')
              v.toString(),
        ];
      }
    } catch (_) {}
    return const ['ALL'];
  }

  Future<void> _reload() => vm.load(widget.item.path!, Map.of(_values));

  Future<void> _exportExcel(ReportTableViewModel vm) async {
    if (_exporting || vm.filteredTotal == 0) return;
    setState(() => _exporting = true);
    try {
      final file = await exportReportToExcel(
        title: widget.item.title,
        columns: vm.columns,
        rows: vm.filtered,
      );
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File tersimpan, tapi gagal dibuka: ${result.message}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export Excel: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _warehouseLabel(String value) =>
      value == 'ALL' ? 'Semua Gudang' : value;

  InputDecoration _compactDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
      );

  Widget _buildField(ReportFieldDef field) {
    switch (field.type) {
      case 'date':
        final raw = _values[field.key] ?? '';
        final display = raw.isEmpty
            ? '—'
            : DateFormat('dd MMM yyyy').format(
                DateTime.tryParse(raw) ?? DateTime.now(),
              );
        return SizedBox(
          width: 132,
          child: InkWell(
            key: ValueKey('table-field-${field.key}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(raw) ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF0D47A1),
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(
                  () => _values[field.key] =
                      DateFormat('yyyy-MM-dd').format(picked),
                );
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          field.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          display,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF172B4D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'number':
        return SizedBox(
          width: 92,
          child: TextField(
            key: ValueKey('table-field-${field.key}'),
            controller: _numberControllers[field.key]!,
            keyboardType: TextInputType.number,
            onChanged: (v) => _values[field.key] = v.trim(),
            decoration: _compactDecoration(field.label),
            style: const TextStyle(fontSize: 13),
          ),
        );
      case 'select':
        return SizedBox(
          width: 190,
          child: InputDecorator(
            decoration: _compactDecoration(field.label),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: ValueKey('table-field-${field.key}'),
                value: field.options.contains(_values[field.key])
                    ? _values[field.key]
                    : field.options.first,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF172B4D)),
                items: [
                  for (final option in field.options)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (v) =>
                    setState(() => _values[field.key] = v ?? _values[field.key]!),
              ),
            ),
          ),
        );
      case 'select-warehouse':
        return SizedBox(
          width: 170,
          child: InputDecorator(
            decoration: _compactDecoration(field.label),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: ValueKey('table-field-${field.key}'),
                value: _warehouseOptions.contains(_values[field.key])
                    ? _values[field.key]
                    : _warehouseOptions.first,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Color(0xFF172B4D)),
                items: [
                  for (final option in _warehouseOptions)
                    DropdownMenuItem(
                      value: option,
                      child: Text(_warehouseLabel(option)),
                    ),
                ],
                onChanged: (v) => setState(
                  () => _values[field.key] = v ?? _values[field.key]!,
                ),
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTopBar() {
    if (widget.item.fields.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final field in widget.item.fields) ...[
                  _buildField(field),
                  const SizedBox(width: 8),
                ],
                FilledButton.icon(
                  key: const ValueKey('table-report-show'),
                  onPressed: vm.loading ? null : _reload,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('TAMPILKAN'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

  Widget _buildSearchRow(ReportTableViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _searchFocused
                      ? const Color(0xFF1565C0).withValues(alpha: .5)
                      : Colors.grey.shade300,
                  width: _searchFocused ? 1.6 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(Icons.search, size: 17, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('table-report-search'),
                      focusNode: _searchFocus,
                      controller: _search,
                      onChanged: (v) {
                        setState(() {});
                        vm.setQuery(v);
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari di tabel…',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_search.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded, size: 18),
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
          Text(
            vm.filteredTotal == vm.rows.length
                ? '${vm.rows.length} baris'
                : '${vm.filteredTotal} dari ${vm.rows.length} baris',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B778C),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            key: const ValueKey('table-report-export-excel'),
            onPressed: vm.filteredTotal == 0 || vm.loading || _exporting
                ? null
                : () => _exportExcel(vm),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1B5E20),
              side: const BorderSide(color: Color(0xFF1B5E20)),
              visualDensity: VisualDensity.compact,
            ),
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Excel', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  static final _numberFormat = NumberFormat('#,##0.##', 'id_ID');

  static String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is num) return _numberFormat.format(value);
    final s = value.toString();
    final parsed = DateTime.tryParse(s);
    if (parsed != null &&
        (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s) ||
            RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(s))) {
      return DateFormat('dd/MM/yyyy').format(parsed);
    }
    return s;
  }

  static double _columnWidth(ReportTableColumn column) {
    final label = column.label.toLowerCase();
    if (label.contains('jenis') ||
        label.contains('nama') ||
        label.contains('keterangan')) {
      return 230;
    }
    if (label.contains('tanggal') || label.contains('date')) return 110;
    if (column.numeric) return 120;
    return 140;
  }

  List<AtlasTableColumn<Map<String, dynamic>>> _buildColumns(
    List<ReportTableColumn> columns,
  ) =>
      [
        AtlasTableColumn(
          title: '#',
          width: 46,
          headerAlign: TextAlign.right,
          cellAlignment: Alignment.centerRight,
          cellBuilder: (_, row, r) => Text(
            '${_rowIndexOnPage(row)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B778C)),
          ),
        ),
        for (final column in columns)
          AtlasTableColumn(
            title: column.label.toUpperCase(),
            width: _columnWidth(column),
            headerAlign:
                column.numeric ? TextAlign.right : TextAlign.left,
            cellAlignment: column.numeric
                ? Alignment.centerRight
                : Alignment.centerLeft,
            cellBuilder: (_, row, r) {
              final value = row[column.key];
              return Text(
                _formatValue(value),
                style: TextStyle(
                  fontSize: 12,
                  color: r.textColor,
                  fontWeight: value == null
                      ? FontWeight.w400
                      : column.numeric
                          ? FontWeight.w500
                          : FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              );
            },
          ),
      ];

  int _rowIndexOnPage(Map<String, dynamic> row) {
    final i = vm.pageItems.indexOf(row);
    return i < 0 ? 0 : (vm.page - 1) * vm.pageSize + i + 1;
  }

  Widget _buildFooter(ReportTableViewModel vm) {
    final total = vm.filteredTotal;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            total == 0
                ? 'Tidak ada data'
                : 'Menampilkan ${vm.fromRow}–${vm.toRow} dari $total baris',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B778C)),
          ),
          const Spacer(),
          Text(
            'Baris / halaman',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              key: const ValueKey('table-report-page-size'),
              value: vm.pageSize,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF172B4D),
                fontWeight: FontWeight.w600,
              ),
              items: const [
                DropdownMenuItem(value: 50, child: Text('50')),
                DropdownMenuItem(value: 100, child: Text('100')),
                DropdownMenuItem(value: 200, child: Text('200')),
              ],
              onChanged: (v) => vm.setPageSize(v ?? 100),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            key: const ValueKey('table-report-prev-page'),
            tooltip: 'Halaman sebelumnya',
            onPressed: vm.page > 1 ? () => vm.setPage(vm.page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${vm.page} / ${vm.totalPages}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172B4D),
            ),
          ),
          IconButton(
            key: const ValueKey('table-report-next-page'),
            tooltip: 'Halaman berikutnya',
            onPressed:
                vm.page < vm.totalPages ? () => vm.setPage(vm.page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: vm,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildTopBar(),
            Consumer<ReportTableViewModel>(
              builder: (context, vm, _) => _buildSearchRow(vm),
            ),
            Expanded(
              child: Consumer<ReportTableViewModel>(
                builder: (context, vm, _) {
                  if (vm.loading && vm.columns.isEmpty && vm.rows.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (vm.error.isNotEmpty && vm.rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 36),
                            const SizedBox(height: 8),
                            Text(vm.error, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final pageItems = vm.pageItems;
                  final minWidth = 46 +
                      vm.columns.fold<double>(
                        0,
                        (sum, c) => sum + _columnWidth(c),
                      );
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth < minWidth
                          ? minWidth
                          : constraints.maxWidth;
                      return Scrollbar(
                        controller: _horizontal,
                        thumbVisibility: true,
                        notificationPredicate: (n) =>
                            n.metrics.axis == Axis.horizontal,
                        child: SingleChildScrollView(
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: width,
                            height: constraints.maxHeight,
                            child: pageItems.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tidak ada baris yang cocok',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B778C),
                                      ),
                                    ),
                                  )
                                : AtlasDataTable<Map<String, dynamic>>(
                                    columns: _buildColumns(vm.columns),
                                    items: pageItems,
                                    isLoading: vm.loading,
                                    errorMessage: '',
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Consumer<ReportTableViewModel>(
              builder: (context, vm, _) =>
                  vm.rows.isNotEmpty ? _buildFooter(vm) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
