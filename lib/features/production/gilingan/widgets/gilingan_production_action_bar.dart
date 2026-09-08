// lib/features/shared/gilingan_production/widgets/gilingan_production_action_bar.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/view_model/permission_view_model.dart';

class GilinganProductionActionBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged; // debounced contains only
  final VoidCallback onClear;
  final VoidCallback onAddPressed;
  final Duration debounce;

  const GilinganProductionActionBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.onClear,
    required this.onAddPressed,
    this.debounce = const Duration(milliseconds: 300),
  });

  @override
  State<GilinganProductionActionBar> createState() =>
      _GilinganProductionActionBarState();
}

class _GilinganProductionActionBarState
    extends State<GilinganProductionActionBar> {
  final FocusNode _searchFocus = FocusNode();
  bool _focused = false;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _focused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  void _triggerDebounced(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      widget.onSearchChanged(value.trim());
    });
  }

  void _handleChanged(String v) {
    setState(() {}); // refresh clear icon
    _triggerDebounced(v);
  }

  void _handleClear() {
    _debounceTimer?.cancel();
    widget.controller.clear();
    setState(() {});
    widget.onClear();
    _searchFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final perm = context.watch<PermissionViewModel>();
    final canCreate = perm.can('produksi_gilingan:create');

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
              final isTight = c.maxWidth < 720;
              return Row(
                children: [
                  // Create button
                  Tooltip(
                    message: canCreate
                        ? 'Buat Produksi Gilingan Baru'
                        : 'Anda tidak memiliki izin untuk membuat produksi gilingan',
                    waitDuration: const Duration(milliseconds: 400),
                    child: FilledButton.icon(
                      onPressed: canCreate ? widget.onAddPressed : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Produksi Gilingan'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        canCreate ? const Color(0xFF00897B) : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Search box (debounced contains only)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _focused
                              ? cs.primary.withOpacity(.5)
                              : Colors.grey.shade300,
                          width: _focused ? 1.6 : 1,
                        ),
                        boxShadow: _focused
                            ? [
                          BoxShadow(
                            color: cs.primary.withOpacity(.12),
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
                              onChanged: _handleChanged, // debounced
                              textInputAction: TextInputAction.none,
                              decoration: InputDecoration(
                                hintText:
                                'Cari NoProduksi Gilingan (contains)…',
                                hintStyle:
                                TextStyle(color: Colors.grey.shade500),
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),

                          // Clear button
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 140),
                            child: _hasText
                                ? IconButton(
                              key: const ValueKey('clear_on'),
                              tooltip: 'Bersihkan',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: _handleClear,
                            )
                                : const SizedBox.shrink(
                              key: ValueKey('clear_off'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!isTight) const SizedBox(width: 8),

                  // External reset (for tight layout)
                  if (isTight)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Reset pencarian',
                      onPressed: _handleClear,
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
