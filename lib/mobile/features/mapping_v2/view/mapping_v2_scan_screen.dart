import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import '../../../core/network/api_errors.dart';
import '../repository/mapping_v2_repository.dart';

class MappingV2ScanScreen extends StatefulWidget {
  const MappingV2ScanScreen({
    super.key,
    required this.blok,
    required this.idLokasi,
    this.initialLabelCount = 0,
  });

  final String blok;
  final int idLokasi;
  final int initialLabelCount;

  @override
  State<MappingV2ScanScreen> createState() => _MappingV2ScanScreenState();
}

class _MappingV2ScanScreenState extends State<MappingV2ScanScreen> {
  final MappingV2Repository _repository = MappingV2Repository();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _hasPermission = false;
  bool _isProcessing = false;
  bool _torchEnabled = false;
  String? _lastCode;
  Timer? _releaseTimer;
  late int _scannedCount;

  @override
  void initState() {
    super.initState();
    _scannedCount = widget.initialLabelCount;
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    _scannerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) setState(() => _hasPermission = status.isGranted);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final code = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (code.isEmpty || code == _lastCode) return;
    _lastCode = code;
    _submitLabel(code);
  }

  Future<void> _showManualInput() async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualInputDialog(),
    );
    if (!mounted) return;
    if (label != null && label.isNotEmpty) {
      await _submitLabel(label);
    }
  }

  Future<void> _submitLabel(String labelCode) async {
    if (_isProcessing) return;
    // Body /api/label/update-lokasi wajib berisi labelCode + idLokasi + blok;
    // tanpa idLokasi yang valid request tidak akan pernah berhasil.
    if (widget.idLokasi == 0 || widget.blok.trim().isEmpty) {
      Vibration.vibrate(pattern: [0, 180, 100, 180]);
      _showMessage(
        'Lokasi tidak valid (idLokasi: ${widget.idLokasi}, blok: '
        '${widget.blok.isEmpty ? '-' : widget.blok}), scan dibatalkan.',
        isError: true,
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final result = await _repository.updateLokasi(
        labelCode: labelCode,
        blok: widget.blok,
        idLokasi: widget.idLokasi,
      );
      await Vibration.vibrate(duration: 80);
      unawaited(_audioPlayer.play(AssetSource('sounds/accepted.mp3')));
      if (!mounted) return;
      setState(() => _scannedCount++);
      _showMessage(result.message, isError: false);
    } catch (e) {
      await Vibration.vibrate(pattern: [0, 180, 100, 180]);
      unawaited(_audioPlayer.play(AssetSource('sounds/denied.mp3')));
      if (!mounted) return;
      final message = e is ApiFailure
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      _showMessage(message, isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      _releaseCode();
    }
  }

  void _releaseCode() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(seconds: 2), () {
      _lastCode = null;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text('Scan ${widget.blok}${widget.idLokasi}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_scannedCount label',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Flash',
            onPressed: () async {
              await _scannerController.toggleTorch();
              if (mounted) {
                setState(() => _torchEnabled = !_torchEnabled);
              }
            },
            icon: Icon(_torchEnabled ? Icons.flash_off : Icons.flash_on),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_hasPermission)
            MobileScanner(controller: _scannerController, onDetect: _onDetect)
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography,
                    size: 64,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Izin kamera diperlukan',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _requestCameraPermission,
                    child: const Text('Berikan Izin'),
                  ),
                ],
              ),
            ),
          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_isProcessing)
            ColoredBox(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _showManualInput,
        icon: const Icon(Icons.keyboard),
        label: const Text('Input Manual'),
      ),
    );
  }
}

/// Dialog input manual yang memiliki `TextEditingController`-nya sendiri.
///
/// Controller harus ikut pemilik widget-nya: `showDialog` selesai saat route
/// di-pop, sedangkan animasi keluar masih berjalan, jadi `TextField` di dalam
/// dialog masih hidup. Dispose dari luar (dari `_showManualInput`) memakai
/// controller yang sudah di-dispose saat element EditableText masih aktif, dan
/// itu membuat subtree route dialog gagal di-deactivate.
class _ManualInputDialog extends StatefulWidget {
  const _ManualInputDialog();

  @override
  State<_ManualInputDialog> createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<_ManualInputDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _submit([String? value]) {
    Navigator.of(context).pop((value ?? _controller.text).trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Input Label Manual'),
      content: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          return TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Nomor label',
              hintText: 'Contoh: B.0000013157',
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus label',
                      icon: const Icon(Icons.close),
                      onPressed: _clear,
                    ),
            ),
            onSubmitted: _submit,
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => _submit(),
          child: const Text('Lanjutkan'),
        ),
      ],
    );
  }
}
