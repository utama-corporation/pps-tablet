// lib/features/label/view/barcode_qr_scan_mapping_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../repository/label_mapping_repository.dart';
import '../../../widgets/scan_notification.dart';
import '../../../widgets/status_indicator.dart';
import '../../../utils/permission_helper.dart';

class BarcodeQrScanMappingScreen extends StatefulWidget {
  final String selectedFilter;
  final String idLokasi;
  final String? blok;

  const BarcodeQrScanMappingScreen({
    Key? key,
    required this.selectedFilter,
    required this.idLokasi,
    required this.blok,
  }) : super(key: key);

  @override
  _BarcodeQrScanMappingScreenState createState() =>
      _BarcodeQrScanMappingScreenState();
}

class _BarcodeQrScanMappingScreenState extends State<BarcodeQrScanMappingScreen>
    with SingleTickerProviderStateMixin {

  // ✅ Controller dengan konfigurasi lengkap
  late final MobileScannerController cameraController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final _mappingRepo = LabelMappingRepository();

  bool isFlashOn = false;
  bool hasCameraPermission = false;
  late AnimationController _animationController;
  bool _isDetected = false;

  bool _isSaving = false;
  String _saveMessage = '';
  String _detailedMessage = '';
  bool _isSuccess = false;
  bool _showStatusIndicator = false;

  Timer? _debounceTimer;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();

    // ✅ Inisialisasi controller dengan konfigurasi lengkap
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.unrestricted,
      detectionTimeoutMs: 100,
      returnImage: false,
      torchEnabled: false, // ⭐ Penting untuk flash
    );

    _getCameraPermission();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    cameraController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _getCameraPermission() async {
    final granted = await PermissionHelper.requestCameraPermission(context);
    setState(() {
      hasCameraPermission = granted;
    });
  }

  // ====== UI helpers ======
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
    final code = _lastScannedCode;
    if (code != null && code.isNotEmpty) {
      _processScanResult(code);
    }
  }

  // ====== Core actions ======
  Future<void> _updateLokasi(String labelCode) async {
    setState(() {
      _isSaving = true;
      _saveMessage = 'Mengupdate lokasi...';
      _detailedMessage = 'Label: $labelCode → Lokasi: ${widget.idLokasi}';
      _isSuccess = false;
      _showStatusIndicator = false;
    });

    try {
      final res = await _mappingRepo.updateLabelLocation(
          labelCode: labelCode,
          idLokasi: widget.idLokasi,
          blok: widget.blok ?? ''
      );

      if (res.success) {
        await _audioPlayer.play(AssetSource('sounds/accepted.mp3'));
        _showSuccessStatus(
          'Lokasi berhasil diupdate!',
          res.message.isNotEmpty
              ? res.message
              : 'Label: $labelCode dipindah ke ${widget.idLokasi}',
        );
      } else {
        await _audioPlayer.play(AssetSource('sounds/denied.mp3'));
        _showErrorStatus(
          'Gagal update lokasi',
          res.message.isNotEmpty ? res.message : 'Label: $labelCode',
        );
      }
    } catch (e) {
      await _audioPlayer.play(AssetSource('sounds/denied.mp3'));
      _showErrorStatus('Koneksi/Server error', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _processScanResult(String rawValue) async {
    // anti duplikasi (scan sama beruntun)
    if (rawValue == _lastScannedCode) {
      debugPrint('Duplicate scan ignored.');
      return;
    }
    _lastScannedCode = rawValue;

    // langsung update lokasi (tanpa validasi/konfirmasi)
    await _updateLokasi(rawValue);
  }

  // ====== Build ======
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scanAreaSize = screenWidth * 0.6;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Lokasi ${widget.blok}${widget.idLokasi}',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(
                isFlashOn ? Icons.flash_off : Icons.flash_on,
                color: Colors.black
            ),
            onPressed: () async {
              // ✅ Tambahkan async dan error handling
              try {
                await cameraController.toggleTorch();
                setState(() {
                  isFlashOn = !isFlashOn;
                });
              } catch (e) {
                debugPrint('Error toggling torch: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Flash tidak tersedia pada perangkat ini'),
                      duration: const Duration(seconds: 2),
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
          // ✅ Camera view - gunakan controller yang sama
          if (hasCameraPermission)
            MobileScanner(
              controller: cameraController, // ⭐ Gunakan controller yang sudah dibuat
              scanWindow: Rect.fromCenter(
                center: Offset(screenWidth / 2, screenHeight / 2),
                width: scanAreaSize * 0.95,
                height: scanAreaSize * 0.95,
              ),
              onDetect: (capture) {
                try {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isEmpty) return;

                  // 🔍 Filter hanya QR Code berdasarkan format
                  final qr = barcodes.firstWhere(
                        (b) {
                      final format = b.format.name.toLowerCase();
                      return b.rawValue != null &&
                          b.rawValue!.isNotEmpty &&
                          (format.contains('qr') || format.contains('qrcode'));
                    },
                    orElse: () => Barcode(rawValue: null),
                  );

                  if (qr.rawValue == null) return;
                  final rawValue = qr.rawValue!;

                  // ⚡ Hindari duplikasi & proses cepat
                  if (!_isDetected) {
                    setState(() => _isDetected = true);
                    _animationController.forward(from: 0);

                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
                      if (!mounted) return;
                      setState(() => _isDetected = false);
                      _processScanResult(rawValue);
                    });
                  }
                } catch (e) {
                  debugPrint('❌ Error during barcode detection: $e');
                  _showErrorStatus('Error Scan 📱', 'Terjadi kesalahan saat memproses QR code');
                }
              },
            )
          else
            Center(
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
                    onPressed: _getCameraPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Berikan Izin Kamera', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),

          // Scan area overlay + detection highlight
          Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: scanAreaSize,
              height: scanAreaSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isDetected ? Colors.greenAccent : Colors.white.withOpacity(0.5),
                  width: 3,
                ),
                boxShadow: _isDetected
                    ? [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
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

          // Status indicator (ikon success/error di atas)
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

          // Notification panel (bottom)
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

          // Hint overlay (jika idle)
          if (_saveMessage.isEmpty && !_isSaving)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
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
              ),
            ),
        ],
      ),
    );
  }
}