// lib/features/production/shared/widgets/production_scan_label_dialog.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/production_formula_model.dart';

const _kBorder = Color(0xFFE2E6EA);
const _kSurface = Color(0xFFF8F9FB);

/// Dialog scan / input label generik untuk semua modul produksi.
///
/// [primaryColor] — warna aksen modul (header, indikator, dll).
/// [formulaOutputs] — jika non-empty, panel kiri "Material Diterima" ditampilkan.
/// [onLookup] — dipanggil dengan kode yang di-scan / diketik.
///   Kembalikan `null` jika sukses (dialog otomatis tertutup), atau string error
///   untuk ditampilkan inline.
class ProductionScanLabelDialog extends StatefulWidget {
  final Future<String?> Function(String code) onLookup;
  final String manualHint;
  final String? headerSubtitle;
  final Color primaryColor;
  final List<ProductionFormulaOutput> formulaOutputs;

  /// Kontrol tambahan di header (mis. tombol pilih mode FULL / PARTIAL).
  /// Kalau null, header hanya menampilkan judul + subtitle.
  final Widget? headerAction;

  const ProductionScanLabelDialog({
    super.key,
    required this.onLookup,
    required this.manualHint,
    this.headerSubtitle,
    this.primaryColor = const Color(0xFF1E6FD9),
    this.formulaOutputs = const [],
    this.headerAction,
  });

  @override
  State<ProductionScanLabelDialog> createState() =>
      _ProductionScanLabelDialogState();
}

