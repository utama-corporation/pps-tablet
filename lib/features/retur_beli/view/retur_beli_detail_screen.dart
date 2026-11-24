import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/scan_label_dialog.dart';
import '../../../common/widgets/success_status_dialog.dart' show StatusAction;
import '../../../common/widgets/warning_status_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/retur_beli.dart';
import '../repository/retur_beli_repository.dart';
import '../widgets/retur_beli_header_dialog.dart';
import 'retur_beli_list_screen.dart' show formatQty;

const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF3F5F8);
const _kBorder = Color(0xFFE2E6EA);
const _kSuccess = Color(0xFF0A7349);
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1D23);

/// Detail Retur Beli (panel kanan master-detail, gaya Retur v3): section
/// "Label Retur" berisi label bahan pendukung yang diretur, FAB Scan untuk
/// menambah label, dan tombol penyelesaian (Potong Tagihan / Diganti).
/// Menambah label langsung mengurangi stoknya; menghapus label / dokumen
/// mengembalikannya.
class ReturBeliDetailScreen extends StatefulWidget {
  final String noReturBeli;
  final ReturBeliRepository? repository;
  final bool Function(String permission)? can;

  /// true = tampil sebagai panel kanan daftar (tanpa AppBar).
  final bool embedded;

  /// Dipanggil setelah data berubah (untuk segarkan daftar kiri).
  final VoidCallback? onChanged;

  /// Dipanggil setelah dokumen dihapus.
  final VoidCallback? onDeleted;

  /// Scan label; default = [ScanLabelDialog]. Untuk test.
  final Future<ReturBeliLabel?> Function(
    BuildContext context,
    Future<String?> Function(String code) onLookup,
  )?
  scanLabel;

  const ReturBeliDetailScreen({
    super.key,
    required this.noReturBeli,
    this.repository,
    this.can,
    this.embedded = false,
    this.onChanged,
    this.onDeleted,
    this.scanLabel,
  });

  @override
  State<ReturBeliDetailScreen> createState() => _ReturBeliDetailScreenState();
}

