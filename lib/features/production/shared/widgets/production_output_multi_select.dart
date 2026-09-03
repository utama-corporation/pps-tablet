// lib/features/production/shared/widgets/production_output_multi_select.dart
//
// Multi-select via long-press untuk section "Label Output" di layar produksi.
//
// Cara pakai di sebuah screen State:
//   1. `with ProductionOutputMultiSelectMixin<MyScreen>`
//   2. Bungkus tiap tile output dengan [wrapOutputTile].
//   3. Saat [isSelectingOutput], tampilkan [ProductionOutputSelectionBar]
//      menggantikan baris summary/aksi biasa.
//   4. Sediakan mapping item -> [ProductionOutputPrintTarget] (untuk cetak
//      sekaligus) dan, bila didukung, aksi hapus per item.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/success_status_dialog.dart' show StatusAction;
import '../../../../common/widgets/warning_status_dialog.dart';
import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';

/// Dialog konfirmasi (warning) sebelum hapus label output. Return `true` bila
/// user menekan "Hapus".
Future<bool> confirmDeleteOutputsDialog(BuildContext context, int count) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => WarningStatusDialog(
      title: 'Hapus $count Label Output?',
      message:
          'Label yang dipilih akan dihapus permanen dan tidak dapat '
          'dikembalikan.',
      actions: [
        StatusAction(
          label: 'Batal',
          isPrimary: false,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        StatusAction(
          label: 'Hapus',
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Ubah error mentah (Exception / body JSON `{success,message}` / string biasa)
/// menjadi pesan yang layak ditampilkan ke user pada dialog status error.
///
/// Pesan teknis DB (constraint FK, `DateUsage IS NOT NULL`, dsb.) diterjemahkan
/// jadi kalimat yang ramah user.
String cleanProductionErrorMessage(Object error) {
  var raw = error.toString().replaceFirst('Exception: ', '').trim();
  final braceStart = raw.indexOf('{');
  final braceEnd = raw.lastIndexOf('}');
  if (braceStart != -1 && braceEnd > braceStart) {
    final jsonPart = raw.substring(braceStart, braceEnd + 1);
    try {
      final decoded = jsonDecode(jsonPart);
      if (decoded is Map && decoded['message'] is String) {
        final suffix = raw.substring(braceEnd + 1).trim();
        raw = (decoded['message'] as String).trim() +
            (suffix.isNotEmpty ? ' $suffix' : '');
      }
    } catch (_) {
      // Bukan JSON valid — biarkan raw apa adanya.
    }
  }
  return _friendlyProductionError(raw);
}

/// Terjemahkan pesan error DB/SQL yang sudah dikenal menjadi kalimat ramah user.
String _friendlyProductionError(String raw) {
  final lower = raw.toLowerCase();

  // Label sudah tercatat pada Stock Opname (FK ke tabel StockOpname*).
  if (lower.contains('stockopname') ||
      lower.contains('stockoppname') ||
      lower.contains('stock opname')) {
    return 'Label ini sudah tercatat pada Stock Opname, jadi tidak bisa dihapus.';
  }

  // Detail label sudah dipakai di proses lain (DateUsage terisi).
  if (lower.contains('dateusage is not null') ||
      lower.contains('sudah terpakai') ||
      lower.contains('already used')) {
    return 'Label ini sudah digunakan pada proses produksi, jadi tidak bisa dihapus.';
  }

  // Constraint referensi / foreign key generik.
  if (lower.contains('reference constraint') ||
      lower.contains('conflicted with the') ||
      lower.contains('foreign key') ||
      lower.contains('constraint referensi') ||
      raw.contains('547')) {
    return 'Label ini masih terhubung dengan data lain, jadi tidak bisa dihapus.';
  }

  return raw.isEmpty ? 'Kesalahan tidak diketahui' : raw;
}

/// Data minimal untuk mencetak satu label output.
class ProductionOutputPrintTarget {
  const ProductionOutputPrintTarget({
    required this.code,
    required this.pdfUrl,
    required this.feature,
    required this.markAsPrinted,
  });

  final String code;
  final String pdfUrl;

  /// Key untuk [LabelPrintSyncQueue] (mis. 'broker', 'bonggolan', 'reject').
  final String feature;

  /// Dipanggil setelah cetak dikonfirmasi — kembalikan print count baru dari
  /// server, atau null bila gagal (akan di-queue untuk retry).
  final Future<int?> Function() markAsPrinted;
}

mixin ProductionOutputMultiSelectMixin<T extends StatefulWidget> on State<T> {
  bool _isSelectingOutput = false;
  final Map<String, Object> _selectedOutputItems = {};

  bool get isSelectingOutput => _isSelectingOutput;
  int get selectedOutputCount => _selectedOutputItems.length;
  List<Object> get selectedOutputItems =>
      _selectedOutputItems.values.toList(growable: false);
  bool isOutputSelected(String code) => _selectedOutputItems.containsKey(code);

  /// Override menjadi `true` bila produksi sudah selesai / terkunci — long-press
  /// tidak akan masuk mode multi-select (tidak boleh cetak/hapus).
  bool get isOutputInteractionLocked => false;

  void startSelectingOutput(String code, Object item) {
    if (isOutputInteractionLocked) return;
    setState(() {
      _isSelectingOutput = true;
      _selectedOutputItems[code] = item;
    });
  }

  void toggleOutputSelection(String code, Object item) {
    setState(() {
      if (_selectedOutputItems.remove(code) == null) {
        _selectedOutputItems[code] = item;
      } else if (_selectedOutputItems.isEmpty) {
        _isSelectingOutput = false;
      }
    });
  }

  void cancelOutputSelection() {
    setState(() {
      _isSelectingOutput = false;
      _selectedOutputItems.clear();
    });
  }

  void clearOutputSelection() => setState(_selectedOutputItems.clear);

  /// Pilih semua [items]; [codeOf] mengembalikan nomor label (null = dilewati).
  void selectAllOutputs(
    Iterable<Object?> items,
    String? Function(Object? item) codeOf,
  ) {
    setState(() {
      _isSelectingOutput = true;
      for (final it in items) {
        final c = codeOf(it);
        if (c != null && it != null) _selectedOutputItems[c] = it;
      }
    });
  }

  /// Bungkus satu tile output supaya bisa long-press → masuk mode multi-select,
  /// dan tap (saat mode aktif) → toggle pilih.
  Widget wrapOutputTile({
    required String code,
    required Object item,
    required Color accentColor,
    required Widget Function(VoidCallback? overrideTap) builder,
  }) {
    final selected = _selectedOutputItems.containsKey(code);
    final tile = builder(
      _isSelectingOutput ? () => toggleOutputSelection(code, item) : null,
    );
    return GestureDetector(
      onLongPress: (_isSelectingOutput || isOutputInteractionLocked)
          ? null
          : () => startSelectingOutput(code, item),
      child: Stack(
        children: [
          tile,
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor, width: 2),
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 4,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hapus semua label terpilih dengan memanggil [deleteOne] per item
  /// ([deleteOne] harus melempar bila gagal). Keluar dari mode select setelah
  /// selesai. Kembalikan jumlah yang berhasil, gagal, dan daftar pesan error
  /// yang sudah dibersihkan & dedup — pemanggil bertanggung jawab atas dialog
  /// konfirmasi, notifikasi, dan refresh list.
  Future<({int deleted, int failed, List<String> errors})> deleteSelectedOutputs(
    Future<void> Function(Object item) deleteOne,
  ) async {
    var deleted = 0;
    var failed = 0;
    final errors = <String>[];
    for (final item in selectedOutputItems) {
      try {
        await deleteOne(item);
        deleted++;
      } catch (e) {
        failed++;
        final msg = cleanProductionErrorMessage(e);
        if (!errors.contains(msg)) errors.add(msg);
      }
    }
    if (mounted) cancelOutputSelection();
    return (deleted: deleted, failed: failed, errors: errors);
  }

  /// Cetak semua label terpilih sekaligus dalam satu PDF viewer.
  /// Menangani lock (acquire/release), mark-as-printed, dan retry-queue.
  /// Keluar dari mode select setelah selesai.
  Future<void> runBatchPrintOutputs(
    List<ProductionOutputPrintTarget> targets,
  ) async {
    if (targets.isEmpty) return;

    final lockApi = LabelPrintLockApi();
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    final rootCtx = Navigator.of(context, rootNavigator: true).context;

    final acquired = <String>{};
    for (final t in targets) {
      if (!mounted) break;
      try {
        await lockApi.acquire(t.code);
        acquired.add(t.code);
      } catch (_) {
        // Lock gagal — label ini tetap dicetak, tanpa lock.
      }
    }

    final printed = <String>{};
    final callbacks = targets.map((t) {
      return (() {
            printed.add(t.code);
            () async {
              var needsIncrement = false;
              var needsRelease = false;
              try {
                final count = await t.markAsPrinted();
                if (count != null) lockVm.setPrintCount(t.code, count);
              } catch (_) {
                needsIncrement = true;
              }
              try {
                await lockApi.release(t.code);
              } catch (_) {
                needsRelease = true;
              }
              if (needsIncrement || needsRelease) {
                await queue.enqueue(
                  feature: t.feature,
                  noLabel: t.code,
                  needsIncrement: needsIncrement,
                  needsReleaseLock: needsRelease,
                );
              }
            }().ignore();
          })
          as VoidCallback;
    }).toList();

    try {
      await PdfPrintService(defaultSystem: 'pps').previewMultipleFromUrls(
        // ignore: use_build_context_synchronously
        context: rootCtx,
        pdfUrls: targets.map((t) => Uri.parse(t.pdfUrl)).toList(),
        title: 'Cetak ${targets.length} Label',
        onPrintedCallbacks: callbacks,
      );
    } finally {
      for (final t in targets) {
        if (acquired.contains(t.code) && !printed.contains(t.code)) {
          () async {
            try {
              await lockApi.release(t.code);
            } catch (_) {
              await queue.enqueue(
                feature: t.feature,
                noLabel: t.code,
                needsReleaseLock: true,
              );
            }
          }().ignore();
        }
      }
      if (mounted) cancelOutputSelection();
    }
  }
}

/// Bar aksi yang tampil menggantikan baris summary saat mode multi-select
/// output aktif. Baris 1: jumlah terpilih. Baris 2: Batal · (Pilih Semua /
/// Bersihkan) · Cetak · Hapus.
class ProductionOutputSelectionBar extends StatelessWidget {
  const ProductionOutputSelectionBar({
    super.key,
    required this.accentColor,
    required this.count,
    required this.totalAvailable,
    required this.allSelected,
    required this.onCancel,
    this.onToggleAll,
    this.onPrint,
    this.onDelete,
  });

  final Color accentColor;
  final int count;
  final int totalAvailable;
  final bool allSelected;
  final VoidCallback onCancel;

  /// Toggle Pilih Semua / Bersihkan. null = disable.
  final VoidCallback? onToggleAll;

  /// Cetak sekaligus. null = fitur tak didukung (tombol disembunyikan).
  final VoidCallback? onPrint;

  /// Hapus sekaligus. null = fitur tak didukung (tombol disembunyikan).
  final VoidCallback? onDelete;

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
              if (onPrint != null) ...[
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: hasSelection ? onPrint : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: accentColor,
                    disabledBackgroundColor: Colors.white24,
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
                  icon: const Icon(Icons.print_outlined, size: 14),
                  label: Text(
                    'Cetak $count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: hasSelection ? onDelete : null,
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
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text(
                    'Hapus',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
