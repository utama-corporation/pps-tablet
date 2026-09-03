import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../common/widgets/loading_dialog.dart';
import '../../common/widgets/pdf_viewer_screen.dart';
import '../printing/label_printer.dart';
import '../services/dialog_service.dart';
import '../services/token_storage.dart';
import 'device_printer_service.dart';

/// Dilempar saat fetch satu PDF label gagal — bawa statusCode & url supaya
/// pesan errornya bisa disesuaikan (mis. 403 = permission, 404 = tidak
/// ditemukan) alih-alih pesan generik "HTTP xxx" yang membingungkan user.
class _PdfFetchException implements Exception {
  final int statusCode;
  final Uri url;

  const _PdfFetchException({required this.statusCode, required this.url});

  @override
  String toString() => 'Gagal ambil PDF label (HTTP $statusCode) — $url';
}

class PdfPrintService {
  /// URL default Crystal Report server. Ganti di sini jika server pindah.
  // static const String defaultBaseUrl = 'http://192.168.11.153:44381';
  static const String defaultBaseUrl = 'http://192.168.10.100:3000';

  PdfPrintService({
    this.baseUrl = PdfPrintService.defaultBaseUrl,
    this.defaultSystem = 'pps',
    this.httpClient,
    this.getAuthHeader,
  });

  final String baseUrl;
  final String defaultSystem;
  final http.Client? httpClient;
  final Map<String, String> Function()? getAuthHeader;

  // Cache untuk printer yang dipilih
  Printer? _selectedPrinter;

  // =============== GENERIC URL BUILDER =================
  Uri buildUri({
    required String reportName,
    required Map<String, String> query,
    String? system,
  }) {
    final u = Uri.parse(
      '$baseUrl/api/crystalreport/${system ?? defaultSystem}/export-pdf',
    );
    return u.replace(queryParameters: {'reportName': reportName, ...query});
  }

  // =============== PUBLIC API (PREVIEW MODE) ===============
  Future<void> printReport80mm({
    required BuildContext context,
    required String reportName,
    required Map<String, String> query,
    String? system,
    String? saveNameHint,
    bool showLoading = true,
    String loadingMessage = 'Menyiapkan label…',
  }) async {
    final url = buildUri(reportName: reportName, query: query, system: system);
    await _withLoading(
      context: context,
      enabled: showLoading,
      message: loadingMessage,
      run: () => downloadAndPrint80mm(
        context: context,
        url: url,
        saveNameHint: saveNameHint ?? _inferName(reportName, query),
      ),
    );
  }

  /// Versi yang menerima URL langsung (PREVIEW MODE)
  Future<void> downloadAndPrint80mm({
    required BuildContext context,
    required Uri url,
    String? saveNameHint,
    bool showLoading = false,
    String loadingMessage = 'Memproses PDF…',
  }) async {
    Future<void> core() async {
      final bytes = await _download(url);
      final filename = _filenameFromHeaders(
        bytes.response,
        saveNameHint ?? 'Label.pdf',
      );
      await _saveOriginalTemp(bytes.body, filename); // optional debug
      final rebuilt = await _remapPdfTo80mm(bytes.body);
      await _openNativePrintPreview(
        fileName: '80mm_$filename',
        pdfBytes: rebuilt,
      );
    }

    if (showLoading) {
      await _withLoading(
        context: context,
        enabled: true,
        message: loadingMessage,
        run: core,
      );
    } else {
      try {
        await core();
      } catch (e) {
        _showSnack(context, 'Print gagal: $e');
      }
    }
  }

  // =============== NEW: DIRECT PRINT MODE ===============

  /// Print langsung ke printer tanpa preview
  /// Returns true jika berhasil, false jika gagal
  Future<bool> directPrintReport80mm({
    required BuildContext context,
    required String reportName,
    required Map<String, String> query,
    String? system,
    bool autoSelectPrinter = true,
    bool showLoading = false,
    String loadingMessage = 'Mencetak label…',
    Function(String)? onError,
    Uri? afterPrintPatchUrl,
  }) async {
    final url = buildUri(reportName: reportName, query: query, system: system);
    debugPrint('🖨️ directPrintReport80mm → $url');

    return await directPrintFromUrl(
      context: context,
      url: url,
      autoSelectPrinter: autoSelectPrinter,
      showLoading: showLoading,
      loadingMessage: loadingMessage,
      onError: onError,
      afterPrintPatchUrl: afterPrintPatchUrl,
    );
  }

