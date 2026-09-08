import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Satu baris meta (label : nilai) pada kartu riwayat.
class ProduksiMetaEntry {
  const ProduksiMetaEntry(this.label, this.value);
  final String label;
  final String value;
}

class ProduksiRowData {
  final DateTime? tglProduksi;
  final String? hourStart;
  final String? hourEnd;
  final int shift;
  final bool isLocked;
  final String namaMesin;
  final String? namaRegu;
  final String? outputJenisNama;

  // inject-specific fields (cetakan/warna/material)
  final String? namaCetakan;
  final String? namaWarna;
  final String? namaFurnitureMaterial;

  final String? noProduksi;
  final String? produksiStatus;

  /// Label kolom "Mesin" (default). Modul non-produksi (mis. penerimaan)
  /// bisa menggantinya jadi "Tim Penerima", dll.
  final String mesinLabel;

  /// Sembunyikan baris jam (schedule) + badge "Shift N" — dipakai modul yang
  /// tidak punya konsep jam/shift (penerimaan barang).
  final bool hideTimeRow;

  /// Bila diisi, daftar meta ini menggantikan seluruh meta default
  /// (Mesin/Regu/Output/Cetakan). Dipakai untuk riwayat non-produksi.
  final List<ProduksiMetaEntry>? metaOverride;

  const ProduksiRowData({
    required this.tglProduksi,
    required this.hourStart,
    required this.hourEnd,
    required this.shift,
    required this.isLocked,
    required this.namaMesin,
    this.namaRegu,
    this.outputJenisNama,
    this.namaCetakan,
    this.namaWarna,
    this.namaFurnitureMaterial,
    this.noProduksi,
    this.produksiStatus,
    this.mesinLabel = 'Mesin',
    this.hideTimeRow = false,
    this.metaOverride,
  });
}

class ProductionProduksiList<T> extends StatefulWidget {
  const ProductionProduksiList({
    super.key,
    required this.items,
    required this.dataOf,
    required this.isLoading,
    required this.isFetchingMore,
    required this.scrollController,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.showMesin = true,
  });

  final List<T> items;
  final ProduksiRowData Function(T) dataOf;
  final bool isLoading;
  final bool isFetchingMore;
  final ScrollController scrollController;
  final Future<void> Function(T) onTap;
  final Future<void> Function(T) onEdit;
  final Future<void> Function(T) onDelete;
  final bool showMesin;

  @override
  State<ProductionProduksiList<T>> createState() =>
      _ProductionProduksiListState<T>();
}

class _ProductionProduksiListState<T>
    extends State<ProductionProduksiList<T>> {
  int? _activeIndex;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_activeIndex != null && mounted) setState(() => _activeIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (widget.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 32, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text(
              'Belum ada data produksi',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final hasActive = _activeIndex != null;

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      itemCount: widget.items.length + (widget.isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final item = widget.items[index];
        final data = widget.dataOf(item);
        final isActive = _activeIndex == index;
        return AnimatedOpacity(
          opacity: hasActive && !isActive ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: _ProduksiRow(
            data: data,
            showMesin: widget.showMesin,
            onTap: () => widget.onTap(item),
            onLongPress: (cardBox) async {
              setState(() => _activeIndex = index);
              final overlay =
                  Overlay.of(context).context.findRenderObject() as RenderBox;
              final cardOffset = cardBox.localToGlobal(Offset.zero);
              final cardSize = cardBox.size;

              final value = await showMenu<String>(
                context: context,
                color: Colors.transparent,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                position: RelativeRect.fromRect(
                  Rect.fromLTWH(
                    cardOffset.dx,
                    cardOffset.dy,
                    cardSize.width,
                    cardSize.height,
                  ),
                  Offset.zero & overlay.size,
                ),
                items: [
                  PopupMenuItem<String>(
                    enabled: false,
                    padding: EdgeInsets.zero,
                    child: _ContextMenu(
                      onEdit: () => Navigator.of(context).pop('edit'),
                      onDelete: () => Navigator.of(context).pop('hapus'),
                    ),
                  ),
                ],
              );

              if (mounted) setState(() => _activeIndex = null);
              if (value == 'edit') widget.onEdit(item);
              if (value == 'hapus') widget.onDelete(item);
            },
            onEdit: () => widget.onEdit(item),
            onDelete: () => widget.onDelete(item),
          ),
        );
      },
    );
  }
}

