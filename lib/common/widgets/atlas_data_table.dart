import 'package:flutter/material.dart';

typedef AtlasCellBuilder<T> =
    Widget Function(BuildContext context, T item, AtlasRowState rowState);

class AtlasRowState {
  final bool isSelected;
  final bool isEven;
  final bool isHighlighted;
  final Color textColor;

  const AtlasRowState({
    required this.isSelected,
    required this.isEven,
    required this.isHighlighted,
    required this.textColor,
  });
}

class AtlasTableColumn<T> {
  final String title;
  final double? width;
  final int flex;
  final bool showDivider;
  final TextAlign headerAlign;
  final Alignment cellAlignment;
  final double horizontalPadding;
  final AtlasCellBuilder<T> cellBuilder;

  /// Optional sortable header: tappable with a trailing sort affordance.
  final VoidCallback? onHeaderTap;
  final Widget? headerTrailing;
  final bool sortActive;

  const AtlasTableColumn({
    required this.title,
    required this.cellBuilder,
    this.width,
    this.flex = 1,
    this.showDivider = true,
    this.headerAlign = TextAlign.left,
    this.cellAlignment = Alignment.centerLeft,
    this.horizontalPadding = 10,
    this.onHeaderTap,
    this.headerTrailing,
    this.sortActive = false,
  });
}

class AtlasDataTable<T> extends StatelessWidget {
  static const _headerBg = Color(0xFFF7F8F9);
  static const _headerBorder = Color(0xFFDCDFE4);
  static const _headerText = Color(0xFF44546F);
  static const _rowDivider = Color(0xFFEBECF0);
  static const _selectedBg = Color(0xFFE9F2FF);
  static const _selectedAccent = Color(0xFF0C66E4);
  static const _highlightEven = Color(0xFFEAFBF2);
  static const _highlightOdd = Color(0xFFE3F7EC);

  final List<AtlasTableColumn<T>> columns;
  final List<T> items;
  final ScrollController? scrollController;
  final bool isLoading;
  final bool isFetchingMore;
  final String errorMessage;
  final Widget Function(String message)? errorBuilder;
  final Widget? loadingBuilder;
  final ValueChanged<T>? onRowTap;
  final void Function(T item, Offset globalPosition)? onRowTapWithPosition;
  final void Function(T item, Offset globalPosition)? onRowLongPress;
  final bool Function(T item)? selectedPredicate;
  final bool Function(T item)? highlightPredicate;

  const AtlasDataTable({
    super.key,
    required this.columns,
    required this.items,
    this.scrollController,
    this.isLoading = false,
    this.isFetchingMore = false,
    this.errorMessage = '',
    this.errorBuilder,
    this.loadingBuilder,
    this.onRowTap,
    this.onRowTapWithPosition,
    this.onRowLongPress,
    this.selectedPredicate,
    this.highlightPredicate,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return loadingBuilder ?? const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty && items.isEmpty) {
      if (errorBuilder != null) {
        return errorBuilder!(errorMessage);
      }
      return Center(
        child: Text(
          errorMessage,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _headerBorder),
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
            child: ListView.builder(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length + (isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final item = items[index];
                final isSelected = selectedPredicate?.call(item) ?? false;
                final isEven = index.isEven;
                final isHighlighted = highlightPredicate?.call(item) ?? false;
                final bgColor = isSelected
                    ? _selectedBg
                    : isHighlighted
                    ? (isEven ? _highlightEven : _highlightOdd)
                    : (isEven ? Colors.white : const Color(0xFFFAFBFC));

                final rowState = AtlasRowState(
                  isSelected: isSelected,
                  isEven: isEven,
                  isHighlighted: isHighlighted,
                  textColor: isSelected
                      ? const Color(0xFF123E73)
                      : Colors.grey.shade800,
                );
                Offset? tapDownPosition;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: onRowTapWithPosition == null
                      ? null
                      : (details) => tapDownPosition = details.globalPosition,
                  onLongPressStart: onRowLongPress == null
                      ? null
                      : (details) =>
                            onRowLongPress!(item, details.globalPosition),
                  onSecondaryTapDown: onRowLongPress == null
                      ? null
                      : (details) =>
                            onRowLongPress!(item, details.globalPosition),
                  child: InkWell(
                    onTap: () {
                      onRowTap?.call(item);
                      if (onRowTapWithPosition != null) {
                        onRowTapWithPosition!(
                          item,
                          tapDownPosition ?? Offset.zero,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border(
                          left: BorderSide(
                            color: isSelected
                                ? _selectedAccent
                                : Colors.transparent,
                            width: 3,
                          ),
                          bottom: const BorderSide(color: _rowDivider),
                        ),
                      ),
                      child: Row(
                        children: columns
                            .map((column) {
                              return _buildCell(
                                showDivider: column.showDivider,
                                width: column.width,
                                flex: column.flex,
                                horizontalPadding: column.horizontalPadding,
                                alignment: column.cellAlignment,
                                child: column.cellBuilder(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCFDFE), _headerBg],
        ),
        border: Border(
          left: BorderSide(color: Colors.transparent, width: 3),
          bottom: BorderSide(color: _headerBorder),
        ),
      ),
      child: Row(
        children: columns
            .map((column) {
              return _buildCell(
                showDivider: column.showDivider,
                width: column.width,
                flex: column.flex,
                horizontalPadding: column.horizontalPadding,
                alignment: column.headerAlign == TextAlign.center
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: _buildHeaderCell(column),
              );
            })
            .toList(growable: false),
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
        color: active ? const Color(0xFF0C66E4) : _headerText,
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
    required Widget child,
    required bool showDivider,
    required double? width,
    required int flex,
    required double horizontalPadding,
    required Alignment alignment,
  }) {
    final content = Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(right: BorderSide(color: _rowDivider))
            : null,
      ),
      child: child,
    );

    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return Expanded(flex: flex, child: content);
  }
}
