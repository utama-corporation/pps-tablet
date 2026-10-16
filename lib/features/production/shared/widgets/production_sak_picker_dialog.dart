// lib/features/production/shared/widgets/production_sak_picker_dialog.dart
// Generic sak chip picker - works with any production VM via callbacks.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/production_label_lookup_result.dart';
import '../models/bb_item.dart';
import '../models/broker_item.dart';
import '../models/washing_item.dart';
import '../models/gilingan_item.dart';
import '../models/crusher_item.dart';
import '../models/mixer_item.dart';
import '../utils/format.dart';
import 'weight_input_dialog.dart';

const _kSakPrimary = Color(0xFF1565C0);
const _kSakAmber = Color(0xFFF59E0B);

// Commit result record — decoupled from any VM's local TempCommitResult type.
typedef SakPickerCommitResult = ({int added, int skipped});

/// Callback type for commitPickedToTemp.
typedef SakCommitFn = SakPickerCommitResult Function({required String noProduksi});

class ProductionSakPickerDialog extends StatefulWidget {
  final String noProduksi;
  final bool isPartialMode;

  // VM as a Listenable — allows dialog to rebuild when VM notifies.
  final ChangeNotifier vm;

  // VM method callbacks
  final ProductionLabelLookupResult? Function() getLookup;
  final bool Function(Map<String, dynamic> row, String noProduksi) willBeDuplicate;
  final bool Function(Map<String, dynamic> row) isPicked;
  final bool Function(String label) hasTemporaryDataForLabel;
  final dynamic Function(String noProduksi) inputsOf;
  final bool Function(String noProduksi) isInputsLoading;
  final Future<void> Function(String noProduksi) loadInputs;
  final void Function() clearPicks;
  final void Function(Map<String, dynamic> row) togglePick;
  final SakCommitFn commitPickedToTemp;

  const ProductionSakPickerDialog({
    super.key,
    required this.noProduksi,
    this.isPartialMode = false,
    required this.vm,
    required this.getLookup,
    required this.willBeDuplicate,
    required this.isPicked,
    required this.hasTemporaryDataForLabel,
    required this.inputsOf,
    required this.isInputsLoading,
    required this.loadInputs,
    required this.clearPicks,
    required this.togglePick,
    required this.commitPickedToTemp,
  });

  @override
  State<ProductionSakPickerDialog> createState() =>
      _ProductionSakPickerDialogState();
}

