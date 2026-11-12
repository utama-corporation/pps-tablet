import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../../../constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../model/bj_jual_lookup_model.dart';

enum ScanMode { full, partial }

class BjJualScanScreen extends StatefulWidget {
  final String noBJJual;
  final ScanMode scanMode;

  const BjJualScanScreen({
    super.key,
    required this.noBJJual,
    required this.scanMode,
  });

  @override
  State<BjJualScanScreen> createState() => _BjJualScanScreenState();
}

class _BjJualScanScreenState extends State<BjJualScanScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = ApiClient();
  late final MobileScannerController _cameraController;
  late AnimationController _animationController;

  bool _hasCameraPermission = false;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  bool _isDetected = false;
  String? _lastScannedCode;
  Timer? _debounceTimer;

  // Floating notification state
  String _notifTitle = '';
  String _notifMessage = '';
  bool _notifIsSuccess = false;
  bool _notifIsWarning = false;
  bool _showNotif = false;
  bool _anySaved = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.unrestricted,
      detectionTimeoutMs: 100,
      returnImage: false,
      formats: [BarcodeFormat.qrCode],
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    )..repeat(reverse: true);
    _getCameraPermission();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _hasCameraPermission = status == PermissionStatus.granted);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final qr = capture.barcodes.firstWhere(
      (b) =>
          b.rawValue != null &&
          b.rawValue!.isNotEmpty &&
          b.format == BarcodeFormat.qrCode,
      orElse: () => Barcode(rawValue: null),
    );
    if (qr.rawValue == null) return;
    final raw = qr.rawValue!;
    if (raw == _lastScannedCode) return;

    if (!_isDetected) {
      setState(() => _isDetected = true);
      _animationController.forward(from: 0);
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _isDetected = false);
        _processLabel(raw);
      });
    }
  }

  Future<void> _processLabel(String labelCode) async {
    final prefix =
        labelCode.length >= 3 ? labelCode.substring(0, 3).toUpperCase() : '';
    if (prefix != 'BA.' && prefix != 'BB.') {
      Vibration.vibrate(pattern: [0, 200, 100, 200]);
      _showError('Label tidak valid', 'Hanya label BA. atau BB. yang diterima');
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = labelCode;
    });

    try {
      final response = await _apiClient.getJson(
        ApiConstants.lookupLabel(labelCode),
        useAuth: true,
      );

      final result = LookupLabelResult.fromJson(response);
      final tableName = result.tableName;
      final items = (response['data'] as List<dynamic>? ?? [])
          .map((e) => LookupLabelItem.fromJson(
                e as Map<String, dynamic>,
                tableName: tableName,
              ))
          .toList();

      if (!mounted) return;

      if (items.isEmpty) {
        Vibration.vibrate(pattern: [0, 200, 100, 200]);
        _showError('Label Tidak Ditemukan',
            'Label $labelCode tidak ada atau sudah terpakai');
        return;
      }

      Vibration.vibrate(duration: 80, amplitude: 100);
      final item = items.first;

      if (widget.scanMode == ScanMode.full) {
        // Auto save tanpa konfirmasi
        await _submitSave(item, tableName, item.pcs, isPartial: false);
      } else {
        // Partial: tampilkan sheet edit pcs
        await _showPartialSheet(item, tableName);
      }
    } catch (e) {
      Vibration.vibrate(pattern: [0, 200, 100, 200]);
      _showError(
          'Koneksi Bermasalah', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _lastScannedCode = null);
      });
    }
  }

  Future<void> _submitSave(
    LookupLabelItem item,
    String tableName,
    int pcs, {
    bool isPartial = false,
  }) async {
    final body = _buildBody(item, tableName, pcs, isPartial);
    try {
      await _apiClient.postJson(
        ApiConstants.bjJualInputs(widget.noBJJual),
        body: body,
        useAuth: true,
      );
      _anySaved = true;
      Vibration.vibrate(duration: 100, amplitude: 128);
      _showSuccess(
        isPartial ? 'Partial Berhasil Disimpan' : 'Data Berhasil Disimpan',
        '${item.noLabel} · ${item.namaJenis.length > 40 ? '${item.namaJenis.substring(0, 40)}...' : item.namaJenis}',
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('Tidak ada data') || msg.contains('diproses')) {
        Vibration.vibrate(pattern: [0, 100, 80, 100]);
        _showWarning('Label Sudah Ada', '${item.noLabel} sudah pernah diinput sebelumnya');
      } else {
        rethrow;
      }
    }
  }

  Map<String, dynamic> _buildBody(
    LookupLabelItem item,
    String tableName,
    int pcs,
    bool isPartial,
  ) {
    if (tableName == 'BarangJadi') {
      if (isPartial) {
        return {
          'barangJadiPartial': [
            {'noBJ': item.noLabel, 'pcs': pcs}
          ],
        };
      } else {
        return {
          'barangJadi': [
            {'noBJ': item.noLabel}
          ],
        };
      }
    } else {
      // FurnitureWIP — key pakai kapital WIP sesuai API
      if (isPartial) {
        return {
          'furnitureWipPartial': [
            {'noFurnitureWIP': item.noLabel, 'pcs': pcs}
          ],
        };
      } else {
        return {
          'furnitureWip': [
            {'noFurnitureWIP': item.noLabel}
          ],
        };
      }
    }
  }

  Future<void> _showPartialSheet(
      LookupLabelItem item, String tableName) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PartialInputSheet(
        item: item,
        tableName: tableName,
        noBJJual: widget.noBJJual,
        onSave: (editedPcs) async {
          Navigator.of(ctx).pop();
          await _submitSave(item, tableName, editedPcs, isPartial: true);
        },
      ),
    );
  }

  void _showSuccess(String title, String message) {
    setState(() {
      _notifTitle = title;
      _notifMessage = message;
      _notifIsSuccess = true;
      _notifIsWarning = false;
      _showNotif = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showNotif = false);
    });
  }

  void _showWarning(String title, String message) {
    setState(() {
      _notifTitle = title;
      _notifMessage = message;
      _notifIsSuccess = false;
      _notifIsWarning = true;
      _showNotif = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showNotif = false);
    });
  }

  void _showError(String title, String message) {
    setState(() {
      _notifTitle = title;
      _notifMessage = message;
      _notifIsSuccess = false;
      _notifIsWarning = false;
      _showNotif = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showNotif = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final scanAreaSize = (screen.width * 0.75).clamp(240.0, screen.width - 40);
    final isFull = widget.scanMode == ScanMode.full;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _anySaved) {
          // Signal to caller that data changed
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(_anySaved),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFull ? 'Scan Full' : 'Scan Partial',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.noBJJual,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.white.withOpacity(0.9),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          actions: [
            // Mode badge
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isFull
                    ? Colors.green[100]
                    : Colors.orange[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isFull ? 'FULL' : 'PARTIAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isFull ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isFlashOn ? Icons.flash_off : Icons.flash_on,
                color: Colors.black,
              ),
              onPressed: () async {
                try {
                  await _cameraController.toggleTorch();
                  setState(() => _isFlashOn = !_isFlashOn);
                } catch (_) {}
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_hasCameraPermission)
              MobileScanner(
                controller: _cameraController,
                scanWindow: Rect.fromCenter(
                  center: Offset(screen.width / 2, screen.height / 2),
                  width: scanAreaSize,
                  height: scanAreaSize,
                ),
                onDetect: _onDetect,
              )
            else
              _NoPermissionWidget(onRequest: _getCameraPermission),

            // Overlay loading
            if (_isProcessing)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.45),
                    child: Center(
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4),
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Memproses label...',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
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
                        : Colors.white.withOpacity(0.6),
                    width: 3,
                  ),
                  boxShadow: _isDetected
                      ? [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.4),
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

            // Hint
            if (!_isProcessing && !_showNotif)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFull
                          ? 'Scan label BA. / BB. → simpan otomatis'
                          : 'Scan label BA. / BB. → edit pcs sebelum simpan',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

            // Floating notification
            if (_showNotif)
              Positioned(
                bottom: 40,
                left: 16,
                right: 16,
                child: _FloatingNotif(
                  title: _notifTitle,
                  message: _notifMessage,
                  isSuccess: _notifIsSuccess,
                  isWarning: _notifIsWarning,
                  onDismiss: () => setState(() => _showNotif = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Partial Input Sheet ────────────────────────────────────────────────────

class _PartialInputSheet extends StatefulWidget {
  final LookupLabelItem item;
  final String tableName;
  final String noBJJual;
  final Future<void> Function(int pcs) onSave;

  const _PartialInputSheet({
    required this.item,
    required this.tableName,
    required this.noBJJual,
    required this.onSave,
  });

  @override
  State<_PartialInputSheet> createState() => _PartialInputSheetState();
}

class _PartialInputSheetState extends State<_PartialInputSheet> {
  late final TextEditingController _pcsController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pcsController =
        TextEditingController(text: widget.item.pcs.toString());
  }

  @override
  void dispose() {
    _pcsController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final pcsText = _pcsController.text.trim();
    final pcs = int.tryParse(pcsText);
    if (pcs == null || pcs <= 0) {
      setState(() => _error = 'Masukkan jumlah pcs yang valid (> 0)');
      return;
    }
    if (pcs > widget.item.pcs) {
      setState(
          () => _error = 'Pcs partial tidak boleh melebihi ${widget.item.pcs}');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(pcs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBarangJadi = widget.tableName == 'BarangJadi';
    final themeColor =
        isBarangJadi ? Colors.green[700]! : Colors.orange[700]!;
    final themeBg = isBarangJadi ? Colors.green[50]! : Colors.orange[50]!;
    final fmt = NumberFormat('#,##0.##', 'id_ID');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isBarangJadi
                      ? Icons.inventory_2_outlined
                      : Icons.chair_outlined,
                  color: themeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.noLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    Text(
                      widget.tableName,
                      style: TextStyle(
                        fontSize: 11,
                        color: themeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Nama jenis
          Text(
            widget.item.namaJenis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),

          const SizedBox(height: 10),

          // Info berat + max pcs
          Row(
            children: [
              _infoBadge(
                'Berat',
                '${fmt.format(widget.item.berat)} kg',
                Colors.blue[700]!,
                Colors.blue[50]!,
              ),
              const SizedBox(width: 8),
              _infoBadge(
                'Maks Pcs',
                fmt.format(widget.item.pcs),
                themeColor,
                themeBg,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pcs input
          Text(
            'Jumlah Pcs Partial',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pcsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Masukkan jumlah pcs...',
              errorText: _error,
              suffixText: 'pcs',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan Partial',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(
      String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Floating Notification ─────────────────────────────────────────────────

class _FloatingNotif extends StatelessWidget {
  final String title;
  final String message;
  final bool isSuccess;
  final bool isWarning;
  final VoidCallback onDismiss;

  const _FloatingNotif({
    required this.title,
    required this.message,
    required this.isSuccess,
    this.isWarning = false,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bgColor;
    final IconData icon;
    if (isSuccess) {
      color = Colors.green[700]!;
      bgColor = Colors.green[50]!;
      icon = Icons.check_circle_outline;
    } else if (isWarning) {
      color = Colors.orange[800]!;
      bgColor = Colors.orange[50]!;
      icon = Icons.warning_amber_outlined;
    } else {
      color = Colors.red[700]!;
      bgColor = Colors.red[50]!;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: color),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─── No Permission Widget ──────────────────────────────────────────────────

class _NoPermissionWidget extends StatelessWidget {
  final VoidCallback onRequest;
  const _NoPermissionWidget({required this.onRequest});

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
              backgroundColor: const Color(0xFF0D47A1),
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
