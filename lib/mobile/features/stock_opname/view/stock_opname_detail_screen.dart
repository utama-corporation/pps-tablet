import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../../shared/lokasi/lokasi_dropdown.dart';
import '../../../shared/lokasi/lokasi_model.dart';
import '../../../shared/lokasi/lokasi_view_model.dart';
import '../view_model/stock_opname_detail_view_model.dart';
import '../view_model/stock_opname_scan_view_model.dart';
import '../../../widgets/loading_skeleton.dart';
import '../../../widgets/error_state.dart';
import '../../../widgets/empty_state.dart';
import '../widget/stock_opname_expandable_card.dart';
import 'barcode_qr_scan_stock_opname_screen.dart';
import '../model/label_validation_result.dart';
import '../widget/confirmation_label_stock_opname_dialog.dart';
import '../widget/input_detail_label_stock_opname_dialog.dart';
import '../../../widgets/error_status_dialog.dart';
import '../../../widgets/success_status_dialog.dart';
import '../../../widgets/loading_dialog.dart';
import '../widget/input_id_label_stock_opname_dialog.dart';

class StockOpnameDetailScreen extends StatefulWidget {
  final String noSO;
  final String tgl;
  final String idWarehouse;

  const StockOpnameDetailScreen({
    Key? key,
    required this.noSO,
    required this.tgl,
    required this.idWarehouse,
  }) : super(key: key);

  @override
  _StockOpnameDetailScreenState createState() =>
      _StockOpnameDetailScreenState();
}