class _ReturBeliDetailScreenState extends State<ReturBeliDetailScreen> {
  late final ReturBeliRepository _repo =
      widget.repository ?? ReturBeliRepository(api: ApiClient());
  ReturBeliDetail? _detail;
  String _error = '';
  bool _busy = false;

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
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _repo.detail(widget.noReturBeli);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    }
  }

  void _snackError(String msg) => ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  /// Jalankan aksi tulis, muat ulang, beri tahu daftar; galat ke SnackBar.
  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      widget.onChanged?.call();
      return true;
    } catch (e) {
      _snackError(apiErrorMessage(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WarningStatusDialog(
        title: title,
        message: message,
        actions: [
          StatusAction(
            label: 'Batal',
            isPrimary: false,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          StatusAction(
            label: yes,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Aksi ───────────────────────────────────────────────────────────────

  Future<void> _editHeader(ReturBeliDetail d) async {
    final h = d.header;
    final input = await ReturBeliHeaderDialog.show(
      context,
      tanggal: DateTime.tryParse(h.tanggal),
      idSupplier: h.idSupplier,
      keterangan: h.keterangan,
      supplierLocked: d.items.isNotEmpty,
    );
    if (input == null) return;
    await _run(
      () => _repo.update(
        h.noReturBeli,
        tanggal: input.tanggalYmd,
        idSupplier: d.items.isEmpty && input.idSupplier != h.idSupplier
            ? input.idSupplier
            : null,
        keterangan: input.keterangan,
      ),
    );
  }

  /// Satu dialog scan (kamera / ketik). Validasi supplier & sisa dilakukan
  /// di `onLookup` supaya pesan galat tampil langsung di dialog scan.
  Future<void> _scan(ReturBeliDetail d) async {
    ReturBeliLabel? found;
    Future<String?> onLookup(String code) async {
      try {
        final label = await _repo.lookupLabel(code);
        if (!label.available) return 'Label ${label.noLabel} sudah habis terpakai';
        if (label.idSupplier != d.header.idSupplier) {
          return 'Label ${label.noLabel} dari supplier ${label.namaSupplier}, '
              'bukan ${d.header.namaSupplier}';
        }
        if (d.items.any((i) => i.noLabel == label.noLabel)) {
          return 'Label ${label.noLabel} sudah ada di retur ini';
        }
        found = label;
        return null;
      } catch (e) {
        return apiErrorMessage(e);
      }
    }

    final scan = widget.scanLabel;
    if (scan != null) {
      found = await scan(context, onLookup);
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => ScanLabelDialog(
          headerSubtitle: 'Scan label bahan pendukung · ${d.header.namaSupplier}',
          manualHint: 'Scan atau ketik kode label',
          onLookup: onLookup,
        ),
      );
    }
    final label = found;
    if (label == null || !mounted) return;
    final input = await showDialog<(num?, String)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QtyDialog(label: label),
    );
    if (input == null) return;
    await _run(
      () => _repo.addItem(
        d.header.noReturBeli,
        noLabel: label.noLabel,
        qty: input.$1,
        remark: input.$2,
      ),
    );
  }

  Future<void> _deleteItem(ReturBeliDetail d, ReturBeliItem item) async {
    final ok = await _confirm(
      'Hapus ${item.noLabel}?',
      'Label dikeluarkan dari retur ini dan qty ${formatQty(item.qty)} '
          'dikembalikan ke stok label.',
      'Ya, Hapus',
    );
    if (ok) await _run(() => _repo.deleteItem(d.header.noReturBeli, item.idItem));
  }

  Future<void> _complete(ReturBeliDetail d, ReturBeliPenyelesaian p) async {
    final ok = await _confirm(
      p == ReturBeliPenyelesaian.diganti ? 'Diganti Supplier?' : 'Potong Tagihan?',
      p == ReturBeliPenyelesaian.diganti
          ? 'Retur ditandai selesai dengan barang diganti supplier. Barang '
                'pengganti diterima lewat Penerimaan Bahan Pendukung. Setelah '
                'ini label retur tidak bisa diubah lagi.'
          : 'Retur ditandai selesai dan nilainya dipotong dari tagihan '
                'supplier. Setelah ini label retur tidak bisa diubah lagi.',
      p == ReturBeliPenyelesaian.diganti ? 'Ya, Diganti' : 'Ya, Potong Tagihan',
    );
    if (ok) await _run(() => _repo.complete(d.header.noReturBeli, p));
  }

  Future<void> _delete(ReturBeliDetail d) async {
    final ok = await _confirm(
      'Hapus ${d.header.noReturBeli}?',
      d.items.isEmpty
          ? 'Retur beli ini akan dihapus.'
          : 'Retur beli dihapus dan qty ${d.items.length} label dikembalikan ke stok.',
      'Ya, Hapus',
    );
    if (!ok) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repo.delete(d.header.noReturBeli);
      if (!mounted) return;
      widget.onDeleted?.call();
      if (!widget.embedded) Navigator.of(context).maybePop();
    } catch (e) {
      _snackError(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Tampilan ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final canUpdate = _can('returbeli:update');
    final showScanFab = d != null && d.header.isOpen && canUpdate;
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: widget.embedded
          ? null
          : AppBar(title: Text('Retur Beli ${widget.noReturBeli}')),
      floatingActionButton: showScanFab
          ? FloatingActionButton.extended(
              key: const ValueKey('rb-scan'),
              onPressed: _busy ? null : () => _scan(d),
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan'),
            )
          : null,
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(d)),
    );
  }

  Widget _buildBody(ReturBeliDetail? d) {
    if (d == null) {
      if (_error.isEmpty) return const Center(child: CircularProgressIndicator());
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Center(child: Text(_error, style: TextStyle(color: Colors.red.shade700))),
        ],
      );
    }
    // Info header (no/tanggal/supplier/status) tidak diulang — sudah jelas
    // dari kartu yang dipilih di panel kiri, sama seperti Retur v3.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (_busy) const LinearProgressIndicator(),
        _LabelSection(screen: this, detail: d),
        if (d.items.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CompletionSection(screen: this, detail: d),
        ],
      ],
    );
  }
}

// ── Section "Label Retur" ─────────────────────────────────────────────────

class _LabelSection extends StatelessWidget {
  final _ReturBeliDetailScreenState screen;
  final ReturBeliDetail detail;

  const _LabelSection({required this.screen, required this.detail});

  @override
  Widget build(BuildContext context) {
    final open = detail.header.isOpen;
    final canUpdate = screen._can('returbeli:update');
    final canDelete = screen._can('returbeli:delete');
    final busy = screen._busy;
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
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                _StepBadge(number: 1, complete: !open),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Label Retur',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
                Text(
                  '${detail.items.length} label · ${formatQty(detail.totalQty)}',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
                if (open && canUpdate)
                  IconButton(
                    tooltip: 'Ubah header',
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : () => screen._editHeader(detail),
                    icon: const Icon(Icons.edit_outlined, size: 18, color: _kMuted),
                  ),
                if (open && canDelete)
                  IconButton(
                    key: const ValueKey('rb-delete'),
                    tooltip: 'Hapus retur beli',
                    visualDensity: VisualDensity.compact,
                    onPressed: busy ? null : () => screen._delete(detail),
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (detail.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada label — tekan Scan untuk menambah label bahan pendukung',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: detail.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: _kBorder),
              itemBuilder: (context, i) => _LabelRow(
                number: i + 1,
                item: detail.items[i],
                onDelete: open && canUpdate && !busy
                    ? () => screen._deleteItem(detail, detail.items[i])
                    : null,
              ),
            ),
         ],
       ),
     );
   }
}

/// Kartu langkah 2 — penyelesaian, sejajar dengan section "Kirim" di v3.
class _CompletionSection extends StatelessWidget {
  final _ReturBeliDetailScreenState screen;
  final ReturBeliDetail detail;

  const _CompletionSection({required this.screen, required this.detail});

