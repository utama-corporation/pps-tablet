import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/search_dropdown_field.dart';
import '../../../core/network/api_error.dart';
import '../../operator/model/operator_model.dart';
import '../../regu/model/regu_model.dart';
import '../view_model/master_operator_regu_view_model.dart';

class ReguFormDialog extends StatefulWidget {
  const ReguFormDialog({super.key, required this.viewModel, this.edit});

  final MasterOperatorReguViewModel viewModel;
  final MstRegu? edit;

  @override
  State<ReguFormDialog> createState() => _ReguFormDialogState();
}

class _ReguFormDialogState extends State<ReguFormDialog> {
  late final TextEditingController _nama;
  final TextEditingController _memberQuery = TextEditingController();
  OperatorBagian? _bagian;
  final Set<int> _memberIds = {};
  bool _submitting = false;
  bool _loadingDetail = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.edit?.namaRegu ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final vm = widget.viewModel;
    if (vm.bagianOptions == null) {
      await vm.loadBagianOptions();
    }
    if (!mounted) return;
    final edit = widget.edit;
    if (edit == null) {
      setState(() {
        _bagian = _findBagian(vm.bagianOptions, edit?.idBagian);
      });
      return;
    }
    setState(() => _loadingDetail = true);
    try {
      final detail = await vm.fetchReguDetail(edit.idRegu);
      if (!mounted) return;
      setState(() {
        if (detail != null) {
          _bagian = _findBagian(vm.bagianOptions, detail.idBagian) ??
              OperatorBagian(
                idBagianMesin: detail.idBagian,
                namaBagianMesin: detail.namaBagianMesin.trim().isEmpty
                    ? 'Bagian ${detail.idBagian}'
                    : detail.namaBagianMesin,
              );
          _memberIds
            ..clear()
            ..addAll(detail.operators.map((o) => o.idOperator));
        }
        _loadingDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  OperatorBagian? _findBagian(List<OperatorBagian>? options, int? id) {
    if (options == null || id == null || id <= 0) return null;
    for (final o in options) {
      if (o.idBagianMesin == id) return o;
    }
    return null;
  }

  @override
  void dispose() {
    _nama.dispose();
    _memberQuery.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama regu wajib diisi.');
      return;
    }
    final bagian = _bagian;
    if (bagian == null) {
      setState(() => _error = 'Bagian regu wajib dipilih.');
      return;
    }
    if (_memberIds.isEmpty) {
      setState(() => _error = 'Pilih minimal 1 operator untuk regu ini.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.saveRegu(
        idRegu: widget.edit?.idRegu,
        namaRegu: nama,
        idBagian: bagian.idBagianMesin,
        operatorIds: _memberIds.toList(),
      );
      if (mounted) Navigator.of(context).pop(nama);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<MstOperator> _filteredOperators(List<MstOperator> all) {
    final bagian = _bagian;
    if (bagian == null) return const [];
    final byBagian = all
        .where(
          (o) => o.idBagian == bagian.idBagianMesin && o.enable,
        )
        .toList();
    final q = _memberQuery.text.trim().toLowerCase();
    if (q.isEmpty) return byBagian;
    return byBagian
        .where(
          (o) => '${o.idOperator} ${o.namaOperator}'
              .toLowerCase()
              .contains(q),
        )
        .toList();
  }

  void _onBagianChanged(OperatorBagian? value) {
    setState(() {
      _bagian = value;
      if (value == null) return;
      // Buang pilihan anggota yang bukan dari bagian terpilih
      final validIds = widget.viewModel.allOperators
          .where((o) => o.idBagian == value.idBagianMesin)
          .map((o) => o.idOperator)
          .toSet();
      _memberIds.retainWhere(validIds.contains);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isEdit
                            ? Colors.orange.shade50
                            : Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isEdit ? Icons.edit : Icons.group_add_outlined,
                        color: _isEdit
                            ? Colors.orange.shade700
                            : Colors.teal.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEdit
                            ? 'Ubah Regu ${widget.edit!.namaRegu}'
                            : 'Tambah Regu',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_loadingDetail)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nama,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 15,
                  decoration: InputDecoration(
                    labelText: 'Nama Regu',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Consumer<MasterOperatorReguViewModel>(
                  builder: (context, vm, _) => SearchDropdownField<OperatorBagian>(
                    items: vm.bagianOptions ?? const [],
                    value: _bagian,
                    onChanged: _onBagianChanged,
                    itemAsString: (b) => b.namaBagianMesin,
                    compareFn: (a, b) => a.idBagianMesin == b.idBagianMesin,
                    label: 'Bagian',
                    hint: 'Pilih bagian',
                    searchHint: 'Cari bagian…',
                    prefixIcon: Icons.precision_manufacturing_outlined,
                    isLoading: vm.bagianLoading && vm.bagianOptions == null,
                    fetchError:
                        vm.bagianError.isNotEmpty && vm.bagianOptions == null,
                    fetchErrorText:
                        vm.bagianError.isNotEmpty ? vm.bagianError : null,
                    onRetry: () => vm.loadBagianOptions(force: true),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'ANGGOTA REGU',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B778C),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_memberIds.length} dipilih',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_bagian == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pilih bagian dulu untuk menampilkan operator yang bisa jadi anggota regu',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextField(
                    controller: _memberQuery,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari operator…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isCollapsed: true,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<MasterOperatorReguViewModel>(
                  builder: (context, vm, _) {
                    final operators = _filteredOperators(vm.allOperators);
                    if (operators.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Tidak ada operator aktif di bagian ini',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: operators.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 0.6,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, i) {
                              final op = operators[i];
                              final selected =
                                  _memberIds.contains(op.idOperator);
                              return Material(
                                color:
                                    selected ? const Color(0xFFE8F5E9) : null,
                                child: InkWell(
                                  onTap: () => setState(() {
                                    if (selected) {
                                      _memberIds.remove(op.idOperator);
                                    } else {
                                      _memberIds.add(op.idOperator);
                                    }
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: selected,
                                          onChanged: (_) => setState(() {
                                            if (selected) {
                                              _memberIds
                                                  .remove(op.idOperator);
                                            } else {
                                              _memberIds.add(op.idOperator);
                                            }
                                          }),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            op.displayName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: selected
                                                  ? const Color(0xFF15803D)
                                                  : const Color(0xFF172B4D),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '#${op.idOperator}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('BATAL'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEdit
                            ? const Color(0xFFF57C00)
                            : const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'SIMPAN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