class _ProductionScanLabelDialogState extends State<ProductionScanLabelDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabCtl;

  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final MobileScannerController _scannerCtl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );

  Color? _flashColor;
  String? _scanError;
  String? _lookupError;
  bool _isProcessingScan = false;
  bool _isLookingUp = false;
  int _cameraQuarterTurns = 3;

  bool get _hasFormula => widget.formulaOutputs.isNotEmpty;
  Color get _primary => widget.primaryColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabCtl = TabController(length: 2, vsync: this);
    _tabCtl.addListener(() {
      if (_tabCtl.indexIsChanging) return;
      setState(() {});
      if (_tabCtl.index == 0) {
        _scannerCtl.start();
      } else {
        _scannerCtl.stop();
        _focus.requestFocus();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateRotation());
  }

  @override
  void didChangeMetrics() => _updateRotation();

  void _updateRotation() {
    if (!mounted) return;
    final size = View.of(context).physicalSize;
    if (size.height > size.width && _cameraQuarterTurns != 0) {
      setState(() => _cameraQuarterTurns = 0);
      if (_tabCtl.index == 0) {
        _scannerCtl.stop();
        _scannerCtl.start();
      }
    }
  }

  void _toggleCameraRotation() {
    setState(() => _cameraQuarterTurns = _cameraQuarterTurns == 1 ? 3 : 1);
    if (_tabCtl.index == 0) {
      _scannerCtl.stop();
      _scannerCtl.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabCtl.dispose();
    _ctl.dispose();
    _focus.dispose();
    _scannerCtl.dispose();
    super.dispose();
  }

  Future<void> _addManual() async {
    final code = _ctl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });
    final error = await widget.onLookup(code);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isLookingUp = false;
        _lookupError = error;
      });
    }
  }

  Future<void> _onScanDetect(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessingScan = true;
      _scanError = null;
    });

    final error = await widget.onLookup(code);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _flashColor = Colors.red;
        _scanError = error;
        _isProcessingScan = false;
      });
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        setState(() {
          _flashColor = null;
          _scanError = null;
        });
      }
    }
  }

  double _keyboardInset = 0;

  @override
  Widget build(BuildContext context) {
    _keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _hasFormula ? 780 : 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasFormula) _buildFormulaPanel(),
                    Expanded(child: _buildMainPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Scan / Input Label',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (widget.headerSubtitle != null) ...[
            Text(
              widget.headerSubtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.headerAction != null) ...[
            widget.headerAction!,
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Left panel: formula ────────────────────────────────────────────────────

  Widget _buildFormulaPanel() {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _kBorder)),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 13,
                  color: _primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  'Jenis Yang Diterima',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary.withValues(alpha: 0.75),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _kBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildFlattenedKategoriBlocks(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFlattenedKategoriBlocks() {
    final grouped = <String, List<ProductionFormulaItem>>{};
    final seenInputIds = <int>{};
    for (final output in widget.formulaOutputs) {
      for (final f in output.formulas) {
        if (seenInputIds.contains(f.inputId)) continue;
        seenInputIds.add(f.inputId);
        grouped.putIfAbsent(f.kategoriNama, () => []).add(f);
      }
    }
    final entries = grouped.entries.toList();
    return [
      for (var i = 0; i < entries.length; i++) ...[
        _buildKategoriBlock(entries[i].key, entries[i].value),
        if (i < entries.length - 1) ...[
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: _kBorder),
          const SizedBox(height: 10),
        ],
      ],
    ];
  }

  Widget _buildKategoriBlock(
    String kategori,
    List<ProductionFormulaItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kategori.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: _primary.withValues(alpha: 0.55),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _primary.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            f.inputNama,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF374151),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  // ── Right panel ────────────────────────────────────────────────────────────

  Widget _buildMainPanel() {
    final borderRadius = _hasFormula
        ? const BorderRadius.only(bottomRight: Radius.circular(16))
        : const BorderRadius.vertical(bottom: Radius.circular(16));

    return ClipRRect(
      borderRadius: borderRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtl,
              indicatorColor: _primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: _kBorder,
              labelColor: _primary,
              unselectedLabelColor: const Color(0xFF9CA3AF),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.camera_alt_outlined, size: 16),
                  text: 'Scan Kamera',
                  iconMargin: EdgeInsets.only(bottom: 3),
                  height: 50,
                ),
                Tab(
                  icon: Icon(Icons.keyboard_outlined, size: 16),
                  text: 'Input Manual',
                  iconMargin: EdgeInsets.only(bottom: 3),
                  height: 50,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 400,
            child: IndexedStack(
              index: _tabCtl.index,
              children: [_buildCameraTab(), _buildManualTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Camera tab ─────────────────────────────────────────────────────────────

  Widget _buildCameraTab() {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: _hasFormula ? Radius.zero : const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
            child: RotatedBox(
              quarterTurns: _cameraQuarterTurns,
              child: MobileScanner(
                controller: _scannerCtl,
                onDetect: _onScanDetect,
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _ScanFramePainter())),
        Positioned.fill(
          child: Center(
            child: Lottie.asset(
              'assets/animations/scanner.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
          ),
        ),
        if (_flashColor != null)
          Positioned.fill(
            child: ColoredBox(color: _flashColor!.withValues(alpha: 0.2)),
          ),
        if (_isProcessingScan)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        if (_scanError != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _scanError!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: _toggleCameraRotation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.screen_rotation_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Manual tab ─────────────────────────────────────────────────────────────

  Widget _buildManualTab() {
    return SingleChildScrollView(
      reverse: true,
      padding: EdgeInsets.fromLTRB(20, 20, 20, _keyboardInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctl,
            focusNode: _focus,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Kode Label',
              hintText: widget.manualHint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
              ),
              errorText: _lookupError,
              errorStyle: const TextStyle(fontSize: 11),
              errorMaxLines: 2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.shade400),
              ),
              filled: true,
              fillColor: _kSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: _ctl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() => _ctl.clear()),
                    )
                  : null,
            ),
            onSubmitted: (_) => _addManual(),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: Material(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _isLookingUp ? null : _addManual,
                borderRadius: BorderRadius.circular(10),
                child: Center(
                  child: _isLookingUp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Tambah Label',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan frame painter ──────────────────────────────────────────────────────

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 28.0;
    const r = 9.0;
    const strokeW = 3.5;

    final boxSize = size.shortestSide * 0.65;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - boxSize / 2;
    final top = cy - boxSize / 2;
    final right = cx + boxSize / 2;
    final bottom = cy + boxSize / 2;

    final dimPaint = Paint()..color = const Color(0x66000000);
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(r + 2),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, dimPaint);

    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(left, top, r * 2, r * 2),
      math.pi,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(
      Offset(left + r, top),
      Offset(left + r + cornerLen, top),
      p,
    );
    canvas.drawLine(
      Offset(left, top + r),
      Offset(left, top + r + cornerLen),
      p,
    );

    canvas.drawArc(
      Rect.fromLTWH(right - r * 2, top, r * 2, r * 2),
      3 * math.pi / 2,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(
      Offset(right - r, top),
      Offset(right - r - cornerLen, top),
      p,
    );
    canvas.drawLine(
      Offset(right, top + r),
      Offset(right, top + r + cornerLen),
      p,
    );

    canvas.drawArc(
      Rect.fromLTWH(left, bottom - r * 2, r * 2, r * 2),
      math.pi / 2,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(
      Offset(left, bottom - r),
      Offset(left, bottom - r - cornerLen),
      p,
    );
    canvas.drawLine(
      Offset(left + r, bottom),
      Offset(left + r + cornerLen, bottom),
      p,
    );

    canvas.drawArc(
      Rect.fromLTWH(right - r * 2, bottom - r * 2, r * 2, r * 2),
      0,
      math.pi / 2,
      false,
      p,
    );
    canvas.drawLine(
      Offset(right, bottom - r),
      Offset(right, bottom - r - cornerLen),
      p,
    );
    canvas.drawLine(
      Offset(right - r, bottom),
      Offset(right - r - cornerLen, bottom),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
