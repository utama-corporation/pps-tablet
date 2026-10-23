// lib/features/production/crusher/widgets/crusher_input_group_popover.dart
// Crusher Input Group Popover - Simplified version with BB + Bonggolan only

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/crusher_production_input_view_model.dart';

/// Cek apakah bucket TEMP untuk labelCode berisi item partial
/// (BB, Reject & Mixer yang punya partial)
bool _hasPartialTempForLabel(
    CrusherProductionInputViewModel vm,
    String labelCode,
    ) {
  final b = vm.getTemporaryDataForLabel(labelCode.trim());
  if (b == null || b.isEmpty) return false;

  final hasBbPart =
      b.bbItems.any((e) => (e.noBBPartial ?? '').trim().isNotEmpty);
  final hasRejectPart = b.reject.any(
    (e) => (e.noRejectPartial ?? '').trim().isNotEmpty || e.isPartialRow,
  );
  final hasMixerPart = b.mixerPartials.any(
    (e) => (e.noMixerPartial ?? '').trim().isNotEmpty || e.isPartialRow,
  );

  return hasBbPart || hasRejectPart || hasMixerPart;
}

/// ✅ Model untuk summary data - HANYA BERAT
class TooltipSummary {
  final double totalBerat;

  const TooltipSummary({
    required this.totalBerat,
  });
}

/// Popover tooltip di sebelah KIRI anchor tile.
class InputsGroupTooltip extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color headerColor;
  final List<Widget> Function() childrenBuilder;
  final VoidCallback onClose;
  final List<Widget> actions;
  final double width;
  final double maxHeight;
  final List<String>? tableHeaders;
  final List<int>? columnFlexes;
  final VoidCallback? onDeleteAllTemp;
  final bool deleteAllTempDisabled;
  final String deleteAllTempLabel;
  final bool canDelete;
  final Future<bool> Function(List<dynamic> items)? onBulkDelete;

  /// ✅ NEW: Builder untuk summary total
  final TooltipSummary Function()? summaryBuilder;

  const InputsGroupTooltip({
    super.key,
    required this.title,
    this.subtitle,
    required this.headerColor,
    required this.childrenBuilder,
    required this.onClose,
    required this.maxHeight,
    this.actions = const [],
    this.width = 340,
    this.tableHeaders,
    this.columnFlexes,
    this.onDeleteAllTemp,
    this.deleteAllTempDisabled = false,
    this.deleteAllTempLabel = 'Hapus Semua (TEMP)',
    this.canDelete = false,
    this.onBulkDelete,
    this.summaryBuilder,
  });

  @override
  State<InputsGroupTooltip> createState() => _InputsGroupTooltipState();
}

class _InputsGroupTooltipState extends State<InputsGroupTooltip> {
  bool _selectionMode = false;
  final Set<int> _selectedIndices = <int>{};
  final Map<int, dynamic> _rowItems = <int, dynamic>{};

  void _enterSelectionMode() {
    if (!widget.canDelete) return;
    setState(() {
      _selectionMode = true;
      _selectedIndices.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _toggleSelected(int index, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedIndices.add(index);
      } else {
        _selectedIndices.remove(index);
      }
    });
  }