  /// Direct print dari URL
  /// Returns true jika berhasil, false jika gagal
  Future<bool> directPrintFromUrl({
    required BuildContext context,
    required Uri url,
    bool autoSelectPrinter = true,
    bool showLoading = false,
    String loadingMessage = 'Mencetak…',
    Function(String)? onError,
    Uri? afterPrintPatchUrl,
  }) async {
    Future<bool> core() async {
      try {
        // 1. Download PDF dari backend
        final bytes = await _download(url);

        // 2. Konversi ke 80mm
        final pdfBytes = await _remapPdfTo80mm(bytes.body);

        // 3. Print langsung
        final success = await _directPrintPdf(
          pdfBytes: pdfBytes,
          autoSelectPrinter: autoSelectPrinter,
        );

        // 4. Hit PATCH endpoint hanya jika print berhasil
        if (success && afterPrintPatchUrl != null) {
          await _patchAfterPrint(afterPrintPatchUrl);
        }

        return success;
      } catch (e) {
        final errorMsg = 'Print gagal: $e';
        if (onError != null) {
          onError(errorMsg);
        } else {
          _showSnack(context, errorMsg);
        }
        return false;
      }
    }

    if (showLoading) {
      return await _withLoading(
        context: context,
        enabled: true,
        message: loadingMessage,
        run: core,
      );
    } else {
      return await core();
    }
  }

  // =============== IN-APP PDF VIEWER MODE ===============

  /// Fetch PDF dari backend, remap ke 80 mm, lalu buka [PdfViewerScreen]
  /// di dalam aplikasi. Printer dipilih in-app dan PRINT langsung tanpa
  /// membuka native Android print dialog.
  Future<void> previewReport80mm({
    required BuildContext context,
    required String reportName,
    required Map<String, String> query,
    String? system,
    String? title,
    VoidCallback? onPrinted,
  }) async {
    final url = buildUri(reportName: reportName, query: query, system: system);

    Uint8List rawPdf;
    Uint8List previewPdf;
    try {
      final result = await _withLoading<(Uint8List, Uint8List)>(
        context: context,
        enabled: true,
        message: 'Menyiapkan PDF…',
        run: () async {
          final dl = await _download(url);
          return (dl.body, await _remapPdfTo80mm(dl.body));
        },
      );
      rawPdf = result.$1;
      previewPdf = result.$2;
    } catch (_) {
      // Error sudah ditampilkan oleh _withLoading / _showSnack
      return;
    }

    if (!context.mounted) return;

    // Buka PDF viewer — screen langsung close saat user tap CETAK LABEL
    final outcome = await PdfViewerScreen.push(
      context: context,
      title:
          title ??
          _inferName(
            reportName,
            query,
          ).replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
      pdfBytes: previewPdf,
    );

    // Jika user menutup tanpa mencetak
    if (outcome == null || !context.mounted) return;

    // Tampilkan snackbar loading sementara print berjalan
    _showPrintingSnack(context, outcome.printerName);

    String? errorMsg;
    final ok = await LabelPrinter.forTarget(outcome.target).printPdf(
      rawPdf,
      onError: (e) => errorMsg = e,
    );

    if (!context.mounted) return;
    if (ok) {
      onPrinted?.call();
      _showPrintSuccessSnack(context, outcome.printerName);
      // Kirim log print ke microservice (fire-and-forget, tidak blok UI)
      final printBy = await DevicePrinterService.getLoggedUsername();
      DevicePrinterService.logPrint(printerId: outcome.mac, printBy: printBy);
    } else {
      _showPrintErrorSnack(context, errorMsg ?? 'Print gagal. Coba lagi.');
    }
  }

