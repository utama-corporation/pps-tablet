// lib/features/production/shared/widgets/production_grand_total_bar.dart
//
// Grand-total bar untuk panel input produksi.
// Menampilkan total Label + Sak + Berat di bagian bawah panel.

import 'package:flutter/material.dart';
import '../utils/format.dart';
import 'production_inline_stat.dart';
import 'production_panel_decoration.dart';

class ProductionInputGrandTotalBar extends StatelessWidget {
  final int totalLabel;

  /// Qty (Sak) — num karena bisa berisi penjumlahan qty cabinet material
  /// (bahan pendukung) yang nilainya bisa desimal.
  final num totalSak;
  final double totalBerat;
  final Color color;
  final String sakLabel;

  const ProductionInputGrandTotalBar({
    super.key,
    required this.totalLabel,
    required this.totalSak,
    required this.totalBerat,
    this.color = kProductionPrimary,
    this.sakLabel = 'Sak',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Icon(Icons.summarize_outlined, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: color,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: sakLabel,
                value: fmtNum(totalSak),
                color: color,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Berat',
                value: '${num2(totalBerat)} kg',
                color: color,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProductionOutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;
  final Color color;

  const ProductionOutputGrandTotalBar({
    super.key,
    required this.totalLabel,
    required this.totalSak,
    required this.totalBerat,
    this.color = kProductionOutput,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            'Total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: color,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Sak',
            value: '$totalSak',
            color: color,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: color,
          ),
        ],
      ),
    );
  }
}
