import 'package:flutter/material.dart';

import '../../../../common/widgets/qc_dialog_components.dart';
import '../model/mixer_header_model.dart';

class MixerQcResult {
  final double? moisture1;
  final double? moisture2;
  final double? moisture3;
  final double? minMeltTemp;
  final double? maxMeltTemp;
  final double? mfi;
  final String? visualNote;

  const MixerQcResult({
    required this.moisture1,
    required this.moisture2,
    required this.moisture3,
    required this.minMeltTemp,
    required this.maxMeltTemp,
    required this.mfi,
    required this.visualNote,
  });
}

class MixerQcDialog extends StatefulWidget {
  final MixerHeader header;

  const MixerQcDialog({super.key, required this.header});

  @override
  State<MixerQcDialog> createState() => _MixerQcDialogState();
}

class _MixerQcDialogState extends State<MixerQcDialog> {
  static const int _maxVisualNoteLength = 150;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _moisture1Ctrl;
  late final TextEditingController _moisture2Ctrl;
  late final TextEditingController _moisture3Ctrl;
  late final TextEditingController _minMeltCtrl;
  late final TextEditingController _maxMeltCtrl;
  late final TextEditingController _mfiCtrl;
  late final TextEditingController _visualNoteCtrl;

  @override
  void initState() {
    super.initState();
    _moisture1Ctrl = TextEditingController(
      text: _toText(widget.header.moisture),
    );
    _moisture2Ctrl = TextEditingController(
      text: _toText(widget.header.moisture2),
    );
    _moisture3Ctrl = TextEditingController(
      text: _toText(widget.header.moisture3),
    );
    _minMeltCtrl = TextEditingController(
      text: _toText(widget.header.minMeltTemp),
    );
    _maxMeltCtrl = TextEditingController(
      text: _toText(widget.header.maxMeltTemp),
    );
    _mfiCtrl = TextEditingController(text: _toText(widget.header.mfi));
    _visualNoteCtrl = TextEditingController(
      text: widget.header.visualNote ?? '',
    );
  }

  @override
  void dispose() {
    _moisture1Ctrl.dispose();
    _moisture2Ctrl.dispose();
    _moisture3Ctrl.dispose();
    _minMeltCtrl.dispose();
    _maxMeltCtrl.dispose();
    _mfiCtrl.dispose();
    _visualNoteCtrl.dispose();
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

    final visualNote = _visualNoteCtrl.text.trim();

    Navigator.of(context).pop(
      MixerQcResult(
        moisture1: _parseNullableDecimal(_moisture1Ctrl.text),
        moisture2: _parseNullableDecimal(_moisture2Ctrl.text),
        moisture3: _parseNullableDecimal(_moisture3Ctrl.text),
        minMeltTemp: _parseNullableDecimal(_minMeltCtrl.text),
        maxMeltTemp: _parseNullableDecimal(_maxMeltCtrl.text),
        mfi: _parseNullableDecimal(_mfiCtrl.text),
        visualNote: visualNote.isEmpty ? null : visualNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QcDialogShell(
      title: 'Quality Control',
      subtitle: widget.header.noMixer,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _submit,
      content: SizedBox(
        width: 560,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: QcDialogPalette.border),
                  ),
                  const QcSectionTitle(
                    icon: Icons.device_thermostat_outlined,
                    text: 'Thermal & Flow',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: QcDecimalField(
                          label: 'Min Melt Temp',
                          controller: _minMeltCtrl,
                          validator: _validateDecimal,
                          suffix: 'C',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QcDecimalField(
                          label: 'Max Melt Temp',
                          controller: _maxMeltCtrl,
                          validator: _validateDecimal,
                          suffix: 'C',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: QcDecimalField(
                          label: 'MFI',
                          controller: _mfiCtrl,
                          validator: _validateDecimal,
                          suffix: null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _visualNoteCtrl,
                    minLines: 2,
                    maxLines: 3,
                    maxLength: _maxVisualNoteLength,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: QcDialogPalette.text,
                    ),
                    decoration: qcInputDecoration(label: 'Visual Note'),
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
