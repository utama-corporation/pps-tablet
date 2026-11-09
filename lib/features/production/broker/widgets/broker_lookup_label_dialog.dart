import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart';
import '../view_model/broker_production_input_view_model.dart';
import '../model/broker_inputs_model.dart';
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class BrokerLookupLabelDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;
  final Set<int>? preDisabledIndices;

  const BrokerLookupLabelDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
    this.preDisabledIndices,
  });

  @override
  State<BrokerLookupLabelDialog> createState() =>
      _BrokerLookupLabelDialogState();
}

class _BrokerLookupLabelDialogState extends State<BrokerLookupLabelDialog> {
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
      final vm = context.read<BrokerProductionInputViewModel>();

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
    final vm = context.read<BrokerProductionInputViewModel>();
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
    final vm = context.read<BrokerProductionInputViewModel>();
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
    BrokerProductionInputViewModel vm,
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
    BrokerProductionInputViewModel vm,
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
    BrokerProductionInputViewModel vm,
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
    BrokerProductionInputViewModel vm,
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
    return Consumer<BrokerProductionInputViewModel>(
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
        final namaJenis = sample == null
            ? prefixType.displayName
            : (_namaJenisOf(sample) ?? '-');

        int newCount = 0;
        for (int i = 0; i < result.data.length; i++) {
          if (!_disabledAtOpen.contains(i)) newCount++;
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ HEADER - Lebih modern dengan gradient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade700],
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
                              namaJenis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labelCode,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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

                // ✅ GRID - Kartu sak kotak-kotak (mengikuti desain _SakCard)
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final crossCount = constraints.maxWidth < 300
                          ? 4
                          : constraints.maxWidth < 450
                          ? 6
                          : constraints.maxWidth < 600
                          ? 7
                          : 8;
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: typedItems.length,
                        itemBuilder: (_, idx) {
                          final item = typedItems[idx];
                          final rawRow = result.data[idx];

                          final presence = _presenceForRow(
                            vm,
                            rawRow,
                            result,
                            widget.noProduksi,
                          );
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
                          final displayBerat =
                              _editedWeights[idx] ?? originalBerat;
                          final beratTxt = displayBerat == null
                              ? '-'
                              : num2(displayBerat);

                          final isPartial = _isPartialOf(item, rawRow);
                          final isWeightEdited = _editedWeights.containsKey(
                            idx,
                          );
                          final isSudahInput = presence == _Presence.temp;

                          Color cardBg;
                          Color borderColor;
                          Color titleColor;
                          if (isSudahInput) {
                            cardBg = Colors.orange.shade50;
                            borderColor = Colors.orange.shade300;
                            titleColor = Colors.orange.shade700;
                          } else if (picked) {
                            cardBg = const Color(0xFFDCEEFF);
                            borderColor = const Color(0xFF1D4ED8);
                            titleColor = const Color(0xFF1D4ED8);
                          } else {
                            cardBg = const Color(0xFFF0F7FF);
                            borderColor = const Color(0xFFBFDBFE);
                            titleColor = const Color(0xFF1D4ED8);
                          }

                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isDuplicate ? 0.45 : 1.0,
                            child: GestureDetector(
                              onTap: isDuplicate
                                  ? null
                                  : () => _toggleRow(vm, idx, rawRow),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: borderColor,
                                    width: picked && !isDuplicate ? 2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Sak ${sak ?? idx + 1}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: titleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$beratTxt kg',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isWeightEdited
                                                  ? Colors.amber.shade800
                                                  : const Color(0xFF374151),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Edit button for partial items (top-right)
                                    if (isPartial && !isDuplicate)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: GestureDetector(
                                          onTap: () async {
                                            if (originalBerat != null) {
                                              final newWeight =
                                                  await WeightInputDialog.show(
                                                    context,
                                                    maxDecimalPlaces: 2,
                                                    maxWeight: originalBerat,
                                                    currentWeight:
                                                        _editedWeights[idx],
                                                  );
                                              if (newWeight != null &&
                                                  mounted) {
                                                setState(
                                                  () => _editedWeights[idx] =
                                                      newWeight,
                                                );
                                              }
                                            }
                                          },
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: isWeightEdited
                                                  ? Colors.amber.shade500
                                                  : Colors.blue.shade400,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 9,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Checkmark for selected (top-left)
                                    if (picked && !isDuplicate)
                                      Positioned(
                                        top: 3,
                                        left: 3,
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    // "Input" label for already-added
                                    if (isSudahInput)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade400,
                                            ),
                                          ),
                                          child: Text(
                                            'Input',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // ✅ FOOTER - Lebih modern dan intuitive
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
                      // Clear button
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

                      // Select all button
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

                      // Submit button
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

  // ===== Helpers =====
  static String _labelCodeOf(dynamic item) {
    if (item is BrokerItem) return item.noBroker ?? '-';
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
    if (item is WashingItem) return item.noWashing ?? '-';
    if (item is CrusherItem) return item.noCrusher ?? '-';
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is MixerItem) return item.noMixer ?? '-';
    if (item is RejectItem) return item.noReject ?? '-';
    return '-';
  }

  static String? _namaJenisOf(dynamic item) {
    if (item is BrokerItem) return item.namaJenis;
    if (item is BbItem) return item.namaJenis;
    if (item is WashingItem) return item.namaJenis;
    if (item is CrusherItem) return item.namaJenis;
    if (item is GilinganItem) return item.namaJenis;
    if (item is MixerItem) return item.namaJenis;
    if (item is RejectItem) return item.namaJenis;
    return null;
  }

  static int? _sakOf(dynamic item) {
    if (item is BrokerItem) return item.noSak;
    if (item is BbItem) return item.noSak;
    if (item is WashingItem) return item.noSak;
    if (item is MixerItem) return item.noSak;
    return null;
  }

  static double? _beratOf(dynamic item) {
    if (item is BrokerItem) return item.berat;
    if (item is BbItem) return item.berat;
    if (item is WashingItem) return item.berat;
    if (item is CrusherItem) return item.berat;
    if (item is GilinganItem) return item.berat;
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
    if (_boolish(row['isPartial']) || _boolish(row['IsPartial'])) return true;

    try {
      if (item is BbItem && item.isPartialRow == true) return true;
      final dynamic dyn = item;
      final hasIsPartial = (dyn as dynamic).isPartial;
      if (hasIsPartial is bool && hasIsPartial) return true;
    } catch (_) {}
    return false;
  }
}
