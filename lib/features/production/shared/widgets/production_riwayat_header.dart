import 'package:flutter/material.dart';

import 'production_filter_chip.dart';

class MesinFilterItem {
  final int idMesin;
  final String namaMesin;

  const MesinFilterItem({required this.idMesin, required this.namaMesin});
}

class ProductionRiwayatHeader extends StatelessWidget {
  const ProductionRiwayatHeader({
    super.key,
    required this.mesinList,
    required this.selectedIdMesin,
    required this.onFilterChanged,
    this.onToggle,
    this.isExpanded = true,
    this.showTitle = true,
    this.showSemuaChip = true,
    this.title = 'Riwayat Produksi',
  });

  /// Judul section (default "Riwayat Produksi"). Modul non-produksi bisa
  /// menggantinya, mis. "Riwayat Penerimaan".
  final String title;

  final List<MesinFilterItem> mesinList;
  final int? selectedIdMesin;
  final ValueChanged<int?> onFilterChanged;
  final VoidCallback? onToggle;
  final bool isExpanded;

  /// Set false when this header sits under an outer panel header/tab
  /// switcher that already shows the section title, so the title row
  /// isn't duplicated.
  final bool showTitle;

  /// Set false when the "Semua" reset chip is rendered elsewhere (rare —
  /// normally kept alongside the per-mesin chip row even if [showTitle]
  /// is false).
  final bool showSemuaChip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle)
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    if (onToggle != null) ...[
                      Tooltip(
                        message: 'Sembunyikan Riwayat',
                        waitDuration: const Duration(milliseconds: 400),
                        child: IconButton(
                          onPressed: onToggle,
                          icon: const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            size: 16,
                          ),
                          color: const Color(0xFF9CA3AF),
                          hoverColor: const Color(0xFFEFF6FF),
                          highlightColor: const Color(0xFFDBEAFE),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (showSemuaChip) ...[
                      const SizedBox(width: 10),
                      ProductionFilterChip(
                        label: 'Semua',
                        selected: selectedIdMesin == null,
                        onTap: () => onFilterChanged(null),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (mesinList.isNotEmpty || (!showTitle && showSemuaChip))
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                children: [
                  if (!showTitle && showSemuaChip)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ProductionFilterChip(
                        label: 'Semua',
                        selected: selectedIdMesin == null,
                        onTap: () => onFilterChanged(null),
                      ),
                    ),
                  ...mesinList.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ProductionFilterChip(
                        label: m.namaMesin,
                        selected: selectedIdMesin == m.idMesin,
                        onTap: () => onFilterChanged(m.idMesin),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
