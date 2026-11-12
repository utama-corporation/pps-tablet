import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'atlas_data_table.dart';

class AtlasPagedDataTable<T> extends StatefulWidget {
  static const _headerBorder = Color(0xFFDCDFE4);
  static const _rowDivider = Color(0xFFEBECF0);
  static const _selectedBg = Color(0xFFE9F2FF);
  static const _selectedAccent = Color(0xFF0C66E4);
  static const _highlightEven = Color(0xFFEAFBF2);
  static const _highlightOdd = Color(0xFFE3F7EC);
  static const _headerBg = Color(0xFFF7F8F9);
  static const _headerText = Color(0xFF44546F);

  final PagingController<int, T> pagingController;
  final List<AtlasTableColumn<T>> columns;
  final double horizontalPadding;
  final bool Function(T row)? selectedPredicate;
  final bool Function(T row)? highlightPredicate;
  final void Function(T row)? onRowTap;
  final void Function(T row, Offset globalPosition)? onRowTapWithPosition;
  final void Function(T row, Offset globalPosition)? onRowLongPress;
  final Color? Function(T row)? rowColorBuilder;
  final WidgetBuilder? firstPageProgress;
  final WidgetBuilder? newPageProgress;
  final WidgetBuilder? firstPageError;
  final WidgetBuilder? newPageError;
  final WidgetBuilder? noItems;

  const AtlasPagedDataTable({
    super.key,
    required this.pagingController,
    required this.columns,
    this.horizontalPadding = 16,
    this.selectedPredicate,
    this.highlightPredicate,
    this.onRowTap,
    this.onRowTapWithPosition,
    this.onRowLongPress,
    this.rowColorBuilder,
    this.firstPageProgress,
    this.newPageProgress,
    this.firstPageError,
    this.newPageError,
    this.noItems,
  });

  @override
  State<AtlasPagedDataTable<T>> createState() => _AtlasPagedDataTableState<T>();
}

class _AtlasPagedDataTableState<T> extends State<AtlasPagedDataTable<T>> {
  final _headerHCtrl = ScrollController();
  final _bodyHCtrl = ScrollController();
  bool _syncing = false;

  double get _contentWidth => widget.columns
      .fold<double>(0, (sum, c) => sum + (c.width ?? 160))
      .floorToDouble();

  @override
  void initState() {
    super.initState();
    _bodyHCtrl.addListener(() {
      if (_syncing) return;
      _syncing = true;
      if (_headerHCtrl.hasClients && _headerHCtrl.offset != _bodyHCtrl.offset) {
        _headerHCtrl.jumpTo(_bodyHCtrl.offset);
      }
      _syncing = false;
    });
    _headerHCtrl.addListener(() {
      if (_syncing) return;
      _syncing = true;
      if (_bodyHCtrl.hasClients && _bodyHCtrl.offset != _headerHCtrl.offset) {
        _bodyHCtrl.jumpTo(_headerHCtrl.offset);
      }
      _syncing = false;
    });
  }

