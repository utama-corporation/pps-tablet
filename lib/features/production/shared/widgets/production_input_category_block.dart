// lib/features/production/shared/widgets/production_input_category_block.dart
//
// Kontainer berborder untuk isi tab input/output produksi.
// Menampilkan konten dengan rounded border bawah + optional summary tile.

import 'package:flutter/material.dart';
import '../utils/format.dart';
import 'production_inline_stat.dart';
import 'section_card.dart';

/// Kotak konten tab — rounded bottom, border warna aksen.
class ProductionInputCategoryBlock extends StatelessWidget {
  final Color color;
  final bool isLoading;
  final String? label;
  final SectionSummary Function()? summaryBuilder;
  final Widget child;

  final bool showBorder;
  final EdgeInsetsGeometry? contentPadding;

  const ProductionInputCategoryBlock({
    super.key,
    required this.color,
    required this.child,
    this.isLoading = false,
    this.label,
    this.summaryBuilder,
    this.showBorder = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final summary = summaryBuilder?.call();

    return Container(
      padding: contentPadding ?? const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: showBorder ? Border.all(color: color.withValues(alpha: 0.32), width: 1.1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading) ...[
            const Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(child: child),
          if (summary != null) ...[
            const SizedBox(height: 10),
            ProductionCategorySummaryTile(summary: summary, accentColor: color),
          ],
        ],
      ),
    );
  }
}

/// Summary tile (Label / Sak / Berat) di bawah content block.
class ProductionCategorySummaryTile extends StatelessWidget {
  final SectionSummary summary;
  final Color accentColor;
  final String sakLabel;
  final bool showBerat;
  final bool showLabel;
  final bool showSak;

  const ProductionCategorySummaryTile({
    super.key,
    required this.summary,
    required this.accentColor,
    this.sakLabel = 'Sak',
    this.showBerat = true,
    this.showLabel = true,
    this.showSak = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          if (showLabel)
            ProductionInlineStat(
              label: 'Label',
              value: '${summary.totalData}',
              color: accentColor,
            ),
          if (showSak) ...[
            if (showLabel) const SizedBox(width: 10),
            ProductionInlineStat(
              label: sakLabel,
              value: '${summary.totalSak}',
              color: accentColor,
            ),
          ],
          if (showBerat) ...[
            if (showLabel || showSak) const SizedBox(width: 10),
            ProductionInlineStat(
              label: 'Berat',
              value: '${num2(summary.totalBerat)} kg',
              color: accentColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder untuk kategori kosong.
class ProductionEmptyCategory extends StatelessWidget {
  final String message;

  const ProductionEmptyCategory({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    );
  }
}

/// Error banner di panel output.
class ProductionOutputErrorBanner extends StatelessWidget {
  final String message;

  const ProductionOutputErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(
        'Sebagian output gagal dimuat:\n$message',
        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
      ),
    );
  }
}

/// Wrapper untuk konten tab output (scrollable child + optional footer).
class ProductionOutputCategoryContent extends StatelessWidget {
  final Widget child;
  final Widget? footer;

  const ProductionOutputCategoryContent({
    super.key,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        if (footer != null) ...[const SizedBox(height: 10), footer!],
      ],
    );
  }
}
