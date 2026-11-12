import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/stock_opname_list_view_model.dart';
import '../../../widgets/loading_skeleton.dart';
import 'stock_opname_detail_screen.dart';

class StockOpnameListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StockOpnameViewModel>(
        context,
        listen: false,
      ).fetchStockOpname();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Stock Opname',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<StockOpnameViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.stockOpnameList.isEmpty) {
            return _buildLoading();
          }

          if (viewModel.errorMessage.isNotEmpty) {
            return _buildErrorState(viewModel);
          }

          // ⬇️ HANYA TAMPILKAN isAscend == false
          final visibleList = viewModel.stockOpnameList
              .where((so) => so.isAscend == false)
              .toList();

          if (visibleList.isEmpty) {
            return _buildEmptyState(viewModel);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await viewModel.fetchStockOpname();
            },
            color: const Color(0xFF0D47A1),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleList.length,
              itemBuilder: (context, index) {
                final stockOpname = visibleList[index];
                return _buildStockOpnameCard(context, stockOpname);
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockOpnameCard(BuildContext context, dynamic stockOpname) {
    final activeProcesses = _getActiveProcesses(stockOpname);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StockOpnameDetailScreen(
                  noSO: stockOpname.noSO,
                  tgl: stockOpname.tanggal,
                  idWarehouse: stockOpname.idWarehouse, // ⬅️ baru
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan tanggal dan nomor SO
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: const Color(0xFF0D47A1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stockOpname.tanggal,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stockOpname.noSO,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Warehouse info
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warehouse,
                        color: const Color(0xFF0D47A1),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stockOpname.namaWarehouse,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Active processes
                if (activeProcesses.isNotEmpty) ...[
                  Text(
                    'Kategori:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: activeProcesses.map((process) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getProcessColor(process).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getProcessColor(process).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          process,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _getProcessColor(process),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[500],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No active processes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getActiveProcesses(dynamic stockOpname) {
    List<String> processes = [];

    if (stockOpname.isBahanBaku) processes.add('Bahan Baku');
    if (stockOpname.isWashing) processes.add('Washing');
    if (stockOpname.isBonggolan) processes.add('Bonggolan');
    if (stockOpname.isCrusher) processes.add('Crusher');
    if (stockOpname.isBroker) processes.add('Broker');
    if (stockOpname.isGilingan) processes.add('Gilingan');
    if (stockOpname.isMixer) processes.add('Mixer');
    if (stockOpname.isFurnitureWIP) processes.add('Furniture WIP');
    if (stockOpname.isBarangJadi) processes.add('Barang Jadi');
    if (stockOpname.isReject) processes.add('Reject');

    return processes;
  }

  Color _getProcessColor(String process) {
    switch (process) {
      case 'Bahan Baku':
      case 'Washing':
      case 'Bonggolan':
      case 'Crusher':
      case 'Broker':
      case 'Gilingan':
      case 'Mixer':
      case 'Furniture WIP':
      case 'Barang Jadi':
      case 'Reject':
        return Colors.blue[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildEmptyState(dynamic viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tidak Ada Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.errorMessage.isNotEmpty
                ? viewModel.errorMessage
                : 'No data available at the moment',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              viewModel.fetchStockOpname();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(dynamic viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              viewModel.errorMessage,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              viewModel.fetchStockOpname();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => const LoadingSkeleton();
}
