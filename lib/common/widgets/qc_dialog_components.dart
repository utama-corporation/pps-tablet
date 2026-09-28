import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class QcDialogPalette {
  static const primary = Color(0xFF1565C0);
  static const primarySubtle = Color(0xFFE9F2FF);
  static const border = Color(0xFFDCDFE4);
  static const text = Color(0xFF172B4D);
  static const subtleText = Color(0xFF44546F);
  static const surface = Color(0xFFF7F8F9);
}

class QcDialogShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget content;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final String submitLabel;

  const QcDialogShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.onCancel,
    required this.onSubmit,
    this.submitLabel = 'Simpan QC',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          color: QcDialogPalette.primarySubtle,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          border: Border(bottom: BorderSide(color: QcDialogPalette.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: QcDialogPalette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.science_outlined,
                size: 20,
                color: QcDialogPalette.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: QcDialogPalette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: QcDialogPalette.subtleText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: content,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: QcDialogPalette.subtleText,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: QcDialogPalette.border),
            ),
          ),
          onPressed: onCancel,
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: QcDialogPalette.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onSubmit,
          icon: const Icon(Icons.save_outlined, size: 20),
          label: Text(submitLabel),
        ),
      ],
    );
  }
}

class QcSectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const QcSectionTitle({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: QcDialogPalette.subtleText),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: QcDialogPalette.subtleText,
          ),
        ),
      ],
    );
  }
}

class QcDecimalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? suffix;

  const QcDecimalField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: QcDialogPalette.text,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: qcInputDecoration(label: label, suffix: suffix),
    );
  }
}

/// Field tanggal (backdate) untuk dialog QC. Default `lastDate` = hari ini
/// supaya operator tidak bisa menginput QC untuk tanggal di masa depan, tapi
/// bebas memilih tanggal lampau untuk input QC susulan.
class QcDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String? hintText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Locale? locale;

  const QcDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.firstDate,
    this.lastDate,
    this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: qcInputDecoration(
          label: label,
        ).copyWith(
          helperText: hintText,
          helperStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: QcDialogPalette.subtleText,
          ),
          prefixIcon: const Icon(
            Icons.event_outlined,
            size: 18,
            color: QcDialogPalette.subtleText,
          ),
          suffixIcon: const Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: QcDialogPalette.subtleText,
          ),
        ),
        child: Text(
          DateFormat('dd MMM yyyy', 'id_ID').format(value),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: QcDialogPalette.text,
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 5);
    final last = lastDate ?? now;

    var initial = value;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Pilih $label',
      builder: locale == null
          ? null
          : (ctx, child) => Localizations.override(
              context: ctx,
              locale: locale,
              child: child!,
            ),
    );
    if (picked != null) onChanged(picked);
  }
}

InputDecoration qcInputDecoration({
  required String label,
  String? suffix,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: QcDialogPalette.subtleText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    suffixText: suffix,
    suffixStyle: const TextStyle(
      color: QcDialogPalette.subtleText,
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: QcDialogPalette.surface,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: QcDialogPalette.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: QcDialogPalette.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: QcDialogPalette.primary),
    ),
  );
}
