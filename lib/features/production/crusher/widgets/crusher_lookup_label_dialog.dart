import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart';
import '../view_model/crusher_production_input_view_model.dart';
import '../model/crusher_inputs_model.dart'; // ✅ untuk BbItem & BonggolanItem
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class CrusherLookupLabelDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;
  final Set<int>? preDisabledIndices;

  const CrusherLookupLabelDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
    this.preDisabledIndices,
  });

  @override
  State<CrusherLookupLabelDialog> createState() =>
      _CrusherLookupLabelDialogState();
}

class _CrusherLookupLabelDialogState extends State<CrusherLookupLabelDialog> {
  final Set<int> _localPickedIndices = <int>{};
  final Set<int> _disabledAtOpen = <int>{};
  final Map<int, double> _editedWeights = {};

  bool _inputsReady = false;
  bool _didAutoSelect = false;

  @override
  void initState() {
    super.initState();
    _editedWeights.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<CrusherProductionInputViewModel>();

      // Refresh lookup berdasarkan label pertama
      final lastLookup = vm.lastLookup;
      if (lastLookup != null && lastLookup.typedItems.isNotEmpty) {
        final firstItem = lastLookup.typedItems.first;
        final labelCode = _labelCodeOf(firstItem);
        if (labelCode != '-') {
          await vm.lookupLabel(labelCode, force: true);
        }
      }

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
    final vm = context.read<CrusherProductionInputViewModel>();
    final result = vm.lastLookup;
    if (result == null) return;

    _disabledAtOpen.clear();
    for (int i = 0; i < result.data.length; i++) {
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
    final vm = context.read<CrusherProductionInputViewModel>();
    final result = vm.lastLookup;
    if (result == null || result.typedItems.isEmpty) return;

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

  void _toggleRow(
      CrusherProductionInputViewModel vm,
      int index,
      Map<String, dynamic> row,
      ) {
    if (_isDisabled(index)) return;
    setState(() {
      if (_localPickedIndices.contains(index)) {
        _localPickedIndices.remove(index);
      } else {
        _localPickedIndices.add(index);
      }
    });
  }

  void _selectAllNew(
      CrusherProductionInputViewModel vm,
      ProductionLabelLookupResult result,
      ) {
    setState(() {
      _localPickedIndices.clear();
      for (int i = 0; i < result.data.length; i++) {
        if (!_isDisabled(i)) {
          _localPickedIndices.add(i);
        }
      }
    });
  }

  void _commitSelection(
      CrusherProductionInputViewModel vm,
      ProductionLabelLookupResult result,
      ) {
    if (_localPickedIndices.isEmpty) return;

    vm.clearPicks();
    for (final i in _localPickedIndices) {
      if (i < result.data.length) {
        final row = result.data[i];
        if (_editedWeights.containsKey(i)) {
          row['berat'] = _editedWeights[i];
          row['Berat'] = _editedWeights[i];
        }
        if (!vm.isPicked(row)) vm.togglePick(row);
      }
    }

    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);
    Navigator.pop(context);

    final msg = r.added > 0
        ? 'Ditambahkan ${r.added} item'
        '${r.skipped > 0 ? ' • Duplikat terlewati ${r.skipped}' : ''}'
        : 'Tidak ada item baru ditambahkan';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  _Presence _presenceForRow(
      CrusherProductionInputViewModel vm,
      Map<String, dynamic> row,
      ProductionLabelLookupResult ctx,
      String noProduksi,
      ) {
    final sk = ctx.simpleKey(row);
    if (vm.isInTempKeys(sk)) {
      return _Presence.temp;
    }
    return _Presence.none;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CrusherProductionInputViewModel>(
      builder: (context, vm, _) {
        final result = vm.lastLookup;
        if (result == null) {
          return const Dialog(
            child: SizedBox(
              height: 120,
              child: Center(child: Text('Tidak ada hasil lookup')),
            ),
          );
        }

        if (!_inputsReady) {
          return const Dialog(
            child: SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final typedItems = result.typedItems;
        final prefixType = result.prefixType;

        final dynamic sample = typedItems.isNotEmpty ? typedItems.first : null;
        final labelCode = sample == null ? '-' : _labelCodeOf(sample);
        final namaJenis =
        sample == null ? prefixType.displayName : (_namaJenisOf(sample) ?? '-');

        int newCount = 0;
        for (int i = 0; i < result.data.length; i++) {
          if (!_disabledAtOpen.contains(i)) newCount++;
        }

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
                      colors: [
                        Colors.blue.shade600,
                        Colors.blue.shade700,
                      ],
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
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
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
                        padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _getDetailHeader(prefixType),
                          style: const TextStyle(
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
                          style: const TextStyle(
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

                      final presence =
                      _presenceForRow(vm, rawRow, result, widget.noProduksi);
                      final isDuplicate = _isDisabled(idx);
                      final picked = _localPickedIndices.contains(idx);

                      if (isDuplicate && picked) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _localPickedIndices.remove(idx));
                        });
                      }

                      final detail = _getDetailText(item, prefixType);
                      final originalBerat = _beratOf(item);
                      final displayBerat = _editedWeights[idx] ?? originalBerat;
                      final beratTxt =
                      displayBerat == null ? '-' : num2(displayBerat);

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

                      // Edit berat hanya relevan untuk item per-sak yang
                      // bisa partial (BB & Mixer).
                      final canEditWeight =
                          (item is BbItem || item is MixerItem) &&
                          isPartial &&
                          !isDuplicate;

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
                                onTap: isDuplicate
                                    ? null
                                    : () => _toggleRow(vm, idx, rawRow),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: picked && !isDuplicate
                                        ? Colors.blue.shade50
                                        : Colors.white,
                                    border: Border.all(
                                      color: picked && !isDuplicate
                                          ? Colors.blue.shade300
                                          : Colors.grey.shade200,
                                      width: picked && !isDuplicate ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: picked && !isDuplicate
                                        ? [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.1),
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
                                        child: Center(
                                          child: Checkbox(
                                            value: picked && !isDuplicate,
                                            onChanged: isDuplicate
                                                ? null
                                                : (_) =>
                                                _toggleRow(vm, idx, rawRow),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(6),
                                            ),
                                            materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                      ),

                                      // DETAIL (SAK / NO BONGGOL) + icon partial
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            if (isPartial) ...[
                                              Container(
                                                padding:
                                                const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                  BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.content_cut,
                                                  size: 14,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Expanded(
                                              child: Text(
                                                detail,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isDuplicate
                                                      ? Colors.grey.shade400
                                                      : Colors.black87,
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
                                            padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isWeightEdited
                                                    ? [
                                                  Colors.amber.shade300,
                                                  Colors.amber.shade400,
                                                ]
                                                    : statusText != null
                                                    ? [
                                                  statusColor!
                                                      .withOpacity(
                                                      0.2),
                                                  statusColor
                                                      .withOpacity(
                                                      0.3),
                                                ]
                                                    : [
                                                  Colors.green.shade100,
                                                  Colors.green.shade200,
                                                ],
                                              ),
                                              borderRadius:
                                              BorderRadius.circular(20),
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

                                      // BADGES & BUTTON
                                      SizedBox(
                                        width: 220,
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.end,
                                          children: [
                                            // Edit button (hanya BbItem partial)
                                            if (canEditWeight)
                                              SizedBox(
                                                height: 32,
                                                child: OutlinedButton.icon(
                                                  style:
                                                  OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    side: BorderSide(
                                                      color: Colors.amber.shade600,
                                                      width: 1.5,
                                                    ),
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                    ),
                                                  ),
                                                  icon: Icon(
                                                    Icons.edit_outlined,
                                                    size: 14,
                                                    color: Colors.amber.shade700,
                                                  ),
                                                  label: Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                      FontWeight.w600,
                                                      color: Colors.amber.shade700,
                                                    ),
                                                  ),
                                                  onPressed: () async {
                                                    if (originalBerat != null) {
                                                      final newWeight =
                                                      await WeightInputDialog
                                                          .show(
                                                        context,
                                                        maxWeight: originalBerat,
                                                        currentWeight:
                                                        _editedWeights[idx],
                                                      );

                                                      if (newWeight != null &&
                                                          mounted) {
                                                        setState(() {
                                                          _editedWeights[idx] =
                                                              newWeight;
                                                        });
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),

                                            if (canEditWeight)
                                              const SizedBox(width: 8),

                                            // Badges PARTIAL / STATUS
                                            if (isPartial)
                                              Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                  BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color:
                                                    Colors.amber.shade400,
                                                  ),
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
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 6),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor!
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                    BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: statusColor
                                                          .withOpacity(0.4),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                      FontWeight.w700,
                                                      color: statusColor,
                                                      letterSpacing: 0.3,
                                                    ),
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
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Clear
                      TextButton.icon(
                        onPressed: _localPickedIndices.isNotEmpty
                            ? () => setState(_localPickedIndices.clear)
                            : null,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Bersihkan'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Select all
                      if (newCount > 0)
                        OutlinedButton.icon(
                          onPressed: () => _selectAllNew(vm, result),
                          icon: const Icon(Icons.done_all, size: 18),
                          label: Text('Pilih Semua ($newCount)'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade300),
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),

                      const Spacer(),

                      // Counter
                      if (_localPickedIndices.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_localPickedIndices.length} terpilih',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // Submit
                      FilledButton.icon(
                        onPressed: _localPickedIndices.isEmpty
                            ? null
                            : () => _commitSelection(vm, result),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(
                          _localPickedIndices.isEmpty
                              ? 'Pilih Item'
                              : 'Tambahkan (${_localPickedIndices.length})',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
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

  // ===== Helpers: BbItem + BonggolanItem + RejectItem + MixerItem =====

  String _getDetailHeader(PrefixType type) {
    switch (type) {
      case PrefixType.bb:
        return 'SAK';
      case PrefixType.crusher:
        return 'NO BONGGOL';
      case PrefixType.mixer:
        return 'SAK';
      case PrefixType.reject:
        return 'NO REJECT';
      default:
        return 'DETAIL';
    }
  }

  String _getDetailText(dynamic item, PrefixType type) {
    if (item is BbItem) return '${item.noSak ?? '-'}';
    if (item is BonggolanItem) return item.noBonggolan ?? '-';
    if (item is MixerItem) return '${item.noSak ?? '-'}';
    if (item is RejectItem) {
      final part = (item.noRejectPartial ?? '').trim();
      return part.isNotEmpty ? part : (item.noReject ?? '-');
    }
    return '-';
  }

  static String _labelCodeOf(dynamic item) {
    if (item is BbItem) {
      // 1) Kalau ada kode partial (Q./P. dsb) → pakai itu
      final npart = (item.noBBPartial ?? '').trim();
      if (npart.isNotEmpty) return npart;

      // 2) Kalau tidak partial → gabung NoBahanBaku + "-" + NoPallet
      final noBB = (item.noBahanBaku ?? '').trim();
      final pallet = item.noPallet; // pastikan field ini ada di BbItem

      if (noBB.isEmpty) return '-';

      if (pallet == null) {
        // tidak ada pallet → tampilkan NoBahanBaku saja
        return noBB;
      }

      final palletStr = pallet.toString().trim();
      if (palletStr.isEmpty) return noBB;

      // Contoh: A.0000000001-1
      return '$noBB-$palletStr';
    }

    if (item is BonggolanItem) {
      return item.noBonggolan ?? '-';
    }

    if (item is MixerItem) {
      final part = (item.noMixerPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noMixer ?? '-';
    }

    if (item is RejectItem) {
      final part = (item.noRejectPartial ?? '').trim();
      if (part.isNotEmpty) return part;
      return item.noReject ?? '-';
    }
    return '-';
  }

  static String? _namaJenisOf(dynamic item) {
    if (item is BbItem) return item.namaJenis;
    if (item is BonggolanItem) return item.namaJenis;
    if (item is MixerItem) return item.namaJenis;
    if (item is RejectItem) return item.namaJenis;
    return null;
  }

  static double? _beratOf(dynamic item) {
    if (item is BbItem) return item.berat;
    if (item is BonggolanItem) return item.berat;
    if (item is MixerItem) return item.berat;
    if (item is RejectItem) return item.berat;
    return null;
  }

  static bool _boolish(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s == '1' || s == 'true' || s == 't' || s == 'yes' || s == 'y';
  }

  static bool _isPartialOf(dynamic item, Map<String, dynamic> row) {
    // Flag di row (IsPartial, isPartial)
    if (_boolish(row['isPartial']) || _boolish(row['IsPartial'])) return true;

    // Dari model
    try {
      if (item is BbItem && item.isPartialRow == true) return true;
      // BonggolanItem tidak punya partial
      if (item is MixerItem && item.isPartialRow == true) return true;
      if (item is RejectItem && item.isPartialRow == true) return true;
    } catch (_) {}
    return false;
  }
}
