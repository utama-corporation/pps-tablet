import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/common/widgets/scan_label_dialog.dart';
import 'package:pps_tablet/common/widgets/success_status_dialog.dart'
    show StatusAction;
import 'package:pps_tablet/common/widgets/warning_status_dialog.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/utils/date_formatter.dart';

import '../model/goods_transfer_header_model.dart';
import '../model/goods_transfer_item_model.dart';
import '../model/goods_transfer_label_scan_model.dart';
import '../repository/goods_transfer_repository.dart';
import '../view_model/goods_transfer_list_view_model.dart';

// Palet & pola visual meniru fitur Retur v3 (retur_v3_list_screen.dart /
// retur_v3_detail_screen.dart) yang sudah fix.
const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF3F5F8);
const _kBorder = Color(0xFFE2E6EA);
const _kSelectedBg = Color(0xFFE9F2FF);
const _kSuccess = Color(0xFF0A7349);
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1D23);

const _kStatusFilters = <String, String>{
  'OPEN': 'Belum Diisi',
  'PARTIAL': 'Sebagian',
  'READY': 'Siap Kirim',
  'SHIPPED': 'Dikirim',
  'RECEIVED': 'Diterima',
};

// ── helper status pemenuhan ────────────────────────────────────────────────

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
        label: 'Dikirim',
      );
    case 'READY':
      return (
        color: _kPrimary,
        icon: Icons.check_circle_rounded,
        label: 'Siap Kirim',
      );
    case 'PARTIAL':
      return (
        color: Colors.orange,
        icon: Icons.hourglass_bottom_rounded,
        label: 'Sebagian',
      );
    case 'CANCELLED':
      return (
        color: Colors.grey,
        icon: Icons.cancel_outlined,
        label: 'Dibatalkan',
      );
    case 'REJECTED':
      return (color: Colors.red, icon: Icons.block_rounded, label: 'Ditolak');
    default:
      return (
        color: Colors.grey,
        icon: Icons.radio_button_unchecked_rounded,
        label: 'Belum Diisi',
      );
  }
}

/// Layout master-detail tablet landscape (meniru Retur v3): daftar transfer
/// di panel kiri (kartu) + detail transfer terpilih langsung di panel kanan.
class GoodsTransferListScreen extends StatefulWidget {
  const GoodsTransferListScreen({super.key});

  @override
  State<GoodsTransferListScreen> createState() =>
      _GoodsTransferListScreenState();
}

