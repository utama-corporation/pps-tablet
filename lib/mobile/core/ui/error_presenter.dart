// lib/core/ui/error_presenter.dart
import 'package:flutter/material.dart';

class ErrorPresenter {
  static void showNetworkOrServerDialog(
    BuildContext context, {
    required String message,
    required String errorType, // network/server
    String? detailCode, // backend_offline/no_route/dns/timeout/server_503...
    VoidCallback? onRetry,
    String? suggestedActionLabel,
    VoidCallback? onSuggestedAction,
  }) {
    if (!context.mounted) return;

    final title = _title(errorType, detailCode);
    final icon = _icon(errorType, detailCode);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (onSuggestedAction != null)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                onSuggestedAction();
              },
              child: Text(suggestedActionLabel ?? 'Gunakan Jaringan Public'),
            ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Coba Lagi'),
            ),
        ],
      ),
    );
  }

  static String _title(String errorType, String? detail) {
    if (detail == 'server_503' || detail == 'maintenance')
      return 'Server Maintenance';
    if (detail == 'backend_offline') return 'Backend Offline';
    if (detail == 'dns') return 'Alamat Server Tidak Ditemukan';
    if (detail == 'no_route') return 'Jaringan Tidak Menjangkau Server';
    if (detail == 'timeout') return 'Server Tidak Merespons';

    if (errorType == 'server') return 'Server Error';
    if (errorType == 'network') return 'Koneksi Bermasalah';
    return 'Terjadi Kesalahan';
  }

  static IconData _icon(String errorType, String? detail) {
    if (detail == 'server_503' || detail == 'maintenance')
      return Icons.build_circle_outlined;
    if (detail == 'backend_offline') return Icons.power_off_outlined;
    if (detail == 'dns') return Icons.dns_outlined;
    if (detail == 'no_route') return Icons.router_outlined;
    if (detail == 'timeout') return Icons.timer_outlined;

    return errorType == 'network'
        ? Icons.wifi_off_rounded
        : Icons.error_outline_rounded;
  }
}
