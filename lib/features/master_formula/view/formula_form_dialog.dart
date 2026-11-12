import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/search_dropdown_field.dart';
import '../../../core/network/api_error.dart';
import '../model/master_formula_models.dart';
import '../view_model/master_formula_view_model.dart';

class FormulaFormDialog extends StatefulWidget {
  const FormulaFormDialog({super.key, required this.viewModel, this.edit});

  final MasterFormulaViewModel viewModel;
  final FormulaListRow? edit;

  @override
  State<FormulaFormDialog> createState() => _FormulaFormDialogState();
}

class _RowDraft {
  _RowDraft({this.kategori, this.item});

  FormulaKategori? kategori;
  FormulaItemOption? item;
}

class _FormulaFormDialogState extends State<FormulaFormDialog> {
  FormulaKategori? _mainKategori;
  FormulaItemOption? _mainOutput;

  final List<_RowDraft> _inputs = [];
  final List<_RowDraft> _secondarys = [];

  bool _bootstrapping = false;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final vm = widget.viewModel;
    if (vm.kategoriList == null) {
      await vm.loadKategori();
    }
    if (!mounted) return;
    final edit = widget.edit;
    if (edit == null) {
      if (_inputs.isEmpty) _inputs.add(_RowDraft());
      setState(() {});
      return;
    }

