// lib/features/production/inject_production/widgets/inject_lookup_label_partial_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart';
import '../view_model/inject_production_input_view_model.dart';
import '../model/inject_production_inputs_model.dart';
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class InjectLookupLabelPartialDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;

  const InjectLookupLabelPartialDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
  });

  @override
  State<InjectLookupLabelPartialDialog> createState() =>
      _InjectLookupLabelPartialDialogState();
}

class _InjectLookupLabelPartialDialogState
    extends State<InjectLookupLabelPartialDialog> {
  int? _selectedIndex;
  double? _editedWeight; // For Broker, Mixer, Gilingan
  int? _editedPcs; // For FurnitureWIP
  bool _inputsReady = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = null;
    _editedWeight = null;
    _editedPcs = null;

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

      if (mounted) setState(() {});
    });
  }

  _Presence _presenceForRow(
      InjectProductionInputViewModel vm,
      Map<String, dynamic> row,
      ProductionLabelLookupResult ctx,
      ) {
    final sk = ctx.simpleKey(row);
    if (vm.isInTempKeys(sk)) {
      return _Presence.temp;
    }
    return _Presence.none;
  }

  void _toggleRow(int index, Map<String, dynamic> row, bool isDisabled, PrefixType prefixType) {
    if (isDisabled) return;

    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = null;
        _editedWeight = null;
        _editedPcs = null;
      } else {
        _selectedIndex = index;

        // Initialize based on prefix type
        if (prefixType == PrefixType.furnitureWip) {
          _editedPcs = _pcsFromRow(row);
          _editedWeight = null;
        } else {
          _editedWeight = _beratFromRow(row);
          _editedPcs = null;
        }
      }
    });
  }

  void _commitSelection(
      InjectProductionInputViewModel vm, ProductionLabelLookupResult result) {
    if (_selectedIndex == null) return;

    final row = result.data[_selectedIndex!];
    final originalBerat = row['berat'];
    final originalPcs = row['pcs'];
    final originalIsPartial = row['isPartial'];

    // Apply edits based on what was changed
    if (_editedWeight != null) {
      row['isPartial'] = true;
      row['IsPartial'] = true;
      row['berat'] = _editedWeight;
      row['Berat'] = _editedWeight;
    }

    if (_editedPcs != null) {
      row['isPartial'] = true;
      row['IsPartial'] = true;
      row['pcs'] = _editedPcs;
      row['Pcs'] = _editedPcs;
    }

    vm.clearPicks();
    vm.togglePick(row);

    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

    // Restore original values
    if (_editedWeight != null) {
      row['berat'] = originalBerat;
      row['Berat'] = originalBerat;
    }
    if (_editedPcs != null) {
      row['pcs'] = originalPcs;
      row['Pcs'] = originalPcs;
    }
    row['isPartial'] = originalIsPartial;
    row['IsPartial'] = originalIsPartial;

    Navigator.pop(context);

    final msg = r.added > 0
        ? 'Ditambahkan ${r.added} item${r.skipped > 0 ? ' • Duplikat terlewati ${r.skipped}' : ''}'
        : 'Item sudah ada atau gagal ditambahkan';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: r.added > 0 ? Colors.green : Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InjectProductionInputViewModel>(
      builder: (context, vm, _) {
        final result = vm.lastLookup;
        if (result == null) {
          return const Dialog(
            child: SizedBox(
                height: 120,
                child: Center(child: Text('Tidak ada hasil lookup'))),
          );
        }

        if (!_inputsReady) {
          return Dialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              height: 160,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat data...',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        }

        final allTypedItems = result.typedItems;
        final allData = result.data;

        if (allTypedItems.isEmpty) {
          return Dialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.info_outline,
                        size: 48, color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tidak ada data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Label ini tidak memiliki data.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          );
        }

        final prefixType = result.prefixType;
        final dynamic sample = allTypedItems.first;
        final labelCode = _labelCodeOf(sample);
        final namaJenis = _namaJenisOf(sample) ?? '-';

        // ✅ Determine if this prefix uses PCS (FWIP) or BERAT (others)
        final bool usesPcs = prefixType == PrefixType.furnitureWip;

        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
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
                        Colors.amber.shade600,
                        Colors.amber.shade700,
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
                        child: const Icon(Icons.content_cut,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  labelCode,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${allTypedItems.length} item',
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

                // INFO BOX
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade50,
                        Colors.blue.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.lightbulb_outline,
                            size: 20, color: Colors.blue.shade700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          usesPcs
                              ? 'Pilih SATU item, lalu klik Edit untuk mengubah jumlah pcs'
                              : 'Pilih SATU item, lalu klik Edit untuk mengubah berat',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
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
                        width: 140,
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
                    itemCount: allTypedItems.length,
                    itemBuilder: (_, idx) {
                      final item = allTypedItems[idx];
                      final rawRow = allData[idx];

                      final presence = _presenceForRow(vm, rawRow, result);
                      final isDisabled = presence == _Presence.temp;

                      final isSelected = _selectedIndex == idx;
                      final detail = _getDetailText(item, prefixType);

                      // Get original values
                      final originalWeight = usesPcs ? null : _beratOf(item);
                      final originalPcs = usesPcs ? _pcsOf(item) : null;

                      // Get display values (with edits)
                      final displayWeight = isSelected && _editedWeight != null
                          ? _editedWeight!
                          : originalWeight;
                      final displayPcs = isSelected && _editedPcs != null
                          ? _editedPcs!
                          : originalPcs;

                      final valueText = usesPcs
                          ? (displayPcs?.toString() ?? '-')
                          : (displayWeight == null ? '-' : num2(displayWeight));

                      final isOriginalPartial = _isPartialOf(item, rawRow);

                      final isValueEdited = usesPcs
                          ? (isSelected && _editedPcs != null && _editedPcs != originalPcs)
                          : (isSelected && _editedWeight != null && _editedWeight != originalWeight);

                      String? statusText;
                      Color? statusColor;
                      if (presence == _Presence.temp) {
                        statusText = 'Sudah Input';
                        statusColor = Colors.orange;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IgnorePointer(
                          ignoring: isDisabled,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isDisabled ? 0.4 : 1.0,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: isDisabled
                                    ? null
                                    : () => _toggleRow(idx, rawRow, isDisabled, prefixType),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected && !isDisabled
                                        ? Colors.amber.shade50
                                        : Colors.white,
                                    border: Border.all(
                                      color: isSelected && !isDisabled
                                          ? Colors.amber.shade400
                                          : Colors.grey.shade200,
                                      width: isSelected && !isDisabled ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isSelected && !isDisabled
                                        ? [
                                      BoxShadow(
                                        color: Colors.amber
                                            .withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Radio button
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: Radio<int>(
                                          value: idx,
                                          groupValue: _selectedIndex,
                                          activeColor: Colors.amber,
                                          onChanged: isDisabled
                                              ? null
                                              : (_) => _toggleRow(
                                              idx, rawRow, isDisabled, prefixType),
                                          materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),

                                      // Detail
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            if (isOriginalPartial) ...[
                                              Container(
                                                padding:
                                                const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                  BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.content_cut,
                                                  size: 14,
                                                  color: Colors.orange,
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
                                                  color: isDisabled
                                                      ? Colors.grey.shade400
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Value (Berat/Pcs)
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
                                              usesPcs ? '$valueText pcs' : '$valueText kg',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isValueEdited
                                                    ? Colors.amber.shade900
                                                    : statusText != null
                                                    ? statusColor
                                                    : Colors
                                                    .green.shade800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Status & Button
                                      SizedBox(
                                        width: 140,
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.end,
                                          children: [
                                            // Edit button
                                            if (isSelected && !isDisabled)
                                              Container(
                                                height: 32,
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    side: BorderSide(
                                                      color: Colors
                                                          .amber.shade600,
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
                                                    color: Colors
                                                        .amber.shade700,
                                                  ),
                                                  label: Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                      FontWeight.w600,
                                                      color: Colors
                                                          .amber.shade700,
                                                    ),
                                                  ),
                                                  onPressed: () async {
                                                    if (usesPcs) {
                                                      // Edit PCS for FWIP
                                                      if (originalPcs != null) {
                                                        final newPcs =
                                                        await _showPcsInputDialog(
                                                          context,
                                                          maxPcs: originalPcs,
                                                          currentPcs: _editedPcs,
                                                        );

                                                        if (newPcs != null &&
                                                            mounted) {
                                                          setState(() {
                                                            _editedPcs = newPcs;
                                                          });
                                                        }
                                                      }
                                                    } else {
                                                      // Edit BERAT for others
                                                      if (originalWeight !=
                                                          null) {
                                                        final newWeight =
                                                        await WeightInputDialog
                                                            .show(
                                                          context,
                                                          maxDecimalPlaces: item is BrokerItem ? 2 : null,
                                                          maxWeight:
                                                          originalWeight,
                                                          currentWeight:
                                                          _editedWeight,
                                                        );

                                                        if (newWeight != null &&
                                                            mounted) {
                                                          setState(() {
                                                            _editedWeight =
                                                                newWeight;
                                                          });
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),

                                            if (isSelected && !isDisabled)
                                              const SizedBox(width: 8),

                                            // Status badges
                                            if (statusText != null)
                                              Container(
                                                padding:
                                                const EdgeInsets.symmetric(
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
                                                    fontWeight: FontWeight.w700,
                                                    color: statusColor,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              )
                                            else if (isValueEdited)
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
                                                    color: Colors.amber.shade400,
                                                  ),
                                                ),
                                                child: Text(
                                                  'EDITED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.amber.shade700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              )
                                            else if (isOriginalPartial)
                                                Container(
                                                  padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                    BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color:
                                                      Colors.orange.shade400,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'PARTIAL',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color:
                                                      Colors.orange.shade700,
                                                      letterSpacing: 0.5,
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
                      TextButton.icon(
                        onPressed: _selectedIndex != null
                            ? () => setState(() {
                          _selectedIndex = null;
                          _editedWeight = null;
                          _editedPcs = null;
                        })
                            : null,
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Batal'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedIndex != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade100,
                                Colors.amber.shade200,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                                () {
                              String text = '1 item';
                              final item = allTypedItems[_selectedIndex!];
                              final isEdited = usesPcs
                                  ? (_editedPcs != null && _editedPcs != _pcsOf(item))
                                  : (_editedWeight != null && _editedWeight != _beratOf(item));
                              if (isEdited) text += ' • Diubah';
                              return text;
                            }(),
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: _selectedIndex == null
                            ? null
                            : () => _commitSelection(vm, result),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: Text(
                          _selectedIndex == null ? 'Pilih Item' : 'Tambahkan',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade600,
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

  // ===== PCS Input Dialog for FWIP =====
  Future<int?> _showPcsInputDialog(
      BuildContext context, {
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

  // ===== HELPERS =====

  String _getDetailHeader(PrefixType type) {
    switch (type) {
      case PrefixType.broker:
      case PrefixType.mixer:
        return 'SAK';
      case PrefixType.gilingan:
        return 'NO GILINGAN';
      case PrefixType.furnitureWip:
        return 'LABEL';
      default:
        return 'DETAIL';
    }
  }

  String _getDetailText(dynamic item, PrefixType type) {
    if (item is BrokerItem) return '${item.noSak ?? '-'}';
    if (item is MixerItem) return '${item.noSak ?? '-'}';
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is FurnitureWipItem) {
      final part = (item.noFurnitureWIPPartial ?? '').trim();
      return part.isNotEmpty ? part : (item.noFurnitureWIP ?? '-');
    }
    return '-';
  }

  double? _beratFromRow(Map<String, dynamic> row) {
    final berat = row['berat'] ?? row['Berat'];
    if (berat is num) return berat.toDouble();
    if (berat is String) return double.tryParse(berat);
    return null;
  }

  int? _pcsFromRow(Map<String, dynamic> row) {
    final pcs = row['pcs'] ?? row['Pcs'];
    if (pcs is int) return pcs;
    if (pcs is num) return pcs.toInt();
    if (pcs is String) return int.tryParse(pcs);
    return null;
  }

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

      final hasIsPartialRow = (dyn as dynamic?)?.isPartialRow;
      if (hasIsPartialRow is bool && hasIsPartialRow) return true;
    } catch (_) {}
    return false;
  }
}