  /// Preview dan cetak beberapa label sekaligus dalam satu layar PDF viewer.
  /// Semua PDF di-download, digabung menjadi satu dokumen multi-halaman,
  /// lalu dibuka satu kali. Setelah user pilih printer, setiap URL dikirim
  /// ke printer, dan [onPrintedCallbacks[i]] dipanggil jika label ke-i berhasil.
  Future<void> previewMultipleFromUrls({
    required BuildContext context,
    required List<Uri> pdfUrls,
    String? title,
    List<VoidCallback?>? onPrintedCallbacks,
  }) async {
    if (pdfUrls.isEmpty) return;

    Uint8List mergedBytes;
    try {
      mergedBytes = await _withLoading<Uint8List>(
        context: context,
        enabled: true,
        message: 'Menyiapkan ${pdfUrls.length} label…',
        run: () async {
          final token = await TokenStorage.getToken();
          final client = httpClient ?? http.Client();
          final headers = <String, String>{
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          };
          final futures = pdfUrls.map((url) async {
            debugPrint('📥 Mengunduh PDF label: $url');
            final resp = await client
                .get(url, headers: headers)
                .timeout(const Duration(seconds: 30));
            debugPrint(
              '📥 Respons PDF $url → status ${resp.statusCode}, ${resp.bodyBytes.length} bytes',
            );
            if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
              throw _PdfFetchException(statusCode: resp.statusCode, url: url);
            }
            return resp.bodyBytes;
          });
          final allBytes = await Future.wait(futures);
          return _mergePdfs(allBytes);
        },
      );
    } catch (e, st) {
      // Sebelumnya error di sini ditelan diam-diam (cuma SnackBar dari
      // _withLoading yang gampang tidak kelihatan kalau ScaffoldMessenger
      // tidak ketemu dari context yang dipakai) — sekarang selalu di-log ke
      // console DAN ditampilkan lewat ErrorStatusDialog level app
      // (DialogService, dipasang di overlay root — tidak bergantung context
      // lokal sama sekali) supaya tidak mungkin kelewat.
      debugPrint('❌ previewMultipleFromUrls gagal: $e\n$st');
      String title = 'Gagal Menyiapkan Label';
      String message = '$e';
      if (e is _PdfFetchException && e.statusCode == 403) {
        title = 'Tidak Punya Izin';
        message =
            'Akun kamu tidak punya izin untuk mencetak label ini. '
            'Minta admin tambahkan permission yang sesuai kategori label '
            '(barang jadi/reject/furniture WIP), lalu login ulang.';
      } else if (e is _PdfFetchException && e.statusCode == 404) {
        title = 'Label Tidak Ditemukan';
        message = 'Label ${e.url} tidak ditemukan di server.';
      }
      await DialogService.instance.showError(title: title, message: message);
      return;
    }

    if (!context.mounted) return;

    final outcome = await PdfViewerScreen.push(
      context: context,
      title: title ?? '${pdfUrls.length} Label',
      pdfBytes: mergedBytes,
    );

    if (outcome == null || !context.mounted) return;

    _showPrintingSnack(context, outcome.printerName);

    final printer = LabelPrinter.forTarget(outcome.target);

    var anyOk = false;
    for (var i = 0; i < pdfUrls.length; i++) {
      String? errorMsg;
      var ok = false;
      try {
        final bytes = await _fetchPdfBytes(pdfUrls[i]);
        ok = await printer.printPdf(bytes, onError: (e) => errorMsg = e);
      } catch (e) {
        errorMsg = '$e';
      }
      if (ok) {
        anyOk = true;
        onPrintedCallbacks?.elementAtOrNull(i)?.call();
      }
      debugPrint(
        ok ? '✅ Printed ${pdfUrls[i]}' : '❌ Failed ${pdfUrls[i]}: $errorMsg',
      );
    }