class _GoodsTransferListScreenState extends State<GoodsTransferListScreen> {
  late final GoodsTransferListViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = GoodsTransferListViewModel(
      repository: GoodsTransferRepository(api: ApiClient()),
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GoodsTransferListViewModel>.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 400, child: _MasterListPanel()),
            Container(width: 1, color: _kBorder),
            Expanded(
              child: Consumer<GoodsTransferListViewModel>(
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

// ── Panel kiri: search + filter + daftar kartu ────────────────────────────

class _MasterListPanel extends StatefulWidget {
  const _MasterListPanel();

  @override
  State<_MasterListPanel> createState() => _MasterListPanelState();
}

class _MasterListPanelState extends State<_MasterListPanel> {
  final _searchCtl = TextEditingController();
  String _search = '';
  String? _statusFilter;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<GoodsTransferHeader> _filtered(List<GoodsTransferHeader> all) {
    final q = _search.trim().toLowerCase();
    return all.where((h) {
      if (_statusFilter != null && h.fulfillStatus != _statusFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return h.noTransfer.toLowerCase().contains(q) ||
          h.warehouseAsalLabel.toLowerCase().contains(q) ||
          h.warehouseTujuanLabel.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openFilter() async {
    final picked = await showDialog<String?>(
      context: context,
      builder: (_) => _StatusFilterDialog(initial: _statusFilter),
    );
    // dialog mengembalikan '' untuk reset, null kalau ditutup tanpa aksi.
    if (picked == null) return;
    setState(() => _statusFilter = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoodsTransferListViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchAndFilterBar(
            controller: _searchCtl,
            onChanged: (v) => setState(() => _search = v),
            onClear: () {
              _searchCtl.clear();
              setState(() => _search = '');
            },
            hasActiveFilter: _statusFilter != null,
            onOpenFilter: _openFilter,
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(child: _buildList(context, vm)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, GoodsTransferListViewModel vm) {
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
                ? 'Belum ada Goods Transfer'
                : 'Tidak ada transfer yang cocok',
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
                  .read<GoodsTransferListViewModel>()
                  .selectTransfer(item.noTransfer),
            ),
          );
        },
      ),
    );
  }
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
                hintText: 'Cari no. transfer / warehouse...',
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
                  tooltip: 'Filter status',
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

class _StatusFilterDialog extends StatefulWidget {
  final String? initial;
  const _StatusFilterDialog({required this.initial});

  @override
  State<_StatusFilterDialog> createState() => _StatusFilterDialogState();
}

class _StatusFilterDialogState extends State<_StatusFilterDialog> {
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
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
                    'Filter Status',
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('RESET'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _status ?? ''),
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

// ── Kartu transfer (item daftar) ─────────────────────────────────────────

class _TransferCard extends StatelessWidget {
  final GoodsTransferHeader header;
  final bool selected;
  final VoidCallback onTap;

  const _TransferCard({
    required this.header,
    required this.selected,
    required this.onTap,
  });

  /// Judul kartu = nomor Goods Transfer dari ERP (disimpan di kolom Catatan).
  /// Fallback ke NoTransfer PPS kalau kosong.
  String get _erpNo {
    final c = (header.catatan ?? '').trim();
    return c.isNotEmpty ? c : header.noTransfer;
  }

  @override
  Widget build(BuildContext context) {
    final filled = header.isFilled; // semua baris permintaan sudah terisi

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
                      color: selected
                          ? const Color(0xFF0C66E4)
                          : const Color(0xFF1A1D23),
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _FulfillChip(status: header.fulfillStatus),
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
                // Kiri: tanggal + pengirim (ellipsis kalau sempit).
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
                        formatDateToShortId(header.tanggalKirim),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if ((header.usernameKirim ?? '').isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            header.usernameKirim!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Kanan: indikator "item terisi" — gaya sama dengan "Terima
                // X/Y" di kartu In Transit, dipatok rata kanan.
                Icon(
                  Icons.inventory_2_outlined,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 3),
                Text(
                  'Terisi ${header.completedLines}/${header.totalLines}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.green.shade700 : _kMuted,
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

class _FulfillChip extends StatelessWidget {
  final String status;
  const _FulfillChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final f = _fulfill(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    );
  }
}

// ── Panel kanan: placeholder ─────────────────────────────────────────────

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
            Icons.local_shipping_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih Goods Transfer dari daftar di sebelah kiri',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Panel kanan: detail transfer terpilih ────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({super.key});

  Future<String?> _handleScan(
    BuildContext context,
    GoodsTransferListViewModel vm,
    String code,
  ) async {
    final result = await vm.attemptScan(code);
    if (result.success) return null;

    if (result.needsConfirmation) {
      if (!context.mounted) return null;
      final s = result.suggestion!;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WarningStatusDialog(
          title: 'Pcs Label Melebihi Kebutuhan',
          message: s.message,
          actions: [
            StatusAction(
              label: 'Batal',
              isPrimary: false,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            StatusAction(
              label: 'Ya, Catat ${s.pcsNeeded} pcs',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return 'Scan dibatalkan — pcs label melebihi sisa kebutuhan';
      }
      final partial = await vm.confirmPartialScan(code);
      return partial.success ? null : partial.error;
    }
    return result.error;
  }

  Future<void> _openScanDialog(
    BuildContext context,
    GoodsTransferListViewModel vm,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        headerSubtitle: 'Scan label untuk memenuhi permintaan transfer',
        manualHint: 'BA.0000000001 / BB.0000000001',
        acceptedLabels: const [
          (prefix: 'BA.', label: 'Barang Jadi'),
          (prefix: 'BB.', label: 'Furniture WIP'),
        ],
        onLookup: (code) => _handleScan(context, vm, code),
      ),
    );
    if (context.mounted) {
      context.read<GoodsTransferListViewModel>().reload();
    }
  }

  Future<void> _confirmKirim(
    BuildContext context,
    GoodsTransferListViewModel vm,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WarningStatusDialog(
        title: 'Tandai Kirim?',
        message:
            'Semua permintaan sudah terpenuhi. Setelah ditandai kirim, transfer '
            'terkunci — label tidak bisa discan atau dibatalkan lagi.',
        actions: [
          StatusAction(
            label: 'Batal',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          StatusAction(
            label: 'Ya, Kirim',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final err = await vm.markKirim();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GoodsTransferListViewModel>();
    final detail = vm.selectedDetail;
    final status = (detail?.header['Status'] ?? '').toString();
    final allComplete = detail?.allLinesComplete ?? false;
    final loading = vm.isLoadingDetail;

    Widget? fab;
    if (detail != null && !loading && status == 'IN_TRANSIT') {
      fab = allComplete
          ? FloatingActionButton.extended(
              heroTag: 'goods_transfer_kirim_fab',
              onPressed: () => _confirmKirim(context, vm),
              backgroundColor: _kSuccess,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Kirim'),
            )
          : FloatingActionButton.extended(
              heroTag: 'goods_transfer_scan_fab',
              onPressed: () => _openScanDialog(context, vm),
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan'),
            );
    }

    return Scaffold(
      backgroundColor: _kSurface,
      floatingActionButton: fab,
      body: RefreshIndicator(
        onRefresh: () => vm.selectTransfer(vm.selectedNoTransfer!),
        child: _buildBody(context, vm),
      ),
    );
  }

  Widget _buildBody(BuildContext context, GoodsTransferListViewModel vm) {
    if (vm.isLoadingDetail && vm.selectedDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.detailError.isNotEmpty && vm.selectedDetail == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 12),
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

    final header = detail.header;
    final fulfillStatus = (header['FulfillStatus'] ?? 'OPEN').toString();
    final status = (header['Status'] ?? '').toString();
    final locked = status != 'IN_TRANSIT';
    final allComplete = detail.allLinesComplete;
    final totalRequired = detail.lines.fold<int>(
      0,
      (a, l) => a + l.pcsRequired,
    );
    final totalScanned = detail.lines.fold<int>(0, (a, l) => a + l.pcsScanned);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _SectionCard(
          // Header section meniru "Label Dikirim" di In Transit: badge bulat
          // (centang hijau saat semua permintaan terisi) + hitungan di kanan.
          leading: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: allComplete ? _kSuccess : _kPrimary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              allComplete ? Icons.check_rounded : Icons.qr_code_scanner_rounded,
              size: allComplete ? 14 : 13,
              color: Colors.white,
            ),
          ),
          title: 'Permintaan',
          trailing: detail.lines.isEmpty
              ? null
              : Text(
                  '$totalScanned / $totalRequired pcs',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: allComplete ? _kSuccess : _kMuted,
                  ),
                ),
          child: detail.lines.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Belum ada baris permintaan dari Ascend',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: detail.lines.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (context, i) => _LineTile(
                    number: i + 1,
                    line: detail.lines[i],
                    locked: locked,
                    onUndoScan: (idScan) => context
                        .read<GoodsTransferListViewModel>()
                        .undoScan(idScan),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _StatusBanner(
          fulfillStatus: fulfillStatus,
          allComplete: detail.allLinesComplete,
        ),
      ],
    );
  }
}

// ── Banner status di bawah section permintaan ───────────────────────────

class _StatusBanner extends StatelessWidget {
  final String fulfillStatus;
  final bool allComplete;

  const _StatusBanner({required this.fulfillStatus, required this.allComplete});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;
    late final String text;

    switch (fulfillStatus) {
      case 'RECEIVED':
        icon = Icons.inventory_2_rounded;
        color = _kSuccess;
        text = 'Semua label sudah diterima di warehouse tujuan.';
        break;
      case 'SHIPPED':
        icon = Icons.local_shipping_rounded;
        color = _kPrimary;
        text =
            'Transfer sudah ditandai kirim — menunggu penerimaan di tujuan. '
            'Scan terkunci.';
        break;
      case 'CANCELLED':
        icon = Icons.cancel_outlined;
        color = _kMuted;
        text = 'Transfer dibatalkan.';
        break;
      case 'REJECTED':
        icon = Icons.block_rounded;
        color = Colors.red;
        text = 'Transfer ditolak di tujuan.';
        break;
      default:
        if (allComplete) {
          icon = Icons.check_circle_rounded;
          color = _kSuccess;
          text =
              'Semua permintaan sudah terpenuhi — tekan tombol Kirim di kanan '
              'bawah.';
        } else {
          icon = Icons.qr_code_scanner_rounded;
          color = _kMuted;
          text =
              'Scan label lewat tombol Scan di kanan bawah. Nomor label & pcs '
              'yang tercatat muncul sebagai chip di tiap baris.';
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card (meniru pola card Retur v3) ─────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.leading,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          child,
        ],
      ),
    );
  }
}

// ── Tile per baris permintaan (meniru _TurnoverTargetTile Retur v3) ──────

class _LineTile extends StatelessWidget {
  final int number;
  final GoodsTransferLine line;
  final bool locked;
  final Future<String?> Function(int idScan) onUndoScan;

  const _LineTile({
    required this.number,
    required this.line,
    required this.locked,
    required this.onUndoScan,
  });

  @override
  Widget build(BuildContext context) {
    final scanned = line.pcsScanned;
    final target = line.pcsRequired;
    final fulfilled = line.isComplete;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: fulfilled
                        ? _kSuccess
                        : _kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: fulfilled
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    (line.namaJenis ?? '').isNotEmpty
                        ? line.namaJenis!
                        : '${line.kategoriLabel} #${line.idJenis}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                ),
                Text(
                  '$scanned/$target pcs',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fulfilled ? _kSuccess : _kMuted,
                  ),
                ),
              ],
            ),
            if (line.scans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: line.scans
                    .map(
                      (s) => _ScanChip(
                        scan: s,
                        onUndo: locked ? null : onUndoScan,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanChip extends StatelessWidget {
  final GoodsTransferLabelScan scan;
  final Future<String?> Function(int idScan)? onUndo;

  const _ScanChip({required this.scan, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final received = scan.isReceived;
    final canUndo = onUndo != null && scan.isInTransit;
    return Chip(
      label: Text(
        '${scan.labelCode} (${scan.pcs})',
        style: TextStyle(
          fontSize: 10.5,
          decoration: received ? TextDecoration.lineThrough : null,
          color: received ? Colors.grey.shade500 : null,
        ),
      ),
      avatar: Icon(
        received ? Icons.check_circle : Icons.local_shipping_outlined,
        size: 13,
        color: received ? _kSuccess : _kPrimary,
      ),
      onDeleted: canUndo
          ? () async {
              final err = await onUndo!(scan.id);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
            }
          : null,
      deleteIconColor: Colors.red.shade400,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
