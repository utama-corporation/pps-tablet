import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/bb_item.dart';
import '../../shared/models/gilingan_item.dart';
import '../../shared/models/mixer_item.dart';
import '../../shared/models/washing_item.dart';
import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart';

import '../view_model/gilingan_production_input_view_model.dart';
import '../model/gilingan_inputs_model.dart'; // contains BrokerItem, BonggolanItem, CrusherItem, RejectItem exports
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class GilinganLookupLabelDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;
  final Set<int>? preDisabledIndices;

  const GilinganLookupLabelDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
    this.preDisabledIndices,
  });

  @override
  State<GilinganLookupLabelDialog> createState() => _GilinganLookupLabelDialogState();
}

class _GilinganLookupLabelDialogState extends State<GilinganLookupLabelDialog> {
  final Set<int> _localPickedIndices = <int>{};
  final Set<int> _disabledAtOpen = <int>{};
  final Map<int, double> _editedWeights = <int, double>{};

  bool _inputsReady = false;
  bool _didAutoSelect = false;

  @override
  void initState() {
    super.initState();
    _editedWeights.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<GilinganProductionInputViewModel>();

      // If dialog reopened and last lookup still exists, re-run lookup for the first item label
      final lastLookup = vm.lastLookup;
      if (lastLookup != null && lastLookup.typedItems.isNotEmpty) {
        final firstItem = lastLookup.typedItems.first;
        final labelCode = _labelCodeOf(firstItem);
        if (labelCode != '-') {
          await vm.lookupLabel(labelCode, force: true);
        }
      }

      // Ensure inputs for this production loaded
      if (vm.inputsOf(widget.noProduksi) == null) {
        await vm.loadInputs(widget.noProduksi);
      }
      _inputsReady = true;

      _precomputeDisabledRows();
      _maybeAutoSelectFirstTime();

      if (mounted) setState(() {});
    });
  }

  void _precomputeDisabledRows() {
    final vm = context.read<GilinganProductionInputViewModel>();
    final result = vm.lastLookup;
    if (result == null) return;

    _disabledAtOpen.clear();

    // respect external disabled indices if provided
    if (widget.preDisabledIndices != null) {
      _disabledAtOpen.addAll(widget.preDisabledIndices!);
    }

    for (int i = 0; i < result.data.length; i++) {
      if (_disabledAtOpen.contains(i)) continue;
      final row = result.data[i];
      if (vm.willBeDuplicate(row, widget.noProduksi)) {
        _disabledAtOpen.add(i);
      }
    }

    _localPickedIndices.removeWhere(_disabledAtOpen.contains);
  }

  bool _isDisabled(int index) => _disabledAtOpen.contains(index);

  void _maybeAutoSelectFirstTime() {
    if (_didAutoSelect) return;

    final vm = context.read<GilinganProductionInputViewModel>();
    final result = vm.lastLookup;
    if (result == null || result.typedItems.isEmpty) return;

    // if label already has temp bucket, do not auto select
    final labelCode = _labelCodeOf(result.typedItems.first);
    final tempData = vm.getTemporaryDataForLabel(labelCode);
    final hasTempForLabel = tempData != null && !tempData.isEmpty;
    if (hasTempForLabel) return;

    _localPickedIndices.clear();
    for (int i = 0; i < result.data.length; i++) {
      if (!_disabledAtOpen.contains(i)) {
        _localPickedIndices.add(i);
      }
    }
    _didAutoSelect = true;
  }

  void _toggleRow(GilinganProductionInputViewModel vm, int index) {
    if (_isDisabled(index)) return;
    setState(() {
      if (_localPickedIndices.contains(index)) {
        _localPickedIndices.remove(index);
      } else {
        _localPickedIndices.add(index);
      }
    });
  }

  void _selectAllNew(GilinganProductionInputViewModel vm, ProductionLabelLookupResult result) {
    setState(() {
      _localPickedIndices.clear();
      for (int i = 0; i < result.data.length; i++) {
        if (!_isDisabled(i)) _localPickedIndices.add(i);
      }
    });
  }

  void _commitSelection(GilinganProductionInputViewModel vm, ProductionLabelLookupResult result) {
    if (_localPickedIndices.isEmpty) return;

    vm.clearPicks();

    for (final i in _localPickedIndices) {
      if (i >= result.data.length) continue;
      final row = result.data[i];

      // apply edited weight (partial)
      if (_editedWeights.containsKey(i)) {
        row['berat'] = _editedWeights[i];
        row['Berat'] = _editedWeights[i];
      }

      if (!vm.isPicked(row)) vm.togglePick(row);
    }

    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);
    Navigator.pop(context);

    final msg = r.added > 0
        ? 'Ditambahkan ${r.added} item${r.skipped > 0 ? ' • Duplikat terlewati ${r.skipped}' : ''}'
        : 'Tidak ada item baru ditambahkan';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  _Presence _presenceForRow(
      GilinganProductionInputViewModel vm,
      Map<String, dynamic> row,
      ProductionLabelLookupResult ctx,
      ) {
    final sk = ctx.simpleKey(row);
    if (vm.isInTempKeys(sk)) return _Presence.temp;
    return _Presence.none;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GilinganProductionInputViewModel>(
      builder: (context, vm, _) {
        final result = vm.lastLookup;

        if (result == null) {
          return const Dialog(
            child: SizedBox(height: 120, child: Center(child: Text('Tidak ada hasil lookup'))),
          );
        }

        if (!_inputsReady) {
          return const Dialog(
            child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
          );
        }

        final typedItems = result.typedItems;
        final prefixType = result.prefixType;

        final dynamic sample = typedItems.isNotEmpty ? typedItems.first : null;
        final labelCode = sample == null ? '-' : _labelCodeOf(sample);
        final namaJenis = sample == null ? prefixType.displayName : (_namaJenisOf(sample) ?? prefixType.displayName);

        int newCount = 0;
        for (int i = 0; i < result.data.length; i++) {
          if (!_disabledAtOpen.contains(i)) newCount++;
        }

        // theme color for Gilingan
        final headerA = Colors.teal.shade600;
        final headerB = Colors.teal.shade700;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [headerA, headerB],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelCode,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              namaJenis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${typedItems.length} item',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // COLUMN HEADERS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'SAK',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'BERAT (KG)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 220,
                        child: Text(
                          'STATUS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: typedItems.length,
                    itemBuilder: (_, idx) {
                      final item = typedItems[idx];
                      final rawRow = result.data[idx];

                      final presence = _presenceForRow(vm, rawRow, result);
                      final isDuplicate = _isDisabled(idx);
                      final picked = _localPickedIndices.contains(idx);

                      if (isDuplicate && picked) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _localPickedIndices.remove(idx));
                        });
                      }

                      final sak = _sakOf(item);
                      final originalBerat = _beratOf(item);
                      final displayBerat = _editedWeights[idx] ?? originalBerat;
                      final beratTxt = displayBerat == null ? '-' : num2(displayBerat);

                      final isPartial = _isPartialOf(item, rawRow);
                      final isWeightEdited = _editedWeights.containsKey(idx);

                      String? statusText;
                      Color? statusColor;
                      switch (presence) {
                        case _Presence.temp:
                          statusText = 'Sudah Input';
                          statusColor = Colors.orange;
                          break;
                        case _Presence.none:
                          statusText = null;
                          statusColor = null;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IgnorePointer(
                          ignoring: isDuplicate,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isDuplicate ? 0.4 : 1.0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: isDuplicate ? null : () => _toggleRow(vm, idx),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: picked && !isDuplicate ? headerA.withOpacity(0.08) : Colors.white,
                                    border: Border.all(
                                      color: picked && !isDuplicate ? headerA.withOpacity(0.6) : Colors.grey.shade200,
                                      width: picked && !isDuplicate ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: picked && !isDuplicate
                                        ? [
                                      BoxShadow(
                                        color: headerA.withOpacity(0.10),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Checkbox(
                                          value: picked && !isDuplicate,
                                          onChanged: isDuplicate ? null : (_) => _toggleRow(vm, idx),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),

                                      // SAK (with partial icon)
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            if (isPartial) ...[
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.content_cut, size: 14, color: Colors.amber),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Expanded(
                                              child: Text(
                                                sak?.toString() ?? '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isDuplicate ? Colors.grey.shade400 : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // BERAT
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isWeightEdited
                                                    ? [Colors.amber.shade300, Colors.amber.shade400]
                                                    : statusText != null
                                                    ? [
                                                  statusColor!.withOpacity(0.2),
                                                  statusColor.withOpacity(0.3),
                                                ]
                                                    : [Colors.green.shade100, Colors.green.shade200],
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$beratTxt kg',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isWeightEdited
                                                    ? Colors.amber.shade900
                                                    : statusText != null
                                                    ? statusColor
                                                    : Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // STATUS / ACTIONS
                                      SizedBox(
                                        width: 220,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // Edit weight (partial)
                                            if (isPartial && !isDuplicate)
                                              SizedBox(
                                                height: 32,
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    side: BorderSide(color: Colors.amber.shade600, width: 1.5),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  icon: Icon(Icons.edit_outlined, size: 14, color: Colors.amber.shade700),
                                                  label: Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.amber.shade700,
                                                    ),
                                                  ),
                                                  onPressed: () async {
                                                    if (originalBerat != null) {
                                                      final newWeight = await WeightInputDialog.show(
                                                        context,
                                                        maxDecimalPlaces: item is BrokerItem ? 2 : null,
                                                        maxWeight: originalBerat,
                                                        currentWeight: _editedWeights[idx],
                                                      );
                                                      if (newWeight != null && mounted) {
                                                        setState(() => _editedWeights[idx] = newWeight);
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            if (isPartial && !isDuplicate) const SizedBox(width: 8),

                                            if (isPartial)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.amber.shade400),
                                                ),
                                                child: Text(
                                                  'PARTIAL',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.amber.shade700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),

                                            if (statusText != null)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor!.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: statusColor.withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: statusColor,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // FOOTER
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _localPickedIndices.isNotEmpty ? () => setState(_localPickedIndices.clear) : null,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Bersihkan'),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 8),

                      if (newCount > 0)
                        OutlinedButton.icon(
                          onPressed: () => _selectAllNew(vm, result),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text('Pilih Semua ($newCount)'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: headerA.withOpacity(0.6)),
                            foregroundColor: headerB,
                          ),
                        ),

                      const Spacer(),

                      if (_localPickedIndices.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: headerA.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_localPickedIndices.length} terpilih',
                            style: TextStyle(
                              color: headerB,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      FilledButton.icon(
                        onPressed: _localPickedIndices.isEmpty ? null : () => _commitSelection(vm, result),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(
                          _localPickedIndices.isEmpty ? 'Pilih Item' : 'Tambahkan (${_localPickedIndices.length})',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: headerA,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  // =========================
  // Helpers (Gilingan inputs)
  // =========================

  static String _labelCodeOf(dynamic item) {
    // GilinganInputs can receive upstream items:
    if (item is BrokerItem) return item.noBroker ?? '-';
    if (item is BbItem) {
      final np = (item.noBBPartial ?? '').trim();
      if (np.isNotEmpty) return np;
      final noBB = (item.noBahanBaku ?? '').trim();
      final pallet = item.noPallet;
      if (noBB.isEmpty) return '-';
      if (pallet == null || pallet.toString().trim().isEmpty) return noBB;
      return '$noBB-$pallet';
    }
    if (item is WashingItem) return item.noWashing ?? '-';
    if (item is CrusherItem) return item.noCrusher ?? '-';
    if (item is BonggolanItem) return item.noBonggolan ?? '-';
    if (item is RejectItem) return item.noReject ?? '-';
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is MixerItem) return item.noMixer ?? '-';
    return '-';
  }

  static String? _namaJenisOf(dynamic item) {
    try {
      final dyn = item as dynamic;
      return dyn.namaJenis as String?;
    } catch (_) {
      return null;
    }
  }

  static int? _sakOf(dynamic item) {
    try {
      final dyn = item as dynamic;
      final v = dyn.noSak;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  static double? _beratOf(dynamic item) {
    try {
      final dyn = item as dynamic;
      final v = dyn.berat;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _boolish(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 't' || s == 'yes' || s == 'y';
  }

  static bool _isPartialOf(dynamic item, Map<String, dynamic> row) {
    // DB flag
    if (_boolish(row['isPartial']) || _boolish(row['IsPartial'])) return true;

    // model flag (your items typically expose isPartialRow)
    try {
      final dyn = item as dynamic;
      final v = dyn.isPartialRow;
      if (v is bool && v) return true;
    } catch (_) {}

    // fallback (some models may expose isPartial)
    try {
      final dyn = item as dynamic;
      final v = dyn.isPartial;
      if (v is bool && v) return true;
    } catch (_) {}

    return false;
  }
}
