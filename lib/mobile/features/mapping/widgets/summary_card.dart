import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final int total;
  final String kategori;
  final String lokasi;
  final num totalQty;
  final double totalBerat;
  final bool showDividers;

  const SummaryCard({
    super.key,
    required this.total,
    required this.kategori,
    required this.lokasi,
    this.totalQty = 0,
    this.totalBerat = 0.0,
    this.showDividers = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox( // bantu full width di berbagai parent
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.15), width: 1.2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final children = <Widget>[
                _summaryItem(
                  icon: Icons.label_rounded,
                  label: 'Total Label',
                  value: '$total',
                  color: const Color(0xFF2196F3),
                ),
                if (showDividers) const _VDivider(),
                _summaryItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Total Qty',
                  value: '$totalQty pcs',
                  color: const Color(0xFF26A69A),
                ),
                if (showDividers) const _VDivider(),
                _summaryItem(
                  icon: Icons.monitor_weight_rounded,
                  label: 'Total Berat',
                  value: '${totalBerat.toStringAsFixed(2)} kg',
                  color: const Color(0xFFEF6C00),
                ),
              ];

              final isNarrow = constraints.maxWidth < 540;
              if (isNarrow) {
                return Wrap(
                  alignment: WrapAlignment.spaceAround,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 20,
                  runSpacing: 12,
                  children: children.where((w) => w is! _VDivider).toList(),
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: children,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
      ],
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.grey.withOpacity(0.3), Colors.transparent],
        ),
      ),
    );
  }
}
