import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/stock_opname_detail_view_model.dart';
import '../view_model/stock_opname_label_before_view_model.dart';
import '../view_model/socket_manager.dart';
import 'widgets/filter_section/filter_dropdown_widget.dart';
import 'widgets/filter_section/lokasi_dropdown_widget.dart';
import 'widgets/filter_section/search_label_widget.dart';
import 'widgets/list_sections/stock_data_list_widget.dart';
import 'widgets/list_sections/scan_result_list_widget.dart';
import 'widgets/list_sections/section_header_widget.dart';
import 'widgets/dialogs/summary_dialog_widget.dart';
import '../../../common/widgets/loading_dialog.dart';

class StockOpnameDetailScreen extends StatefulWidget {
  final String noSO;
  final String tgl;

  const StockOpnameDetailScreen({
    Key? key,
    required this.noSO,
    required this.tgl,
  }) : super(key: key);

  @override
  State<StockOpnameDetailScreen> createState() =>
      _StockOpnameDetailScreenState();
}

class _StockOpnameDetailScreenState extends State<StockOpnameDetailScreen> {
  static const _primary = Color(0xFF0D47A1);
  static const _bgPage = Color(0xFFF8F9FB);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE2E6EE);
  static const _textPrimary = Color(0xFF1A2340);
  static const _textSec = Color(0xFF4A5568);

  String? _selectedFilter;
  String? _selectedBlok;
  int? _selectedIdLokasi;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    final detailVM = Provider.of<StockOpnameDetailViewModel>(
      context,
      listen: false,
    );
    final beforeVM = Provider.of<StockOpnameLabelBeforeViewModel>(
      context,
      listen: false,
    );
    final socketManager = SocketManager();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      socketManager.initSocket();
      detailVM.initSocket();
      beforeVM.initSocket();

      detailVM.fetchInitialData(widget.noSO);
      beforeVM.fetchInitialData(widget.noSO);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Row(
              children: [
                _buildStockDataSection(),
                Container(width: 1, color: _border),
                _buildScanResultSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.noSO,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tgl,
                  style: const TextStyle(color: _textSec, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: FilterDropdownWidget(
              selectedFilter: _selectedFilter,
              onChanged: _onFilterChanged,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 200,
            child: LokasiDropdownWidget(
              selectedBlok: _selectedBlok,
              selectedIdLokasi: _selectedIdLokasi,
              onChanged: (blok, idLokasi) {
                setState(() {
                  _selectedBlok = blok;
                  _selectedIdLokasi = idLokasi;
                });
                _refreshData();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SearchLabelWidget(
              onSearch: _onSearch,
              onClear: _onSearchClear,
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Lihat Ringkasan',
            child: SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _showSummaryDialog,
                icon: const Icon(Icons.assessment_outlined, size: 17),
                label: const Text('Ringkasan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: Color(0xFFC5CEE0)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockDataSection() {
    return Expanded(
      child: Column(
        children: [
          Consumer<StockOpnameLabelBeforeViewModel>(
            builder: (context, beforeVM, _) {
              return SectionHeaderWidget(
                title: 'DATA STOCK',
                color: const Color(0xFFF59E0B),
                totalData: beforeVM.totalData,
              );
            },
          ),
          Expanded(
            child: StockDataListWidget(
              noSO: widget.noSO,
              selectedFilter: _selectedFilter,
              selectedBlok: _selectedBlok,
              selectedIdLokasi: _selectedIdLokasi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanResultSection() {
    return Expanded(
      child: Column(
        children: [
          Consumer<StockOpnameDetailViewModel>(
            builder: (context, detailVM, _) {
              return SectionHeaderWidget(
                title: 'HASIL SCAN',
                color: const Color(0xFF0A7349),
                totalData: detailVM.totalData,
              );
            },
          ),
          Expanded(
            child: ScanResultListWidget(
              noSO: widget.noSO,
              selectedFilter: _selectedFilter,
              selectedBlok: _selectedBlok,
              selectedIdLokasi: _selectedIdLokasi,
              onDeleteSuccess: _refreshData,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSummaryDialog() async {
    final detailVM = Provider.of<StockOpnameDetailViewModel>(
      context,
      listen: false,
    );
    final beforeVM = Provider.of<StockOpnameLabelBeforeViewModel>(
      context,
      listen: false,
    );

    if (detailVM.isInitialLoading || beforeVM.isInitialLoading) {
      // showDialog default-nya push ke root Navigator (useRootNavigator:
      // true), sementara layar ini sendiri hidup di nested shell Navigator
      // milik AppShell yang hanya punya SATU route - Navigator.pop(context)
      // polos bakal nge-pop shell Navigator (no-op) sehingga dialog loading
      // ini tidak pernah tertutup dan menimpa ringkasan di bawahnya.
      final rootNavigator = Navigator.of(context, rootNavigator: true);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LoadingDialog(message: 'Menyiapkan ringkasan...'),
      );

      while (detailVM.isInitialLoading || beforeVM.isInitialLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SummaryDialogWidget(
          stockTotalDataGlobal: beforeVM.totalGlobal,
          stockTotalSakGlobal: beforeVM.totalSakGlobal,
          stockTotalBeratGlobal: beforeVM.totalBeratGlobal,
          stockTotalData: beforeVM.totalData,
          stockTotalSak: beforeVM.totalSak,
          stockTotalBerat: beforeVM.totalBerat,
          scanTotalData: detailVM.totalData,
          scanTotalSak: detailVM.totalSak,
          scanTotalBerat: detailVM.totalBerat,
          noSO: widget.noSO,
          tgl: widget.tgl,
          selectedCategory: _selectedFilter ?? 'all',
          selectedBlok: _selectedBlok,
          selectedIdLokasi: _selectedIdLokasi,
        );
      },
    );
  }

  void _onFilterChanged(String? value) {
    setState(() => _selectedFilter = value);
    _refreshData();
  }

  void _onSearch(String query) {
    final detailVM = Provider.of<StockOpnameDetailViewModel>(
      context,
      listen: false,
    );
    final beforeVM = Provider.of<StockOpnameLabelBeforeViewModel>(
      context,
      listen: false,
    );

    detailVM.search(query);
    beforeVM.search(query);
  }

  void _onSearchClear() {
    final detailVM = Provider.of<StockOpnameDetailViewModel>(
      context,
      listen: false,
    );
    final beforeVM = Provider.of<StockOpnameLabelBeforeViewModel>(
      context,
      listen: false,
    );

    detailVM.clearSearch();
    beforeVM.clearSearch();
  }

  void _refreshData() {
    final detailVM = Provider.of<StockOpnameDetailViewModel>(
      context,
      listen: false,
    );
    final beforeVM = Provider.of<StockOpnameLabelBeforeViewModel>(
      context,
      listen: false,
    );

    // ✅ Normalisasi agar selalu kirim null jika "Semua Lokasi"
    final String? blok =
        (_selectedBlok == null ||
            _selectedBlok == 'all' ||
            _selectedBlok!.trim().isEmpty)
        ? null
        : _selectedBlok;

    final int? idLokasi = (_selectedIdLokasi == null || _selectedIdLokasi == 0)
        ? null
        : _selectedIdLokasi;

    detailVM.fetchInitialData(
      widget.noSO,
      filterBy: _selectedFilter ?? 'all',
      blok: blok,
      idLokasi: idLokasi,
    );

    beforeVM.fetchInitialData(
      widget.noSO,
      filterBy: _selectedFilter ?? 'all',
      blok: blok,
      idLokasi: idLokasi,
    );
  }
}
