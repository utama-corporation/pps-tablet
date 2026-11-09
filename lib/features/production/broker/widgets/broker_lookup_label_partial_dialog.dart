import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/weight_input_dialog.dart'; // ✅ Import ini
import '../view_model/broker_production_input_view_model.dart';
import '../model/broker_inputs_model.dart';
import '../../shared/models/production_label_lookup_result.dart';

enum _Presence { none, temp }

class LookupLabelPartialDialog extends StatefulWidget {
  final String noProduksi;
  final String selectedMode;

  const LookupLabelPartialDialog({
    super.key,
    required this.noProduksi,
    required this.selectedMode,
  });

  @override
  State<LookupLabelPartialDialog> createState() => _LookupLabelPartialDialogState();
}

class _LookupLabelPartialDialogState extends State<LookupLabelPartialDialog> {
  int? _selectedIndex;
  double? _editedWeight;
  bool _inputsReady = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = null;
    _editedWeight = null;

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

      if (mounted) setState(() {});
    });
  }

  _Presence _presenceForRow(
      BrokerProductionInputViewModel vm,
      Map<String, dynamic> row,
      ProductionLabelLookupResult ctx,
      ) {
    final sk = ctx.simpleKey(row);
    if (vm.isInTempKeys(sk)) {
      return _Presence.temp;
    }
    return _Presence.none;
  }

  Future<void> _toggleRow(
    int index,
    Map<String, dynamic> row,
    bool isDisabled,
    BrokerProductionInputViewModel vm,
    ProductionLabelLookupResult result,
  ) async {
    if (isDisabled) return;

    final originalBerat = _beratFromRow(row);
    if (originalBerat == null) return;

    final newWeight = await WeightInputDialog.show(
      context,
      maxDecimalPlaces: 2,
      maxWeight: originalBerat,
      currentWeight: null,
    );

    if (!mounted || newWeight == null) return;

    // Langsung commit — tidak perlu kembali ke dialog grid
    _editedWeight = newWeight;
    _selectedIndex = index;
    _commitSelection(vm, result);
  }

  void _commitSelection(BrokerProductionInputViewModel vm, ProductionLabelLookupResult result) {
    if (_selectedIndex == null) return;

    final row = result.data[_selectedIndex!];
    final originalBerat = row['berat'];
    final originalIsPartial = row['isPartial'];

    if (_editedWeight != null) {
      row['isPartial'] = true;
      row['IsPartial'] = true;
      row['berat'] = _editedWeight;
      row['Berat'] = _editedWeight;
    }

    vm.clearPicks();
    vm.togglePick(row);

    final r = vm.commitPickedToTemp(noProduksi: widget.noProduksi);

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
    return Consumer<BrokerProductionInputViewModel>(
      builder: (context, vm, _) {
        final result = vm.lastLookup;
        if (result == null) {
          return const Dialog(
            child: SizedBox(height: 120, child: Center(child: Text('Tidak ada hasil lookup'))),
          );
        }

        if (!_inputsReady) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: Icon(Icons.info_outline, size: 48, color: Colors.orange.shade700),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                        child: const Icon(Icons.content_cut, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    namaJenis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                // HINT
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Text(
                    'Ketuk sak untuk memilih berat partial yang akan diinput',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),

                // GRID
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final crossCount = constraints.maxWidth < 300
                          ? 4
                          : constraints.maxWidth < 400
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
                        itemCount: allTypedItems.length,
                        itemBuilder: (_, idx) {
                          final item = allTypedItems[idx];
                          final rawRow = allData[idx];

                          final presence = _presenceForRow(vm, rawRow, result);
                          final isDisabled = presence == _Presence.temp;
                          final isSelected = _selectedIndex == idx;
                          final detail = _getDetailText(item, prefixType);
                          final originalWeight = _beratOf(item);
                          final displayWeight = isSelected && _editedWeight != null
                              ? _editedWeight!
                              : originalWeight;
                          final weightText = displayWeight == null ? '-' : num2(displayWeight);
                          final isOriginalPartial = _isPartialOf(item, rawRow);
                          final isWeightEdited = isSelected &&
                              _editedWeight != null &&
                              _editedWeight != originalWeight;

                          Color cardBg;
                          Color borderColor;
                          Color titleColor;
                          if (isDisabled) {
                            cardBg = Colors.orange.shade50;
                            borderColor = Colors.orange.shade300;
                            titleColor = Colors.orange.shade700;
                          } else if (isSelected) {
                            cardBg = Colors.amber.shade50;
                            borderColor = Colors.amber.shade500;
                            titleColor = Colors.amber.shade800;
                          } else {
                            cardBg = const Color(0xFFF0F7FF);
                            borderColor = const Color(0xFFBFDBFE);
                            titleColor = const Color(0xFF1D4ED8);
                          }

                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isDisabled ? 0.45 : 1.0,
                            child: GestureDetector(
                              onTap: isDisabled ? null : () => _toggleRow(idx, rawRow, isDisabled, vm, result),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            detail,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: titleColor,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$weightText kg',
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
                                    // Checkmark (top-left) saat terpilih
                                    if (isSelected && !isDisabled)
                                      Positioned(
                                        top: 3,
                                        left: 3,
                                        child: Icon(Icons.check_circle, size: 12, color: Colors.amber.shade700),
                                      ),
                                    // "P" badge untuk partial asli
                                    if (isOriginalPartial && !isSelected)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade400,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Text('P', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                                          ),
                                        ),
                                      ),
                                    // "Input" badge untuk sudah diinput
                                    if (isDisabled)
                                      Positioned(
                                        top: 3,
                                        right: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.orange.shade400),
                                          ),
                                          child: Text(
                                            'Input',
                                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.orange.shade700),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  // ===== HELPERS =====



  String _getDetailText(dynamic item, PrefixType type) {
    if (item is BbItem) return '${item.noSak ?? '-'}';
    if (item is GilinganItem) return item.noGilingan ?? '-';
    if (item is MixerItem) return '${item.noSak ?? '-'}';
    if (item is RejectItem) return item.noReject ?? '-';
    if (item is BrokerItem) return '${item.noSak ?? '-'}';
    if (item is WashingItem) return '${item.noSak ?? '-'}';
    if (item is CrusherItem) return item.noCrusher ?? '-';
    return '-';
  }

  double? _beratFromRow(Map<String, dynamic> row) {
    final berat = row['berat'] ?? row['Berat'];
    if (berat is num) return berat.toDouble();
    if (berat is String) return double.tryParse(berat);
    return null;
  }

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
    if (item is GilinganItem) {
      return (item.noGilinganPartial ?? '').trim().isNotEmpty
          ? item.noGilinganPartial!
          : item.noGilingan ?? '-';
    }
    if (item is MixerItem) {
      return (item.noMixerPartial ?? '').trim().isNotEmpty
          ? item.noMixerPartial!
          : item.noMixer ?? '-';
    }
    if (item is RejectItem) {
      return (item.noRejectPartial ?? '').trim().isNotEmpty
          ? item.noRejectPartial!
          : item.noReject ?? '-';
    }
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
      final hasIsPartial = (dyn as dynamic?)?.isPartial;
      if (hasIsPartial is bool && hasIsPartial) return true;
    } catch (_) {}
    return false;
  }
}