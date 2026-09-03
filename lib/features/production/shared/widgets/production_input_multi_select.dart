// lib/features/production/shared/widgets/production_input_multi_select.dart
//
// Multi-select via long-press untuk section "Label Input" di layar produksi —
// pola identik dengan multi-select output.
//
// Cara pakai di sebuah screen State:
//   1. `with ProductionInputMultiSelectMixin<MyScreen>`
//   2. Pada tiap tile input (`ProductionInputGroupTile`):
//        isSelected: isInputGroupSelected(key),
//        onTap: isSelectingInput ? () => toggleInputGroup(key, items) : <tap lama>,
//        onLongPress: isSelectingInput ? null : () => startSelectingInput(key, items),
//   3. Saat [isSelectingInput], tampilkan [ProductionInputSelectionBar]
//      menggantikan baris summary/aksi biasa.
//   4. Sediakan handler "Keluarkan" yang memanggil `vm.deleteItems(...)`.

import 'package:flutter/material.dart';

import '../../../../common/widgets/success_status_dialog.dart' show StatusAction;
import '../../../../common/widgets/warning_status_dialog.dart';

/// Dialog konfirmasi (warning) sebelum "Keluarkan" label input dari proses.
/// Return `true` bila user menekan "Keluarkan".
Future<bool> confirmReleaseInputDialog(BuildContext context, int count) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => WarningStatusDialog(
      title: 'Keluarkan $count Label Input?',
      message:
          'Label yang dipilih akan dilepas dari proses ini. Label tidak '
          'dihapus dan bisa dipakai lagi di proses lain.',
      actions: [
        StatusAction(
          label: 'Batal',
          isPrimary: false,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        StatusAction(
          label: 'Keluarkan',
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok == true;
}

mixin ProductionInputMultiSelectMixin<T extends StatefulWidget> on State<T> {
  bool _isSelectingInput = false;
  final Map<String, List<Object>> _selectedInputGroups = {};

  bool get isSelectingInput => _isSelectingInput;
  int get selectedInputCount => _selectedInputGroups.length;
  bool isInputGroupSelected(String key) =>
      _selectedInputGroups.containsKey(key);

  /// Semua item dari grup-grup yang dipilih (di-flatten).
  List<Object> get selectedInputItems =>
      _selectedInputGroups.values.expand((l) => l).toList(growable: false);

  /// Override menjadi `true` bila produksi sudah selesai / terkunci — long-press
  /// tidak akan masuk mode multi-select (tidak boleh keluarkan label).
  bool get isInputInteractionLocked => false;

  void startSelectingInput(String key, List<Object> items) {
    if (isInputInteractionLocked) return;
    setState(() {
      _isSelectingInput = true;
      _selectedInputGroups[key] = items;
    });
  }

  void toggleInputGroup(String key, List<Object> items) {
    setState(() {
      if (_selectedInputGroups.remove(key) == null) {
        _selectedInputGroups[key] = items;
      } else if (_selectedInputGroups.isEmpty) {
        _isSelectingInput = false;
      }
    });
  }

  void cancelInputSelection() {
    setState(() {
      _isSelectingInput = false;
      _selectedInputGroups.clear();
    });
  }

  void clearInputSelection() => setState(_selectedInputGroups.clear);

  /// Pilih semua grup pada [groups] (map key -> items).
  void selectAllInputGroups(Map<String, List<Object>> groups) {
    setState(() {
      _isSelectingInput = true;
      for (final e in groups.entries) {
        _selectedInputGroups[e.key] = e.value;
      }
    });
  }
}

/// Bar aksi yang tampil menggantikan baris summary saat mode multi-select
/// input aktif. Baris 1: jumlah terpilih. Baris 2: Batal · (Pilih Semua /
/// Bersihkan) · Keluarkan.
class ProductionInputSelectionBar extends StatelessWidget {
  const ProductionInputSelectionBar({
    super.key,
    required this.accentColor,
    required this.count,
    required this.totalAvailable,
    required this.allSelected,
    required this.onCancel,
    this.onToggleAll,
    this.onRelease,
    this.isBusy = false,
    this.releaseLabel = 'Keluarkan',
    this.releaseIcon = Icons.logout,
  });

  final Color accentColor;
  final int count;
  final int totalAvailable;
  final bool allSelected;
  final VoidCallback onCancel;

  /// Toggle Pilih Semua / Bersihkan. null = disable.
  final VoidCallback? onToggleAll;

  /// Keluarkan label terpilih dari proses. null = fitur tak didukung.
  final VoidCallback? onRelease;

  final bool isBusy;
  final String releaseLabel;
  final IconData releaseIcon;

  @override
  Widget build(BuildContext context) {
    final hasSelection = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count label dipilih',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: totalAvailable == 0 ? null : onToggleAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  allSelected ? Icons.remove_done : Icons.done_all,
                  size: 14,
                ),
                label: Text(
                  allSelected ? 'Bersihkan' : 'Pilih Semua',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onRelease != null) ...[
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: (!hasSelection || isBusy) ? null : onRelease,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.shade200,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: isBusy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(releaseIcon, size: 14),
                  label: Text(
                    isBusy ? 'Memproses...' : releaseLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
