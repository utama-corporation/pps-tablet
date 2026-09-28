import 'package:flutter/material.dart';

import '../../../../common/widgets/qc_dialog_components.dart';
import '../../../../core/utils/date_formatter.dart';
import '../model/washing_header_model.dart';

class WashingQcResult {
  final double? density1;
  final double? density2;
  final double? density3;
  final double? moisture1;
  final double? moisture2;
  final double? moisture3;

  /// Tanggal QC — boleh backdate (lampau) untuk input susulan.
  final DateTime dateQc;

  const WashingQcResult({
    required this.density1,
    required this.density2,
    required this.density3,
    required this.moisture1,
    required this.moisture2,
    required this.moisture3,
    required this.dateQc,
  });
}

class WashingQcDialog extends StatefulWidget {
  final WashingHeader header;

  const WashingQcDialog({super.key, required this.header});

  @override
  State<WashingQcDialog> createState() => _WashingQcDialogState();
}

class _WashingQcDialogState extends State<WashingQcDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _density1Ctrl;
  late final TextEditingController _density2Ctrl;
  late final TextEditingController _density3Ctrl;
  late final TextEditingController _moisture1Ctrl;
  late final TextEditingController _moisture2Ctrl;
  late final TextEditingController _moisture3Ctrl;

  /// Default: tanggal QC yang tersimpan, atau hari ini bila belum pernah.
  /// Operator bisa mundur ke tanggal lampau untuk input QC susulan.
  late DateTime _dateQc;

  @override
  void initState() {
    super.initState();
    _density1Ctrl = TextEditingController(text: _toText(widget.header.density));
    _density2Ctrl = TextEditingController(
      text: _toText(widget.header.density2),
    );
    _density3Ctrl = TextEditingController(
      text: _toText(widget.header.density3),
    );
    _moisture1Ctrl = TextEditingController(
      text: _toText(widget.header.moisture),
    );
    _moisture2Ctrl = TextEditingController(
      text: _toText(widget.header.moisture2),
    );
    _moisture3Ctrl = TextEditingController(
      text: _toText(widget.header.moisture3),
    );
    _dateQc = parseAnyToDateTime(widget.header.dateQc) ?? DateTime.now();
  }

  @override
  void dispose() {
    _density1Ctrl.dispose();
    _density2Ctrl.dispose();
    _density3Ctrl.dispose();
    _moisture1Ctrl.dispose();
    _moisture2Ctrl.dispose();
    _moisture3Ctrl.dispose();
    super.dispose();
  }

  String _toText(double? value) =>
      value == null ? '' : value.toStringAsFixed(3);

  double? _parseNullableDecimal(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _validateDecimal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = _parseNullableDecimal(raw);
    if (value == null) return 'Angka tidak valid';
    if (value < 0) return 'Tidak boleh negatif';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      WashingQcResult(
        density1: _parseNullableDecimal(_density1Ctrl.text),
        density2: _parseNullableDecimal(_density2Ctrl.text),
        density3: _parseNullableDecimal(_density3Ctrl.text),
        moisture1: _parseNullableDecimal(_moisture1Ctrl.text),
        moisture2: _parseNullableDecimal(_moisture2Ctrl.text),
        moisture3: _parseNullableDecimal(_moisture3Ctrl.text),
        dateQc: _dateQc,
      ),
    );
  }

  /// Shortcut tanggal yang paling sering dipakai untuk input QC susulan.
  Widget _quickDateRow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final options = <(String, DateTime)>[
      ('Hari ini', today),
      ('Kemarin', today.subtract(const Duration(days: 1))),
      ('2 hari lalu', today.subtract(const Duration(days: 2))),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((o) {
        final selected =
            o.$2.year == _dateQc.year &&
            o.$2.month == _dateQc.month &&
            o.$2.day == _dateQc.day;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _dateQc = o.$2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? QcDialogPalette.primarySubtle
                  : QcDialogPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? QcDialogPalette.primary
                    : QcDialogPalette.border,
              ),
            ),
            child: Text(
              o.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? QcDialogPalette.primary
                    : QcDialogPalette.subtleText,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QcDialogShell(
      title: 'Quality Control',
      subtitle: widget.header.noWashing,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: QcDialogPalette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const QcSectionTitle(
                    icon: Icons.event_note_outlined,
                    text: 'Tanggal QC',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: QcDateField(
                          label: 'Tanggal QC',
                          hintText: 'boleh backdate',
                          value: _dateQc,
                          locale: const Locale('id', 'ID'),
                          onChanged: (d) => setState(() => _dateQc = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _quickDateRow(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: QcDialogPalette.border),
                  ),
                  const QcSectionTitle(
                    icon: Icons.science_outlined,
                    text: 'Density (g/cm3)',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: QcDecimalField(
                          label: 'Density 1',
                          controller: _density1Ctrl,
                          validator: _validateDecimal,
                          suffix: 'g/cm3',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QcDecimalField(
                          label: 'Density 2',
                          controller: _density2Ctrl,
                          validator: _validateDecimal,
                          suffix: 'g/cm3',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QcDecimalField(
                          label: 'Density 3',
                          controller: _density3Ctrl,
                          validator: _validateDecimal,
                          suffix: 'g/cm3',
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: QcDialogPalette.border),
                  ),
                  const QcSectionTitle(
                    icon: Icons.opacity_outlined,
                    text: 'Moisture (g/cm3)',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: QcDecimalField(
                          label: 'Moisture 1',
                          controller: _moisture1Ctrl,
                          validator: _validateDecimal,
                          suffix: 'g/cm3',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QcDecimalField(
                          label: 'Moisture 2',
                          controller: _moisture2Ctrl,
                          validator: _validateDecimal,
                          suffix: 'g/cm3',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QcDecimalField(
                          label: 'Moisture 3',
                          controller: _moisture3Ctrl,
                          validator: _validateDecimal,
                          suffix: 'g/cm3',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
