import 'package:flutter/material.dart';

import '../../../operator/model/operator_model.dart';
import '../../../operator/repository/operator_repository.dart';
import '../../../regu/model/regu_model.dart';
import '../../../regu/repository/regu_repository.dart';

typedef ReguOperatorResult = ({MstRegu regu, List<MstOperator> operators});

// ─────────────────────────────────────────────────────────────────────────────
// Field: container 2 kolom berlabel (Regu | Operator) — tap → buka dialog
// ─────────────────────────────────────────────────────────────────────────────
class ReguOperatorPickerField extends StatelessWidget {
  const ReguOperatorPickerField({
    super.key,
    required this.selectedRegu,
    required this.selectedOperators,
    required this.isLoading,
    required this.onTap,
    this.errorText,
  });

  final MstRegu? selectedRegu;
  final List<MstOperator> selectedOperators;
  final bool isLoading;
  final VoidCallback onTap;

  /// Pesan error inline (mis. "Regu & operator wajib dipilih"). Saat diisi,
  /// border jadi merah dan teks error tampil di bawah field — tidak pakai
  /// SnackBar yang bisa ketutup dialog.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasRegu = selectedRegu != null;
    final hasOperator = selectedOperators.isNotEmpty;
    final hasAny = hasRegu || hasOperator;
    final hasError = errorText != null && errorText!.isNotEmpty;

