// lib/features/production/shared/widgets/production_usage_badge.dart
//
// Badge status pemakaian untuk satu label penerimaan (barang dagang / bahan
// pendukung). Gaya-nya mengikuti badge "Terpakai" di feature label
// (lib/features/label/*/widgets/*_header_table.dart) supaya konsisten.
//
// Untuk `terpakai` ditampilkan juga sisa qty, karena itu informasi yang paling
// dibutuhkan: label masih ada sisa tapi sudah tidak utuh.

import 'package:flutter/material.dart';

import '../../../../core/utils/number_formatter.dart';
import '../models/label_usage_status.dart';

class ProductionUsageBadge extends StatelessWidget {
  const ProductionUsageBadge({
    super.key,
    required this.status,
    this.sisaQty,
  });

  final LabelUsageStatus status;

  /// Sisa qty (stok live). Hanya dipakai saat [status] == terpakai.
  final double? sisaQty;

  // Hijau/abu jadi "belum dipakai" sengaja tidak punya warna sendiri —
  // badge-nya transparan supaya tile tidak ramai untuk label yang masih utuh.
  static const _habisColor = Color(0xFFB71C1C);
  static const _terpakaiColor = Color(0xFFB26A00);
  static const _belumColor = Color(0xFF6B7280);

  static Color colorOf(LabelUsageStatus status) => switch (status) {
    LabelUsageStatus.terpakai => _terpakaiColor,
    LabelUsageStatus.habis => _habisColor,
    LabelUsageStatus.belumDipakai => _belumColor,
  };

  /// Kuantitas terpakai/sisa ikut memakai format PCS yang sama dengan tile
  /// (tanpa angka di belakang koma).
  static String fmtQty(double v) => formatPcsQty(v);

  String get _text {
    if (status != LabelUsageStatus.terpakai) return status.label;
    final sisa = sisaQty;
    if (sisa == null) return status.label;
    return '${status.label} · Sisa ${fmtQty(sisa)} PCS';
  }

  String get _tooltip => switch (status) {
    LabelUsageStatus.terpakai =>
      'Label sudah dipakai sebagian. Data label tidak bisa diubah lagi.',
    LabelUsageStatus.habis => 'Label sudah habis dipakai. Data label tidak bisa diubah lagi.',
    LabelUsageStatus.belumDipakai => 'Label belum dipakai.',
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(status);
    return Tooltip(
      message: _tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          _text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}