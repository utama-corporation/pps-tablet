import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../model/bj_jual_input_model.dart';
import '../model/bj_jual_model.dart';
import '../view/bj_jual_scan_screen.dart';
import '../view_model/bj_jual_detail_view_model.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kPrimaryLight = Color(0xFF1976D2);
const _kBg = Color(0xFFF0F4FF);
const _kGreenAccent = Color(0xFF059669);
const _kOrangeAccent = Color(0xFFD97706);

class BjJualDetailScreen extends StatefulWidget {
  final BjJual bjJual;

  const BjJualDetailScreen({super.key, required this.bjJual});

  @override
  State<BjJualDetailScreen> createState() => _BjJualDetailScreenState();
}

class _BjJualDetailScreenState extends State<BjJualDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BjJualDetailViewModel>().fetchInputs(widget.bjJual.noBJJual);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showModeSelection(BuildContext context) {
    final viewModel = context.read<BjJualDetailViewModel>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Mode Scan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Text(
              'Pilih cara pengambilan data label',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            _buildModeCard(
              context: ctx,
              icon: Icons.bolt_rounded,
              iconColor: _kGreenAccent,
              iconBg: const Color(0xFFECFDF5),
              title: 'Full',
              subtitle: 'Simpan otomatis, pcs sesuai nilai penuh dari label',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BjJualScanScreen(
                      noBJJual: widget.bjJual.noBJJual,
                      scanMode: ScanMode.full,
                    ),
                  ),
                ).then((saved) {
                  if (saved == true) {
                    viewModel.fetchInputs(widget.bjJual.noBJJual);
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            _buildModeCard(
              context: ctx,
              icon: Icons.tune_rounded,
              iconColor: _kOrangeAccent,
              iconBg: const Color(0xFFFFFBEB),
              title: 'Partial',
              subtitle: 'Edit jumlah pcs sebelum menyimpan data',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BjJualScanScreen(
                      noBJJual: widget.bjJual.noBJJual,
                      scanMode: ScanMode.partial,
                    ),
                  ),
                ).then((saved) {
                  if (saved == true) {
                    viewModel.fetchInputs(widget.bjJual.noBJJual);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showModeSelection(context),
        backgroundColor: _kPrimary,
        elevation: 4,
        icon: const Icon(
          Icons.qr_code_scanner_rounded,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          'Scan Label',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimary, _kPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bjJual.noBJJual,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const Text(
              'Detail Input',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Consumer<BjJualDetailViewModel>(
            builder: (context, vm, _) {
              final bjCount = vm.inputData?.summary.barangJadi;
              final wipCount = vm.inputData?.summary.furnitureWip;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: _kPrimary,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.all(3),
                  tabs: [
                    _buildTab('Barang Jadi', bjCount),
                    _buildTab('Furniture WIP', wipCount),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Consumer<BjJualDetailViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _kPrimary,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (viewModel.errorMessage.isNotEmpty) {
                  return _buildErrorState(viewModel);
                }

                if (viewModel.inputData == null) {
                  return const SizedBox.shrink();
                }

                final data = viewModel.inputData!;

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBarangJadiTab(data),
                    _buildFurnitureWipTab(data),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bj = widget.bjJual;
    final formattedDate = _formatDate(bj.tanggal);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, _kPrimaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // Buyer info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bj.namaPembeli,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white54,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        if (bj.remark.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Colors.white38,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bj.remark,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Tab _buildTab(String label, int? count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarangJadiTab(BjJualInputData data) {
    if (data.barangJadi.isEmpty) return _buildEmptyTab('Barang Jadi');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: data.barangJadi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = data.barangJadi[index];
        return _buildBarangJadiCard(item, context);
      },
    );
  }

  Widget _buildBarangJadiCard(BarangJadiItem item, BuildContext ctx) {
    final isPartialRow = item.isPartialRow == true;
    final deleteLabel = isPartialRow && item.noBJPartial != null
        ? item.noBJPartial!
        : item.noBJ;
    final deleteTableName = isPartialRow ? 'BarangJadiPartial' : 'BarangJadi';

    return _buildItemCard(
      icon: Icons.sell_rounded,
      accentColor: _kGreenAccent,
      iconBgColor: const Color(0xFFECFDF5),
      noLabel: isPartialRow && item.noBJPartial != null
          ? item.noBJPartial!
          : item.noBJ,
      namaJenis: item.namaJenis,
      berat: item.berat,
      pcs: item.pcs,
      namaUom: item.namaUom,
      datetimeInput: item.datetimeInput,
      isPartial: item.isPartial,
      onDelete: () => _confirmDelete(ctx, deleteLabel, deleteTableName),
    );
  }

  Widget _buildFurnitureWipTab(BjJualInputData data) {
    if (data.furnitureWip.isEmpty) return _buildEmptyTab('Furniture WIP');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: data.furnitureWip.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = data.furnitureWip[index];
        return _buildFurnitureWipCard(item, context);
      },
    );
  }

  Widget _buildFurnitureWipCard(FurnitureWipItem item, BuildContext ctx) {
    return _buildItemCard(
      icon: Icons.sell_rounded,
      accentColor: _kOrangeAccent,
      iconBgColor: const Color(0xFFFFFBEB),
      noLabel: item.noFurnitureWip,
      namaJenis: item.namaJenis,
      berat: item.berat,
      pcs: item.pcs,
      namaUom: item.namaUom,
      datetimeInput: item.datetimeInput,
      isPartial: item.isPartial,
      onDelete: () => _confirmDelete(ctx, item.noFurnitureWip, 'FurnitureWIP'),
    );
  }

  Future<void> _confirmDelete(
    BuildContext ctx,
    String noLabel,
    String tableName,
  ) async {
    final viewModel = context.read<BjJualDetailViewModel>();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red[500],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Hapus Input?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Label $noLabel akan dihapus dari input. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[500],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await viewModel.deleteInput(widget.bjJual.noBJJual, noLabel, tableName);
      await viewModel.fetchInputs(widget.bjJual.noBJJual);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildItemCard({
    required IconData icon,
    required Color accentColor,
    required Color iconBgColor,
    required String noLabel,
    required String namaJenis,
    required double berat,
    required int pcs,
    required String namaUom,
    String? datetimeInput,
    bool? isPartial,
    VoidCallback? onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        namaJenis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isPartial == true)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: const Text(
                      'Partial',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (onDelete != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red[400],
                      ),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      tooltip: 'Hapus',
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // Stats section
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCell(
                    label: 'Berat',
                    value: '${_formatNumber(berat)} kg',
                    icon: Icons.scale_outlined,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                  indent: 8,
                  endIndent: 8,
                ),
                Expanded(
                  child: _buildStatCell(
                    label: 'Qty',
                    value: '${_formatInt(pcs)} $namaUom',
                    icon: Icons.layers_outlined,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),

          // Timestamp footer
          if (datetimeInput != null && datetimeInput.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 11,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(datetimeInput),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Scan Label" untuk menambahkan $label',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BjJualDetailViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade100, width: 1.5),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => viewModel.fetchInputs(widget.bjJual.noBJJual),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatDateTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatNumber(double value) {
    final f = NumberFormat('#,##0.##', 'id_ID');
    return f.format(value);
  }

  String _formatInt(int value) {
    final f = NumberFormat('#,##0', 'id_ID');
    return f.format(value);
  }
}
