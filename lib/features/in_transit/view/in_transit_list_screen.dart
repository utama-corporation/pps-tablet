import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/utils/date_formatter.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_header_model.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_label_scan_model.dart';
import 'package:pps_tablet/features/mapping/model/mapping_lokasi_model.dart';
import 'package:pps_tablet/features/mapping/repository/mapping_repository.dart';

import '../repository/in_transit_repository.dart';
import '../view_model/in_transit_list_view_model.dart';
import 'in_transit_scan_dialog.dart';

// Palet & pola visual meniru fitur Retur v3 yang sudah fix.
const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF3F5F8);
const _kBorder = Color(0xFFE2E6EA);
const _kSelectedBg = Color(0xFFE9F2FF);
const _kSuccess = Color(0xFF0A7349);
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1D23);

({Color color, IconData icon, String label}) _fulfill(String s) {
  switch (s) {
    case 'RECEIVED':
      return (
        color: Colors.green,
        icon: Icons.inventory_2_rounded,
        label: 'Diterima',
      );
    case 'SHIPPED':
      return (
        color: _kPrimary,
        icon: Icons.local_shipping_rounded,
        label: 'Siap Terima',
      );
    case 'PARTIAL':
      return (
        color: Colors.orange,
        icon: Icons.hourglass_bottom_rounded,
        label: 'Sebagian',
      );
    default:
      return (
        color: Colors.grey,
        icon: Icons.radio_button_unchecked_rounded,
        label: 'Belum Diisi',
      );
  }
}

/// Sisi penerimaan Goods Transfer — layout master-detail meniru Retur v3.
class InTransitListScreen extends StatefulWidget {
  const InTransitListScreen({super.key});

  @override
  State<InTransitListScreen> createState() => _InTransitListScreenState();
}

class _InTransitListScreenState extends State<InTransitListScreen> {
  late final InTransitListViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = InTransitListViewModel(
      repository: InTransitRepository(api: ApiClient()),
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InTransitListViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 400, child: _MasterListPanel()),
            Container(width: 1, color: _kBorder),
            Expanded(
              child: Consumer<InTransitListViewModel>(
                builder: (context, vm, _) => vm.selectedNoTransfer == null
                    ? const _EmptyDetailPlaceholder()
                    : _DetailPanel(key: ValueKey(vm.selectedNoTransfer)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Panel kiri ───────────────────────────────────────────────────────────

class _MasterListPanel extends StatefulWidget {
  const _MasterListPanel();

  @override
  State<_MasterListPanel> createState() => _MasterListPanelState();
}

class _MasterListPanelState extends State<_MasterListPanel> {
  final _searchCtl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<GoodsTransferHeader> _filtered(List<GoodsTransferHeader> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (h) =>
              h.noTransfer.toLowerCase().contains(q) ||
              h.warehouseAsalLabel.toLowerCase().contains(q) ||
              h.warehouseTujuanLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InTransitListViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari no. transfer / warehouse...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                suffixIcon: _searchCtl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() => _search = '');
                        },
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
          const Divider(height: 1, color: _kBorder),
          Expanded(child: _buildList(context, vm)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, InTransitListViewModel vm) {
    if (vm.isLoading && vm.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error.isNotEmpty && vm.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(vm.error, textAlign: TextAlign.center),
        ),
      );
    }

    final items = _filtered(vm.items);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            vm.items.isEmpty
                ? 'Tidak ada transfer masuk'
                : 'Tidak ada yang cocok',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransferCard(
              header: item,
              selected: item.noTransfer == vm.selectedNoTransfer,
              onTap: () => context
                  .read<InTransitListViewModel>()
                  .selectTransfer(item.noTransfer),
            ),
          );
        },
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final GoodsTransferHeader header;
  final bool selected;
  final VoidCallback onTap;

  const _TransferCard({
    required this.header,
    required this.selected,
    required this.onTap,
  });

  /// Judul = nomor Goods Transfer dari ERP (kolom Catatan), fallback NoTransfer.
  String get _erpNo {
    final c = (header.catatan ?? '').trim();
    return c.isNotEmpty ? c : header.noTransfer;
  }