    final reguValue = hasRegu ? selectedRegu!.namaRegu : null;
    final operatorValue = hasOperator
        ? selectedOperators.map((o) => o.namaOperator).join(', ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _PickerContainer(
          hasValue: hasAny,
          isLoading: isLoading,
          onTap: onTap,
          hasError: hasError,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Col(
                  icon: Icons.groups_outlined,
                  label: 'REGU',
                  value: reguValue,
                  hint: 'Pilih regu',
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFFE5E7EB),
                ),
                _Col(
                  icon: Icons.person_outline,
                  label: 'OPERATOR',
                  value: operatorValue,
                  hint: 'Pilih operator',
                  extraLabel: hasOperator
                      ? '${selectedOperators.length} orang'
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _PickerContainer extends StatelessWidget {
  const _PickerContainer({
    required this.hasValue,
    required this.isLoading,
    required this.onTap,
    required this.child,
    this.hasError = false,
  });

  final bool hasValue;
  final bool isLoading;
  final VoidCallback onTap;
  final Widget child;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: hasValue ? Colors.white : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFDC2626)
                  : hasValue
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFD1D5DB),
              width: hasError ? 1.4 : (hasValue ? 1.0 : 1.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 8),
              isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : Icon(
                      hasValue
                          ? Icons.edit_outlined
                          : Icons.chevron_right_rounded,
                      size: 16,
                      color: hasValue
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF9CA3AF),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  const _Col({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    this.extraLabel,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String hint;
  final String? extraLabel;

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: const Color(0xFF9CA3AF)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              if (extraLabel != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    extraLabel!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? hint : value!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
              color: isEmpty ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: load regu list then open the picker dialog
// ─────────────────────────────────────────────────────────────────────────────
Future<ReguOperatorResult?> showReguOperatorPicker(
  BuildContext context, {
  MstRegu? initialRegu,
  List<MstOperator> initialSelected = const [],
  int? idBagian,
  List<int>? idBagianList,
}) async {
  List<MstRegu> allRegu = [];
  try {
    allRegu = await ReguRepository().fetchAll(
      idBagian: idBagian,
      idBagianList: idBagianList,
    );
  } catch (_) {}

  if (!context.mounted) return null;

  return showDialog<ReguOperatorResult>(
    context: context,
    builder: (_) => ReguOperatorPickerDialog(
      reguList: allRegu,
      initialRegu: initialRegu,
      initialSelected: initialSelected,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: pilih regu (kiri) lalu operator via checkbox (kanan)
// ─────────────────────────────────────────────────────────────────────────────
class ReguOperatorPickerDialog extends StatefulWidget {
  const ReguOperatorPickerDialog({
    super.key,
    required this.reguList,
    required this.initialRegu,
    required this.initialSelected,
  });

  final List<MstRegu> reguList;
  final MstRegu? initialRegu;
  final List<MstOperator> initialSelected;

  @override
  State<ReguOperatorPickerDialog> createState() =>
      _ReguOperatorPickerDialogState();
}

class _ReguOperatorPickerDialogState
    extends State<ReguOperatorPickerDialog> {
  MstRegu? _activeRegu;
  List<MstOperator> _operators = [];
  bool _loadingOp = false;
  Set<int> _selected = {};

  final Map<int, Set<int>> _selectionPerRegu = {};
  final Map<int, List<MstOperator>> _operatorsCache = {};

  @override
  void initState() {
    super.initState();
    _activeRegu = widget.initialRegu;
    final initSet =
        widget.initialSelected.map((o) => o.idOperator).toSet();
    if (widget.initialRegu != null && initSet.isNotEmpty) {
      _selectionPerRegu[widget.initialRegu!.idRegu] = Set.from(initSet);
    }
    _selected = Set.from(initSet);
    if (_activeRegu != null) _fetchOperators(_activeRegu!.idRegu);
  }

  Future<void> _fetchOperators(int idRegu) async {
    if (_operatorsCache.containsKey(idRegu)) {
      setState(() => _operators = _operatorsCache[idRegu]!);
      return;
    }
    setState(() {
      _loadingOp = true;
      _operators = [];
    });
    try {
      final result = await OperatorRepository().fetchByRegu(idRegu);
      _operatorsCache[idRegu] = result;
      if (mounted) setState(() => _operators = result);
    } catch (_) {
      if (mounted) setState(() => _operators = []);
    } finally {
      if (mounted) setState(() => _loadingOp = false);
    }
  }

  bool get _allSelected =>
      _operators.isNotEmpty && _selected.length == _operators.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(_operators.map((o) => o.idOperator));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          size: 18, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pilih Regu & Operator',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(null),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    // Kiri: daftar regu
                    SizedBox(
                      width: 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            color: const Color(0xFFF8FAFC),
                            child: const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'REGU',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          const Divider(
                              height: 1, color: Color(0xFFE5E7EB)),
                          Expanded(
                            child: widget.reguList.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Tidak ada regu',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: widget.reguList.length,
                                    itemBuilder: (_, i) {
                                      final regu = widget.reguList[i];
                                      final isActive =
                                          _activeRegu?.idRegu ==
                                              regu.idRegu;
                                      return InkWell(
                                        onTap: () {
                                          if (_activeRegu != null) {
                                            _selectionPerRegu[
                                                    _activeRegu!.idRegu] =
                                                Set.from(_selected);
                                          }
                                          setState(() {
                                            _activeRegu = regu;
                                            _selected = Set.from(
                                              _selectionPerRegu[
                                                      regu.idRegu] ??
                                                  {},
                                            );
                                          });
                                          _fetchOperators(regu.idRegu);
                                        },
                                        child: Container(
                                          height: 44,
                                          padding: const EdgeInsets
                                              .symmetric(horizontal: 16),
                                          color: isActive
                                              ? const Color(0xFFEFF6FF)
                                              : Colors.transparent,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isActive
                                                      ? const Color(
                                                          0xFF2563EB)
                                                      : const Color(
                                                          0xFFCBD5E1),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  regu.namaRegu,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isActive
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                    color: isActive
                                                        ? const Color(
                                                            0xFF1E40AF)
                                                        : const Color(
                                                            0xFF374151),
                                                  ),
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const VerticalDivider(
                        width: 1, color: Color(0xFFE5E7EB)),

                    // Kanan: operator checkboxes
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            color: const Color(0xFFF8FAFC),
                            child: Row(
                              children: [
                                const Text(
                                  'OPERATOR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                if (_operators.isNotEmpty)
                                  TextButton(
                                    onPressed: _toggleAll,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize
                                          .shrinkWrap,
                                    ),
                                    child: Text(
                                      _allSelected
                                          ? 'Hapus Semua'
                                          : 'Pilih Semua',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2563EB)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(
                              height: 1, color: Color(0xFFE5E7EB)),
                          Expanded(
                            child: _activeRegu == null
                                ? const Center(
                                    child: Text(
                                      'Pilih regu terlebih dahulu',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  )
                                : _loadingOp
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : _operators.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'Tidak ada operator',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9CA3AF)),
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: _operators.length,
                                            itemBuilder: (_, i) {
                                              final op = _operators[i];
                                              final isChecked = _selected
                                                  .contains(op.idOperator);
                                              return CheckboxListTile(
                                                value: isChecked,
                                                dense: true,
                                                title: Text(
                                                  op.namaOperator,
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                                onChanged: (v) {
                                                  setState(() {
                                                    if (v == true) {
                                                      _selected.add(
                                                          op.idOperator);
                                                    } else {
                                                      _selected.remove(
                                                          op.idOperator);
                                                    }
                                                  });
                                                },
                                              );
                                            },
                                          ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer ──────────────────────────────────────────────
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selected.length} operator dipilih',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(null),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _activeRegu == null ||
                                  _selected.isEmpty
                              ? null
                              : () {
                                  final ops = _operators
                                      .where((o) => _selected
                                          .contains(o.idOperator))
                                      .toList();
                                  Navigator.of(context).pop((
                                    regu: _activeRegu!,
                                    operators: ops,
                                  ));
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Pilih'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
