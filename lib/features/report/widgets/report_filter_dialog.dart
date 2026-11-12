// lib/features/report/widgets/report_filter_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/report_item.dart';

/// Resolusi nilai default field (keyword tanggal dipakai web report).
String defaultFieldValue(ReportFieldDef field, [DateTime? now]) {
  final today = now ?? DateTime.now();
  if (field.type == 'date') {
    return switch (field.defaultValue) {
      'today' => DateFormat('yyyy-MM-dd').format(today),
      'month-start' =>
        DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, 1)),
      'month-end' =>
        DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month + 1, 0)),
      final value => value,
    };
  }
  if (field.type == 'number') return field.defaultValue;
  // select — pakai default kalau ada, selain itu opsi pertama.
  if (field.options.isNotEmpty) {
    return field.defaultValue.isNotEmpty &&
            field.options.contains(field.defaultValue)
        ? field.defaultValue
        : field.options.first;
  }
  return field.defaultValue;
}

/// Dialog filter generik: date picker, field angka, select statis dan
/// select-warehouse (opsi dari API).
class ReportFilterDialog extends StatefulWidget {
  const ReportFilterDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.fields,
    required this.warehouseOptions,
    required this.onGenerate,
    this.singleDate = false,
  });

  final String title;
  final IconData icon;
  final List<ReportFieldDef> fields;

  /// Opsi untuk field `select-warehouse` — diawali 'ALL'.
  final List<String> warehouseOptions;

  final bool singleDate;

  /// Dipanggil saat user menekan "Buka PDF" — dialog sudah ditutup.
  /// [values] berisi nilai mentah per key field.
  final Future<void> Function(Map<String, String> values) onGenerate;

  @override
  State<ReportFilterDialog> createState() => _ReportFilterDialogState();
}

class _ReportFilterDialogState extends State<ReportFilterDialog> {
  late final Map<String, String> _values = {
    for (final field in widget.fields)
      field.key: defaultFieldValue(field),
  };
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.fields)
      if (field.type == 'number')
        field.key: TextEditingController(text: _values[field.key]),
  };
  bool _opening = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _warehouseLabel(String value) => value == 'ALL' ? 'Semua Gudang' : value;

  Future<void> _submit() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      Navigator.pop(context);
      await widget.onGenerate(Map<String, String>.from(_values));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _dateField(ReportFieldDef field) {
    final raw = _values[field.key] ?? '';
    return InkWell(
      key: ValueKey('report-field-${field.key}'),
      onTap: () async {
        final initial = DateTime.tryParse(raw) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF0D47A1),
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(
            () => _values[field.key] = DateFormat('yyyy-MM-dd').format(picked),
          );
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: Color(0xFF0D47A1)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    raw.isEmpty
                        ? '-'
                        : DateFormat('dd MMM yyyy').format(
                            DateTime.parse(raw),
                          ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(ReportFieldDef field) {
    return TextField(
      key: ValueKey('report-field-${field.key}'),
      controller: _controllers[field.key],
      keyboardType: TextInputType.number,
      onChanged: (v) => _values[field.key] = v.trim(),
      decoration: InputDecoration(
        labelText: field.label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _selectField(ReportFieldDef field, List<String> options) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey('report-field-${field.key}'),
          value: options.contains(_values[field.key])
              ? _values[field.key]
              : options.first,
          isExpanded: true,
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(field.type == 'select-warehouse'
                    ? _warehouseLabel(option)
                    : option),
              ),
          ],
          onChanged: (v) => setState(() => _values[field.key] = v ?? _values[field.key]!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(widget.icon, color: const Color(0xFF0D47A1), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in widget.fields) ...[
            _buildField(field),
            const SizedBox(height: 12),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _opening ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child:
              const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: _opening
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Buka PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          onPressed: _opening ? null : _submit,
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  Widget _buildField(ReportFieldDef field) {
    switch (field.type) {
      case 'date':
        return _dateField(field);
      case 'number':
        return _numberField(field);
      case 'select':
        return _selectField(field, field.options);
      case 'select-warehouse':
        return _selectField(field, widget.warehouseOptions);
      default:
        return const SizedBox.shrink();
    }
  }
}
