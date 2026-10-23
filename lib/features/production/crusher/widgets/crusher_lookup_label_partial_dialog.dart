import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart'; // ✅ Import ini
import '../view_model/crusher_production_input_view_model.dart';
import '../model/crusher_inputs_model.dart'; // ✅ berisi BbItem & BonggolanItem
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class CrusherLookupLabelPartialDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;

  const CrusherLookupLabelPartialDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
  });

  @override
  State<CrusherLookupLabelPartialDialog> createState() =>
      _CrusherLookupLabelPartialDialogState();
}

class _CrusherLookupLabelPartialDialogState
    extends State<CrusherLookupLabelPartialDialog> {
  int? _selectedIndex;
  double? _editedWeight;
  bool _inputsReady = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = null;
    _editedWeight = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<CrusherProductionInputViewModel>();

      // Refresh lookup berdasarkan label code pertama (optional refresh)
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
      CrusherProductionInputViewModel vm,
      Map<String, dynamic> row,
      ProductionLabelLookupResult ctx,
      ) {
    final sk = ctx.simpleKey(row);
    if (vm.isInTempKeys(sk)) {
      return _Presence.temp;
    }
    return _Presence.none;
  }

  void _toggleRow(int index, Map<String, dynamic> row, bool isDisabled) {
    if (isDisabled) return;

    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = null;
        _editedWeight = null;
      } else {
        _selectedIndex = index;
        _editedWeight = _beratFromRow(row);
      }
    });
  }

  void _showWeightError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _commitSelection(
      CrusherProductionInputViewModel vm,
      ProductionLabelLookupResult result,
      ) {
    if (_selectedIndex == null) return;

    final row = result.data[_selectedIndex!];
    final originalBerat = row['berat'];
    final originalIsPartial = row['isPartial'];

    // Batas berat: sisa yang masih tersedia dari backend. WeightInputDialog
    // sudah memvalidasi saat user mengetik, tapi commit dicek ulang di sini
    // karena _editedWeight bisa terisi dari jalur lain.
    final maxWeight = _beratFromRow(row);
    if (_editedWeight != null) {
      if (_editedWeight! <= 0) {
        _showWeightError('Berat harus lebih besar dari 0 kg.');
        return;
      }
      if (maxWeight != null && _editedWeight! > maxWeight) {
        _showWeightError(
          'Berat ${num2(_editedWeight!)} kg melebihi sisa ${num2(maxWeight)} kg.',
        );
        return;
      }
    }

    // Kalau user edit berat → tandai sebagai partial (BB & Reject)
    if (_editedWeight != null) {
      row['isPartial'] = true;
      row['IsPartial'] = true;
      row['berat'] = _editedWeight;
      row['Berat'] = _editedWeight;
    }

    vm.clearPicks();
    vm.togglePick(row);

    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

    // Kembalikan row ke kondisi awal (biar ctx.data tetap “asli”)
    if (_editedWeight != null) {
      row['berat'] = originalBerat;
      row['Berat'] = originalBerat;
      row['isPartial'] = originalIsPartial;
      row['IsPartial'] = originalIsPartial;
    }

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
                      fontWeight: FontWeight.w600,
                    ),
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
                    child: Icon(
                      Icons.info_outline,
                      size: 48,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Tidak ada data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Label ini tidak memiliki data.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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

        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints:
            const BoxConstraints(maxWidth: 700, maxHeight: 600),
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
                        child: const Icon(
                          Icons.content_cut,
                          size: 28,
                          color: Colors.white,
                        ),
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
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
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
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pilih SATU item, lalu klik Edit untuk mengubah berat (hanya Bahan Baku).',
                          style: TextStyle(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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

                      final presence =
                      _presenceForRow(vm, rawRow, result);
                      final isDisabled = presence == _Presence.temp;

                      final isSelected = _selectedIndex == idx;
                      final detail = _getDetailText(item, prefixType);
                      final originalWeight = _beratOf(item);

                      final displayWeight =
                      isSelected && _editedWeight != null
                          ? _editedWeight!
                          : originalWeight;
                      final weightText = displayWeight == null
                          ? '-'
                          : num2(displayWeight);

                      final isOriginalPartial = _isPartialOf(item, rawRow);

                      final isWeightEdited = isSelected &&
                          _editedWeight != null &&
                          _editedWeight != originalWeight;

                      String? statusText;
                      Color? statusColor;
                      if (presence == _Presence.temp) {
                        statusText = 'Sudah Input';
                        statusColor = Colors.orange;
                      }

                      // BB, Reject & Mixer punya partial; semuanya batasnya
                      // berat sisa dari backend
                      final canEditWeight =
                          (item is BbItem ||
                              item is RejectItem ||
                              item is MixerItem) &&
                          !isDisabled &&
                          isSelected;

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
                                    : () => _toggleRow(
                                  idx,
                                  rawRow,
                                  isDisabled,
                                ),
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
                                    borderRadius:
                                    BorderRadius.circular(12),
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
                                      // Radio
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Center(
                                          child: Radio<int>(
                                            value: idx,
                                            groupValue: _selectedIndex,
                                            activeColor: Colors.amber,
                                            onChanged: isDisabled
                                                ? null
                                                : (_) => _toggleRow(
                                              idx,
                                              rawRow,
                                              isDisabled,
                                            ),
                                            materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
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
                                                  BorderRadius.circular(
                                                    6,
                                                  ),
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
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isDisabled
                                                      ? Colors
                                                      .grey.shade400
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Berat
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment:
                                          Alignment.centerRight,
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
                                                  Colors
                                                      .amber.shade300,
                                                  Colors
                                                      .amber.shade400,
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
                                                  Colors.green
                                                      .shade100,
                                                  Colors.green
                                                      .shade200,
                                                ],
                                              ),
                                              borderRadius:
                                              BorderRadius.circular(
                                                  20),
                                            ),
                                            child: Text(
                                              '$weightText kg',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                FontWeight.bold,
                                                color: isWeightEdited
                                                    ? Colors
                                                    .amber.shade900
                                                    : statusText != null
                                                    ? statusColor
                                                    : Colors.green
                                                    .shade800,
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
// Edit berat (BB & Reject)
                                             if (canEditWeight)
                                              SizedBox(
                                                height: 32,
                                                child:
                                                OutlinedButton.icon(
                                                  style: OutlinedButton
                                                      .styleFrom(
                                                    padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    side: BorderSide(
                                                      color: Colors.amber
                                                          .shade600,
                                                      width: 1.5,
                                                    ),
                                                    shape:
                                                    RoundedRectangleBorder(
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
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
                                                    final originalWeight =
                                                    _beratOf(item);
                                                    if (originalWeight !=
                                                        null) {
                                                      final newWeight =
                                                      await WeightInputDialog
                                                          .show(
                                                        context,
                                                        maxWeight:
                                                        originalWeight,
                                                        currentWeight:
                                                        _editedWeight,
                                                      );

                                                      if (newWeight !=
                                                          null &&
                                                          mounted) {
                                                        setState(() {
                                                          _editedWeight =
                                                              newWeight;
                                                        });
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),

                                            if (canEditWeight)
                                              const SizedBox(width: 8),

                                            if (statusText != null)
                                              Container(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor!
                                                      .withOpacity(
                                                      0.15),
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                                  border: Border.all(
                                                    color: statusColor
                                                        .withOpacity(
                                                        0.4),
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
                                              )
                                            else if (isWeightEdited)
                                              Container(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                                  border: Border.all(
                                                    color: Colors.amber
                                                        .shade400,
                                                  ),
                                                ),
                                                child: Text(
                                                  'EDITED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                    FontWeight.w800,
                                                    color: Colors.amber
                                                        .shade700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              )
                                            else if (isOriginalPartial)
                                                Container(
                                                  padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(6),
                                                    border: Border.all(
                                                      color: Colors.orange
                                                          .shade400,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'PARTIAL',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                      FontWeight.w800,
                                                      color: Colors.orange
                                                          .shade700,
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
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                            '1 item${_editedWeight != null && _editedWeight != _beratOf(allTypedItems[_selectedIndex!]) ? ' • Diubah' : ''}',
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
                          _selectedIndex == null
                              ? 'Pilih Item'
                              : 'Tambahkan',
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

  // ===== HELPERS =====

  String _getDetailHeader(PrefixType type) {
    switch (type) {
      case PrefixType.bb:
        return 'SAK';
      case PrefixType.crusher:
      // diasumsikan prefix untuk Bonggolan di Crusher
        return 'NO BONGGOL';
      case PrefixType.mixer:
        return 'SAK';
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

  double? _beratFromRow(Map<String, dynamic> row) {
    final berat = row['berat'] ?? row['Berat'];
    if (berat is num) return berat.toDouble();
    if (berat is String) return double.tryParse(berat);
    return null;
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
    return s == '1' ||
        s == 'true' ||
        s == 't' ||
        s == 'yes' ||
        s == 'y';
  }

  static bool _isPartialOf(dynamic item, Map<String, dynamic> row) {
    // Flag di row
    if (_boolish(row['isPartial']) || _boolish(row['IsPartial'])) {
      return true;
    }

    try {
      if (item is BbItem && item.isPartialRow == true) return true;
      if (item is MixerItem && item.isPartialRow == true) return true;
      // kalau BonggolanItem → selalu false
    } catch (_) {}
    return false;
  }
}
