import 'package:flutter/material.dart';

import 'home_screen.dart';

/// App shell for the phone: Beranda doubles as the module menu. Feature
/// screens (Stock Opname, Mapping V2, Penjualan BJ, ...) are pushed on top
/// of this shell via Navigator. There is no bottom navigation; the user
/// screen is opened from the profile icon in the Beranda header.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  Future<bool> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin keluar aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit(context) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: const Scaffold(
        body: BerandaTab(),
      ),
    );
  }
}