  Future<void> _confirmBulkDelete() async {
    if (_selectedIndices.isEmpty) return;
    if (widget.onBulkDelete == null) return;

    final indices = _selectedIndices.toList()..sort();

    final itemsToDelete = <dynamic>[];
    for (final i in indices) {
      final item = _rowItems[i];
      if (item != null) {
        itemsToDelete.add(item);
      }
    }

    final count = itemsToDelete.length;
    if (count == 0) return;

    setState(() {
      _selectionMode = false;
      _selectedIndices.clear();
    });

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootCtx = rootNavigator.context;

    widget.onClose();

    final confirmed = await showDialog<bool>(
      context: rootCtx,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus $count item?'),
        content: Text(
          'Yakin ingin menghapus $count item yang sudah dipilih?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ??
        false;

    if (!confirmed) return;

    final success = await widget.onBulkDelete!(itemsToDelete);

    await Future.delayed(const Duration(milliseconds: 300));

    if (rootCtx.mounted) {
      if (success) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          SnackBar(
            content: Text('✅ Berhasil menghapus $count item'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          SnackBar(
            content: const Text('❌ Gagal menghapus item'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSelectableRow(Widget child, int index) {
    bool canSelect = false;

    if (widget.canDelete && child is TooltipTableRow && !child.isTempRow) {
      canSelect = true;

      if (child.itemData != null) {
        _rowItems[index] = child.itemData;
      }

      child = TooltipTableRow(
        columns: child.columns,
        columnFlexes: child.columnFlexes,
        onDelete: child.onDelete,
        deleteColor: child.deleteColor,
        showDelete: !_selectionMode && child.showDelete,
        isHighlighted: child.isHighlighted,
        isDisabled: child.isDisabled,
        isTempRow: child.isTempRow,
        itemData: child.itemData,
      );
    }

    Widget content = child;

    if (_selectionMode && canSelect) {
      content = Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: _selectedIndices.contains(index),
              onChanged: (v) => _toggleSelected(index, v),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: content),
        ],
      );
    }

    return InkWell(
      onTap: () {
        if (_selectionMode && canSelect) {
          final now = _selectedIndices.contains(index);
          _toggleSelected(index, !now);
        }
      },
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider =
    Divider(height: 0, thickness: 0.6, color: Colors.grey.shade300);
    final double clampedMaxH = widget.maxHeight.clamp(180.0, 520.0).toDouble();
    final bool canDeleteExisting = widget.canDelete;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.width,
        maxWidth: widget.width,
        maxHeight: clampedMaxH,
      ),
      child: Material(
        color: Colors.transparent,
        child: Material(
          color: Colors.white,
          elevation: 12,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: widget.width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // =======================================================
                // HEADER
                // =======================================================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.headerColor.withOpacity(0.65),
                        widget.headerColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.qr_code_2,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final vm = context
                                .read<CrusherProductionInputViewModel>();
                            final hasTempForThis =
                            vm.hasTemporaryDataForLabel(widget.title);
                            final showTempChip = hasTempForThis;
                            final chipText = 'PENDING';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.title.isEmpty
                                            ? '-'
                                            : widget.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (showTempChip) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                          border: Border.all(
                                            color:
                                            Colors.white.withOpacity(0.35),
                                          ),
                                        ),
                                        child: Text(
                                          chipText,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: !canDeleteExisting
                            ? 'Tidak punya izin menghapus data existing'
                            : _selectionMode
                            ? 'Keluar mode hapus'
                            : 'Pilih data existing untuk dihapus',
                        icon: Icon(
                          _selectionMode ? Icons.close_rounded : Icons.edit,
                          color: canDeleteExisting
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                        ),
                        onPressed: !canDeleteExisting
                            ? null
                            : () {
                          if (_selectionMode) {
                            _exitSelectionMode();
                          } else {
                            _enterSelectionMode();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                divider,

                // =======================================================
                // TABLE HEADER
                // =======================================================
                if (widget.tableHeaders != null &&
                    widget.tableHeaders!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_selectionMode && canDeleteExisting)
                          const SizedBox(width: 36),
                        ...widget.tableHeaders!.asMap().entries.map(
                              (entry) {
                            final index = entry.key;
                            final header = entry.value;

                            if (index == widget.tableHeaders!.length - 1) {
                              return SizedBox(
                                width: 60,
                                child: Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            final flex = (widget.columnFlexes != null &&
                                index < widget.columnFlexes!.length &&
                                widget.columnFlexes![index] > 0)
                                ? widget.columnFlexes![index]
                                : 1;

                            return Expanded(
                              flex: flex,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < widget.tableHeaders!.length - 1
                                      ? 8
                                      : 0,
                                ),
                                child: Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // =======================================================
                // BODY
                // =======================================================
                Flexible(
                  child: Consumer<CrusherProductionInputViewModel>(
                    builder: (context, vm, _) {
                      final children = widget.childrenBuilder();

                      if (children.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Tidak ada data',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      _rowItems.clear();

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        itemBuilder: (_, i) =>
                            _buildSelectableRow(children[i], i),
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: Colors.grey.shade200,
                        ),
                        itemCount: children.length,
                      );
                    },
                  ),
                ),

                // =======================================================
                // ✅ SUMMARY SECTION (Total Berat Sejajar)
                // =======================================================
                if (widget.summaryBuilder != null)
                  Consumer<CrusherProductionInputViewModel>(
                    builder: (context, vm, _) {
                      final summary = widget.summaryBuilder!();
                      final flexes = widget.columnFlexes ?? [];

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: widget.headerColor.withOpacity(0.08),
                          border: Border(
                            top: BorderSide(
                              color: widget.headerColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // ✅ Align dengan checkbox space
                            if (_selectionMode && canDeleteExisting)
                              const SizedBox(width: 36),

                            // ✅ Build kolom summary dengan flex yang SAMA dengan data rows
                            ...() {
                              final List<Widget> summaryColumns = [];

                              if (flexes.isEmpty) {
                                // Fallback jika tidak ada columnFlexes
                                summaryColumns.add(
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: widget.headerColor,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                summaryColumns.add(
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '${summary.totalBerat.toStringAsFixed(2)} kg',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: widget.headerColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                // ✅ Render sesuai jumlah kolom (gunakan flex yang sama)
                                for (int i = 0; i < flexes.length; i++) {
                                  if (i == flexes.length - 1) {
                                    // Kolom terakhir = Total Berat
                                    summaryColumns.add(
                                      Expanded(
                                        flex: flexes[i],
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Text(
                                            '${summary.totalBerat.toStringAsFixed(2)} kg',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: widget.headerColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else if (i == 0) {
                                    // Kolom pertama = TOTAL label
                                    summaryColumns.add(
                                      Expanded(
                                        flex: flexes[i],
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: widget.headerColor,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Kolom tengah = kosong (untuk alignment)
                                    summaryColumns.add(
                                      Expanded(
                                        flex: flexes[i],
                                        child: const SizedBox.shrink(),
                                      ),
                                    );
                                  }
                                }
                              }

                              return summaryColumns;
                            }(),

                            // Spacer untuk kolom action (fixed 60px)
                            const SizedBox(width: 60),
                          ],
                        ),
                      );
                    },
                  ),

                divider,

                // =======================================================
                // FOOTER
                // =======================================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: _selectionMode && canDeleteExisting
                        ? [
                      TextButton(
                        onPressed: _exitSelectionMode,
                        child: const Text('Batal'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _selectedIndices.isEmpty
                            ? null
                            : _confirmBulkDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          'Hapus (${_selectedIndices.length})',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ]
                        : [
                      if (widget.onDeleteAllTemp != null)
                        TextButton.icon(
                          onPressed: widget.deleteAllTempDisabled
                              ? null
                              : widget.onDeleteAllTemp,
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                          ),
                          label: Text(widget.deleteAllTempLabel),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      const Spacer(),
                      ...widget.actions,
                    ],
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

/// Table row dengan itemData
class TooltipTableRow extends StatelessWidget {
  final List<String> columns;
  final List<int>? columnFlexes;
  final VoidCallback? onDelete;
  final Color? deleteColor;
  final bool showDelete;
  final bool isHighlighted;
  final bool isDisabled;
  final bool isTempRow;
  final dynamic itemData;

  const TooltipTableRow({
    super.key,
    required this.columns,
    this.columnFlexes,
    this.onDelete,
    this.deleteColor,
    this.showDelete = true,
    this.isHighlighted = false,
    this.isDisabled = false,
    this.isTempRow = false,
    this.itemData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.yellow.shade50 : Colors.transparent,
      ),
      child: Row(
        children: [
          ...columns.asMap().entries.map((entry) {
            final index = entry.key;
            final value = entry.value;

            final flex = (columnFlexes != null &&
                index < columnFlexes!.length &&
                columnFlexes![index] > 0)
                ? columnFlexes![index]
                : 1;

            return Expanded(
              flex: flex,
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < columns.length - 1 ? 8 : 0,
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
          SizedBox(
            width: 60,
            child: Center(
              child: showDelete && onDelete != null
                  ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDisabled ? null : onDelete,
                  borderRadius: BorderRadius.circular(6),
                  child: Opacity(
                    opacity: isDisabled ? 0.4 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: deleteColor ?? Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: deleteColor ?? Colors.red.shade200,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isDisabled
                            ? Icons.lock_outline
                            : Icons.delete_outline,
                        size: 16,
                        color: deleteColor ?? Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              )
                  : const Text(
                '-',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile anchor
class GroupTooltipAnchorTile extends StatefulWidget {
  final String title;
  final String? headerSubtitle;
  final Color color;
  final List<Widget> Function() detailsBuilder;
  final List<String>? tableHeaders;
  final List<int>? columnFlexes;
  final bool canDelete;
  final double popoverWidth;
  final double gap;
  final VoidCallback? onUpdate;
  final Future<bool> Function(List<dynamic> items)? onBulkDelete;

  /// ✅ NEW: Summary builder
  final TooltipSummary Function()? summaryBuilder;

  const GroupTooltipAnchorTile({
    super.key,
    required this.title,
    required this.color,
    required this.detailsBuilder,
    this.headerSubtitle,
    this.tableHeaders,
    this.columnFlexes,
    this.canDelete = false,
    this.popoverWidth = 350,
    this.gap = 16,
    this.onUpdate,
    this.onBulkDelete,
    this.summaryBuilder,
  });

  @override
  State<GroupTooltipAnchorTile> createState() =>
      _GroupTooltipAnchorTileState();
}

class _GroupTooltipAnchorTileState extends State<GroupTooltipAnchorTile> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _show() {
    if (_entry != null) return;

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final padding = media.padding;

    final rb = context.findRenderObject() as RenderBox;
    final targetTopLeft = rb.localToGlobal(Offset.zero, ancestor: overlayBox);
    final tileSize = rb.size;
    final tileCenterY = targetTopLeft.dy + tileSize.height / 2;

    final double maxHeight =
    (screenH - padding.vertical - 32).clamp(180.0, 520.0).toDouble();

    final double topLimit = padding.top + 8;
    final double bottomLimit = screenH - padding.bottom - 8;

    double yOffset = 0.0;
    final double popoverTop = tileCenterY - maxHeight / 2;
    final double popoverBottom = tileCenterY + maxHeight / 2;

    if (popoverTop < topLimit) {
      yOffset = topLimit - popoverTop;
    } else if (popoverBottom > bottomLimit) {
      yOffset = bottomLimit - popoverBottom;
    }

    final vm = context.read<CrusherProductionInputViewModel>();
    final hasTempForThis = vm.hasTemporaryDataForLabel(widget.title);
    final hasPartialTemp = _hasPartialTempForLabel(vm, widget.title);
    final delAllLabel = hasPartialTemp
        ? 'Hapus Semua (TEMP Partial)'
        : 'Hapus Semua (TEMP)';

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hide,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.centerLeft,
              followerAnchor: Alignment.centerRight,
              offset: Offset(-widget.gap, yOffset),
              child: InputsGroupTooltip(
                title: widget.title,
                subtitle: (widget.headerSubtitle ?? '').trim().isNotEmpty
                    ? widget.headerSubtitle!.trim()
                    : null,
                headerColor: widget.color,
                onClose: _hide,
                width: widget.popoverWidth,
                maxHeight: maxHeight,
                tableHeaders: widget.tableHeaders,
                columnFlexes: widget.columnFlexes,
                canDelete: widget.canDelete,
                onBulkDelete: widget.onBulkDelete,
                summaryBuilder: widget.summaryBuilder,
                childrenBuilder: widget.detailsBuilder,
                onDeleteAllTemp:
                hasTempForThis ? () => _handleDeleteAllTemp(vm) : null,
                deleteAllTempDisabled: !hasTempForThis,
                deleteAllTempLabel: delAllLabel,
                actions: [
                  TextButton.icon(
                    onPressed: _hide,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Oke'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _handleDeleteAllTemp(
      CrusherProductionInputViewModel vm) async {
    final removed = vm.deleteAllTempForLabel(widget.title);
    widget.onUpdate?.call();
    _hide();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed > 0
              ? 'Berhasil menghapus $removed item TEMP.'
              : 'Tidak ada item TEMP untuk dihapus.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Consumer<CrusherProductionInputViewModel>(
        builder: (context, vm, _) {
          final details = widget.detailsBuilder();
          if (details.isEmpty) return const SizedBox.shrink();

          final hasTempForThis = vm.hasTemporaryDataForLabel(widget.title);

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color:
            hasTempForThis ? Colors.yellow.shade50 : Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: hasTempForThis
                    ? Colors.amber.shade200
                    : Colors.grey.shade200,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _show,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasTempForThis
                                ? Colors.brown.shade800
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${details.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}