    setState(() {
      _bootstrapping = true;
      _error = '';
    });
    try {
      final detail = await vm.fetchDetail(edit.idFormula);
      if (!mounted) return;
      setState(() {
        _mainKategori = _findKategori(vm.kategoriList, detail.mainOutputKategoriId) ??
            FormulaKategori(
              id: detail.mainOutputKategoriId,
              kode: '',
              nama: detail.mainKategori,
              isWaste: false,
            );
        _mainOutput = FormulaItemOption(
          detail.mainOutputId,
          detail.mainOutputNama,
        );
        _inputs
          ..clear()
          ..addAll(
            detail.inputs.map(
              (r) => _RowDraft(
                kategori: FormulaKategori(
                  id: r.kategoriId,
                  kode: '',
                  nama: r.kategoriNama,
                  isWaste: false,
                ),
                item: FormulaItemOption(r.itemId, r.itemNama),
              ),
            ),
          );
        _secondarys
          ..clear()
          ..addAll(
            detail.secondarys.map(
              (r) => _RowDraft(
                kategori: FormulaKategori(
                  id: r.kategoriId,
                  kode: '',
                  nama: r.kategoriNama,
                  isWaste: false,
                ),
                item: FormulaItemOption(r.itemId, r.itemNama),
              ),
            ),
          );
        _bootstrapping = false;
      });
      final kategoriIds = <int>{
        detail.mainOutputKategoriId,
        for (final r in detail.inputs) r.kategoriId,
        for (final r in detail.secondarys) r.kategoriId,
      };
      for (final id in kategoriIds) {
        await vm.loadItems(id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  void _touchItems(int idKategori) => unawaited(vm.loadItems(idKategori));

  FormulaKategori? _findKategori(List<FormulaKategori>? list, int id) {
    if (list == null) return null;
    for (final k in list) {
      if (k.id == id) return k;
    }
    return null;
  }

  MasterFormulaViewModel get vm => widget.viewModel;

  Future<void> _submit() async {
    if (_submitting) return;
    final mainKategori = _mainKategori;
    if (mainKategori == null) {
      setState(() => _error = 'Kategori output utama wajib dipilih.');
      return;
    }
    final mainOutput = _mainOutput;
    if (mainOutput == null) {
      setState(() => _error = 'Output utama wajib dipilih.');
      return;
    }

    final allRows = [..._inputs, ..._secondarys];
    if (allRows.isEmpty) {
      setState(
        () => _error = 'Formula minimal memiliki 1 Input atau 1 Secondary Output.',
      );
      return;
    }
    for (final row in allRows) {
      if (row.kategori == null || row.item == null) {
        setState(
          () =>
              _error = 'Setiap baris wajib memiliki kategori dan item yang dipilih.',
        );
        return;
      }
    }

    List<Map<String, int>> toPayload(List<_RowDraft> rows) => [
      for (final r in rows)
        {'kategoriId': r.kategori!.id, 'itemId': r.item!.id},
    ];

    Map<String, int> key(_RowDraft r) =>
        {'kategoriId': r.kategori!.id, 'itemId': r.item!.id};

    final dupInput = _findDuplicate(_inputs.map(key).toList());
    if (dupInput != null) {
      setState(() => _error = 'Terdapat Input yang sama (kategori & item).');
      return;
    }
    final dupSecondary = _findDuplicate(_secondarys.map(key).toList());
    if (dupSecondary != null) {
      setState(
        () => _error = 'Terdapat Secondary Output yang sama (kategori & item).',
      );
      return;
    }
    final sameAsMain = _secondarys.any(
      (r) =>
          r.kategori!.id == mainKategori.id && r.item!.id == mainOutput.id,
    );
    if (sameAsMain) {
      setState(
        () => _error = 'Secondary Output tidak boleh sama dengan Output utama.',
      );
      return;
    }
    for (final r in _secondarys) {
      final kategori = _findKategori(vm.kategoriList, r.kategori!.id);
      if (kategori != null && !kategori.isWaste) {
        setState(
          () => _error =
              'Secondary Output hanya boleh memakai kategori Waste.',
        );
        return;
      }
    }

    final label = '${mainKategori.nama} — ${mainOutput.nama}';
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await vm.save(
        idFormula: widget.edit?.idFormula,
        mainKategoriId: mainKategori.id,
        mainOutputId: mainOutput.id,
        inputs: toPayload(_inputs),
        secondarys: toPayload(_secondarys),
        label: label,
      );
      if (mounted) Navigator.of(context).pop(label);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Map<String, int>? _findDuplicate(List<Map<String, int>> rows) {
    final seen = <String>{};
    for (final r in rows) {
      final key = '${r['kategoriId']}:${r['itemId']}';
      if (!seen.add(key)) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Consumer<MasterFormulaViewModel>(
          builder: (context, viewModel, _) {
            final kategori = viewModel.kategoriList;
            final kategoriReady = kategori != null && !viewModel.kategoriLoading;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (viewModel.kategoriLoading && kategori == null)
                            _buildKategoriLoading()
                          else if (viewModel.kategoriError.isNotEmpty &&
                              kategori == null)
                            _buildKategoriError(viewModel)
                          else ...[
                            _buildMainSection(viewModel, kategoriReady),
                            const SizedBox(height: 16),
                            _buildSectionCaption('INPUT'),
                            const SizedBox(height: 6),
                            _buildRows(
                              viewModel: viewModel,
                              rows: _inputs,
                              onRemove: (i) =>
                                  setState(() => _inputs.removeAt(i)),
                              emptyHint: 'Belum ada input. Tambah minimal 1 input atau secondary output.',
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _inputs.add(_RowDraft())),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tambah Input'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSectionCaption(
                              'SECONDARY OUTPUT (WASTE)',
                            ),
                            const SizedBox(height: 6),
                            _buildRows(
                              viewModel: viewModel,
                              rows: _secondarys,
                              wasteOnly: true,
                              onRemove: (i) =>
                                  setState(() => _secondarys.removeAt(i)),
                              emptyHint: 'Opsional. Hanya kategori Waste yang boleh dipilih.',
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _secondarys.add(_RowDraft())),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tambah Secondary'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 10),
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
                  _buildButtons(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final edit = widget.edit;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isEdit ? Colors.orange.shade50 : Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _isEdit ? Icons.edit : Icons.add,
            color: _isEdit ? Colors.orange.shade700 : Colors.teal.shade700,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Ubah Formula' : 'Tambah Formula',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                edit?.displayName ??
                    'Kategori → output utama, dengan input & output sekunder',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (_bootstrapping)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildKategoriLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 12),
          Text(
            'Memuat kategori…',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriError(MasterFormulaViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.kategoriError,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: viewModel.loadKategori,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainSection(
    MasterFormulaViewModel viewModel,
    bool kategoriReady,
  ) {
    final kategoriItems = viewModel.kategoriList ?? const <FormulaKategori>[];
    final items = vm.itemsFor(_mainKategori?.id);
    final itemsLoading = viewModel.isItemsLoading(_mainKategori?.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCaption('OUTPUT UTAMA'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: SearchDropdownField<FormulaKategori>(
                items: kategoriItems,
                value: _mainKategori,
                onChanged: (v) {
                  setState(() {
                    _mainKategori = v;
                    _mainOutput = null;
                  });
                  if (v != null) _touchItems(v.id);
                },
                itemAsString: (k) => k.nama,
                compareFn: (a, b) => a.id == b.id,
                label: 'Kategori',
                hint: 'Pilih kategori',
                searchHint: 'Cari kategori…',
                prefixIcon: Icons.category_outlined,
                isLoading: !kategoriReady,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SearchDropdownField<FormulaItemOption>(
                items: items ?? const [],
                value: _mainOutput,
                onChanged: (v) => setState(() => _mainOutput = v),
                itemAsString: (o) => o.nama,
                compareFn: (a, b) => a.id == b.id,
                label: 'Output Utama',
                hint: _mainKategori == null
                    ? 'Pilih kategori dulu'
                    : 'Pilih output',
                searchHint: 'Cari item…',
                prefixIcon: Icons.precision_manufacturing_outlined,
                enabled: _mainKategori != null,
                isLoading: itemsLoading,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCaption(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B778C),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildRows({
    required MasterFormulaViewModel viewModel,
    required List<_RowDraft> rows,
    required void Function(int index) onRemove,
    required String emptyHint,
    bool wasteOnly = false,
  }) {
    if (rows.isEmpty) {
      return Text(
        emptyHint,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Color(0xFF94A3B8),
        ),
      );
    }
    final kategoriItems = viewModel.kategoriList ?? const <FormulaKategori>[];
    final secondaryKategoriItems = wasteOnly
        ? kategoriItems.where((k) => k.isWaste).toList()
        : kategoriItems;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: SearchDropdownField<FormulaKategori>(
                    items: secondaryKategoriItems,
                    value: rows[i].kategori,
                    onChanged: (v) {
                      setState(() {
                        rows[i].kategori = v;
                        rows[i].item = null;
                      });
                      if (v != null) _touchItems(v.id);
                    },
                    itemAsString: (k) => k.nama,
                    compareFn: (a, b) => a.id == b.id,
                    label: 'Kategori',
                    hint: 'Pilih',
                    searchHint: 'Cari kategori…',
                    isLoading: !kategoriReadyOf(viewModel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Builder(
                    builder: (context) {
                      final id = rows[i].kategori?.id;
                      final items = viewModel.itemsFor(id);
                      return SearchDropdownField<FormulaItemOption>(
                        items: items ?? const [],
                        value: rows[i].item,
                        onChanged: (v) => setState(() => rows[i].item = v),
                        itemAsString: (o) => o.nama,
                        compareFn: (a, b) => a.id == b.id,
                        label: 'Item',
                        hint: id == null ? 'Pilih kategori dulu' : 'Pilih item',
                        searchHint: 'Cari item…',
                        enabled: id != null,
                        isLoading: viewModel.isItemsLoading(id),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Hapus baris',
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red.shade400,
                    onPressed: () => onRemove(i),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool kategoriReadyOf(MasterFormulaViewModel viewModel) =>
      viewModel.kategoriList != null && !viewModel.kategoriLoading;

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isEdit ? const Color(0xFFF57C00) : const Color(0xFF00897B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
    );
  }
}
