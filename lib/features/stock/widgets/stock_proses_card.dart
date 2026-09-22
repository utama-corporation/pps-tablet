import 'package:flutter/material.dart';

import '../stock_totals.dart';

/// Kartu proses pada grid menu Stock — bergaya sama dengan
/// `ProductionMesinCard` (border hijau, radius 12) tapi tanpa status
/// aktif/nonaktif karena yang direpresentasikan adalah proses, bukan mesin.
/// Menampilkan ringkasan jumlah label & total berat/pcs proses tersebut.
class StockProsesCard extends StatelessWidget {
  const StockProsesCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.totals,
    this.isLoading = false,
    this.hasError = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final StockProsesTotals? totals;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    // return Material(
    //   color: Colors.white,
    //   borderRadius: BorderRadius.circular(12),
    //   elevation: 0,
    return Container(
      width: 100.0,
      //height: 120.0,
      constraints: const BoxConstraints(
        minHeight: 120.0,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: const Color(0xFF0277BD)),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              _buildSummary(),
            ],
          ),
        ),
      ),
    //);
    );
  }

  Widget _buildSummary() {
    if (isLoading) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (hasError || totals == null) {
      return const Text(
        '-',
        style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
      );
    }
    final t = totals!;
    final amountText = t.unit == StockAmountUnit.pcs
        ? '${t.amount.toStringAsFixed(0)} PCS'
        : '${t.amount.toStringAsFixed(2)} kg';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${t.labelSisa} Label',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF059669),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          amountText,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
