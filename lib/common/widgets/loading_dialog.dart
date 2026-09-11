import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingDialog extends StatelessWidget {
  final String message;

  /// Opsional — kalau di-set, teks pesan ikut berubah live tanpa perlu
  /// tutup-buka dialog lagi (dipakai untuk progress mis. "3 dari 10 label").
  final ValueListenable<String>? messageListenable;

  /// Opsional — kalau di-set (0.0–1.0), tampilkan progress bar di bawah teks.
  final ValueListenable<double>? progressListenable;

  const LoadingDialog({
    Key? key,
    this.message = 'Memproses...',
    this.messageListenable,
    this.progressListenable,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/loading.json',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 16),
            if (messageListenable != null)
              ValueListenableBuilder<String>(
                valueListenable: messageListenable!,
                builder: (_, value, __) => Text(
                  value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              )
            else
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            if (progressListenable != null) ...[
              const SizedBox(height: 12),
              ValueListenableBuilder<double>(
                valueListenable: progressListenable!,
                builder: (_, value, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E6EA),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
