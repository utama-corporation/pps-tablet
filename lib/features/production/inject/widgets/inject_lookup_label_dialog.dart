// lib/features/production/inject_production/widgets/inject_lookup_label_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart';
import '../view_model/inject_production_input_view_model.dart';
import '../model/inject_production_inputs_model.dart';
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class InjectLookupLabelDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;
  final Set<int>? preDisabledIndices;

  const InjectLookupLabelDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
    this.preDisabledIndices,
  });

  @override
  State<InjectLookupLabelDialog> createState() => _InjectLookupLabelDialogState();
}

class _InjectLookupLabelDialogState extends State<InjectLookupLabelDialog> {
  final Set<int> _localPickedIndices = <int>{};
  final Set<int> _disabledAtOpen = <int>{};
  final Map<int, double> _editedWeights = {}; // For Broker, Mixer, Gilingan partials
  final Map<int, int> _editedPcs = {}; // For FWIP partials

  bool _inputsReady = false;
  bool _didAutoSelect = false;

  @override
  void initState() {
    super.initState();
    _editedWeights.clear();
    _editedPcs.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<InjectProductionInputViewModel>();

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
    final vm = context.read<InjectProductionInputViewModel>();
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
    final vm = context.read<InjectProductionInputViewModel>();
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

  void _toggleRow(InjectProductionInputViewModel vm, int index, Map<String, dynamic> row) {
    if (_isDisabled(index)) return;
    setState(() {
      if (_localPickedIndices.contains(index)) {
        _localPickedIndices.remove(index);
      } else {
        _localPickedIndices.add(index);
      }
    });
  }

  void _selectAllNew(InjectProductionInputViewModel vm, ProductionLabelLookupResult result) {
    setState(() {
      _localPickedIndices.clear();
      for (int i = 0; i < result.data.length; i++) {
        if (!_isDisabled(i)) {
          _localPickedIndices.add(i);
        }
      }
    });
  }

  void _commitSelection(InjectProductionInputViewModel vm, ProductionLabelLookupResult result) {
    if (_localPickedIndices.isEmpty) return;

    vm.clearPicks();
    for (final i in _localPickedIndices) {
      if (i < result.data.length) {
        final row = result.data[i];

        // Apply weight edits (for Broker, Mixer, Gilingan partials)
        if (_editedWeights.containsKey(i)) {
          row['berat'] = _editedWeights[i];
          row['Berat'] = _editedWeights[i];
        }

        // Apply pcs edits (for FWIP partials)
        if (_editedPcs.containsKey(i)) {
          row['pcs'] = _editedPcs[i];
          row['Pcs'] = _editedPcs[i];
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
      InjectProductionInputViewModel vm,
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
    return Consumer<InjectProductionInputViewModel>(
      builder: (context, vm, _) {
        final result = vm.lastLookup;
        if (result == null) {
          return const Dialog(
            child: SizedBox(height: 120, child: Center(child: Text('Tidak ada hasil lookup'))),
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
        final namaJenis = sample == null ? prefixType.displayName : (_namaJenisOf(sample) ?? '-');

        int newCount = 0;
        for (int i = 0; i < result.data.length; i++) {
          if (!_disabledAtOpen.contains(i)) newCount++;
        }

        // ✅ Determine if this prefix uses PCS (FWIP) or BERAT (others)
        final bool usesPcs = prefixType == PrefixType.furnitureWip;

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
                // ✅ HEADER - Modern dengan gradient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.shade600,
                        Colors.deepPurple.shade700,
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

                // ✅ COLUMN HEADERS (Dynamic based on prefix type)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          _getColumnHeader1(prefixType),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          usesPcs ? 'PCS' : 'BERAT (KG)',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
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

                // ✅ LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: typedItems.length,
                    itemBuilder: (_, idx) {
                      final item = typedItems[idx];
                      final rawRow = result.data[idx];

                      final presence = _presenceForRow(vm, rawRow, result, widget.noProduksi);
                      final isDuplicate = _isDisabled(idx);
                      final picked = _localPickedIndices.contains(idx);

                      if (isDuplicate && picked) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() => _localPickedIndices.remove(idx));
                        });
                      }

                      final col1Value = _getColumn1Value(item, prefixType);

                      // Get original value (berat or pcs)
                      final originalBerat = usesPcs ? null : _beratOf(item);
                      final originalPcs = usesPcs ? _pcsOf(item) : null;

                      // Get display value (with edits)
                      final displayBerat = usesPcs ? null : (_editedWeights[idx] ?? originalBerat);
                      final displayPcs = usesPcs ? (_editedPcs[idx] ?? originalPcs) : null;

                      final valueText = usesPcs
                          ? (displayPcs?.toString() ?? '-')
                          : (displayBerat == null ? '-' : num2(displayBerat));

                      final isPartial = _isPartialOf(item, rawRow);
                      final isValueEdited = usesPcs
                          ? _editedPcs.containsKey(idx)
                          : _editedWeights.containsKey(idx);

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
                                onTap: isDuplicate ? null : () => _toggleRow(vm, idx, rawRow),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: picked && !isDuplicate
                                        ? Colors.deepPurple.shade50
                                        : Colors.white,
                                    border: Border.all(
                                      color: picked && !isDuplicate
                                          ? Colors.deepPurple.shade300
                                          : Colors.grey.shade200,
                                      width: picked && !isDuplicate ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: picked && !isDuplicate
                                        ? [
                                      BoxShadow(
                                        color: Colors.deepPurple.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: Checkbox(
                                          value: picked && !isDuplicate,
                                          onChanged: isDuplicate
                                              ? null
                                              : (_) => _toggleRow(vm, idx, rawRow),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),

                                      // Column 1 (SAK / Label) dengan icon partial
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
                                                col1Value,
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

                                      // VALUE (BERAT/PCS) - Pill style
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isValueEdited
                                                    ? [
                                                  Colors.amber.shade300,
                                                  Colors.amber.shade400,
                                                ]
                                                    : statusText != null
                                                    ? [
                                                  statusColor!.withOpacity(0.2),
                                                  statusColor.withOpacity(0.3),
                                                ]
                                                    : [
                                                  Colors.green.shade100,
                                                  Colors.green.shade200,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              usesPcs ? '$valueText pcs' : '$valueText kg',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isValueEdited
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
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // Edit button (for partials only)
                                            if (isPartial && !isDuplicate)
                                              Container(
                                                height: 32,
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    side: BorderSide(
                                                      color: Colors.amber.shade600,
                                                      width: 1.5,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
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
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.amber.shade700,
                                                    ),
                                                  ),
                                                  onPressed: () async {
                                                    if (usesPcs) {
                                                      // Edit PCS for FWIP
                                                      if (originalPcs != null) {
                                                        final newPcs = await _showPcsInputDialog(
                                                          context,
                                                          maxPcs: originalPcs,
                                                          currentPcs: _editedPcs[idx],
                                                        );

                                                        if (newPcs != null && mounted) {
                                                          setState(() {
                                                            _editedPcs[idx] = newPcs;
                                                          });
                                                        }
                                                      }
                                                    } else {
                                                      // Edit BERAT for Broker/Mixer/Gilingan
                                                      if (originalBerat != null) {
                                                        final newWeight =
                                                        await WeightInputDialog.show(
                                                          context,
                                                          maxDecimalPlaces: item is BrokerItem ? 2 : null,
                                                          maxWeight: originalBerat,
                                                          currentWeight: _editedWeights[idx],
                                                        );

                                                        if (newWeight != null && mounted) {
                                                          setState(() {
                                                            _editedWeights[idx] = newWeight;
                                                          });
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),

                                            if (isPartial && !isDuplicate)
                                              const SizedBox(width: 8),

                                            // Badges
                                            if (isPartial)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.amber.shade400,
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
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor!.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: statusColor.withOpacity(0.4),
                                                  ),
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

                // ✅ FOOTER
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
                            side: BorderSide(color: Colors.deepPurple.shade300),
                            foregroundColor: Colors.deepPurple.shade700,
                          ),
                        ),

                      const Spacer(),

                      // Counter
                      if (_localPickedIndices.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_localPickedIndices.length} terpilih',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
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
                          backgroundColor: Colors.deepPurple.shade600,
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

  // ===== Helper: Show PCS input dialog for FWIP =====
  Future<int?> _showPcsInputDialog(BuildContext context, {
    required int maxPcs,
    int? currentPcs,
  }) async {
    final controller = TextEditingController(
      text: currentPcs?.toString() ?? '',
    );

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Jumlah Pcs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maksimal: $maxPcs pcs'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Pcs',
                suffixText: 'pcs',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              final val = int.tryParse(text);
              if (val == null || val <= 0 || val > maxPcs) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Pcs harus antara 1 dan $maxPcs'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, val);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ===== Helpers =====
  static String _labelCodeOf(dynamic item) {
    if (item is BrokerItem) return item.noBroker ?? '-';
    if (item is MixerItem) return item.noMixer ?? '-';
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is FurnitureWipItem) {
      final npart = (item.noFurnitureWIPPartial ?? '').trim();
      if (npart.isNotEmpty) return npart;
      return item.noFurnitureWIP ?? '-';
    }
    return '-';
  }

  static String? _namaJenisOf(dynamic item) {
    if (item is BrokerItem) return item.namaJenis;
    if (item is MixerItem) return item.namaJenis;
    if (item is GilinganItem) return item.namaJenis;
    if (item is FurnitureWipItem) return item.namaJenis;
    return null;
  }

  static String _getColumnHeader1(PrefixType type) {
    switch (type) {
      case PrefixType.broker:
      case PrefixType.mixer:
        return 'SAK';
      case PrefixType.gilingan:
        return 'LABEL';
      case PrefixType.furnitureWip:
        return 'LABEL';
      default:
        return 'ID';
    }
  }

  static String _getColumn1Value(dynamic item, PrefixType type) {
    switch (type) {
      case PrefixType.broker:
        if (item is BrokerItem) return item.noSak?.toString() ?? '-';
        break;
      case PrefixType.mixer:
        if (item is MixerItem) return item.noSak?.toString() ?? '-';
        break;
      case PrefixType.gilingan:
        if (item is GilinganItem) return item.noGilingan ?? '-';
        break;
      case PrefixType.furnitureWip:
        if (item is FurnitureWipItem) {
          final part = (item.noFurnitureWIPPartial ?? '').trim();
          return part.isNotEmpty ? part : (item.noFurnitureWIP ?? '-');
        }
        break;
      default:
        break;
    }
    return '-';
  }

  static double? _beratOf(dynamic item) {
    if (item is BrokerItem) return item.berat;
    if (item is MixerItem) return item.berat;
    if (item is GilinganItem) return item.berat;
    if (item is FurnitureWipItem) return item.berat;
    return null;
  }

  static int? _pcsOf(dynamic item) {
    if (item is FurnitureWipItem) return item.pcs;
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
      final dynamic dyn = item;
      final hasIsPartial = (dyn as dynamic?)?.isPartial;
      if (hasIsPartial is bool && hasIsPartial) return true;

      // Check isPartialRow
      final hasIsPartialRow = (dyn as dynamic?)?.isPartialRow;
      if (hasIsPartialRow is bool && hasIsPartialRow) return true;
    } catch (_) {}
    return false;
  }
}