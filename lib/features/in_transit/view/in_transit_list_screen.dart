import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_header_model.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_item_model.dart';
import 'package:pps_tablet/features/mapping/model/mapping_blok_model.dart';
import 'package:pps_tablet/features/mapping/model/mapping_lokasi_model.dart';
import 'package:pps_tablet/features/mapping/repository/mapping_repository.dart';

import '../repository/in_transit_repository.dart';
import '../view_model/in_transit_list_view_model.dart';
import 'in_transit_scan_dialog.dart';

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

class InTransitListScreen extends StatelessWidget {
  const InTransitListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InTransitListViewModel(
        repository: InTransitRepository(api: ApiClient()),
      )..load(),
      child: const _InTransitListView(),
    );
  }
}

class _InTransitListView extends StatelessWidget {
  const _InTransitListView();

  Future<void> _openScanFlow(
    BuildContext context,
    InTransitListViewModel vm,
  ) async {
    final noTransfer = vm.selectedNoTransfer;
    if (noTransfer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih transfer di daftar sebelah kiri terlebih dahulu',
          ),
        ),
      );
      return;
    }

    // Warehouse tujuan diambil dari transfer yang dipilih (bukan filter
    // manual) — karena tiap transfer sudah punya warehouse tujuan tetap.
    final idWarehouseTujuan = int.tryParse(
      '${vm.selectedDetail?.header['IdWarehouseTujuan'] ?? ''}',
    );
    if (idWarehouseTujuan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data warehouse tujuan tidak ditemukan')),
      );
      return;
    }

    final result = await showDialog<({String blok, int idLokasi})>(
      context: context,
      builder: (_) => _PickBlokLokasiDialog(idWarehouse: idWarehouseTujuan),
    );
    if (result == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      // showDialog nge-push lewat root Navigator, di luar subtree Provider
      // yang membungkus _InTransitListView — jadi vm harus diteruskan ulang
      // secara eksplisit lewat ChangeNotifierProvider.value.
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: InTransitScanDialog(
          noTransfer: noTransfer,
          blok: result.blok,
          idLokasi: result.idLokasi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InTransitListViewModel>();

    return Scaffold(
      backgroundColor: _kSurface,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT SECTION: daftar transfer masuk ─────────────────────
            SizedBox(width: 340, child: _TransferListPanel(vm: vm)),
            const SizedBox(width: 16),
            // ── RIGHT SECTION: daftar label + FAB Scan ──────────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _TransferDetailPanel(vm: vm)),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.extended(
                      heroTag: 'in_transit_scan_fab',
                      onPressed: () => _openScanFlow(context, vm),
                      backgroundColor: _kPrimary,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left panel: list header ─────────────────────────────────────────────────

class _TransferListPanel extends StatelessWidget {
  final InTransitListViewModel vm;
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
                    Icons.move_to_inbox_outlined,
                    size: 16,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'In Transit',
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
              'Tidak ada transfer masuk',
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
          onTap: () => context.read<InTransitListViewModel>().selectTransfer(
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
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
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
  final InTransitListViewModel vm;
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
              'Pilih transfer di sebelah kiri untuk lihat detail label',
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
          // ruang kosong di bawah supaya list tidak tertutup FAB Scan
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _DetailLabelTile extends StatelessWidget {
  final GoodsTransferItem item;
  const _DetailLabelTile({required this.item});

  bool get _received => item.statusItem == 'RECEIVED';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
        color: _received ? Colors.green.withValues(alpha: 0.04) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _received ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: _received ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _received
                        ? Colors.grey.shade500
                        : const Color(0xFF1A1D23),
                    decoration: _received ? TextDecoration.lineThrough : null,
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
        ],
      ),
    );
  }
}

// ── Dialog: pilih Blok + IdLokasi tujuan sebelum mulai scan ─────────────────

class _PickBlokLokasiDialog extends StatefulWidget {
  final int idWarehouse;
  const _PickBlokLokasiDialog({required this.idWarehouse});

  @override
  State<_PickBlokLokasiDialog> createState() => _PickBlokLokasiDialogState();
}

class _PickBlokLokasiDialogState extends State<_PickBlokLokasiDialog> {
  final _mappingRepository = MappingRepository(api: ApiClient());

  bool _isLoadingBlok = false;
  bool _isLoadingLokasi = false;
  String _error = '';

  List<MappingBlok> _blokList = [];
  String? _selectedBlok;

  List<MappingLokasi> _lokasiList = [];
  int? _selectedIdLokasi;

  @override
  void initState() {
    super.initState();
    _loadBlok();
  }

  Future<void> _loadBlok() async {
    setState(() {
      _isLoadingBlok = true;
      _error = '';
    });
    try {
      final all = await _mappingRepository.fetchBlokList();
      _blokList = all
          .where((b) => b.idWarehouse == widget.idWarehouse)
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingBlok = false);
    }
  }

  Future<void> _selectBlok(String blok) async {
    setState(() {
      _selectedBlok = blok;
      _selectedIdLokasi = null;
      _lokasiList = [];
      _isLoadingLokasi = true;
    });
    try {
      _lokasiList = await _mappingRepository.fetchLokasiByBlok(blok);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingLokasi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _selectedBlok != null && _selectedIdLokasi != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Lokasi Penerimaan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Label yang discan akan diletakkan di lokasi ini',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Blok',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_isLoadingBlok)
              const Center(child: CircularProgressIndicator())
            else if (_blokList.isEmpty)
              const Text('Tidak ada blok untuk warehouse ini')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _blokList.map((b) {
                  final selected = _selectedBlok == b.blok;
                  return ChoiceChip(
                    label: Text(b.blok),
                    selected: selected,
                    onSelected: (_) => _selectBlok(b.blok),
                  );
                }).toList(),
              ),
            if (_selectedBlok != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Lokasi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (_isLoadingLokasi)
                const Center(child: CircularProgressIndicator())
              else if (_lokasiList.isEmpty)
                const Text('Tidak ada lokasi untuk blok ini')
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _lokasiList.map((l) {
                        final selected = _selectedIdLokasi == l.idLokasi;
                        return ChoiceChip(
                          label: Text(l.label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedIdLokasi = l.idLokasi),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canApply
                      ? () => Navigator.of(context).pop((
                          blok: _selectedBlok!,
                          idLokasi: _selectedIdLokasi!,
                        ))
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