const _kBlue = Color(0xFF1D4ED8);
const _kLocked = Color(0xFFF97316);
const _kGreen = Color(0xFF059669);
const _kRed = Color(0xFFDC2626);
const _kYellow = Color(0xFFD97706);

Color _statusColor(String? status) {
  switch (status) {
    case 'current':
      return _kBlue;
    case 'pending':
      return _kYellow;
    case 'complete':
      return _kGreen;
    default:
      return const Color(0xFFD1D5DB);
  }
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _ProduksiRow extends StatefulWidget {
  const _ProduksiRow({
    required this.data,
    required this.showMesin,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  final ProduksiRowData data;
  final bool showMesin;
  final VoidCallback onTap;
  final Future<void> Function(RenderBox) onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProduksiRow> createState() => _ProduksiRowState();
}

class _ProduksiRowState extends State<_ProduksiRow> {
  final _key = GlobalKey();

  String _fmtDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(date.toLocal());
  }

  String _fmtTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final hasCetakanInfo = (data.namaCetakan ?? '').trim().isNotEmpty ||
        (data.namaWarna ?? '').trim().isNotEmpty ||
        (data.namaFurnitureMaterial ?? '').trim().isNotEmpty;

    final metaItems = data.metaOverride != null
        ? data.metaOverride!
            .map((m) => _MetaItem(label: m.label, value: m.value))
            .toList()
        : <_MetaItem>[
      if (widget.showMesin)
        _MetaItem(
          label: data.mesinLabel,
          value:
              data.namaMesin.trim().isNotEmpty ? data.namaMesin.trim() : '-',
        ),
      if (hasCetakanInfo) ...[
        if ((data.namaCetakan ?? '').trim().isNotEmpty)
          _MetaItem(label: 'Cetakan', value: data.namaCetakan!.trim()),
        if ((data.namaWarna ?? '').trim().isNotEmpty)
          _MetaItem(label: 'Warna', value: data.namaWarna!.trim()),
        _MetaItem(
          label: 'Material',
          value: (data.namaFurnitureMaterial ?? '').trim().isNotEmpty
              ? data.namaFurnitureMaterial!.trim()
              : '-',
        ),
      ] else ...[
        _MetaItem(
          label: 'Regu',
          value: (data.namaRegu ?? '').trim().isNotEmpty
              ? data.namaRegu!.trim()
              : '-',
        ),
        _MetaItem(
          label: 'Output',
          value: (data.outputJenisNama ?? '').trim().isNotEmpty
              ? data.outputJenisNama!.trim()
              : '-',
        ),
      ],
    ];

    final statusColor = _statusColor(data.produksiStatus);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RepaintBoundary(
        key: _key,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: statusColor),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onTap,
                        onLongPress: () {
                          final box = _key.currentContext
                              ?.findRenderObject() as RenderBox?;
                          if (box != null) widget.onLongPress(box);
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  if (data.hideTimeRow)
                                    Expanded(
                                      child: Text(
                                        _fmtDate(data.tglProduksi),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827)),
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      _fmtDate(data.tglProduksi),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827)),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(Icons.schedule_outlined,
                                        size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${_fmtTime(data.hourStart)} - ${_fmtTime(data.hourEnd)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _TitleBadge(text: 'Shift ${data.shift}'),
                                  ],
                                  if (data.isLocked)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: _StatusChip(
                                          label: 'Locked',
                                          foreground: _kLocked,
                                          background: Color(0xFFFFF7ED)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _MetaSection(items: metaItems),
                              if ((data.noProduksi ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    data.noProduksi!.trim(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade400),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Context menu (horizontal Edit | Delete) ───────────────────────────────────

class _ContextMenu extends StatelessWidget {
  const _ContextMenu({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MenuBtn(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: _kBlue,
                  isFirst: true,
                  isLast: false,
                  onTap: onEdit,
                ),
                Container(width: 1, height: 60, color: const Color(0xFFE5E7EB)),
                _MenuBtn(
                  icon: Icons.delete_outline,
                  label: 'Hapus',
                  color: _kRed,
                  isFirst: false,
                  isLast: true,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuBtn extends StatelessWidget {
  const _MenuBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(12) : Radius.zero,
        right: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.10),
          highlightColor: color.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _MetaItem {
  const _MetaItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.items});
  final List<_MetaItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFFE5E7EB),
                ),
              Expanded(child: _MetaColumn(item: items[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaColumn extends StatelessWidget {
  const _MetaColumn({required this.item});
  final _MetaItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
  });
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
