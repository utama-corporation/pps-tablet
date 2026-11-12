import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/search_dropdown_field.dart';
import '../../../core/network/api_error.dart';
import '../model/master_cetakan_models.dart';
import '../view_model/master_cetakan_view_model.dart';

class CetakanFormDialog extends StatefulWidget {
  const CetakanFormDialog({super.key, required this.viewModel, this.edit});

  final MasterCetakanViewModel viewModel;
  final CetakanWarnaMaterialRow? edit;

  @override
  State<CetakanFormDialog> createState() => _CetakanFormDialogState();
}

class _CetakanFormDialogState extends State<CetakanFormDialog> {
  LookupOption? _cetakan;
  LookupOption? _warna;
  LookupOption? _material;

  String _outputMode = 'bj'; // 'bj' | 'wip'
  LookupOption? _selectedBj;
  final List<LookupOption> _selectedWips = [];

  bool _detailLoading = false;
  bool _submitting = false;
  bool _quickAdding = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final vm = widget.viewModel;
    if (vm.options == null) {
      await vm.loadOptions();
    }
    if (!mounted) return;
    final edit = widget.edit;
    if (edit == null) return;

    final opts = vm.options;
    setState(() {
      _cetakan = _findById(opts?.cetakan, edit.idCetakan);
      _warna = _findById(opts?.warna, edit.idWarna);
      _material = edit.idMaterial > 0
          ? _findById(opts?.materials, edit.idMaterial)
          : null;
      _detailLoading = true;
      _error = '';
    });

