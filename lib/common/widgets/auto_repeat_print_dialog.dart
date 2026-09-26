import 'package:flutter/material.dart';

import '../../core/printing/label_printer_target_mixin.dart';
import '../../core/utils/device_printer_service.dart';
import 'info_box.dart';
import 'printer_selector_tile.dart';

/// Dialog "Quick" — create → print → mark-as-printed, berulang sebanyak
/// [totalRounds] kali tanpa perlu sentuh printer tiap label.
///
/// Berbeda dengan `FurnitureWipAutoRepeatDialog` / `PackingAutoRepeatDialog`
/// yang meng-hardcode query key + repository-nya, dialog ini sepenuhnya
/// generik: cukup berikan [pdfUrlBuilder] (URL PDF per kode label),
/// [onCreate] (callback buat label baru) dan [markAsPrinted] (konfirmasi ke
/// backend). Dipakai fitur yang label PDF-nya dilayani REST endpoint
/// (bahan pendukung, barang dagang) — bukan Crystal Report.
///
/// Round 1 memakai [firstNoLabel] yang sudah dibuat form submit.
/// Round 2..N memanggil [onCreate] untuk membuat label baru lalu print.
class AutoRepeatPrintDialog extends StatefulWidget {
  final int totalRounds;
  final String firstNoLabel;

  /// URL PDF untuk satu kode label. Contoh: `ApiConstants.barangDagangLabelPdf`.
  final Uri Function(String code) pdfUrlBuilder;

  /// Buat label baru (round 2+). Kembalikan kode label, atau null jika gagal.
  final Future<String?> Function() onCreate;

  /// Tandai label sudah dicetak di backend. Non-fatal kalau gagal.
  final Future<void> Function(String code)? markAsPrinted;

  const AutoRepeatPrintDialog({
    super.key,
    required this.totalRounds,
    required this.firstNoLabel,
    required this.pdfUrlBuilder,
    required this.onCreate,
    this.markAsPrinted,
  });

  @override
  State<AutoRepeatPrintDialog> createState() => _AutoRepeatPrintDialogState();
}

