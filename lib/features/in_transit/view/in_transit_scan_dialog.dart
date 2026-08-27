import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/goods_transfer/model/goods_transfer_item_model.dart';

import '../repository/in_transit_repository.dart';
import '../view_model/in_transit_list_view_model.dart';

const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFE2E6EA);

/// Dialog scan untuk menerima label 1 Goods Transfer tertentu.
///
/// Panel kiri menampilkan checklist semua label milik [noTransfer] dan
/// tercentang otomatis begitu berhasil discan. Label yang bukan bagian dari
/// transfer ini akan ditolak tanpa perlu memanggil API.
class InTransitScanDialog extends StatefulWidget {
  final String noTransfer;
  final String blok;
  final int idLokasi;

  const InTransitScanDialog({
    super.key,
    required this.noTransfer,
    required this.blok,
    required this.idLokasi,
  });

  @override
  State<InTransitScanDialog> createState() => _InTransitScanDialogState();
}

class _InTransitScanDialogState extends State<InTransitScanDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabCtl;

  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final MobileScannerController _scannerCtl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );
  final InTransitRepository _repository = InTransitRepository(
    api: ApiClient(),
  );

  Color? _flashColor;
  String? _scanError;
  String? _lookupError;
  bool _isProcessingScan = false;
  bool _isLookingUp = false;
  int _cameraQuarterTurns = 3;

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabCtl.dispose();
    _ctl.dispose();
    _focus.dispose();
    _scannerCtl.dispose();
    super.dispose();
  }

  /// Validasi label termasuk item transfer ini dulu (tanpa panggil API) baru
  /// panggil accept-scan kalau valid.
  Future<String?> _process(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return null;

    final vm = context.read<InTransitListViewModel>();
    final items = vm.selectedDetail?.items ?? [];
    GoodsTransferItem? match;
    for (final it in items) {
      if (it.labelCode == code) {
        match = it;
        break;
      }
    }

    if (match == null) {
      return 'Label $code bukan bagian dari transfer ${widget.noTransfer}';
    }
    if (match.statusItem == 'RECEIVED') {
      return 'Label $code sudah diterima sebelumnya';
    }

    try {
      await _repository.acceptScan(
        labelCode: code,
        blokTujuan: widget.blok,
        idLokasiTujuan: widget.idLokasi,
      );
      await vm.selectTransfer(widget.noTransfer);
      return null;
    } on ApiException catch (e) {
      return e.friendlyMessage;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _addManual() async {
    final code = _ctl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });
    final error = await _process(code);
    if (!mounted) return;
    setState(() {
      _isLookingUp = false;
      _lookupError = error;
      if (error == null) _ctl.clear();
    });
  }

  Future<void> _onScanDetect(BarcodeCapture capture) async {
    if (_isProcessingScan) return;
    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    setState(() {
      _isProcessingScan = true;
      _scanError = null;
    });

    final error = await _process(code);
    if (!mounted) return;

    setState(() {
      _isProcessingScan = false;
      _flashColor = error == null ? Colors.green : Colors.red;
      _scanError = error;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _flashColor = null;
        _scanError = null;
      });
    }
  }

  double _keyboardInset = 0;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InTransitListViewModel>();
    final items = vm.selectedDetail?.items ?? [];
    final receivedCount = items
        .where((it) => it.statusItem == 'RECEIVED')
        .length;

    _keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(receivedCount, items.length),
              // Pakai Expanded (bukan IntrinsicHeight) supaya panel kiri boleh
              // berisi ListView — IntrinsicHeight tidak bisa menghitung tinggi
              // untuk widget scrollable seperti ListView dan akan melempar
              // FlutterError saat build.
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildChecklistPanel(items),
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

  // ── Blue header ────────────────────────────────────────────────────────

  Widget _buildHeader(int received, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
          Text(
            'Scan Terima — ${widget.noTransfer}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '$received/$total diterima',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
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

  // ── Left panel: checklist label transfer ini ─────────────────────────────

  Widget _buildChecklistPanel(List<GoodsTransferItem> items) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        border: Border(right: BorderSide(color: _kBorder)),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 13,
                color: _kPrimary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 5),
              Text(
                'Label di Transfer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary.withValues(alpha: 0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada label',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final received = it.statusItem == 'RECEIVED';
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            received
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 15,
                            color: received
                                ? Colors.green
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              it.labelCode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: received
                                    ? const Color(0xFF1A1D23)
                                    : Colors.grey.shade600,
                                decoration: received
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Right panel: TabBar + camera/manual content ────────────────────────

  Widget _buildMainPanel() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: _kPrimary,
            child: TabBar(
              controller: _tabCtl,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.camera_alt_outlined, size: 18),
                  text: 'Scan Kamera',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.keyboard_outlined, size: 18),
                  text: 'Input Manual',
                  iconMargin: EdgeInsets.only(bottom: 4),
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

  Widget _buildCameraTab() {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(16),
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
            onTap: () {
              setState(
                () => _cameraQuarterTurns = _cameraQuarterTurns == 1 ? 3 : 1,
              );
              _scannerCtl.stop();
              _scannerCtl.start();
            },
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
              hintText: 'A.0000000001',
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
                borderSide: const BorderSide(color: _kPrimary, width: 1.5),
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
              color: _kPrimary,
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
                              'Tandai Diterima',
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