class _StockOpnameDetailScreenState extends State<StockOpnameDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  String? _selectedFilter;
  String? _selectedBlok;
  int? _selectedIdLokasi;

  @override
  void initState() {
    super.initState();

    final normalizedIdWarehouse = widget.idWarehouse
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(',');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LokasiViewModel>().fetchLokasiList(
        idWarehouse: normalizedIdWarehouse,
      );

      context.read<StockOpnameDetailViewModel>().fetchInitialData(widget.noSO);
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final vm = context.read<StockOpnameDetailViewModel>();
    if (!vm.hasMoreData || vm.isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      vm.loadMoreData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noSO, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildListView()),
        ],
      ),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildFilterDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildLokasiDropdown()),
            ],
          ),
          const SizedBox(height: 8),
          _buildSummarySection(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Consumer<StockOpnameDetailViewModel>(
      builder: (context, vm, _) {
        // Loading state - tampilkan skeleton
        if (vm.isInitialLoading && vm.labels.isEmpty) {
          return const LoadingSkeleton();
        }

        // Error state - tampilkan error widget
        if (vm.errorMessage.isNotEmpty && vm.labels.isEmpty) {
          return ErrorState(
            message: vm.errorMessage,
            onRetry: () => vm.fetchInitialData(
              widget.noSO,
              filterBy: _selectedFilter ?? 'all',
              blok: _selectedBlok,
              idLokasi: _selectedIdLokasi,
            ),
          );
        }

        // Empty state - tampilkan empty widget
        if (vm.labels.isEmpty) {
          return EmptyState(
            onRefresh: () => vm.fetchInitialData(
              widget.noSO,
              filterBy: _selectedFilter ?? 'all',
              blok: _selectedBlok,
              idLokasi: _selectedIdLokasi,
            ),
          );
        }

        // List with data
        return RefreshIndicator(
          onRefresh: () => vm.fetchInitialData(
            widget.noSO,
            filterBy: _selectedFilter ?? 'all',
            blok: _selectedBlok,
            idLokasi: _selectedIdLokasi,
          ),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: vm.labels.length + (vm.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Loading more indicator
              if (index >= vm.labels.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Expandable card item
              return StockOpnameExpandableCard(item: vm.labels[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildSummarySection() {
    return Consumer<StockOpnameDetailViewModel>(
      builder: (context, vm, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.label_rounded,
                label: 'Label',
                value: '${vm.totalData}',
                iconColor: const Color(0xFF2196F3),
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                icon: Icons.monitor_weight_rounded,
                label: 'Berat',
                value: '${vm.totalBerat.toStringAsFixed(2)} kg',
                iconColor: const Color(0xFFFF9800),
              ),
              _buildSummaryDivider(),
              _buildSummaryItem(
                icon: Icons.inventory_2_rounded,
                label: 'Sak',
                value: '${vm.totalSak}',
                iconColor: const Color(0xFF00BCD4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: _selectedFilter,
        hint: const Text('Filter'),
        isExpanded: true,
        onChanged: (value) {
          setState(() => _selectedFilter = value);
          context.read<StockOpnameDetailViewModel>().fetchInitialData(
            widget.noSO,
            filterBy: value ?? 'all',
            blok: _selectedBlok,
            idLokasi: _selectedIdLokasi,
          );
        },
        items: const [
          DropdownMenuItem(value: 'all', child: Text('Semua')),
          DropdownMenuItem(value: 'bahanbaku', child: Text('Bahan Baku')),
          DropdownMenuItem(value: 'washing', child: Text('Washing')),
          DropdownMenuItem(value: 'broker', child: Text('Broker')),
          DropdownMenuItem(value: 'crusher', child: Text('Crusher')),
          DropdownMenuItem(value: 'bonggolan', child: Text('Bonggolan')),
          DropdownMenuItem(value: 'gilingan', child: Text('Gilingan')),
          DropdownMenuItem(value: 'mixer', child: Text('Mixer')),
          DropdownMenuItem(value: 'furniturewip', child: Text('Furniture WIP')),
          DropdownMenuItem(value: 'barangjadi', child: Text('Barang Jadi')),
          DropdownMenuItem(value: 'reject', child: Text('Reject')),
        ],
        underline: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLokasiDropdown() {
    Lokasi? currentValue() {
      if (_selectedBlok == null && _selectedIdLokasi == null) {
        return const Lokasi(idLokasi: '__SEMUA__', blok: '-', enable: true);
      }
      if (_selectedBlok != null &&
          (_selectedIdLokasi == null || _selectedIdLokasi == 0)) {
        return Lokasi(idLokasi: '', blok: _selectedBlok!, enable: true);
      }
      if (_selectedBlok != null && _selectedIdLokasi != null) {
        return Lokasi(
          idLokasi: _selectedIdLokasi!.toString(),
          blok: _selectedBlok!,
          enable: true,
        );
      }
      return const Lokasi(idLokasi: '__SEMUA__', blok: '-', enable: true);
    }

    return LokasiDropdown(
      value: currentValue(),
      includeSemua: true,
      onChanged: (Lokasi? picked) {
        String? blok;
        int? id;

        if (picked == null || picked.idLokasi == '__SEMUA__') {
          blok = null;
          id = null;
        } else {
          blok = picked.blok.isEmpty ? null : picked.blok;
          id = picked.idLokasi.isEmpty ? null : int.tryParse(picked.idLokasi);
        }

        setState(() {
          _selectedBlok = blok;
          _selectedIdLokasi = id;
        });

        context.read<StockOpnameDetailViewModel>().fetchInitialData(
          widget.noSO,
          filterBy: _selectedFilter ?? 'all',
          blok: _selectedBlok,
          idLokasi: _selectedIdLokasi,
        );
      },
    );
  }

  Widget _buildSpeedDial() {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      backgroundColor: const Color(0xFF0D47A1),
      foregroundColor: Colors.white,
      curve: Curves.linear,
      spaceBetweenChildren: 16,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.qr_code),
          label: 'Scan QR',
          onTap: () => _showScanBarQRCode(context),
        ),
        SpeedDialChild(
          child: const Icon(Icons.edit_note),
          label: 'Input Manual',
          onTap: () => _showAddManualDialog(context),
        ),
      ],
    );
  }

  // ... Semua method helper lainnya tetap sama
  void _showScanBarQRCode(BuildContext context) {
    if (_selectedIdLokasi == null || _selectedIdLokasi == 0) {
      showErrorStatusDialog(
        context,
        'Pilih lokasi dulu!',
        'Silakan pilih lokasi terlebih dahulu sebelum melakukan scan / input label',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeQrScanStockOpnameScreen(
          noSO: widget.noSO,
          selectedFilter: _selectedFilter ?? 'all',
          idLokasi: _selectedIdLokasi!,
          blok: _selectedBlok,
        ),
      ),
    );
  }

  void _showAddManualDialog(BuildContext context) {
    final scanVM = context.read<StockOpnameScanViewModel>();

    if (_selectedIdLokasi == null || _selectedIdLokasi == 0) {
      showErrorStatusDialog(
        context,
        'Pilih lokasi dulu!',
        'Silakan pilih lokasi terlebih dahulu sebelum melakukan scan / input label',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => InputIdLabelStockOpnameDialog(
        onSubmit: (label) async {
          final result = await scanVM.validateLabel(
            label,
            _selectedBlok!,
            _selectedIdLokasi!,
            widget.noSO,
          );

          if (result == null ||
              result.labelType == null ||
              result.labelType.isEmpty) {
            showErrorStatusDialog(
              context,
              'Validasi gagal',
              'Tidak dapat memvalidasi label: $label',
            );
            return;
          }

          if (result.isDuplicate) {
            showErrorStatusDialog(
              context,
              'Label Duplikat',
              '${result.message} Label: $label',
            );
            return;
          }

          if (!result.isValidCategory) {
            showErrorStatusDialog(
              context,
              'Kategori Tidak Valid',
              '${result.message} Label: $label',
            );
            return;
          }

          await _showConfirmDialog(label, result);
        },
      ),
    );
  }

  void showErrorStatusDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorStatusDialog(title: title, message: message),
    );
  }

  Future<void> _showConfirmDialog(
    String label,
    LabelValidationResult result,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConfirmationLabelStockOpnameSheet(
          label: label,
          result: result,
          onConfirm: () async {
            Navigator.of(ctx).pop();
            await _saveLabel(label, result.jmlhSak ?? 0, result.berat ?? 0);
          },
          onManualInput: () async {
            Navigator.of(ctx).pop();
            await _showManualInputSheet(label);
          },
        );
      },
    );
  }

  Future<void> _showManualInputSheet(String label) async {
    await showInputLabelStockOpnameBottomSheet(
      context: context,
      label: label,
      onSave: (jmlhSak, berat) async {
        await _saveLabel(label, jmlhSak, berat);
      },
    );
  }

  Future<void> _saveLabel(String label, int jmlhSak, double berat) async {
    final scanVM = Provider.of<StockOpnameScanViewModel>(
      context,
      listen: false,
    );
    final detailVM = Provider.of<StockOpnameDetailViewModel>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Menyimpan data label...'),
    );

    try {
      final success = await scanVM.insertLabel(
        label: label,
        noSO: widget.noSO,
        jmlhSak: jmlhSak,
        berat: berat,
        blok: _selectedBlok ?? '',
        idLokasi: _selectedIdLokasi!,
      );

      Navigator.of(context).pop();

      if (success) {
        detailVM.fetchInitialData(
          widget.noSO,
          filterBy: _selectedFilter ?? 'all',
        );

        showDialog(
          context: context,
          builder: (_) => SuccessStatusDialog(
            title: 'Berhasil!',
            message: 'Label berhasil disimpan.',
            extraContent: _buildLabelSummary(label, jmlhSak, berat),
          ),
        );
      } else {
        Navigator.of(context).pop();
        showErrorStatusDialog(
          context,
          'Gagal menyimpan data',
          'Label: $label\nSilakan coba lagi.',
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      showErrorStatusDialog(
        context,
        'Terjadi kesalahan',
        'Error: ${e.toString()}',
      );
    }
  }

  Widget _buildLabelSummary(String label, int jmlhSak, double berat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDataRow('Label', label),
        _buildDataRow('Jumlah Sak', '$jmlhSak'),
        _buildDataRow('Berat', '${berat.toStringAsFixed(2)} kg'),
      ],
    );
  }

  Widget _buildDataRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(':'),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
