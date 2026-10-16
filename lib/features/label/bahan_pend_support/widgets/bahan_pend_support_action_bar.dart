// lib/features/label/bahan_pend_support/widgets/bahan_pend_support_action_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BahanPendukungActionBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final bool includeUsed;
  final ValueChanged<bool> onIncludeUsedChanged;

  const BahanPendukungActionBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.onClear,
    required this.includeUsed,
    required this.onIncludeUsedChanged,
  });

  @override
  State<BahanPendukungActionBar> createState() =>
      _BahanPendukungActionBarState();
}

class _BahanPendukungActionBarState extends State<BahanPendukungActionBar> {
  final FocusNode _searchFocus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _focused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  void _doClear() {
    widget.controller.clear();
    setState(() {});
    widget.onClear();
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
            _searchFocus.requestFocus();
          },
        },
        child: Focus(
          autofocus: false,
          child: LayoutBuilder(
            builder: (context, c) {
              final isTight = c.maxWidth < 660;
              return Row(
                children: [
                  // 🔹 Info: label BP. dibuat dari menu Penerimaan Bahan Pendukung
                  /*Tooltip(
                    message:
                        'Label Bahan Pendukung dibuat lewat menu Penerimaan Bahan Pendukung',
                    waitDuration: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00897B).withValues(alpha: 0.30),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.move_to_inbox_outlined,
                            size: 18,
                            color: Color(0xFF00897B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Dari Penerimaan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00695C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),*/

                  // 🔍 Search box
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _focused
                              ? cs.primary.withValues(alpha: .5)
                              : Colors.grey.shade300,
                          width: _focused ? 1.6 : 1,
                        ),
                        boxShadow: _focused
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: .12),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          const SizedBox(width: 6),
                          Icon(Icons.search, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              focusNode: _searchFocus,
                              controller: widget.controller,
                              onChanged: (v) {
                                setState(() {}); // trigger ikon clear
                                widget.onSearchChanged(v);
                              },
                              onSubmitted: widget.onSearchChanged,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText:
                                    'Cari No. Label / Material / Supplier / No. Penerimaan',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: _hasText
                                ? IconButton(
                                    key: const ValueKey('clear_on'),
                                    tooltip: 'Bersihkan',
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: _doClear,
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('clear_off'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 🔘 Toggle: tampilkan semua data (termasuk sudah dipakai)
                  Tooltip(
                    message: widget.includeUsed
                        ? 'Tampilkan hanya yang belum dipakai'
                        : 'Tampilkan semua data',
                    waitDuration: const Duration(milliseconds: 400),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          widget.onIncludeUsedChanged(!widget.includeUsed),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: widget.includeUsed
                              ? const Color(0xFF1565C0).withValues(alpha: 0.10)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.includeUsed
                                ? const Color(0xFF1565C0).withValues(alpha: 0.35)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.includeUsed
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 18,
                              color: widget.includeUsed
                                  ? const Color(0xFF1565C0)
                                  : Colors.grey.shade500,
                            ),
                            if (!isTight) ...[
                              const SizedBox(width: 6),
                              Text(
                                'Tampilkan Semua',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.includeUsed
                                      ? const Color(0xFF1565C0)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (!isTight) const SizedBox(width: 8),

                  if (isTight)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Reset pencarian',
                      onPressed: _doClear,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}