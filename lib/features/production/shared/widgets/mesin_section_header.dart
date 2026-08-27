import 'package:flutter/material.dart';

import 'production_stat_badge.dart';

class MesinSectionHeader extends StatelessWidget {
  const MesinSectionHeader({
    super.key,
    required this.title,
    required this.activeCount,
    required this.inactiveCount,
    required this.isLoading,
    this.pendingCount = 0,
    this.alwaysShowPending = false,
  });

  final String title;
  final int activeCount;
  final int pendingCount;
  final int inactiveCount;
  final bool isLoading;

  /// Saat true, badge Pending tetap tampil walau [pendingCount] = 0 (mis.
  /// modul yang punya konsep pending sebagai kategori tetap, bukan cuma
  /// muncul saat ada datanya). Default false supaya modul lain yang tidak
  /// pernah kirim [pendingCount] tidak ikut menampilkan badge "0 Pending".
  final bool alwaysShowPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          if (!isLoading) ...[
            const SizedBox(width: 10),
            ProductionStatBadge(
              count: activeCount,
              label: 'Aktif',
              color: const Color(0xFF16A34A),
              bg: const Color(0xFFDCFCE7),
            ),
            if (pendingCount > 0 || alwaysShowPending) ...[
              const SizedBox(width: 6),
              ProductionStatBadge(
                count: pendingCount,
                label: 'Pending',
                color: const Color(0xFFB45309),
                bg: const Color(0xFFFEF3C7),
              ),
            ],
            const SizedBox(width: 6),
            ProductionStatBadge(
              count: inactiveCount,
              label: 'Tidak Aktif',
              color: const Color(0xFFDC2626),
              bg: const Color(0xFFFEE2E2),
            ),
          ],
        ],
      ),
    );
  }
}
