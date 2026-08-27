import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';

import '../model/goods_transfer_header_model.dart';
import '../model/goods_transfer_item_model.dart';
import '../repository/goods_transfer_repository.dart';
import '../view_model/goods_transfer_list_view_model.dart';
import 'goods_transfer_create_screen.dart';

const _kPrimary = Color(0xFF0D47A1);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);
const _kRadius = 12.0;

final NumberFormat _nf = NumberFormat('#,##0.###', 'id_ID');

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(_kRadius),
  border: Border.all(color: _kBorder),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ],
);

class GoodsTransferListScreen extends StatelessWidget {
  const GoodsTransferListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GoodsTransferListViewModel(
        repository: GoodsTransferRepository(api: ApiClient()),
      )..load(),
      child: const _GoodsTransferListView(),
    );
  }
}

class _GoodsTransferListView extends StatelessWidget {
  const _GoodsTransferListView();

  Future<void> _openCreate(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const GoodsTransferCreateDialog(),
    );
    if (context.mounted) {
      context.read<GoodsTransferListViewModel>().reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoodsTransferListViewModel>();

    return Scaffold(
      backgroundColor: _kSurface,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT SECTION: daftar Goods Transfer + FAB ──────────────────
            SizedBox(
              width: 340,
              child: Stack(
                children: [
                  Positioned.fill(child: _TransferListPanel(vm: vm)),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.extended(
                      heroTag: 'goods_transfer_create_fab',
                      onPressed: () => _openCreate(context),
                      backgroundColor: _kPrimary,
                      icon: const Icon(Icons.add),
                      label: const Text('Buat Transfer'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // ── RIGHT SECTION: detail label transfer terpilih ─────────────
            Expanded(child: _TransferDetailPanel(vm: vm)),
          ],
        ),
      ),
    );
  }
}

// ── Left panel: list header ─────────────────────────────────────────────────

class _TransferListPanel extends StatelessWidget {
  final GoodsTransferListViewModel vm;
  const _TransferListPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Goods Transfer',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const Spacer(),
                if (vm.items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${vm.items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(child: _buildBody(context)),
          // ruang kosong di bawah supaya list tidak tertutup FAB
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(vm.error, textAlign: TextAlign.center),
        ),
      );
    }
    if (vm.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Belum ada Goods Transfer',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: vm.items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16, color: _kBorder),
      itemBuilder: (context, index) {
        final item = vm.items[index];
        final selected = vm.selectedNoTransfer == item.noTransfer;
        return _TransferTile(
          item: item,
          selected: selected,
          onTap: () => context.read<GoodsTransferListViewModel>().selectTransfer(
            item.noTransfer,
          ),
        );
      },
    );
  }
}

class _TransferTile extends StatelessWidget {
  final GoodsTransferHeader item;
  final bool selected;
  final VoidCallback onTap;

  const _TransferTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  Color _statusColor() {
    switch (item.status) {
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'RECEIVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String get _tanggalText {
    final d = item.tanggalKirim;
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kPrimary.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.warehouseAsalLabel} → ${item.warehouseTujuanLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.noTransfer} • Oleh ${item.usernameKirim ?? '-'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tanggalText,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Right panel: detail label dari transfer terpilih ────────────────────────

class _TransferDetailPanel extends StatelessWidget {
  final GoodsTransferListViewModel vm;
  const _TransferDetailPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (vm.selectedNoTransfer == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih Goods Transfer di sebelah kiri untuk lihat detail label',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (vm.isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.detailError.isNotEmpty) {
      return Center(child: Text(vm.detailError));
    }

    final detail = vm.selectedDetail;
    if (detail == null) {
      return const Center(child: Text('Data tidak ditemukan'));
    }

    final header = detail.header;
    final status = (header['Status'] ?? '').toString();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                vm.selectedNoTransfer!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Warehouse Asal: ${header['NamaWarehouseAsal'] ?? 'WH #${header['IdWarehouseAsal']}'}',
          ),
          Text(
            'Warehouse Tujuan: ${header['NamaWarehouseTujuan'] ?? 'WH #${header['IdWarehouseTujuan']}'}',
          ),
          if ((header['Catatan'] ?? '').toString().isNotEmpty)
            Text('Catatan: ${header['Catatan']}'),
          if ((header['AlasanTolak'] ?? '').toString().isNotEmpty)
            Text(
              'Alasan Tolak: ${header['AlasanTolak']}',
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 16),
          const Text(
            'Daftar Label',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ...detail.items.map((item) => _DetailLabelTile(item: item)),
          if (status == 'IN_TRANSIT') ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _confirmCancel(context),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Batalkan Transfer'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transfer'),
        content: const Text('Yakin ingin membatalkan transfer ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<GoodsTransferListViewModel>().cancelSelected();
    }
  }
}

class _DetailLabelTile extends StatelessWidget {
  final GoodsTransferItem item;
  const _DetailLabelTile({required this.item});

  String get _qtyBeratText {
    if (item.isPcsUom) {
      return '${_nf.format(item.qty ?? 0)} pcs';
    }
    return '${_nf.format(item.berat ?? 0)} kg';
  }

  String get _lokasiText {
    final asal = (item.blokAsal ?? '').isEmpty
        ? '-'
        : '${item.blokAsal}${item.idLokasiAsal ?? ''}';
    if (item.blokTujuan == null) return asal;
    return '$asal → ${item.blokTujuan}${item.idLokasiTujuan ?? ''}';
  }

  Color _statusColor() {
    switch (item.statusItem) {
      case 'IN_TRANSIT':
        return Colors.orange;
      case 'RECEIVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              item.prefixKategori,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.namaJenis?.isNotEmpty == true
                      ? item.namaJenis!
                      : item.labelCode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D23),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.labelCode,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _qtyBeratText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _lokasiText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.statusItem,
              style: TextStyle(
                color: _statusColor(),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
