import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mode pencetakan label yang bisa dipilih user di form tambah label.
///
/// Peta ke perilaku (mengikuti packing & furniture WIP):
/// - [single]   — buat label, tampilkan nomor label, tidak ada interaksi printer.
/// - [multiple] — buka dialog cetak manual, user jalan label per label.
/// - [quick]    — buka dialog auto create & print sebanyak N label.
enum PrintMode { single, multiple, quick }

extension PrintModeX on PrintMode {
  String get label {
    switch (this) {
      case PrintMode.single:
        return 'Single';
      case PrintMode.multiple:
        return 'Multiple';
      case PrintMode.quick:
        return 'Quick';
    }
  }

  IconData get icon {
    switch (this) {
      case PrintMode.single:
        return Icons.add_circle_outline;
      case PrintMode.multiple:
        return Icons.touch_app_outlined;
      case PrintMode.quick:
        return Icons.repeat;
    }
  }
}

/// Panel "Mode Cetak" — tiga chip [Single] / [Multiple] / [Quick].
///
/// Kolom "Jumlah label" hanya muncul saat mode [PrintMode.quick].
/// [repeatCountCtrl] dimiliki pemanggil supaya nilai jumlah label tetap
/// terbaca setelah dialog ditutup.
///
/// Mode di [disabledModes] tampil mati (tidak bisa dipilih) dengan
/// [disabledReason] sebagai penjelas lewat tooltip.
class PrintModeSelector extends StatelessWidget {
  final PrintMode value;
  final TextEditingController repeatCountCtrl;
  final ValueChanged<PrintMode> onChanged;
  final Set<PrintMode> disabledModes;
  final String? disabledReason;

  const PrintModeSelector({
    super.key,
    required this.value,
    required this.repeatCountCtrl,
    required this.onChanged,
    this.disabledModes = const {},
    this.disabledReason,
  });

  /// Jumlah label untuk mode Quick, dibatasi 1..99.
  int get repeatCount =>
      (int.tryParse(repeatCountCtrl.text.trim()) ?? 1).clamp(1, 99);

  /// Pilih mode baru. Menjauhi [PrintMode.quick] mereset jumlah label ke 1.
  void _handleTap(PrintMode mode) {
    if (mode != PrintMode.quick) {
      repeatCountCtrl.text = '1';
    }
    onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.print, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                'Mode Cetak',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final mode in PrintMode.values) ...[
                if (mode != PrintMode.values.first) const SizedBox(width: 6),
                Expanded(child: _buildChip(mode)),
              ],
            ],
          ),
          if (value == PrintMode.quick) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Jumlah label:',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: repeatCountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.blue.shade300),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(PrintMode mode) {
    final selected = value == mode;
    final disabled = disabledModes.contains(mode) && !selected;

    final chip = GestureDetector(
      onTap: disabled ? null : () => _handleTap(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade100
              : (selected ? Colors.blue.shade700 : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled
                ? Colors.grey.shade200
                : (selected ? Colors.blue.shade700 : Colors.blue.shade300),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode.icon,
              size: 18,
              color: disabled
                  ? Colors.grey.shade400
                  : (selected ? Colors.white : Colors.blue.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: disabled
                    ? Colors.grey.shade400
                    : (selected ? Colors.white : Colors.blue.shade800),
              ),
            ),
          ],
        ),
      ),
    );

    if (!disabled) return chip;
    final reason = disabledReason;
    return reason == null ? chip : Tooltip(message: reason, child: chip);
  }
}
