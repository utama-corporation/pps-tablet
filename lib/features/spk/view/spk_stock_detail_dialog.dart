import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/spk_models.dart';
import '../repository/spk_repository.dart';
import '../widgets/spk_widgets.dart';
import 'spk_document_dialog.dart';

class SpkStockDetailDialog extends StatefulWidget {
  const SpkStockDetailDialog({
    super.key,
    required this.item,
    required this.repository,
    this.selected = false,
    this.onToggleSelection,
  });

  final SpkStockItem item;
  final SpkRepository repository;

  /// Whether [item] is currently in the "Buat SPK" selection.
  final bool selected;

  /// Adds/removes [item] from the selection; the button is hidden when null.
  final VoidCallback? onToggleSelection;

  @override
  State<SpkStockDetailDialog> createState() => _SpkStockDetailDialogState();
}

class _SpkStockDetailDialogState extends State<SpkStockDetailDialog> {
  late Future<SpkPage<SpkHistoryItem>> future;
  late bool selected = widget.selected;
  int page = 1;

  @override
  void initState() {
    super.initState();
    future = _fetch();
  }

  Future<SpkPage<SpkHistoryItem>> _fetch() async {
    if (!context.read<PermissionViewModel>().can(spkReadPermission)) {
      throw Exception('Tidak punya akses.');
    }
    final result = await widget.repository.history(widget.item.id, page: page);
    if (!mounted) return result;
    if (page > result.totalPages) {
      page = result.totalPages;
      return _fetch();
    }
    return result;
  }

  void reload([int? p]) {
    if (!context.read<PermissionViewModel>().can(spkReadPermission)) return;
    setState(() {
      page = p ?? page;
      future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<PermissionViewModel>().can(spkReadPermission)) {
      return AlertDialog(
        title: const Text('Akses ditolak'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      );
    }
    final i = widget.item;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 960,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<SpkPage<SpkHistoryItem>>(
                future: future,
                builder: (context, snapshot) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildItemCard(i),
                    const SizedBox(height: 12),
                    _buildStatTiles(i),
                    if (widget.onToggleSelection != null) ...[
                      const SizedBox(height: 12),
                      _buildSelectionButton(),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: Color(0xFF44546F),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Riwayat SPK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172B4D),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      SpkFailure(
                        apiErrorMessage(snapshot.error!),
                        retry: reload,
                      )
                    else if (snapshot.data!.items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 36,
                              color: Color(0xFFC1C7D0),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada riwayat SPK untuk barang ini.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B778C),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      for (final history in snapshot.data!.items)
                        _buildHistoryCard(context, i, history),
                      const SizedBox(height: 4),
                      SpkPagination(
                        page: snapshot.data!.page,
                        pages: snapshot.data!.totalPages,
                        loading: false,
                        onPage: reload,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => const SpkDialogHeader(
    icon: Icons.inventory_2_outlined,
    title: 'Detail Barang & Riwayat SPK',
    subtitle: 'Monitoring stok barang jadi dan rekomendasi produksi',
    color: Color(0xFFB45309),
    background: Color(0xFFFFF7ED),
  );

  Widget _buildSelectionButton() {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        key: const ValueKey('spk-detail-toggle-selection'),
        style: selected
            ? FilledButton.styleFrom(backgroundColor: const Color(0xFF6B778C))
            : null,
        onPressed: () {
          widget.onToggleSelection!();
          setState(() => selected = !selected);
        },
        icon: Icon(
          selected
              ? Icons.remove_done_rounded
              : Icons.playlist_add_check_rounded,
        ),
        label: Text(selected ? 'Batalkan Pilihan' : 'Pilih untuk Buat SPK'),
      ),
    );
  }

  Widget _buildItemCard(SpkStockItem i) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i.name.trim().isEmpty ? '—' : i.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172B4D),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                i.code.isEmpty ? '—' : i.code,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF44546F),
                ),
              ),
              if (i.uom.trim().isNotEmpty) ...[
                const Text(
                  ' · ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B778C),
                  ),
                ),
                Text(
                  i.uom.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF44546F),
                  ),
                ),
              ],
              const Text(
                ' · ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B778C),
                ),
              ),
              SpkStatusLozenge(i.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTiles(SpkStockItem i) {
    final tiles =
        <({String label, String value, IconData icon, Color? valueColor})>[
          (
            label: 'Stok saat ini',
            value: spkQty(i.stock),
            icon: Icons.warehouse_outlined,
            valueColor: i.stock <= 0 ? const Color(0xFFB91C1C) : null,
          ),
          (
            label: 'Stok minimum',
            value: spkQty(i.min),
            icon: Icons.vertical_align_bottom_rounded,
            valueColor: null,
          ),
          (
            label: 'Stok maksimum',
            value: spkQty(i.max),
            icon: Icons.vertical_align_top_rounded,
            valueColor: null,
          ),
          (
            label: 'MPQ',
            value: spkQty(i.mpq),
            icon: Icons.view_module_outlined,
            valueColor: null,
          ),
          (
            label: 'Qty rekomendasi',
            value: spkQty(i.recommendation),
            icon: Icons.assignment_outlined,
            valueColor: i.recommendation > 0 ? const Color(0xFFB45309) : null,
          ),
        ];
    return Row(
      children: [
        for (final (index, tile) in tiles.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(tile.icon, size: 14, color: const Color(0xFF6B778C)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tile.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B778C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tile.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tile.valueColor ?? const Color(0xFF172B4D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    SpkStockItem item,
    SpkHistoryItem h,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (context.read<PermissionViewModel>().can(spkReadPermission)) {
              showDialog<void>(
                context: context,
                builder: (_) => SpkDocumentDialog(
                  code: h.code,
                  repository: widget.repository,
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${h.code} · ${spkDate(h.date)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF172B4D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SPK: ${h.status} · Baris: ${h.lineStatus}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF44546F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Qty SPK: ${spkQty(h.qty)} · Selesai: ${spkQty(h.completed)} ${item.uom}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF44546F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stok saat SPK: ${spkQty(h.stock)} · Rekomendasi: ${spkQty(h.recommendation)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B778C),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6B778C),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
