import 'package:flutter/material.dart';

import '../../../common/widgets/confirm_dialog.dart';
import '../../../core/network/api_error.dart';
import '../model/role_models.dart';
import '../view_model/role_view_model.dart';

class RolePermissionDialog extends StatefulWidget {
  const RolePermissionDialog({
    super.key,
    required this.viewModel,
    this.canCreate = false,
    this.canUpdate = false,
    this.canDelete = false,
  });

  final RoleViewModel viewModel;
  final bool canCreate;
  final bool canUpdate;
  final bool canDelete;

  @override
  State<RolePermissionDialog> createState() => _RolePermissionDialogState();
}

class _RolePermissionDialogState extends State<RolePermissionDialog> {
  final _search = TextEditingController();
  final _no = TextEditingController();
  final _description = TextEditingController();
  bool _editing = false;
  bool _busy = false;
  String _editNo = '';
  String _query = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    _search.dispose();
    _no.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  List<PermissionItem> get _visible {
    final query = _query.trim().toLowerCase();
    final items = widget.viewModel.permissions;
    if (query.isEmpty) return items;
    return [
      for (final item in items)
        if ('${item.no} ${item.description}'.toLowerCase().contains(query))
          item,
    ];
  }

  void _startEdit(PermissionItem? item) {
    setState(() {
      _editing = true;
      _error = '';
      _editNo = item?.no ?? '';
      _no.text = _editNo;
      _description.text = item?.description ?? '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _error = '';
      _editNo = '';
      _no.clear();
      _description.clear();
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final no = _no.text.trim();
    final description = _description.text.trim();
    if (no.isEmpty || description.isEmpty) {
      setState(() => _error = 'No Permission dan keterangan harus diisi');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (_editNo.isEmpty) {
        await widget.viewModel.createPermission(no, description);
      } else {
        await widget.viewModel.updatePermission(no, description);
      }
      if (!mounted) return;
      _cancelEdit();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(PermissionItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Permission',
        message: 'Hapus permission ${item.no}?',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.viewModel.deletePermission(item.no);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    }
  }

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
            320,
            isLandscape ? 620 : 720,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.vpn_key_outlined,
                      color: Colors.teal.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Kelola Permission',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        hintText: 'Cari No Permission / keterangan…',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (widget.canCreate && !_editing)
                    FilledButton.icon(
                      onPressed: () => _startEdit(null),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text(
                        'Permission Baru',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (_editing) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 210,
                        child: TextField(
                          controller: _no,
                          enabled: _editNo.isEmpty,
                          maxLength: 50,
                          decoration: InputDecoration(
                            labelText: 'No Permission',
                            hintText: 'contoh: modul:read',
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: _editNo.isEmpty
                                ? Colors.white
                                : const Color(0xFFEDF0F2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _description,
                          maxLength: 50,
                          decoration: InputDecoration(
                            labelText: 'Keterangan',
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Simpan'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: _busy ? null : _cancelEdit,
                        child: const Text('Batal'),
                      ),
                    ],
                  ),
                ),
              ],
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
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCDFE4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: const Color(0xFFF7F8F9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Text(
                                'NO PERMISSION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF44546F),
                                  letterSpacing: 0.35,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'KETERANGAN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF44546F),
                                  letterSpacing: 0.35,
                                ),
                              ),
                            ),
                            SizedBox(width: 96),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _visible.isEmpty
                            ? const Center(
                                child: Text(
                                  'Permission tidak ditemukan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF44546F),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _visible.length,
                                itemBuilder: (_, index) {
                                  final item = _visible[index];
                                  return Container(
                                    color: index.isEven
                                        ? Colors.white
                                        : const Color(0xFFFAFBFC),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.no,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11.5,
                                              color: Color(0xFF172B4D),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF44546F),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 96,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (widget.canUpdate)
                                                IconButton(
                                                  tooltip: 'Ubah',
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () =>
                                                      _startEdit(item),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 15,
                                                    color: Color(0xFF0C66E4),
                                                  ),
                                                ),
                                              if (widget.canDelete)
                                                IconButton(
                                                  tooltip: 'Hapus',
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () =>
                                                      _delete(item),
                                                  icon: Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 15,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${_visible.length} dari ${widget.viewModel.permissions.length} permission',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B778C),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
