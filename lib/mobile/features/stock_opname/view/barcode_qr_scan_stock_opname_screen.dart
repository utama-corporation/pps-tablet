import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:pps_tablet/core/network/network_mode_config.dart';
import '../view_model/stock_opname_scan_view_model.dart';
import '../view_model/stock_opname_detail_view_model.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../model/label_validation_result.dart';
import '../widget/confirmation_label_stock_opname_dialog.dart';
import '../widget/input_detail_label_stock_opname_dialog.dart';
import '../../login/view/widgets/network_mode_bottom_sheet.dart';
import '../../../widgets/scan_notification.dart';
import '../../../widgets/status_indicator.dart';

class BarcodeQrScanStockOpnameScreen extends StatefulWidget {
  final String noSO;
  final String selectedFilter;
  final int idLokasi;
  final String? blok;

  const BarcodeQrScanStockOpnameScreen({
    Key? key,
    required this.noSO,
    required this.selectedFilter,
    required this.idLokasi,
    required this.blok,
  }) : super(key: key);

  @override
  _BarcodeQrScanStockOpnameScreenState createState() =>
      _BarcodeQrScanStockOpnameScreenState();
}

class _BarcodeQrScanStockOpnameScreenState
    extends State<BarcodeQrScanStockOpnameScreen>
    with SingleTickerProviderStateMixin {
  // ✅ Controller dengan konfigurasi optimal untuk QR Code
  late final MobileScannerController cameraController;

  bool isFlashOn = false;
  bool hasCameraPermission = false;
  late AnimationController _animationController;
  bool _isDetected = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isSaving = false;
  bool _isValidatingServer = false;
  String _saveMessage = '';
  String _detailedMessage = '';
  bool _isSuccess = false;
  bool _showStatusIndicator = false;
  NetworkMode _selectedNetworkMode = NetworkModeConfig.currentMode;

  Timer? _debounceTimer;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _selectedNetworkMode = NetworkModeConfig.currentMode;

    // ✅ Konfigurasi controller untuk scan cepat QR Code
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,

      // ⚡ KUNCI KECEPATAN - deteksi tanpa pembatasan
      detectionSpeed: DetectionSpeed.unrestricted,

      // ⚡ Timeout minimal untuk responsif maksimal
      detectionTimeoutMs: 100,

      // ⚡ Tidak perlu image, hemat resource
      returnImage: false,

      // 🎯 FILTER HANYA QR CODE - skip barcode lain
      formats: [BarcodeFormat.qrCode],
    );

    _getCameraPermission();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _showConfirmBottomSheet(
    String label,
    LabelValidationResult result,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConfirmationLabelStockOpnameSheet(
          label: label,
          result: result,
          onConfirm: () async {
            Navigator.of(ctx).pop();
            await _saveLabel(
              label,
              result.jmlhSak ?? 0,
              result.berat ?? 0,
              result.idDiscrepancy,
            );
          },
          onManualInput: () async {
            Navigator.of(ctx).pop();
            await _showManualInputSheet(label, result.idDiscrepancy);
          },
        );
      },
    );
  }

  Future<void> _showManualInputSheet(String label, int? idDiscrepancy) async {
    await showInputLabelStockOpnameBottomSheet(
      context: context,
      label: label,
      onSave: (jmlhSak, berat) async {
        await _saveLabel(label, jmlhSak, berat, idDiscrepancy);
      },
    );
  }

  Future<void> _saveLabel(
    String label,
    int jmlhSak,
    double berat,
    int? idDiscrepancy,
  ) async {
    setState(() {
      _isSaving = true;
      _saveMessage = 'Menyimpan data...';
      _detailedMessage = '';
      _isSuccess = false;
      _showStatusIndicator = false;
    });

    try {
      final scanVM = context.read<StockOpnameScanViewModel>();
      final success = await scanVM.insertLabel(
        label: label,
        noSO: widget.noSO,
        jmlhSak: jmlhSak,
        berat: berat,
        blok: widget.blok ?? '',
        idLokasi: widget.idLokasi,
        idDiscrepancy: idDiscrepancy, // ⬅️ PAKAI PARAMETER
      );

      if (success) {
        _audioPlayer.play(AssetSource('sounds/accepted.mp3'));

        await context.read<StockOpnameDetailViewModel>().fetchInitialData(
          widget.noSO,
          filterBy: widget.selectedFilter,
          idLokasi: widget.idLokasi,
        );

        _showSuccessStatus(
          'Data Berhasil Disimpan! 🎉',
          'Label: $label\nJumlah: $jmlhSak sak\nBerat: ${berat.toStringAsFixed(2)} kg',
        );
      } else {
        _audioPlayer.play(AssetSource('sounds/denied.mp3'));
        _showErrorStatus(
          'Gagal Menyimpan Data',
          'Label: $label\nSilakan coba lagi',
        );
      }
    } catch (e) {
      _audioPlayer.play(AssetSource('sounds/denied.mp3'));
      _showErrorStatus('Terjadi Kesalahan', 'Error: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSuccessStatus(String title, String message) {
    setState(() {
      _saveMessage = title;
      _detailedMessage = message;
      _isSuccess = true;
      _showStatusIndicator = true;
    });
    Vibration.vibrate(duration: 100, amplitude: 128);
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _saveMessage = '';
        _detailedMessage = '';
        _lastScannedCode = null;
        _showStatusIndicator = false;
      });
    });
  }

  void _showErrorStatus(String title, String message) {
    setState(() {
      _saveMessage = title;
      _detailedMessage = message;
      _isSuccess = false;
      _showStatusIndicator = true;
    });
    Vibration.vibrate(pattern: [0, 200, 100, 200]);
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _saveMessage = '';
        _detailedMessage = '';
        _lastScannedCode = null;
        _showStatusIndicator = false;
      });
    });
  }

  void _dismissNotification() {
    setState(() {
      _saveMessage = '';
      _detailedMessage = '';
      _lastScannedCode = null;
      _showStatusIndicator = false;
    });
  }

  void _retryLastScan() {
    if (_lastScannedCode != null) {
      _processScanResult(_lastScannedCode!);
    }
  }

  Future<void> _onNetworkModeChanged(NetworkMode mode) async {
    if (mode == _selectedNetworkMode) return;
    setState(() {
      _selectedNetworkMode = mode;
    });

    await NetworkModeConfig.setMode(mode);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mode jaringan: ${NetworkModeConfig.currentModeLabel}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showNetworkModeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => NetworkModeBottomSheet(
        selectedMode: _selectedNetworkMode,
        isSelectionLocked: _isSaving || _isValidatingServer,
        onSelectMode: _onNetworkModeChanged,
      ),
    );
  }

  Future<void> _getCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => hasCameraPermission = status == PermissionStatus.granted);

    if (status == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izin kamera diperlukan untuk scanning'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Buka Pengaturan',
            textColor: Colors.white,
            onPressed: openAppSettings,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _processScanResult(String rawValue) async {
    // ⚡ Anti-duplikasi scan beruntun
    if (rawValue == _lastScannedCode) {
      debugPrint('🔄 Duplicate scan ignored: $rawValue');
      return;
    }
    _lastScannedCode = rawValue;

    setState(() {
      _isSaving = true;
      _isValidatingServer = true;
      // Tampilkan jelas: scan sukses, sekarang tunggu API.
      _saveMessage = 'QR berhasil dibaca';
      _detailedMessage = 'Menghubungi server untuk validasi label...';
      _isSuccess = true;
      _showStatusIndicator = false;
    });

    try {
      final scanVM = context.read<StockOpnameScanViewModel>();
      final result = await scanVM.validateLabel(
        rawValue,
        widget.blok!,
        widget.idLokasi,
        widget.noSO,
      );

      setState(() {
        _isSaving = false;
        _isValidatingServer = false;
      });

      // 🔴 VALIDASI GAGAL / RESPONSE ANEH
      if (result == null) {
        _audioPlayer.play(AssetSource('sounds/denied.mp3'));
        _showErrorStatus(
          'Validasi Gagal',
          'Label tidak dapat divalidasi\nLabel: $rawValue',
        );
        return;
      }

      // karena di model labelType non-nullable (String), cek empty saja:
      if (result.labelType.isEmpty) {
        _audioPlayer.play(AssetSource('sounds/denied.mp3'));
        _showErrorStatus(
          'Label Tidak Dikenali',
          result.message.isNotEmpty
              ? result.message
              : 'Tipe label tidak diketahui',
        );
        return;
      }

      // 🔴 Duplikat
      if (result.isDuplicate) {
        _audioPlayer.play(AssetSource('sounds/denied.mp3'));
        _showErrorStatus('Label Duplikat!', result.message);
        return;
      }

      // 🔴 Contoh rule khusus kamu sebelumnya
      if (!result.isValidCategory && result.foundInStockOpname) {
        _audioPlayer.play(AssetSource('sounds/denied.mp3'));
        _showErrorStatus('Kategori Tidak Sesuai', result.message);
        return;
      }

      // 🟢 success == true → AUTO INSERT, TANPA DIALOG
      if (result.success) {
        await _saveLabel(
          result.label,
          result.jmlhSak ?? 0,
          result.berat ?? 0.0,
          result.idDiscrepancy,
        );
        return; // ⬅️ penting, jangan lanjut ke bottom sheet
      }

      // 🟡 success == false → TAMPILKAN DIALOG KONFIRMASI
      await _showConfirmBottomSheet(rawValue, result);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _isValidatingServer = false;
      });
      _audioPlayer.play(AssetSource('sounds/denied.mp3'));
      _showErrorStatus(
        'Koneksi Bermasalah 📱',
        'Periksa koneksi internet Anda',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    // Area scan dibuat lebih besar agar kamera tidak perlu terlalu presisi.
    final scanAreaSize = (screen.width * 0.82).clamp(260.0, screen.width - 28);
    final count = context.read<StockOpnameDetailViewModel>().totalData;

    final lokasiTitle = widget.blok == null || widget.blok!.isEmpty
        ? 'Lokasi ${widget.idLokasi}'
        : 'Lokasi ${widget.blok}${widget.idLokasi}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '$lokasiTitle ($count)',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black),
            onPressed: (_isSaving || _isValidatingServer)
                ? null
                : _showNetworkModeSheet,
          ),
          IconButton(
            icon: Icon(
              isFlashOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.black,
            ),
            onPressed: () async {
              try {
                await cameraController.toggleTorch();
                setState(() => isFlashOn = !isFlashOn);
              } catch (e) {
                debugPrint('Error toggling torch: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Flash tidak tersedia pada perangkat ini'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ✅ Camera dengan controller yang sudah dikonfigurasi
          if (hasCameraPermission)
            MobileScanner(
              controller:
                  cameraController, // ⭐ Gunakan controller yang sudah optimal
              scanWindow: Rect.fromCenter(
                center: Offset(screen.width / 2, screen.height / 2),
                width: scanAreaSize,
                height: scanAreaSize,
              ),
              onDetect: (capture) {
                try {
                  // Saat API sedang diproses, abaikan deteksi baru.
                  if (_isSaving) return;

                  final codes = capture.barcodes;

                  // ⚡ Filter cepat - ambil QR pertama
                  if (codes.isEmpty) return;

                  // Semua label sekarang QR code, jadi baca QR saja.
                  final qrCode = codes.firstWhere(
                    (b) =>
                        b.rawValue != null &&
                        b.rawValue!.isNotEmpty &&
                        b.format == BarcodeFormat.qrCode,
                    orElse: () => Barcode(rawValue: null),
                  );

                  if (qrCode.rawValue == null) return;
                  final raw = qrCode.rawValue!;

                  // ⚡ Debounce ultra-pendek untuk responsif
                  if (!_isDetected) {
                    setState(() => _isDetected = true);
                    _animationController.forward(from: 0);

                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 200),
                      () {
                        if (!mounted) return;
                        setState(() => _isDetected = false);
                        _processScanResult(raw);
                      },
                    );
                  }
                } catch (e) {
                  debugPrint('❌ Error during QR detection: $e');
                  _showErrorStatus(
                    'Error Scan 📱',
                    'Terjadi kesalahan saat memproses QR code',
                  );
                }
              },
            )
          else
            _NoPermission(onRequest: _getCameraPermission),

          if (_isValidatingServer)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Memvalidasi ke server...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Frame scan area
          Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: scanAreaSize,
              height: scanAreaSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDetected
                      ? Colors.greenAccent
                      : Colors.white.withOpacity(0.5),
                  width: 3,
                ),
                boxShadow: _isDetected
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: _isDetected
                  ? Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: Colors.greenAccent.withOpacity(0.1),
                      ),
                    )
                  : null,
            ),
          ),

          // Status indicator
          if (_showStatusIndicator)
            Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: StatusIndicator(
                  isSuccess: _isSuccess,
                  isVisible: _showStatusIndicator,
                ),
              ),
            ),

          // Notification
          if (_saveMessage.isNotEmpty)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: ScanNotification(
                title: _saveMessage,
                message: _detailedMessage,
                isSuccess: _isSuccess,
                isLoading: _isSaving,
                onDismiss: _dismissNotification,
                onRetry: !_isSuccess && !_isSaving ? _retryLastScan : null,
              ),
            ),

          // Hint
          if (_saveMessage.isEmpty && !_isSaving)
            const Positioned(bottom: 50, left: 0, right: 0, child: _ScanHint()),
        ],
      ),
    );
  }
}

class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.onRequest});
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Izin kamera diperlukan untuk scanning',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Berikan Izin Kamera',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Arahkan kamera ke QR code',
          style: TextStyle(color: Colors.white, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
