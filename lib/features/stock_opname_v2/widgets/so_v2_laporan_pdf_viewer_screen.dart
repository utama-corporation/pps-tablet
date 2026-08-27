import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

/// Preview laporan PDF stock opname v2 — mengikuti pola UI
/// [ReportPdfViewerScreen] (menu Laporan): preview gelap + panel
/// kiri/bawah berisi tombol Cetak. Tidak ada panel parameter tanggal
/// karena laporan ini di-scope per stockOpnameNo, bukan rentang tanggal.
///
/// Preview memakai `pdfx` (native PDF renderer via pdfium), bukan
/// `printing`-nya `PdfPreview`. `PdfPreview` merasterisasi SEMUA halaman
/// di depan lewat platform channel untuk membangun cache-nya, jadi untuk
/// laporan dengan ribuan halaman (mis. daftar label belum-scan yang
/// panjang) totalnya menumpuk di memori dan bikin OutOfMemoryError/force
/// close di tablet. `pdfx` merender per-halaman on-demand cuma untuk
/// halaman yang sedang/nyaris terlihat (mirip PDF viewer native), jadi
/// pemakaian memori tidak bertumbuh sebanding jumlah halaman. Cetak tetap
/// pakai `Printing.layoutPdf` — itu diproses oleh print service Android,
/// bukan dirender sebagai widget di app ini.
class SoV2LaporanPdfViewerScreen extends StatefulWidget {
  final String title;
  final Uint8List pdfBytes;

  const SoV2LaporanPdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfBytes,
  });

  static Future<void> push({
    required BuildContext context,
    required String title,
    required Uint8List pdfBytes,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            SoV2LaporanPdfViewerScreen(title: title, pdfBytes: pdfBytes),
      ),
    );
  }

  @override
  State<SoV2LaporanPdfViewerScreen> createState() =>
      _SoV2LaporanPdfViewerScreenState();
}

class _SoV2LaporanPdfViewerScreenState
    extends State<SoV2LaporanPdfViewerScreen> {
  static const _kDark = Color(0xFF0F172A);
  static const _kNavy = Color(0xFF1E293B);
  static const _kBlue = Color(0xFF0D47A1);
  static const _kSurface = Color(0xFFF8FAFC);
  static const _panelW = 300.0;

  late final PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openData(widget.pdfBytes),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _print() async {
    await Printing.layoutPdf(
      onLayout: (_) async => widget.pdfBytes,
      name: widget.title,
    );
  }

  // ── Root build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          return isLandscape
              ? _buildLandscape(context)
              : _buildPortrait(context);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LANDSCAPE — PDF kiri, panel kanan
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLandscape(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildPreview(context, isLandscape: true)),
        SizedBox(
          width: _panelW,
          child: _buildPanel(context, isLandscape: true),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PORTRAIT — PDF atas, panel bawah
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPortrait(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildPreview(context, isLandscape: false)),
        _buildPanel(context, isLandscape: false),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PDF PREVIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPreview(BuildContext context, {required bool isLandscape}) {
    return Stack(
      children: [
        PdfViewPinch(
          controller: _pdfController,
          scrollDirection: Axis.vertical,
          backgroundDecoration: const BoxDecoration(color: _kDark),
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            pageLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (_, error) => Center(
              child: Text(
                'Gagal memuat PDF: $error',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),

        // Top bar dengan close + judul
        Positioned(
          top: 0,
          left: 0,
          right: isLandscape ? null : 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              4,
              MediaQuery.of(context).padding.top,
              16,
              8,
            ),
            decoration: isLandscape
                ? null
                : BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _kDark.withValues(alpha: 0.95),
                        Colors.transparent,
                      ],
                    ),
                  ),
            child: Row(
              mainAxisSize: isLandscape ? MainAxisSize.min : MainAxisSize.max,
              children: [
                _CloseBtn(onPressed: () => Navigator.of(context).pop()),
                if (!isLandscape) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Title badge (landscape)
        if (isLandscape)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    size: 13,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PANEL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPanel(BuildContext context, {required bool isLandscape}) {
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget content = Column(
      mainAxisSize: isLandscape ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLandscape) _buildPanelHeader(context),
        if (isLandscape) const Spacer(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            isLandscape ? 18 : 16,
            isLandscape ? 0 : 14,
            isLandscape ? 18 : 16,
            (isLandscape ? 18 : 16) + bottom,
          ),
          child: _buildActions(),
        ),
      ],
    );

    if (isLandscape) {
      return Container(
        decoration: BoxDecoration(
          color: _kSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(-6, 0),
            ),
          ],
        ),
        child: content,
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 2),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            content,
          ],
        ),
      );
    }
  }

  Widget _buildPanelHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 14,
        18,
        14,
      ),
      decoration: const BoxDecoration(
        color: _kNavy,
        border: Border(bottom: BorderSide(color: Color(0xFF2D3F55))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Laporan Stock Opname',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _print,
        icon: const Icon(Icons.print_rounded, size: 18),
        label: const Text('Cetak'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          elevation: 2,
          shadowColor: _kBlue.withValues(alpha: 0.4),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Close Button ──────────────────────────────────────────────────────────────

class _CloseBtn extends StatelessWidget {
  final VoidCallback onPressed;
  const _CloseBtn({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
      ),
      tooltip: 'Tutup',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