  @override
  Widget build(BuildContext context) {
    final open = detail.header.isOpen;
    final canUpdate = screen._can('returbeli:update');
    final busy = screen._busy;

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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                _StepBadge(number: 2, complete: !open),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Penyelesaian',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (!open)
            Padding(
              padding: const EdgeInsets.all(14),
              child: _DoneBanner(header: detail.header),
            )
          else if (canUpdate)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('rb-penyelesaian-POTONG_TAGIHAN'),
                      onPressed: busy
                          ? null
                          : () => screen._complete(
                              detail,
                              ReturBeliPenyelesaian.potongTagihan,
                            ),
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('Potong Tagihan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade800,
                        side: BorderSide(color: Colors.green.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('rb-penyelesaian-DIGANTI'),
                      onPressed: busy
                          ? null
                          : () => screen._complete(
                              detail,
                              ReturBeliPenyelesaian.diganti,
                            ),
                      icon: const Icon(Icons.autorenew, size: 16),
                      label: const Text('Diganti'),
                      style: FilledButton.styleFrom(backgroundColor: _kPrimary),
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menunggu penyelesaian oleh user yang berwenang.',
                      style: TextStyle(fontSize: 12.5, color: _kMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final int number;
  final bool complete;

  const _StepBadge({required this.number, this.complete = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: complete ? _kSuccess : _kPrimary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Satu baris label: nomor, kode label + nama barang (+ alasan), qty retur.
class _LabelRow extends StatelessWidget {
  final int number;
  final ReturBeliItem item;
  final VoidCallback? onDelete;

  const _LabelRow({required this.number, required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final partial = item.qtyAwal != null && item.qty < item.qtyAwal!;
    return Padding(
      key: ValueKey('rb-item-${item.noLabel}'),
      padding: EdgeInsets.fromLTRB(14, 8, onDelete == null ? 14 : 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$number.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.namaBarang.isEmpty ? item.noLabel : item.namaBarang,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    item.noLabel,
                    if (item.remark.isNotEmpty) 'Alasan: ${item.remark}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatQty(item.qty),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: partial
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              partial ? 'Sebagian' : 'Utuh',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: partial ? Colors.orange.shade800 : Colors.blue.shade700,
              ),
            ),
          ),
          if (onDelete != null)
            IconButton(
              key: ValueKey('rb-item-delete-${item.noLabel}'),
              tooltip: 'Hapus dari retur',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18, color: _kMuted),
            ),
        ],
      ),
    );
  }
}

/// Banner status selesai (Diganti / Potong Tagihan).
class _DoneBanner extends StatelessWidget {
  final ReturBeliHeader header;
  const _DoneBanner({required this.header});

  @override
  Widget build(BuildContext context) {
    final diganti = header.penyelesaian == ReturBeliPenyelesaian.diganti;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSuccess.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kSuccess.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.task_alt_rounded, size: 18, color: _kSuccess),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              diganti
                  ? 'Selesai — diganti supplier. Barang pengganti diterima lewat Penerimaan Bahan Pendukung.'
                  : 'Selesai — dipotong dari tagihan supplier.',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kSuccess,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Input qty retur untuk satu label: default seluruh sisa, maksimal sisa.
/// Hasil: (qty atau null = seluruh sisa, alasan).
class _QtyDialog extends StatefulWidget {
  final ReturBeliLabel label;
  const _QtyDialog({required this.label});

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final _qty = TextEditingController(text: formatQty(widget.label.sisa));
  final _remark = TextEditingController();

  int? get _value => int.tryParse(_qty.text.trim().replaceAll(',', '.'));

  String? get _qtyError {
    final v = _value;
    if (v == null || v <= 0) return 'Qty harus lebih dari 0';
    if (v > widget.label.sisa) return 'Maksimal ${formatQty(widget.label.sisa)}';
    return null;
  }

  @override
  void dispose() {
    _qty.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.label;
    final err = _qtyError;
    final sisa = l.sisa;
    final progress = (l.qtyAwal != null && l.qtyAwal! > 0)
        ? (sisa / l.qtyAwal!).toDouble().clamp(0.0, 1.0)
        : null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: _kPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Qty Retur Label',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.namaBarang.isEmpty ? l.noLabel : l.namaBarang,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: _kText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.noLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _kMuted,
                            ),
                          ),
                        ],
                      ),
                      if (l.namaSupplier.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          l.namaSupplier,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _kMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SISA BISA DIRETUR',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kMuted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatQty(sisa),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: _kPrimary,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (l.qtyAwal != null)
                            Text(
                              'dari ${formatQty(l.qtyAwal!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kMuted,
                              ),
                            ),
                        ],
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: _kBorder,
                            color: _kPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('rb-qty'),
                  controller: _qty,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Qty diretur',
                    hintText: 'Masukkan qty',
                    prefixIcon: const Icon(Icons.dialpad, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorText: err,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remark,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Alasan retur (opsional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('rb-qty-save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: err != null
                        ? null
                        : () {
                            final v = _value!;
                            // Seluruh sisa dikirim sebagai null supaya backend
                            // menutup label persis (tanpa selisih pembulatan).
                            Navigator.of(context).pop((
                              v >= sisa ? null : v,
                              _remark.text,
                            ));
                          },
                    child: const Text('Tambahkan ke Retur'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
