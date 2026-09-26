import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/widgets/info_box.dart';
import '../../../../common/widgets/printer_selector_tile.dart';
import '../../../../core/printing/label_printer_target_mixin.dart';
import '../../../../core/utils/bt_print_service.dart';
import '../../../../core/utils/device_printer_service.dart';

typedef GenerateSameCallback = Future<List<dynamic>> Function();

class BtAutoPrintDialog extends StatefulWidget {
  final List<dynamic> headers;

  /// Total label berhasil dibuat (dari backend create)
  final int count;

  final String? reportName;
  final String baseUrl;
  final GenerateSameCallback onGenerateSame;
  final String? labelQueryKey;
  final String Function(dynamic header) labelExtractor;
  final Future<void> Function(String code)? markAsPrinted;

  /// Builder URL PDF per kode label. Kalau diisi, dialog mencetak lewat
  /// `BtPrintService.printLabelFromUrl` (REST endpoint PDF) dan mengabaikan
  /// [reportName]/[labelQueryKey]. Dipakai fitur yang tidak punya Crystal
  /// Report — mis. bahan pendukung & barang dagang.
  ///
  /// Kalau null, dialog memakai mode Crystal Report lama.
  final Uri Function(String code)? pdfUrlBuilder;

  const BtAutoPrintDialog({
    super.key,
    required this.headers,
    required this.count,
    this.reportName,
    required this.baseUrl,
    required this.onGenerateSame,
    this.labelQueryKey,
    required this.labelExtractor,
    this.markAsPrinted,
    this.pdfUrlBuilder,
  });

  @override
  State<BtAutoPrintDialog> createState() => _BtAutoPrintDialogState();
}

