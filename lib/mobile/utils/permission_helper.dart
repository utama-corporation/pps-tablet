import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper untuk minta izin kamera dan menampilkan notifikasi jika ditolak.
class PermissionHelper {
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status == PermissionStatus.granted) {
      return true;
    }

    if (status == PermissionStatus.denied && context.mounted) {
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
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }

    return false;
  }
}
