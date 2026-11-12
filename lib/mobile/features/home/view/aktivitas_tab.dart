import 'package:flutter/material.dart';

import 'home_screen.dart' show BerandaColors;

/// Aktivitas tab: placeholder until a transaction-history endpoint exists.
/// Kept as an honest empty state rather than fabricated entries.
class AktivitasTab extends StatelessWidget {
  const AktivitasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BerandaColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aktivitas',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: BerandaColors.ink,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: BerandaColors.slate.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: BerandaColors.slate,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada aktivitas',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: BerandaColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Riwayat transaksi dari semua modul akan ditampilkan di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: BerandaColors.slate),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
