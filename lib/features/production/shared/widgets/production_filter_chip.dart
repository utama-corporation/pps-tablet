import 'package:flutter/material.dart';

/// Chip filter yang bisa dipilih (selected/unselected).
/// Dipakai di riwayat section header untuk filter per-mesin
/// pada semua modul production.
class ProductionFilterChip extends StatelessWidget {
  const ProductionFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFF1D4ED8),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Warna saat aktif. Default biru; layar beraccent lain bisa mengoverride
  /// supaya chip menyatu dengan tema halaman tersebut.
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? selectedColor : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