    try {
      final detail = await vm.fetchDetail(edit);
      if (!mounted) return;
      setState(() {
        _outputMode = detail.isFurnitureWip ? 'wip' : 'bj';
        _selectedBj = detail.barangJadi.isNotEmpty ? detail.barangJadi.first : null;
        _selectedWips
          ..clear()
          ..addAll(detail.furnitureWip);
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  LookupOption? _findById(List<LookupOption>? items, int id) {
    if (items == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return LookupOption(id, '#$id');
  }

  Future<String?> _promptNewName({
    required String title,
    required String label,
    required int maxLength,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NamePromptDialog(
        title: title,
        label: label,
        maxLength: maxLength,
      ),
    );
    final name = result?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> _quickAdd({required bool isCetakan}) async {
    if (_quickAdding) return;
    final name = await _promptNewName(
      title: isCetakan ? 'Tambah Cetakan Baru' : 'Tambah Warna Baru',
      label: isCetakan ? 'Nama Cetakan' : 'Warna',
      maxLength: isCetakan ? 50 : 15,
    );
    if (name == null || !mounted) return;
    setState(() => _quickAdding = true);
    try {
      final created = isCetakan
          ? await widget.viewModel.addCetakan(name)
          : await widget.viewModel.addWarna(name);
      if (!mounted) return;
      setState(() {
        if (isCetakan) {
          _cetakan = created;
        } else {
          _warna = created;
        }
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _quickAdding = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final cetakan = _cetakan;
    final warna = _warna;
    if (cetakan == null) {
      setState(() => _error = 'Cetakan wajib dipilih.');
      return;
    }
    if (warna == null) {
      setState(() => _error = 'Warna wajib dipilih.');
      return;
    }

    final barangJadi = <int>[];
    final furnitureWip = <int>[];
    if (_outputMode == 'bj') {
      final bj = _selectedBj;
      if (bj == null) {
        setState(() => _error = 'Pilih Barang Jadi lebih dulu.');
        return;
      }
      barangJadi.add(bj.id);
    } else {
      if (_selectedWips.isEmpty) {
        setState(() => _error = 'Pilih minimal 1 Furniture WIP.');
        return;
      }
      furnitureWip.addAll(_selectedWips.map((w) => w.id));
    }

    final label = '${cetakan.name} — ${warna.name}';
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.save(
        edit: widget.edit,
        idCetakan: cetakan.id,
        idWarna: warna.id,
        idMaterial: _material?.id ?? 0,
        barangJadi: barangJadi,
        furnitureWip: furnitureWip,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Consumer<MasterCetakanViewModel>(
          builder: (context, vm, _) {
            final options = vm.options;
            final optionsReady = options != null && !vm.optionsLoading;
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
                          if (vm.optionsLoading && options == null)
                            _buildOptionsLoading()
                          else if (vm.optionsError.isNotEmpty && options == null)
                            _buildOptionsError(vm)
                          else ...[
                            _buildCetakanRow(options),
                            const SizedBox(height: 12),
                            _buildWarnaRow(options),
                            const SizedBox(height: 12),
                            _buildMaterialRow(options),
                            const SizedBox(height: 16),
                            _buildOutputSection(options, optionsReady),
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
                _isEdit ? 'Ubah Data Cetakan' : 'Tambah Data Cetakan',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              Text(
                edit?.displayName ??
                    'Pemetaan cetakan → barang jadi / furniture wip',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 12),
          Text(
            'Memuat opsi cetakan…',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsError(MasterCetakanViewModel vm) {
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
            vm.optionsError,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: vm.loadOptions,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildCetakanRow(MasterCetakanOptions? options) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SearchDropdownField<LookupOption>(
            items: options?.cetakan ?? const [],
            value: _cetakan,
            onChanged: (v) => setState(() => _cetakan = v),
            itemAsString: (c) => c.name,
            compareFn: (a, b) => a.id == b.id,
            label: 'Cetakan',
            hint: 'Pilih cetakan',
            searchHint: 'Cari cetakan…',
            prefixIcon: Icons.widgets_outlined,
            isLoading: options == null,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Tambah cetakan baru',
          child: IconButton.filledTonal(
            onPressed: _quickAdding ? null : () => _quickAdd(isCetakan: true),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildWarnaRow(MasterCetakanOptions? options) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SearchDropdownField<LookupOption>(
            items: options?.warna ?? const [],
            value: _warna,
            onChanged: (v) => setState(() => _warna = v),
            itemAsString: (w) => w.name,
            compareFn: (a, b) => a.id == b.id,
            label: 'Warna',
            hint: 'Pilih warna',
            searchHint: 'Cari warna…',
            prefixIcon: Icons.palette_outlined,
            isLoading: options == null,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Tambah warna baru',
          child: IconButton.filledTonal(
            onPressed: _quickAdding ? null : () => _quickAdd(isCetakan: false),
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialRow(MasterCetakanOptions? options) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SearchDropdownField<LookupOption>(
            items: options?.materials ?? const [],
            value: _material,
            onChanged: (v) => setState(() => _material = v),
            itemAsString: (m) => m.name,
            compareFn: (a, b) => a.id == b.id,
            label: 'Material (opsional)',
            hint: 'Tanpa material',
            searchHint: 'Cari material…',
            prefixIcon: Icons.inventory_2_outlined,
            helperText: 'Kosongkan bila cetakan tidak terikat material',
            isLoading: options == null,
          ),
        ),
        if (_material != null) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Kosongkan material',
            child: IconButton.filledTonal(
              onPressed: () => setState(() => _material = null),
              icon: const Icon(Icons.clear),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOutputSection(
    MasterCetakanOptions? options,
    bool optionsReady,
  ) {
    if (_detailLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 8),
            Text(
              'Memuat data output…',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'OUTPUT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B778C),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'bj',
              label: Text('Barang Jadi'),
              icon: Icon(Icons.inventory_2_outlined),
            ),
            ButtonSegment(
              value: 'wip',
              label: Text('Furniture WIP'),
              icon: Icon(Icons.chair_outlined),
            ),
          ],
          selected: {_outputMode},
          onSelectionChanged: (selection) {
            setState(() => _outputMode = selection.first);
          },
        ),
        const SizedBox(height: 12),
        if (_outputMode == 'bj')
          SearchDropdownField<LookupOption>(
            items: options?.barangJadi ?? const [],
            value: _selectedBj,
            onChanged: (v) => setState(() => _selectedBj = v),
            itemAsString: (b) => b.name,
            compareFn: (a, b) => a.id == b.id,
            label: 'Barang Jadi',
            hint: 'Pilih barang jadi',
            searchHint: 'Cari barang jadi…',
            prefixIcon: Icons.inventory_2_outlined,
            helperText: 'Maksimal 1 item',
            isLoading: !optionsReady,
          )
        else ...[
          SearchDropdownField<LookupOption>(
            items: [
              for (final w in options?.furnitureWip ?? const <LookupOption>[])
                if (!_selectedWips.any((s) => s.id == w.id)) w,
            ],
            value: null,
            onChanged: (v) {
              if (v == null) return;
              if (_selectedWips.length >= 4) return;
              if (_selectedWips.any((s) => s.id == v.id)) return;
              setState(() => _selectedWips.add(v));
            },
            itemAsString: (w) => w.name,
            compareFn: (a, b) => a.id == b.id,
            label: 'Tambah Furniture WIP',
            hint: _selectedWips.length >= 4
                ? 'Maksimal 4 item'
                : 'Pilih untuk menambah',
            searchHint: 'Cari furniture wip…',
            prefixIcon: Icons.add_circle_outline,
            helperText: '${_selectedWips.length}/4 terpilih · maksimal 4 item',
            enabled: _selectedWips.length < 4,
            isLoading: !optionsReady,
          ),
          const SizedBox(height: 8),
          if (_selectedWips.isEmpty)
            const Text(
              'Belum ada Furniture WIP dipilih',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF94A3B8),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final w in _selectedWips)
                  InputChip(
                    label: Text(w.name),
                    onDeleted: () =>
                        setState(() => _selectedWips.remove(w)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
        ],
      ],
    );
  }

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

// Dialog kecil untuk quick-add Cetakan/Warna. Controller dimiliki State
// sehingga di-dispose saat route benar-benar unmount - menutup dialog tidak
// mendahului frame exit-animation yang masih membangun ulang TextField.
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.label,
    required this.maxLength,
  });

  final String title;
  final String label;
  final int maxLength;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: widget.label,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          isDense: true,
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('SIMPAN'),
        ),
      ],
    );
  }
}