  @override
  Widget build(BuildContext context) {
    final f = _fulfill(header.fulfillStatus);

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
                    _erpNo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? const Color(0xFF0C66E4) : _kText,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: f.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(f.icon, size: 11, color: f.color),
                      const SizedBox(width: 4),
                      Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: f.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_erpNo != header.noTransfer) ...[
              const SizedBox(height: 2),
              Text(
                header.noTransfer,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${header.warehouseAsalLabel}  →  ${header.warehouseTujuanLabel}',
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
                Text(
                  formatDateToShortId(header.tanggalKirim),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 3),
                Text(
                  'Terima ${header.receivedCount}/${header.scanCount}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        header.receivedCount >= header.scanCount &&
                            header.scanCount > 0
                        ? Colors.green.shade700
                        : _kMuted,
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

// ── Placeholder ──────────────────────────────────────────────────────────

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
            Icons.move_to_inbox_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih transfer dari daftar di sebelah kiri',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Panel kanan: detail + FAB Scan Terima ────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({super.key});

  Future<void> _openScanFlow(
    BuildContext context,
    InTransitListViewModel vm,
  ) async {
    final noTransfer = vm.selectedNoTransfer;
    if (noTransfer == null) return;

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
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: InTransitScanDialog(
          noTransfer: noTransfer,
          blok: result.blok,
          idLokasi: result.idLokasi,
        ),
      ),
    );
    // Refresh daftar: transfer yang baru saja diterima penuh sudah bukan
    // SHIPPED lagi dan harus lepas dari daftar In Transit.
    await vm.reload();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InTransitListViewModel>();
    final detail = vm.selectedDetail;
    final scans = detail?.scans ?? [];
    final hasPending = scans.any((s) => s.isInTransit);
    final showFab = detail != null && hasPending && !vm.isLoadingDetail;

    return Scaffold(
      backgroundColor: _kSurface,
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              heroTag: 'in_transit_scan_fab',
              onPressed: () => _openScanFlow(context, vm),
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Terima'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => vm.selectTransfer(vm.selectedNoTransfer!),
        child: _buildBody(context, vm),
      ),
    );
  }

  Widget _buildBody(BuildContext context, InTransitListViewModel vm) {
    if (vm.isLoadingDetail && vm.selectedDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.detailError.isNotEmpty && vm.selectedDetail == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              vm.detailError,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      );
    }

    final detail = vm.selectedDetail;
    if (detail == null) return const SizedBox.shrink();

    final scans = detail.scans;
    final receivedCount = scans.where((s) => s.isReceived).length;
    final allReceived = scans.isNotEmpty && receivedCount == scans.length;

    // Header info (no.transfer / status / asal-tujuan / catatan) tidak diulang
    // di sini — sudah jelas dari kartu yang dipilih di panel kiri.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: allReceived ? _kSuccess : _kPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: allReceived
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Label Dikirim',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$receivedCount / ${scans.length} diterima',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: allReceived ? _kSuccess : _kMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _kBorder),
              if (scans.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Belum ada label discan di sisi pengirim',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: scans.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (context, i) => _ScanRow(scan: scans[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanRow extends StatelessWidget {
  final GoodsTransferLabelScan scan;
  const _ScanRow({required this.scan});

  bool get _received => scan.isReceived;

  String get _lokasiTujuan {
    if ((scan.blokTujuan ?? '').isEmpty) return '';
    return '${scan.blokTujuan}${scan.idLokasiTujuan ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _received ? _kSuccess.withValues(alpha: 0.04) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            _received
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: _received ? _kSuccess : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              scan.prefix,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              scan.labelCode,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _received ? Colors.grey.shade500 : _kText,
                decoration: _received ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${scan.pcs} pcs',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
            ),
          ),
          if (_received && _lokasiTujuan.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.location_on_outlined,
              size: 12,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 2),
            Text(
              _lokasiTujuan,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Dialog: pilih lokasi tujuan — grid kotak blok+idlokasi langsung ──────
//
// Semua lokasi (blok + idlokasi) untuk warehouse tujuan ditampilkan sekaligus
// sebagai kotak yang bisa langsung ditekan — tidak perlu pilih blok dulu.

class _PickBlokLokasiDialog extends StatefulWidget {
  final int idWarehouse;
  const _PickBlokLokasiDialog({required this.idWarehouse});

  @override
  State<_PickBlokLokasiDialog> createState() => _PickBlokLokasiDialogState();
}

class _PickBlokLokasiDialogState extends State<_PickBlokLokasiDialog> {
  final _mappingRepository = MappingRepository(api: ApiClient());
  final _searchCtl = TextEditingController();

  bool _loading = true;
  String _error = '';
  String _search = '';
  List<MappingLokasi> _all = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final bloks = (await _mappingRepository.fetchBlokList())
          .where((b) => b.idWarehouse == widget.idWarehouse)
          .toList();
      // Ambil lokasi tiap blok paralel, lalu gabung jadi satu daftar.
      final perBlok = await Future.wait(
        bloks.map((b) => _mappingRepository.fetchLokasiByBlok(b.blok)),
      );
      final flat = perBlok.expand((x) => x).where((l) => l.enable).toList()
        ..sort((a, b) {
          final c = a.blok.compareTo(b.blok);
          return c != 0 ? c : a.idLokasi.compareTo(b.idLokasi);
        });
      _all = flat;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MappingLokasi> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where(
          (l) =>
              l.label.toLowerCase().contains(q) ||
              l.blok.toLowerCase().contains(q) ||
              l.description.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih Lokasi Penerimaan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tekan satu kotak — label yang discan diletakkan di lokasi itu.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtl,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari blok / lokasi...',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                filled: true,
                fillColor: _kSurface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kPrimary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(child: _buildGrid(items)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<MappingLokasi> items) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _all.isEmpty
                ? 'Tidak ada lokasi untuk warehouse ini'
                : 'Tidak ada lokasi yang cocok',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((l) {
          return InkWell(
            onTap: () =>
                Navigator.of(context).pop((blok: l.blok, idLokasi: l.idLokasi)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: _kPrimary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    l.label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