class _BtAutoPrintDialogState extends State<BtAutoPrintDialog>
    with LabelPrinterTargetMixin<BtAutoPrintDialog> {
  int _currentIndex = 0;

  bool _busy = false;
  bool _lastPrintSuccess = false;

  String _status = 'Pilih printer lalu tap PRINT untuk mencetak.';
  String? _error;

  late final BtPrintService _btService;
  late List<dynamic> _headers;
  late int _count;

  // Printer yang tersimpan / dipilih dikelola oleh
  // [LabelPrinterTargetMixin] (field `printerId`/`printerMac`/`printerName`/
  // `printerTarget`) sehingga printer jaringan & Bluetooth bisa dipilih.

  @override
  void initState() {
    super.initState();
    _btService = BtPrintService(baseUrl: widget.baseUrl, defaultSystem: 'pps');

    _headers = List<dynamic>.from(widget.headers);
    _count = widget.count > 0 ? widget.count : _headers.length;
    if (_headers.length > _count) _count = _headers.length;

    _loadSavedPrinter();
  }

  Future<void> _loadSavedPrinter() async {
    await loadTargetPrinter();
    if (!mounted || !hasPrinter) return;
    setState(() => _status = 'Siap mencetak ke $printerName.');
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  String get _currentLabel {
    if (_headers.isEmpty || _currentIndex >= _headers.length) return '-';
    return widget.labelExtractor(_headers[_currentIndex]);
  }

  bool get _hasPrev => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _headers.length - 1;
  int get _pos => _headers.isEmpty ? 0 : (_currentIndex + 1);

  Color _toneColor() {
    if (_error != null) return Colors.red.shade700;
    if (_lastPrintSuccess) return Colors.green.shade700;
    return Colors.blue.shade700;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tone = _toneColor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== Title =====
              Row(
                children: [
                  Icon(Icons.print, color: tone),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cetak Label (Auto)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Tutup',
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ===== Current label =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_pos/$_count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                          _currentLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy label',
                      onPressed: (_currentLabel == '-' || _busy)
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(text: _currentLabel),
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Tersalin: $_currentLabel'),
                                  duration: const Duration(milliseconds: 800),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ===== Printer selector row =====
              _buildPrinterRow(),

              const SizedBox(height: 10),

              // ===== Status / Error =====
              InfoBox(
                height: 78,
                busy: _busy,
                isError: _error != null,
                icon: _error != null
                    ? Icons.error_outline
                    : (_lastPrintSuccess
                          ? Icons.check_circle_outline
                          : Icons.info_outline),
                iconColor: _error != null ? Colors.red.shade700 : tone,
                text: _error ?? _status,
              ),

              const SizedBox(height: 14),

              // ===== PRINT button =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_busy || !hasPrinter) ? null : _doPrint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'PRINT',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ===== Prev / Next =====
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : (_hasPrev ? _prev : null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('SEBELUMNYA'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : (_hasNext ? _next : null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('BERIKUTNYA'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ===== Generate new label (same data) =====
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _generateNewLabelSameData,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'BUAT LABEL BARU (DATA SAMA)',
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
          disabled: _busy,
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

  // ── Actions ───────────────────────────────────────────────────────────────

  void _prev() {
    if (!_hasPrev) return;
    setState(() {
      _currentIndex--;
      _error = null;
      _lastPrintSuccess = false;
      _status = hasPrinter
          ? 'Siap mencetak ke $printerName.'
          : 'Pilih printer lalu tap PRINT untuk mencetak.';
    });
  }

  void _next() {
    if (!_hasNext) return;
    setState(() {
      _currentIndex++;
      _error = null;
      _lastPrintSuccess = false;
      _status = hasPrinter
          ? 'Siap mencetak ke $printerName.'
          : 'Pilih printer lalu tap PRINT untuk mencetak.';
    });
  }

  /// Buka dialog MasterPrinterSelector untuk memilih printer (Bluetooth atau
  /// jaringan).
  Future<void> _selectPrinter() async {
    final picked = await pickTargetPrinter();
    if (!picked) return;
    setState(() {
      _error = null;
      _status = 'Siap mencetak ke $printerName.';
    });
  }

  Future<void> _doPrint() async {
    if (_headers.isEmpty || _currentIndex >= _headers.length) return;
    if (!hasPrinter) {
      setState(() => _error = 'Pilih printer terlebih dahulu.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _lastPrintSuccess = false;
      _status = 'Memulai proses cetak...';
    });

    final labelCode = _currentLabel;

    final bool ok;
    final urlBuilder = widget.pdfUrlBuilder;
    if (urlBuilder != null) {
      ok = await printPdfViaTarget(
        urlBuilder(labelCode),
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
        onError: (e) {
          if (mounted) setState(() => _error = e);
        },
      );
    } else {
      final reportName = widget.reportName;
      final queryKey = widget.labelQueryKey;
      if (reportName == null || queryKey == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Konfigurasi cetak tidak lengkap.';
        });
        return;
      }
      final query = {queryKey: labelCode};
      if (isNetworkPrinter) {
        // Printer jaringan tidak bisa pakai printLabel() (ESC/POS via BT) —
        // bangun URL Crystal Report lalu kirim bytes-nya via relay TSPL.
        ok = await printPdfViaTarget(
          _btService.buildPdfUri(
            reportName: reportName,
            query: query,
          ),
          onStatus: (s) {
            if (mounted) setState(() => _status = s);
          },
          onError: (e) {
            if (mounted) setState(() => _error = e);
          },
        );
      } else {
        ok = await _btService.printLabel(
          reportName: reportName,
          query: query,
          mac: printerMac!,
          onStatus: (s) {
            if (mounted) setState(() => _status = s);
          },
          onError: (e) {
            if (mounted) setState(() => _error = e);
          },
        );
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      // Log print ke microservice (fire-and-forget)
      final printBy = await DevicePrinterService.getLoggedUsername();
      DevicePrinterService.logPrint(
        printerId: printerId?.isNotEmpty == true ? printerId! : printerMac!,
        printBy: printBy,
      );
      setState(() {
        _lastPrintSuccess = true;
        _status = 'Label $labelCode berhasil dicetak.';
        _error = null;
      });

      // Tandai label sebagai sudah dicetak di backend
      widget.markAsPrinted?.call(labelCode);

      // Auto-advance ke label berikutnya
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      if (_hasNext) {
        setState(() {
          _currentIndex++;
          _lastPrintSuccess = false;
          _status = 'Siap untuk label berikutnya.';
        });
      }
    }
  }

  Future<void> _generateNewLabelSameData() async {
    if (!mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _lastPrintSuccess = false;
      _status = 'Membuat label baru (data sama)...';
    });

    try {
      final newHeaders = await widget.onGenerateSame();

      if (!mounted) return;

      if (newHeaders.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Gagal membuat label baru.';
          _status = 'Coba lagi.';
        });
        return;
      }

      setState(() {
        _headers.addAll(newHeaders);
        _count += newHeaders.length;
        _currentIndex = _headers.length - 1;
        _busy = false;
              _status = 'Label baru dibuat. Siap mencetak...';
      });

      await _doPrint();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Error: ${e.toString()}';
        _status = 'Terjadi kesalahan.';
      });
    }
  }
}
