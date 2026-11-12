import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../model/master_user_models.dart';
import '../repository/master_user_repository.dart';
import '../view_model/master_user_view_model.dart';
import '../widgets/employee_picker.dart';

class MasterUserFormDialog extends StatefulWidget {
  const MasterUserFormDialog({
    super.key,
    required this.repository,
    required this.viewModel,
    required this.groups,
    this.edit,
  });

  final MasterUserRepository repository;
  final MasterUserViewModel viewModel;
  final List<UserGroup> groups;
  final MasterUser? edit;

  @override
  State<MasterUserFormDialog> createState() => _MasterUserFormDialogState();
}

class _MasterUserFormDialogState extends State<MasterUserFormDialog> {
  late final TextEditingController _fName;
  late final TextEditingController _lName;
  late final TextEditingController _username;
  final _password = TextEditingController();
  late final TextEditingController _employeeId;
  late final TextEditingController _companyId;
  late final TextEditingController _nik;
  bool _resetPassword = false;
  bool _submitting = false;
  String _error = '';
  Set<int> _selectedGroups = {};
  bool _loadingGroups = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _fName = TextEditingController(text: edit?.fName ?? '');
    _lName = TextEditingController(text: edit?.lName ?? '');
    _username = TextEditingController(text: edit?.username ?? '');
    _employeeId = TextEditingController(
      text: edit?.employeeId?.toString() ?? '',
    );
    _companyId = TextEditingController(text: edit?.companyId ?? '');
    _nik = TextEditingController(text: edit?.nik ?? '');
    if (_isEdit) _loadUserGroups();
  }

  @override
  void dispose() {
    _fName.dispose();
    _lName.dispose();
    _username.dispose();
    _password.dispose();
    _employeeId.dispose();
    _companyId.dispose();
    _nik.dispose();
    super.dispose();
  }

  Future<void> _loadUserGroups() async {
    final edit = widget.edit!;
    setState(() => _loadingGroups = true);
    try {
      final groups = await widget.repository.fetchUserGroups(edit.id);
      if (!mounted) return;
      setState(() => _selectedGroups = {for (final g in groups) g.id});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  void _onEmployeePicked(EmployeeMatch employee) {
    setState(() {
      _employeeId.text = '${employee.employeeId}';
      _companyId.text = employee.companyId;
      _nik.text = employee.code;
    });
    if (!_isEdit && _fName.text.trim().isEmpty) {
      final parts = employee.fullName
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      var first = parts.isEmpty ? '' : parts.first;
      if (first.length > 25) first = first.substring(0, 25);
      var rest = parts.skip(1).join(' ');
      if (rest.length > 25) rest = rest.substring(0, 25);
      _fName.text = first;
      _lName.text = rest;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final employeeId = int.tryParse(_employeeId.text.trim()) ?? 0;
    final fName = _fName.text.trim();
    final lName = _lName.text.trim();

    final baseValid =
        fName.isNotEmpty && employeeId > 0 && _selectedGroups.isNotEmpty;
    final createValid = _username.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        _companyId.text.trim().isNotEmpty &&
        _nik.text.trim().isNotEmpty;

    if (!(baseValid && (_isEdit || createValid))) {
      setState(
        () => _error = _isEdit
            ? 'Data user belum lengkap.'
            : 'Data user belum lengkap. Pilih karyawan, isi akun, dan pilih minimal 1 role.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });

    try {
      if (_isEdit) {
        await widget.viewModel.updateUser(
          idUsername: widget.edit!.id,
          fName: fName,
          lName: lName,
          employeeId: employeeId,
          resetPassword: _resetPassword,
          groupIds: _selectedGroups.toList(),
        );
      } else {
        await widget.viewModel.createUser(
          fName: fName,
          lName: lName,
          username: _username.text.trim(),
          password: _password.text,
          employeeId: employeeId,
          companyId: _companyId.text.trim(),
          nik: _nik.text.trim(),
          groupIds: _selectedGroups.toList(),
        );
      }
      if (mounted) Navigator.of(context).pop(_username.text.trim());
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
    int maxLength = 25,
    bool readOnly = false,
    bool obscure = false,
    String? hint,
  }) => TextField(
    controller: controller,
    readOnly: readOnly,
    obscureText: obscure,
    maxLength: maxLength,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: readOnly ? const Color(0xFFF7F8F9) : Colors.white,
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    ),
  );

  Widget _resetPasswordCheckbox() => Align(
    alignment: Alignment.centerLeft,
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Checkbox(
          value: _resetPassword,
          onChanged: (v) => setState(() => _resetPassword = v ?? false),
        ),
        const Text(
          'Reset password ke Utama1234',
          style: TextStyle(fontSize: 13),
        ),
      ],
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
          maxWidth: isLandscape ? 700 : 640,
          maxHeight: (MediaQuery.of(context).size.height - 24).clamp(
            300,
            isLandscape ? 620 : 740,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                                  ? 'Ubah User ${widget.edit!.username}'
                                  : 'Tambah User',
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
                      EmployeePicker(
                        repository: widget.repository,
                        label: _isEdit
                            ? 'Ganti Karyawan (opsional)'
                            : 'Cari Karyawan',
                        initialCompany: _companyId.text.toLowerCase(),
                        onPicked: _onEmployeePicked,
                      ),
                      const SizedBox(height: 14),
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
                                child: _field('Nama Depan', _fName),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _field('Nama Belakang', _lName),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _field(
                                  'Username',
                                  _username,
                                  readOnly: _isEdit,
                                ),
                              ),
                              if (_isEdit)
                                SizedBox(
                                  width: itemWidth,
                                  child: _resetPasswordCheckbox(),
                                )
                              else
                                SizedBox(
                                  width: itemWidth,
                                  child: _field(
                                    'Password',
                                    _password,
                                    obscure: true,
                                    hint: 'Minimal 8 karakter',
                                  ),
                                ),
                              SizedBox(
                                width: itemWidth,
                                child: _field(
                                  'Employee ID',
                                  _employeeId,
                                  readOnly: !_isEdit,
                                  hint: _isEdit
                                      ? ''
                                      : 'Terisi dari pencarian karyawan',
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _field('Perusahaan', _companyId,
                                    readOnly: true),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _field(
                                  'NIK',
                                  _nik,
                                  readOnly: true,
                                  maxLength: 10,
                                  hint: 'Terisi dari pencarian karyawan',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 16,
                            color: Color(0xFF44546F),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Role (minimal 1)${_selectedGroups.isEmpty ? '' : ' · ${_selectedGroups.length} dipilih'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Color(0xFF44546F),
                            ),
                          ),
                          if (_loadingGroups) ...[
                            const SizedBox(width: 10),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 8),
                    Container(
                      height: 118,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _selectedGroups.isEmpty && _error.isNotEmpty
                              ? Colors.red.shade300
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final group in widget.groups)
                                _RoleChip(
                                  name: group.name,
                                  selected:
                                      _selectedGroups.contains(group.id),
                                  onChanged: (value) => setState(() {
                                    if (value) {
                                      _selectedGroups = {
                                        ..._selectedGroups,
                                        group.id,
                                      };
                                    } else {
                                      _selectedGroups = {
                                        ..._selectedGroups,
                                      }..remove(group.id);
                                    }
                                  }),
                                ),
                            ],
                          ),
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.name,
    required this.selected,
    required this.onChanged,
  });

  final String name;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00897B);
    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? teal : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
          color: selected ? const Color(0xFFE0F2F1) : Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? teal : Colors.white,
                border: Border.all(
                  color: selected ? teal : Colors.grey.shade400,
                  width: 1.4,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 11,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 7),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF00695C)
                    : const Color(0xFF44546F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