    if (!context.mounted) return;
    if (anyOk) {
      _showPrintSuccessSnack(context, outcome.printerName);
      final printBy = await DevicePrinterService.getLoggedUsername();
      DevicePrinterService.logPrint(printerId: outcome.mac, printBy: printBy);
    } else {
      _showPrintErrorSnack(context, 'Semua label gagal dicetak. Coba lagi.');
    }
  }

  /// Variant [previewReport80mm] yang menerima URL langsung (tidak melalui
  /// Crystal Report URL builder). Digunakan untuk endpoint PDF baru.
  Future<void> previewFromUrl({
    required BuildContext context,
    required Uri pdfUrl,
    String? title,
    VoidCallback? onPrinted,
  }) async {
    Uint8List pdfBytes;
    try {
      pdfBytes = await _withLoading<Uint8List>(
        context: context,
        enabled: true,
        message: 'Menyiapkan PDF…',
        run: () async {
          final token = await TokenStorage.getToken();
          final client = httpClient ?? http.Client();
          final resp = await client
              .get(
                pdfUrl,
                headers: {
                  if (token != null && token.isNotEmpty)
                    'Authorization': 'Bearer $token',
                },
              )
              .timeout(const Duration(seconds: 30));
          debugPrint(
            '📥 PDF status: ${resp.statusCode}, bytes: ${resp.bodyBytes.length} from $pdfUrl',
          );
          if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
            throw Exception('HTTP ${resp.statusCode} — tidak ada data.');
          }
          // PDF dari endpoint sudah berformat thermal — tidak perlu di-remap
          return resp.bodyBytes;
        },
      );
    } catch (_) {
      return;
    }

    if (!context.mounted) return;

    final outcome = await PdfViewerScreen.push(
      context: context,
      title: title ?? 'Label',
      pdfBytes: pdfBytes,
    );

    if (outcome == null || !context.mounted) return;

    _showPrintingSnack(context, outcome.printerName);

    String? errorMsg;
    final ok = await LabelPrinter.forTarget(outcome.target).printPdf(
      pdfBytes,
      onError: (e) => errorMsg = e,
    );

    if (!context.mounted) return;
    if (ok) {
      onPrinted?.call();
      _showPrintSuccessSnack(context, outcome.printerName);
      final printBy = await DevicePrinterService.getLoggedUsername();
      DevicePrinterService.logPrint(printerId: outcome.mac, printBy: printBy);
    } else {
      _showPrintErrorSnack(context, errorMsg ?? 'Print gagal. Coba lagi.');
    }
  }

  /// Variant [previewFromUrl] yang menerima PDF bytes yang sudah digenerate
  /// secara lokal (mis. via `package:pdf`) alih-alih mengunduh dari backend.
  /// Dipakai oleh fitur yang belum punya endpoint PDF sendiri di server —
  /// alur in-app viewer + pilih printer + Bluetooth print tetap sama persis
  /// seperti [previewFromUrl].
  Future<void> previewFromBytes({
    required BuildContext context,
    required Uint8List pdfBytes,
    String? title,
    VoidCallback? onPrinted,
  }) async {
    if (!context.mounted) return;

    final outcome = await PdfViewerScreen.push(
      context: context,
      title: title ?? 'Label',
      pdfBytes: pdfBytes,
    );

    if (outcome == null || !context.mounted) return;

    _showPrintingSnack(context, outcome.printerName);

    String? errorMsg;
    final ok = await LabelPrinter.forTarget(outcome.target).printPdf(
      pdfBytes,
      onError: (e) => errorMsg = e,
    );

    if (!context.mounted) return;
    if (ok) {
      onPrinted?.call();
      _showPrintSuccessSnack(context, outcome.printerName);
      final printBy = await DevicePrinterService.getLoggedUsername();
      DevicePrinterService.logPrint(printerId: outcome.mac, printBy: printBy);
    } else {
      _showPrintErrorSnack(context, errorMsg ?? 'Print gagal. Coba lagi.');
    }
  }

  /// Core function untuk direct print
  Future<bool> _directPrintPdf({
    required Uint8List pdfBytes,
    bool autoSelectPrinter = true,
  }) async {
    try {
      // Jika auto select dan belum punya printer, cari printer thermal
      if (autoSelectPrinter && _selectedPrinter == null) {
        await _autoSelectThermalPrinter();
      }

      // Jika masih belum ada printer, gunakan default
      if (_selectedPrinter == null) {
        // Print ke printer default system
        final result = await Printing.directPrintPdf(
          printer: Printer(url: ''), // empty = use default
          onLayout: (_) => pdfBytes,
          format: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm),
        );
        return result;
      } else {
        // Print ke printer yang sudah dipilih
        final result = await Printing.directPrintPdf(
          printer: _selectedPrinter!,
          onLayout: (_) => pdfBytes,
          format: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm),
        );
        return result;
      }
    } catch (e) {
      debugPrint('❌ Direct print error: $e');
      return false;
    }
  }

  /// Auto-select printer thermal (RawBT, Panda, dll)
  Future<void> _autoSelectThermalPrinter() async {
    try {
      // Get list semua printer yang tersedia
      await Printing.listPrinters().then((printers) {
        if (printers.isEmpty) {
          debugPrint('⚠️ No printers found');
          return;
        }

        // Prioritas: cari printer dengan keyword thermal
        final keywords = [
          'rawbt',
          'panda',
          'prj',
          'thermal',
          'bluetooth',
          'bt',
          '80mm',
        ];

        for (final keyword in keywords) {
          final found = printers.firstWhere(
            (p) => p.name.toLowerCase().contains(keyword),
            orElse: () => Printer(url: ''),
          );

          if (found.url.isNotEmpty) {
            _selectedPrinter = found;
            debugPrint('✅ Auto-selected printer: ${found.name}');
            return;
          }
        }

        // Jika tidak ada yang match, gunakan printer pertama
        _selectedPrinter = printers.first;
        debugPrint('ℹ️ Using first available printer: ${printers.first.name}');
      });
    } catch (e) {
      debugPrint('⚠️ Error listing printers: $e');
      // Tetap lanjut, akan pakai default printer
    }
  }

  /// Manual select printer (untuk settings)
  Future<Printer?> selectPrinter(BuildContext context) async {
    try {
      final printers = await Printing.listPrinters();

      if (printers.isEmpty) {
        _showSnack(context, 'Tidak ada printer yang tersedia');
        return null;
      }

      // Show dialog untuk pilih printer
      final selected = await showDialog<Printer>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pilih Printer'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: printers.length,
              itemBuilder: (_, i) {
                final p = printers[i];
                final isSelected = _selectedPrinter?.url == p.url;

                return ListTile(
                  leading: Icon(
                    Icons.print,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(p.url),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('BATAL'),
            ),
          ],
        ),
      );

      if (selected != null) {
        _selectedPrinter = selected;
        debugPrint('✅ Manually selected printer: ${selected.name}');
      }

      return selected;
    } catch (e) {
      _showSnack(context, 'Error: $e');
      return null;
    }
  }

  /// Reset printer selection (gunakan auto-select lagi)
  void resetPrinterSelection() {
    _selectedPrinter = null;
    debugPrint('🔄 Printer selection reset');
  }

  /// Get current selected printer info
  String? get selectedPrinterName => _selectedPrinter?.name;
  bool get hasPrinterSelected => _selectedPrinter != null;

  // =============== INTERNALS ===============

  Future<void> _patchAfterPrint(Uri url) async {
    try {
      final client = httpClient ?? http.Client();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (getAuthHeader != null) headers.addAll(getAuthHeader!());
      final resp = await client
          .patch(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ PATCH after print: ${resp.statusCode} ${url.path}');
    } catch (e) {
      debugPrint('⚠️ PATCH after print failed (ignored): $e');
    }
  }

  String _inferName(String reportName, Map<String, String> query) {
    final keysPref = const [
      'NoBroker',
      'NoWashing',
      'NoProduksi',
      'NoTrans',
      'Nomor',
      'NoBJ',
    ];
    final key = keysPref.firstWhere(
      (k) => query[k]?.isNotEmpty == true,
      orElse: () => '',
    );
    final val = key.isEmpty ? '' : query[key]!;
    final safe = val.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    return '${reportName}_${safe.isEmpty ? DateTime.now().millisecondsSinceEpoch : safe}.pdf';
  }

  Future<_HttpBytes> _download(Uri url) async {
    final client = httpClient ?? http.Client();
    final headers = <String, String>{};
    if (getAuthHeader != null) headers.addAll(getAuthHeader!());

    final resp = await client
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw Exception('HTTP ${resp.statusCode} — tidak ada data.');
    }
    return _HttpBytes(resp, resp.bodyBytes);
  }

  /// Unduh satu PDF label pakai Bearer token (dipakai jalur cetak multi-label,
  /// yang perlu bytes tiap label untuk dikirim ke [LabelPrinter]).
  Future<Uint8List> _fetchPdfBytes(Uri url) async {
    final token = await TokenStorage.getToken();
    final client = httpClient ?? http.Client();
    final resp = await client
        .get(
          url,
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw Exception('HTTP ${resp.statusCode} — tidak ada data PDF.');
    }
    return resp.bodyBytes;
  }

  Future<void> _saveOriginalTemp(Uint8List src, String filename) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$filename');
    await f.writeAsBytes(src, flush: true);
  }

  String _filenameFromHeaders(http.Response resp, String fallback) {
    final cd = resp.headers['content-disposition'] ?? '';
    final m = RegExp(
      r'filename\*?=([^;]+)',
      caseSensitive: false,
    ).firstMatch(cd);
    if (m != null) {
      var v = m.group(1)!.trim();
      v = v.replaceAll(RegExp(r"^UTF-8''"), '');
      v = v.replaceAll('"', '');
      return Uri.decodeFull(v);
    }
    return fallback;
  }

  Future<Uint8List> _remapPdfTo80mm(Uint8List srcBytes) async {
    final doc = pw.Document();
    final pageWidthPt = 80 * PdfPageFormat.mm;
    final rasters = Printing.raster(srcBytes, dpi: 300);

    await for (final r in rasters) {
      final pageHeightPt = pageWidthPt * (r.height / r.width);
      final png = await r.toPng();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidthPt, pageHeightPt),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return doc.save();
  }

  /// Gabungkan beberapa PDF menjadi satu dokumen multi-halaman untuk preview.
  /// Tiap halaman dirasterisasi lalu ditempel pada halaman berukuran sama persis
  /// dengan resolusi rasternya (tanpa paksa 80mm / tanpa rescale) supaya preview
  /// tetap tajam untuk ukuran label apa pun.
  Future<Uint8List> _mergePdfs(List<Uint8List> pdfs) async {
    if (pdfs.length == 1) return pdfs.first;
    final doc = pw.Document();
    const dpi = 300.0;
    for (final pdfBytes in pdfs) {
      await for (final r in Printing.raster(pdfBytes, dpi: dpi)) {
        final png = await r.toPng();
        final wPt = r.width / dpi * 72.0;
        final hPt = r.height / dpi * 72.0;
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(wPt, hPt),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(
              pw.MemoryImage(png),
              fit: pw.BoxFit.fill,
            ),
          ),
        );
      }
    }
    return doc.save();
  }

  Future<void> _openNativePrintPreview({
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    await Printing.layoutPdf(
      name: fileName,
      format: PdfPageFormat(80 * PdfPageFormat.mm, 200 * PdfPageFormat.mm),
      usePrinterSettings: true,
      onLayout: (_) async => pdfBytes,
    );
  }

  // ==== Loading helpers =====================================
  Future<T> _withLoading<T>({
    required BuildContext context,
    required Future<T> Function() run,
    bool enabled = true,
    String message = 'Memproses...',
  }) async {
    if (!enabled) return await run();

    final nav = Navigator.of(context, rootNavigator: true);
    bool shown = false;

    try {
      shown = true;
      // ignore: unawaited_futures
      showDialog(
        context: nav.context,
        barrierDismissible: false,
        builder: (_) => LoadingDialog(message: message),
      );

      final result = await run();
      return result;
    } catch (e) {
      _showSnack(context, e.toString());
      rethrow;
    } finally {
      if (shown && nav.canPop()) {
        nav.pop();
      }
    }
  }

  void _showSnack(BuildContext ctx, String msg) {
    final m = ScaffoldMessenger.maybeOf(ctx);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showPrintingSnack(BuildContext ctx, String printerName) {
    final m = ScaffoldMessenger.maybeOf(ctx);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 30),
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mencetak Label…',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Mengirim ke $printerName',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      height: 1.3,
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

  void _showPrintErrorSnack(BuildContext ctx, String message) {
    final m = ScaffoldMessenger.maybeOf(ctx);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF7F1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.print_disabled_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cetak Gagal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrintSuccessSnack(BuildContext ctx, String printerName) {
    final m = ScaffoldMessenger.maybeOf(ctx);
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF166534),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Label Berhasil Dicetak',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Dicetak ke $printerName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.3,
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
}

class _HttpBytes {
  _HttpBytes(this.response, this.body);
  final http.Response response;
  final Uint8List body;
}
