import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../model/master_user_models.dart';
import '../repository/master_user_repository.dart';

/// Pencarian karyawan: pilih perusahaan, masukkan kata kunci, lalu pilih hasil.
class EmployeePicker extends StatefulWidget {
  const EmployeePicker({
    super.key,
    required this.repository,
    required this.onPicked,
    this.initialCompany,
    this.label = 'Cari Karyawan',
  });

  final MasterUserRepository repository;
  final ValueChanged<EmployeeMatch> onPicked;
  final String? initialCompany;
  final String label;

  @override
  State<EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<EmployeePicker> {
  final _query = TextEditingController();
  late String _company = userCompanies.any(
        (option) => option.$1 == widget.initialCompany,
      )
      ? widget.initialCompany!
      : userCompanies.first.$1;
  String? _submitted;
  bool _loading = false;
  String _error = '';
  List<EmployeeMatch> _results = const [];
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final generation = ++_generation;
    final query = _query.text.trim();
    setState(() {
      _submitted = query;
      _loading = true;
      _error = '';
      _results = const [];
    });
    try {
      final results = await widget.repository.searchEmployees(
        db: _company,
        query: query,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _pick(EmployeeMatch employee) {
    widget.onPicked(employee);
    setState(() => _submitted = null);
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF44546F),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: _company,
                  isDense: true,
                  isExpanded: true,
                  selectedItemBuilder: (context) => [
                    for (final (_, label) in userCompanies)
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Perusahaan',
                    labelStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    for (final (value, label) in userCompanies)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _company = value;
                        _submitted = null;
                        _results = const [];
                      });
                    }
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Nama / ID / kode karyawan…',
                    labelStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Cari'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ),
            ],
          ),
          if (_submitted != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Mencari…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF44546F),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    )
                  : _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Karyawan tidak ditemukan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B778C),
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final employee in _results)
                          InkWell(
                            onTap: () => _pick(employee),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      employee.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF172B4D),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${employee.code} · ID ${employee.employeeId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B778C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