class _ProductionSakPickerDialogState
    extends State<ProductionSakPickerDialog> {
  final Set<int> _picked = {};
  final Map<int, double> _editedWeights = {};

  int? _selectedIndex;
  final TextEditingController _weightCtrl = TextEditingController();
  double? _originalWeight;

  final Set<int> _disabled = {};
  bool _ready = false;
  bool _didAutoSelect = false;

  bool get _isPartial => widget.isPartialMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.inputsOf(widget.noProduksi) == null) {
        await widget.loadInputs(widget.noProduksi);
      }
      _computeDisabled();
      if (!_isPartial) _autoSelectIfNew();
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _computeDisabled() {
    final result = widget.getLookup();
    if (result == null) return;
    _disabled.clear();
    for (int i = 0; i < result.data.length; i++) {
      if (widget.willBeDuplicate(result.data[i], widget.noProduksi)) {
        _disabled.add(i);
      }
    }
    _picked.removeWhere(_disabled.contains);
  }

  void _autoSelectIfNew() {
    if (_didAutoSelect) return;
    final result = widget.getLookup();
    if (result == null) return;
    final labelCode = _labelCodeOfFirst(result);
    if (labelCode != null && widget.hasTemporaryDataForLabel(labelCode)) return;
    for (int i = 0; i < result.data.length; i++) {
      if (!_disabled.contains(i)) _picked.add(i);
    }
    _didAutoSelect = true;
  }

  // ── Multi-select ──────────────────────────────────────────────────────────

  void _toggleChip(int index) {
    if (_disabled.contains(index)) return;
    setState(() {
      if (_picked.contains(index)) {
        _picked.remove(index);
        _editedWeights.remove(index);
      } else {
        _picked.add(index);
      }
    });
  }

  Future<void> _editWeightForChip(int index, dynamic item) async {
    if (_disabled.contains(index) || !_picked.contains(index)) return;
    final original = _beratOf(item);
    if (original == null) return;
    final newWeight = await WeightInputDialog.show(
      context,
      maxWeight: original,
      currentWeight: _editedWeights[index] ?? original,
    );
    if (newWeight != null && mounted) {
      setState(() => _editedWeights[index] = newWeight);
    }
  }

  void _selectAll(ProductionLabelLookupResult result) {
    setState(() {
      for (int i = 0; i < result.data.length; i++) {
        if (!_disabled.contains(i)) _picked.add(i);
      }
    });
  }

  void _clearAll() => setState(() {
        _picked.clear();
        _editedWeights.clear();
      });

  // ── Single-select partial ─────────────────────────────────────────────────

  void _selectPartialChip(int index, dynamic item) {
    if (_disabled.contains(index)) return;
    final berat = _beratOf(item);
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = null;
        _originalWeight = null;
        _weightCtrl.clear();
      } else {
        _selectedIndex = index;
        _originalWeight = berat;
        _weightCtrl.text = berat != null ? num2(berat) : '';
      }
    });
  }

  double? get _editedWeight {
    final v = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    return v;
  }

  bool get _weightValid {
    final v = _editedWeight;
    if (v == null || v <= 0) return false;
    if (_originalWeight != null && v > _originalWeight!) return false;
    return true;
  }

  // ── Commit ────────────────────────────────────────────────────────────────

  void _commit(ProductionLabelLookupResult result) {
    if (_isPartial) {
      _commitPartial(result);
    } else {
      _commitMulti(result);
    }
  }

  void _commitMulti(ProductionLabelLookupResult result) {
    if (_picked.isEmpty) return;

    final Map<int, dynamic> origBerats = {};
    final Map<int, dynamic> origIsPartial = {};
    for (final i in _editedWeights.keys) {
      if (!_picked.contains(i) || i >= result.data.length) continue;
      final row = result.data[i];
      origBerats[i] = row['berat'];
      origIsPartial[i] = row['isPartial'];
      row['berat'] = _editedWeights[i];
      row['Berat'] = _editedWeights[i];
      row['isPartial'] = true;
      row['IsPartial'] = true;
    }

    widget.clearPicks();
    for (final i in _picked) {
      if (i < result.data.length) {
        final row = result.data[i];
        if (!widget.isPicked(row)) widget.togglePick(row);
      }
    }
    final r = widget.commitPickedToTemp(noProduksi: widget.noProduksi);

    for (final i in origBerats.keys) {
      final row = result.data[i];
      row['berat'] = origBerats[i];
      row['Berat'] = origBerats[i];
      row['isPartial'] = origIsPartial[i];
      row['IsPartial'] = origIsPartial[i];
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.added > 0
              ? '✅ Ditambahkan ${r.added} item${r.skipped > 0 ? ' • Duplikat terlewati ${r.skipped}' : ''}'
              : 'Tidak ada item baru ditambahkan',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _commitPartial(ProductionLabelLookupResult result) {
    if (_selectedIndex == null || !_weightValid) return;
    final row = result.data[_selectedIndex!];
    final originalBerat = row['berat'];
    final originalIsPartial = row['isPartial'];

    row['isPartial'] = true;
    row['IsPartial'] = true;
    row['berat'] = _editedWeight;
    row['Berat'] = _editedWeight;

    widget.clearPicks();
    widget.togglePick(row);
    final r = widget.commitPickedToTemp(noProduksi: widget.noProduksi);

    row['berat'] = originalBerat;
    row['Berat'] = originalBerat;
    row['isPartial'] = originalIsPartial;
    row['IsPartial'] = originalIsPartial;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.added > 0
              ? '✅ Ditambahkan 1 item partial${r.skipped > 0 ? ' • Duplikat terlewati ${r.skipped}' : ''}'
              : 'Item sudah ada atau gagal ditambahkan',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Static helpers (typed item accessors) ─────────────────────────────────

  static String _chipLabel(dynamic item) {
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is CrusherItem) return item.noCrusher ?? '-';
    final sak = _sakOf(item);
    return sak != null ? 'Sak $sak' : '-';
  }

  static int? _sakOf(dynamic item) {
    if (item is BbItem) return item.noSak;
    if (item is BrokerItem) return item.noSak;
    if (item is WashingItem) return item.noSak;
    if (item is MixerItem) return item.noSak;
    return null;
  }

  static double? _beratOf(dynamic item) {
    if (item is BbItem) return item.berat;
    if (item is BrokerItem) return item.berat;
    if (item is WashingItem) return item.berat;
    if (item is GilinganItem) return item.berat;
    if (item is CrusherItem) return item.berat;
    if (item is MixerItem) return item.berat;
    return null;
  }

  static bool _isPartialOf(dynamic item) {
    if (item is BbItem) return item.isPartialRow;
    if (item is BrokerItem) return item.isPartialRow;
    if (item is WashingItem) return item.isPartial == true;
    if (item is GilinganItem) return item.isPartialRow;
    if (item is MixerItem) return item.isPartialRow;
    return false;
  }

  static bool _isWashingItem(dynamic item) => item is WashingItem;

  static String _labelCode(ProductionLabelLookupResult result) {
    if (result.typedItems.isEmpty) return '-';
    final item = result.typedItems.first;
    if (item is BbItem) {
      final p = (item.noBBPartial ?? '').trim();
      if (p.isNotEmpty) return p;
      final nb = (item.noBahanBaku ?? '').trim();
      final np = item.noPallet;
      if (nb.isNotEmpty && np != null && np > 0) return '$nb-$np';
      return nb.isNotEmpty ? nb : '-';
    }
    if (item is BrokerItem) return item.noBroker ?? '-';
    if (item is WashingItem) return item.noWashing ?? '-';
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is CrusherItem) return item.noCrusher ?? '-';
    if (item is MixerItem) return item.noMixer ?? '-';
    return '-';
  }

  static String? _namaJenis(ProductionLabelLookupResult result) {
    if (result.typedItems.isEmpty) return null;
    final item = result.typedItems.first;
    if (item is BbItem) return item.namaJenis;
    if (item is BrokerItem) return item.namaJenis;
    if (item is WashingItem) return item.namaJenis;
    if (item is GilinganItem) return item.namaJenis;
    if (item is CrusherItem) return item.namaJenis;
    if (item is MixerItem) return item.namaJenis;
    return null;
  }

  static String? _labelCodeOfFirst(ProductionLabelLookupResult result) {
    if (result.typedItems.isEmpty) return null;
    final item = result.typedItems.first;
    if (item is BbItem) {
      final p = (item.noBBPartial ?? '').trim();
      if (p.isNotEmpty) return p;
      final nb = (item.noBahanBaku ?? '').trim();
      final np = item.noPallet;
      if (nb.isNotEmpty && np != null && np > 0) return '$nb-$np';
      return nb.isNotEmpty ? nb : null;
    }
    if (item is BrokerItem) return item.noBroker;
    if (item is WashingItem) return item.noWashing;
    if (item is GilinganItem) return item.noGilingan;
    if (item is CrusherItem) return item.noCrusher;
    if (item is MixerItem) return item.noMixer;
    return null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final result = widget.getLookup();
        if (result == null) {
          return const Dialog(
            child: SizedBox(
              height: 100,
              child: Center(child: Text('Tidak ada hasil lookup')),
            ),
          );
        }

        if (!_ready) {
          return const Dialog(
            child: SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final typedItems = result.typedItems;
        final labelCode = _labelCode(result);
        final namaJenis = _namaJenis(result) ?? result.prefixType.displayName;
        final newCount = List.generate(result.data.length, (i) => i)
            .where((i) => !_disabled.contains(i))
            .length;

        final headerColor = _isPartial ? _kSakAmber : _kSakPrimary;
        final bool canSubmit = _isPartial
            ? (_selectedIndex != null && _weightValid)
            : _picked.isNotEmpty;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: _isPartial ? 580 : 520,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isPartial
                              ? Icons.content_cut
                              : Icons.inventory_2_outlined,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  labelCode,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_isPartial) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PARTIAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              namaJenis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${typedItems.length} sak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Partial hint ─────────────────────────────────────────
                if (_isPartial)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pilih satu sak, lalu isi berat yang diambil (maks. berat asli)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Chip grid ────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: typedItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada data sak',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                  childAspectRatio: 1.3,
                                ),
                            itemCount: typedItems.length,
                            itemBuilder: (_, i) {
                              final item = typedItems[i];
                              final isDisabled = _disabled.contains(i);
                              final isPartialItem = _isPartialOf(item);
                              final berat = _beratOf(item);
                              final chipLabel = _chipLabel(item);
                              final isWashing = _isWashingItem(item);

                              final bool isSelected = _isPartial
                                  ? _selectedIndex == i && !isDisabled
                                  : _picked.contains(i) && !isDisabled;
                              final bool isWeightEdited =
                                  !_isPartial && _editedWeights.containsKey(i);

                              Color bg, border, labelColor;
                              if (isDisabled) {
                                bg = Colors.grey.shade100;
                                border = Colors.grey.shade300;
                                labelColor = Colors.grey.shade400;
                              } else if (isWeightEdited) {
                                bg = Colors.amber.shade50;
                                border = _kSakAmber;
                                labelColor = Colors.amber.shade800;
                              } else if (isSelected && _isPartial) {
                                bg = Colors.amber.shade50;
                                border = _kSakAmber;
                                labelColor = Colors.amber.shade800;
                              } else if (isSelected) {
                                bg = const Color(0xFFDCEEFD);
                                border = _kSakPrimary;
                                labelColor = _kSakPrimary;
                              } else if (isPartialItem) {
                                bg = Colors.deepOrange.shade50;
                                border = Colors.deepOrange.shade200;
                                labelColor = Colors.deepOrange.shade700;
                              } else {
                                bg = const Color(0xFFF0F7FF);
                                border = const Color(0xFFBFDBFE);
                                labelColor = const Color(0xFF1D4ED8);
                              }

                              return GestureDetector(
                                onTap: () => _isPartial
                                    ? _selectPartialChip(i, item)
                                    : _toggleChip(i),
                                onLongPress: (!_isPartial &&
                                        isSelected &&
                                        berat != null &&
                                        !isWashing)
                                    ? () => _editWeightForChip(i, item)
                                    : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: border,
                                      width: (isSelected || isWeightEdited)
                                          ? 2
                                          : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: (_isPartial ||
                                                          isWeightEdited
                                                      ? _kSakAmber
                                                      : _kSakPrimary)
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                chipLabel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDisabled
                                                      ? Colors.grey.shade400
                                                      : labelColor,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              if (berat != null &&
                                                  ((_isPartial &&
                                                          isSelected &&
                                                          _editedWeight !=
                                                              null) ||
                                                      isWeightEdited))
                                                RichText(
                                                  textAlign: TextAlign.center,
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: num2(isWeightEdited
                                                            ? _editedWeights[i]!
                                                            : _editedWeight!),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: (_isPartial &&
                                                                  !_weightValid)
                                                              ? Colors
                                                                  .red.shade700
                                                              : Colors.amber
                                                                  .shade900,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            ' / ${num2(berat)} kg',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors
                                                              .grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Text(
                                                  berat != null
                                                      ? '${num2(berat)} kg'
                                                      : '-',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDisabled
                                                        ? Colors.grey.shade400
                                                        : const Color(
                                                            0xFF374151),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isWeightEdited)
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Icon(
                                            Icons.edit,
                                            size: 9,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      if (isPartialItem &&
                                          !isDisabled &&
                                          !isWeightEdited)
                                        Positioned(
                                          top: 3,
                                          right: 3,
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.deepOrange.shade400,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      if (isSelected)
                                        Positioned(
                                          top: 2,
                                          left: 2,
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: _isPartial || isWeightEdited
                                                  ? _kSakAmber
                                                  : _kSakPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _isPartial
                                                  ? Icons.radio_button_checked
                                                  : Icons.check,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      if (isDisabled)
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // ── Partial weight input ──────────────────────────────────
                if (_isPartial && _selectedIndex != null) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.scale_outlined,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Input berat partial',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Berat Asli',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _originalWeight != null
                                          ? '${num2(_originalWeight!)} kg'
                                          : '-',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: Colors.amber.shade400,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Berat Diambil',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.amber.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _weightCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*[,.]?\d*'),
                                            ),
                                          ],
                                          autofocus: true,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _weightValid
                                                ? Colors.amber.shade900
                                                : Colors.red.shade700,
                                          ),
                                          decoration: InputDecoration(
                                            suffixText: 'kg',
                                            suffixStyle: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber.shade700,
                                            ),
                                            hintText: '0',
                                            hintStyle: TextStyle(
                                              color: Colors.amber.shade300,
                                              fontSize: 18,
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: Colors.amber.shade300,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: _kSakAmber,
                                                width: 2,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide(
                                                color: _weightValid
                                                    ? Colors.amber.shade300
                                                    : Colors.red.shade300,
                                              ),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      if (_originalWeight != null) ...[
                                        const SizedBox(width: 6),
                                        Tooltip(
                                          message: 'Isi berat penuh',
                                          child: InkWell(
                                            onTap: () => setState(() {
                                              _weightCtrl.text =
                                                  num2(_originalWeight!);
                                            }),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.amber.shade300,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.keyboard_double_arrow_up,
                                                size: 16,
                                                color: Colors.amber.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_editedWeight != null &&
                            _originalWeight != null &&
                            _editedWeight! > _originalWeight!)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tidak boleh melebihi berat asli ${num2(_originalWeight!)} kg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // ── Summary bar ──────────────────────────────────────────
                Builder(builder: (_) {
                  int totalSak = 0;
                  double totalBerat = 0;

                  if (_isPartial) {
                    if (_selectedIndex != null) {
                      totalSak = 1;
                      totalBerat =
                          (_weightValid ? _editedWeight : null) ??
                          _originalWeight ??
                          0;
                    }
                  } else {
                    for (final i in _picked) {
                      if (i >= typedItems.length) continue;
                      totalSak++;
                      final item = typedItems[i];
                      final b =
                          _editedWeights[i] ?? _beratOf(item) ?? 0;
                      totalBerat += b;
                    }
                  }

                  final hasData = _isPartial
                      ? _selectedIndex != null
                      : _picked.isNotEmpty;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: hasData ? null : 0,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: hasData
                        ? Container(
                            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _isPartial
                                  ? Colors.amber.shade50
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isPartial
                                    ? Colors.amber.shade200
                                    : const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 14,
                                  color: _isPartial
                                      ? Colors.amber.shade700
                                      : _kSakPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total dipilih',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _isPartial
                                        ? Colors.amber.shade700
                                        : _kSakPrimary,
                                  ),
                                ),
                                const Spacer(),
                                _SummaryChip(
                                  icon: Icons.inventory_2_outlined,
                                  label: '$totalSak sak',
                                  color: _isPartial
                                      ? Colors.amber.shade700
                                      : _kSakPrimary,
                                ),
                                const SizedBox(width: 8),
                                _SummaryChip(
                                  icon: Icons.scale_outlined,
                                  label: '${num2(totalBerat)} kg',
                                  color: _isPartial
                                      ? Colors.amber.shade700
                                      : _kSakPrimary,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  );
                }),

                // ── Footer ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade200)),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isPartial)
                        TextButton.icon(
                          onPressed: _selectedIndex != null
                              ? () => setState(() {
                                    _selectedIndex = null;
                                    _originalWeight = null;
                                    _weightCtrl.clear();
                                  })
                              : null,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Batal Pilih'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                        )
                      else if (newCount > 0)
                        OutlinedButton.icon(
                          onPressed: _picked.length == newCount
                              ? _clearAll
                              : () => _selectAll(result),
                          icon: Icon(
                            _picked.length == newCount
                                ? Icons.clear_all
                                : Icons.done_all,
                            size: 16,
                          ),
                          label: Text(
                            _picked.length == newCount
                                ? 'Bersihkan'
                                : 'Pilih Semua ($newCount)',
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade400),
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed:
                            canSubmit ? () => _commit(result) : null,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: Text(
                          _isPartial
                              ? (_selectedIndex == null
                                  ? 'Pilih Sak'
                                  : 'Tambahkan Partial')
                              : (_picked.isEmpty
                                  ? 'Pilih Sak'
                                  : 'Tambahkan (${_picked.length})'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isPartial
                              ? Colors.amber.shade600
                              : _kSakPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