  @override
  void dispose() {
    _headerHCtrl.dispose();
    _bodyHCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kLeftBorderW = 3.0;
    final totalWidth =
        _contentWidth + (widget.horizontalPadding * 2) + kLeftBorderW;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AtlasPagedDataTable._headerBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14091E42),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Scrollbar(
              controller: _bodyHCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _bodyHCtrl,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints.tightFor(width: totalWidth),
                  child: PagingListener<int, T>(
                    controller: widget.pagingController,
                    builder: (context, state, fetchNextPage) {
                      return RefreshIndicator(
                        onRefresh: () async =>
                            widget.pagingController.refresh(),
                        child: PagedListView<int, T>(
                          state: state,
                          fetchNextPage: fetchNextPage,
                          padding: EdgeInsets.zero,
                          builderDelegate: PagedChildBuilderDelegate<T>(
                            itemBuilder: (context, item, index) {
                              final selected =
                                  widget.selectedPredicate?.call(item) ?? false;
                              final isEven = index.isEven;
                              final isHighlighted =
                                  widget.highlightPredicate?.call(item) ??
                                  false;
                              final customColor = widget.rowColorBuilder?.call(item);
                              final bgColor = customColor ??
                                  (selected
                                  ? AtlasPagedDataTable._selectedBg
                                  : isHighlighted
                                  ? (isEven
                                        ? AtlasPagedDataTable._highlightEven
                                        : AtlasPagedDataTable._highlightOdd)
                                  : (isEven
                                        ? Colors.white
                                        : const Color(0xFFFAFBFC)));

                              final rowState = AtlasRowState(
                                isSelected: selected,
                                isEven: isEven,
                                isHighlighted: isHighlighted,
                                textColor: selected
                                    ? const Color(0xFF123E73)
                                    : Colors.grey.shade800,
                              );
                              Offset? tapDownPosition;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: widget.onRowTapWithPosition == null
                                    ? null
                                    : (details) => tapDownPosition =
                                          details.globalPosition,
                                onLongPressStart: widget.onRowLongPress == null
                                    ? null
                                    : (details) => widget.onRowLongPress!(
                                        item,
                                        details.globalPosition,
                                      ),
                                onSecondaryTapDown:
                                    widget.onRowLongPress == null
                                    ? null
                                    : (details) => widget.onRowLongPress!(
                                        item,
                                        details.globalPosition,
                                      ),
                                child: InkWell(
                                  onTap: () {
                                    widget.onRowTap?.call(item);
                                    if (widget.onRowTapWithPosition != null) {
                                      widget.onRowTapWithPosition!(
                                        item,
                                        tapDownPosition ?? Offset.zero,
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    curve: Curves.easeInOut,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      border: Border(
                                        left: BorderSide(
                                          color: selected
                                              ? AtlasPagedDataTable
                                                    ._selectedAccent
                                              : Colors.transparent,
                                          width: kLeftBorderW,
                                        ),
                                        bottom: const BorderSide(
                                          color:
                                              AtlasPagedDataTable._rowDivider,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: widget.horizontalPadding,
                                        vertical: 10,
                                      ),
                                      child: SizedBox(
                                        width: _contentWidth,
                                        child: Row(
                                          children: widget.columns
                                              .map((c) {
                                                return _buildCell(
                                                  width: c.width ?? 160,
                                                  showDivider: c.showDivider,
                                                  horizontalPadding:
                                                      c.horizontalPadding,
                                                  alignment: c.cellAlignment,
                                                  child: c.cellBuilder(
                                                    context,
                                                    item,
                                                    rowState,
                                                  ),
                                                );
                                              })
                                              .toList(growable: false),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            firstPageProgressIndicatorBuilder:
                                widget.firstPageProgress ??
                                (_) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            newPageProgressIndicatorBuilder:
                                widget.newPageProgress ??
                                (_) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            firstPageErrorIndicatorBuilder:
                                widget.firstPageError ??
                                (_) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Terjadi kesalahan memuat data.',
                                    ),
                                  ),
                                ),
                            newPageErrorIndicatorBuilder:
                                widget.newPageError ??
                                (_) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Gagal memuat halaman berikutnya',
                                    ),
                                  ),
                                ),
                            noItemsFoundIndicatorBuilder:
                                widget.noItems ??
                                (_) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('Tidak ada data.'),
                                  ),
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCFDFE), AtlasPagedDataTable._headerBg],
        ),
        border: Border(
          left: BorderSide(color: Colors.transparent, width: 3),
          bottom: BorderSide(color: AtlasPagedDataTable._headerBorder),
        ),
      ),
      child: SingleChildScrollView(
        controller: _headerHCtrl,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
          child: SizedBox(
            width: _contentWidth,
            child: Row(
              children: widget.columns
                  .map((c) {
                    return _buildCell(
                      width: c.width ?? 160,
                      showDivider: c.showDivider,
                      horizontalPadding: c.horizontalPadding,
                      alignment: c.headerAlign == TextAlign.center
                          ? Alignment.center
                          : c.headerAlign == TextAlign.right
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: _buildHeaderCell(c),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(AtlasTableColumn<T> column) {
    final active = column.sortActive;
    final text = Text(
      column.title,
      textAlign: column.headerAlign,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: active
            ? const Color(0xFF0C66E4)
            : AtlasPagedDataTable._headerText,
        letterSpacing: 0.35,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        if (column.headerTrailing != null) ...[
          const SizedBox(width: 4),
          column.headerTrailing!,
        ],
      ],
    );

    if (column.onHeaderTap == null) return row;

    return InkWell(
      onTap: column.onHeaderTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: row,
      ),
    );
  }

  Widget _buildCell({
    required double width,
    required bool showDivider,
    required double horizontalPadding,
    required Alignment alignment,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        alignment: alignment,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  right: BorderSide(color: AtlasPagedDataTable._rowDivider),
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}