class _AutoRepeatPrintDialogState extends State<AutoRepeatPrintDialog>
    with LabelPrinterTargetMixin<AutoRepeatPrintDialog> {
  // ── Progress ──────────────────────────────────────────────────────────────
  int _completedCount = 0;
  bool _running = false;
  bool _done = false;
  String _statusMsg = 'Pilih printer lalu tekan MULAI.';
  String? _errorMsg;

  /// Riwayat setiap round: kode label + apakah sukses.
  final List<_RoundResult> _results = [];

  @override
  void initState() {
    super.initState();
    _loadPrinterAndDescribe();
  }

  Future<void> _loadPrinterAndDescribe() async {
    await loadTargetPrinter();
    if (!mounted || !hasPrinter) return;
    setState(() {
      _statusMsg =
          'Printer: $printerName ($printerTargetSubtitle). '
          'Tekan MULAI untuk memulai.';
    });
  }

  Future<void> _startLoop() async {
    if (!hasPrinter) {
      setState(() => _errorMsg = 'Pilih printer terlebih dahulu.');
      return;
    }

    setState(() {
      _running = true;
      _errorMsg = null;
    });

    final int total = widget.totalRounds;

    for (int round = _completedCount + 1; round <= total; round++) {
      if (!mounted) return;

      setState(() {
        _errorMsg = null;
        _statusMsg = 'Round $round/$total — Menyiapkan...';
      });

      // ── Step 1: Tentukan label ────────────────────────────────────────────
      String? labelCode;
      if (round == 1) {
        // Label pertama sudah dibuat oleh form submit.
        labelCode = widget.firstNoLabel;
      } else {
        _setStatus(round, total, 'Membuat label...');
        try {
          labelCode = await widget.onCreate();
        } catch (e) {
          _stopWithError(round, null, 'Gagal membuat label: $e');
          return;
        }
        if (labelCode == null || labelCode.isEmpty) {
          _stopWithError(round, null, 'Create label gagal (kode label kosong).');
          return;
        }

        // Tunggu sebentar agar data label tersedia di server PDF.
        // Label baru saja di-INSERT; tanpa jeda server kadang return 500
        // karena query PDF belum bisa menemukan row yang baru.
        _setStatus(round, total, 'Menunggu server...');
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;
      }

      // ── Step 2: Print ─────────────────────────────────────────────────────
      _setStatus(round, total, 'Mencetak $labelCode...');
      bool printOk = false;
      String? printError;
      try {
        printOk = await printPdfViaTarget(
          widget.pdfUrlBuilder(labelCode),
          onStatus: (s) {
            if (mounted) {
              setState(() => _statusMsg = 'Round $round/$total — $s');
            }
          },
          onError: (e) => printError = e,
        );
      } catch (e) {
        printOk = false;
        printError = e.toString();
      }

      if (printOk) {
        final printBy = await DevicePrinterService.getLoggedUsername();
        DevicePrinterService.logPrint(
          printerId: printerId?.isNotEmpty == true ? printerId! : printerMac!,
          printBy: printBy,
        );
      }

      if (!printOk) {
        _stopWithError(round, labelCode, 'Cetak gagal: ${printError ?? "error"}');
        return;
      }

      // ── Step 3: Mark as printed ───────────────────────────────────────────
      _setStatus(round, total, 'Menyimpan status cetak...');
      bool markOk = false;
      try {
        await widget.markAsPrinted?.call(labelCode);
        markOk = true;
      } catch (_) {
        // markAsPrinted gagal tidak fatal — label sudah tercetak fisik.
        markOk = false;
      }

      if (!mounted) return;

      // ── Round selesai ─────────────────────────────────────────────────────
      setState(() {
        _completedCount++;
        _results.add(
          _RoundResult(
            round: round,
            noLabel: labelCode!,
            success: true,
            marked: markOk,
          ),
        );
        _statusMsg = '$_completedCount/$total selesai.';
      });

      // Jeda singkat antar round agar socket BT bersih.
      if (round < total) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    if (mounted) {
      setState(() {
        _running = false;
        _done = true;
        _statusMsg =
            '✅ Semua $_completedCount/$total label berhasil dibuat dan dicetak!';
      });
    }
  }

  void _setStatus(int round, int total, String msg) {
    if (mounted) setState(() => _statusMsg = 'Round $round/$total — $msg');
  }

  void _stopWithError(int round, String? noLabel, String msg) {
    if (!mounted) return;
    setState(() {
      _running = false;
      _errorMsg = 'Round $round${noLabel != null ? " ($noLabel)" : ""}: $msg';
      if (noLabel != null) {
        _results.add(
          _RoundResult(
            round: round,
            noLabel: noLabel,
            success: false,
            marked: false,
          ),
        );
      }
    });
  }

  Future<void> _selectPrinter() async {
    final picked = await pickTargetPrinter();
    if (!picked || !mounted) return;
    setState(() {
      _errorMsg = null;
      _statusMsg =
          'Printer: $printerName ($printerTargetSubtitle). '
          'Tekan MULAI untuk memulai.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final canStart = !_running && !_done && hasPrinter;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Title ──
              Row(
                children: [
                  Icon(Icons.loop, color: Colors.blue.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Auto Create & Print  ($_completedCount / ${widget.totalRounds})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!_running)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Tutup',
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Progress bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.totalRounds > 0
                      ? _completedCount / widget.totalRounds
                      : 0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: _done ? Colors.green : Colors.blue.shade600,
                ),
              ),

              const SizedBox(height: 10),

              // ── Printer row ──
              _buildPrinterRow(),

              const SizedBox(height: 10),

              // ── Status box ──
              InfoBox(
                height: 72,
                busy: _running,
                isError: _errorMsg != null,
                icon: _errorMsg != null
                    ? Icons.error_outline
                    : (_done ? Icons.check_circle_outline : Icons.info_outline),
                iconColor: _errorMsg != null
                    ? Colors.red.shade700
                    : (_done ? Colors.green.shade700 : Colors.blue.shade700),
                text: _errorMsg ?? _statusMsg,
              ),

              const SizedBox(height: 10),

              // ── Log hasil ──
              if (_results.isNotEmpty) ...[
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, i) {
                        final r = _results[_results.length - 1 - i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            r.success ? Icons.check_circle : Icons.cancel,
                            color: r.success
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                            size: 20,
                          ),
                          title: Text(
                            r.noLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            r.success
                                ? (r.marked
                                      ? '✓ Tercetak'
                                      : '✓ Print (mark gagal)')
                                : '✗ Gagal',
                            style: TextStyle(
                              fontSize: 11,
                              color: r.success
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── Actions ──
              if (!_done)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canStart ? _startLoop : null,
                    icon: _running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _running
                          ? 'Sedang berjalan...'
                          : (_completedCount > 0 ? 'LANJUTKAN' : 'MULAI'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'SELESAI',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrinterRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrinterSelectorTile(
          printerName: printerName,
          printerMac: printerMac,
          printerId: printerId,
          onSelect: _selectPrinter,
          disabled: _running,
          compact: true,
        ),
        if (hasPrinter)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              printerTargetSubtitle,
              style: TextStyle(
                fontSize: 11,
                color: isNetworkPrinter
                    ? Colors.teal.shade700
                    : Colors.blueGrey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────────────

class _RoundResult {
  final int round;
  final String noLabel;
  final bool success;
  final bool marked;

  const _RoundResult({
    required this.round,
    required this.noLabel,
    required this.success,
    required this.marked,
  });
}
