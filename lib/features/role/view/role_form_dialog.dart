import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../model/role_models.dart';
import '../repository/role_repository.dart';
import '../view_model/role_view_model.dart';
import '../widgets/permission_module_section.dart';

class RoleFormDialog extends StatefulWidget {
  const RoleFormDialog({
    super.key,
    required this.repository,
    required this.viewModel,
    required this.permissions,
    this.edit,
  });

  final RoleRepository repository;
  final RoleViewModel viewModel;
  final List<PermissionItem> permissions;
  final RoleGroup? edit;

  @override
  State<RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<RoleFormDialog> {
  late final TextEditingController _name;
  final _filter = TextEditingController();
  final Map<String, bool> _allow = {};
  bool _loadingDetail = false;
  bool _submitting = false;
  String _error = '';
  String _filterQuery = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.edit?.name ?? '');
    if (_isEdit) _loadDetail();
  }

  @override
  void dispose() {
    _name.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    try {
      final allows = await widget.repository.fetchRoleAllows(widget.edit!.id);
      if (!mounted) return;
      setState(() => _allow.addAll(allows));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  List<(String, List<PermissionItem>)> get _modules {
    final query = _filterQuery.trim().toLowerCase();
    Iterable<PermissionItem> filtered = widget.permissions;
    if (query.isNotEmpty) {
      filtered = widget.permissions.where(
        (item) => '${item.no} ${item.description}'.toLowerCase().contains(
          query,
        ),
      );
    }
    final modules = <String, List<PermissionItem>>{};
    for (final item in filtered) {
      modules.putIfAbsent(item.module, () => []).add(item);
    }
    final keys = modules.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final key in keys)
        (
          key,
          modules[key]!..sort(
            (a, b) => a.no.toLowerCase().compareTo(b.no.toLowerCase()),
          ),
        ),
    ];
  }

  int get _allowedCount => _allow.values.where((value) => value).length;

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama Role harus diisi');
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });

    try {
      if (_isEdit) {
        await widget.viewModel.updateRole(
          idUGroup: widget.edit!.id,
          name: name,
          allow: _allow,
        );
      } else {
        await widget.viewModel.createRole(name: name, allow: _allow);
      }
      if (mounted) Navigator.of(context).pop(name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int? maxLength,
    String? hint,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: controller,
    maxLength: maxLength,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isLandscape
          ? const EdgeInsets.symmetric(horizontal: 72, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 760 : 640,
          maxHeight: (MediaQuery.of(context).size.height - 24).clamp(
            300,
            isLandscape ? 640 : 740,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                              _isEdit ? Icons.edit : Icons.add,
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
                                  ? 'Ubah Role ${widget.edit!.name}'
                                  : 'Tambah Role',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final wide = bounds.maxWidth > 620;
                          final itemWidth = wide
                              ? (bounds.maxWidth - 12) / 2
                              : bounds.maxWidth;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: itemWidth,
                                child: _field(
                                  'Nama Role',
                                  _name,
                                  maxLength: 25,
                                  hint: 'Maksimal 25 karakter',
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _field(
                                  'Filter Permission',
                                  _filter,
                                  hint: 'Cari modul / permission…',
                                  onChanged: (value) =>
                                      setState(() => _filterQuery = value),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.vpn_key_outlined,
                            size: 16,
                            color: Color(0xFF44546F),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isEdit && _loadingDetail
                                ? 'Memuat permission…'
                                : '$_allowedCount dari ${widget.permissions.length} permission diizinkan',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Color(0xFF44546F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(
                          maxHeight: 320,
                          minHeight: 120,
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: _modules.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Permission tidak ditemukan',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF44546F),
                                  ),
                                ),
                              )
                            : ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final (module, items) in _modules)
                                    PermissionModuleSection(
                                      module: module,
                                      items: items,
                                      allow: _allow,
                                      onToggle: (no, value) =>
                                          setState(() => _allow[no] = value),
                                      onToggleAll: (value) => setState(() {
                                        for (final item in items) {
                                          _allow[item.no] = value;
                                        }
                                      }),
                                    ),
                                ],
                              ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 14),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('BATAL', style: TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isEdit
                ? const Color(0xFFF57C00)
                : const Color(0xFF00897B),
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
              : Text(
                  'SIMPAN',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}
