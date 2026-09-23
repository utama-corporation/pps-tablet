import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/format.dart';

/// ✅ Model untuk summary total
class SectionSummary {
  final int totalData;  // ✅ Renamed dari totalSak

  /// num karena bisa berisi qty cabinet material (bahan pendukung) desimal.
  final num totalSak;
  final double totalBerat;

  const SectionSummary({
    required this.totalData,  // ✅ NEW
    required this.totalSak,
    required this.totalBerat,
  });
}

class SectionCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final Widget child;
  final bool isLoading;

  /// ✅ NEW: Summary builder untuk info icon
  final SectionSummary Function()? summaryBuilder;

  const SectionCard({
    super.key,
    required this.title,
    required this.count,
    required this.color,
    required this.child,
    this.isLoading = false,
    this.summaryBuilder,
  });

  void _showSummaryPopover(BuildContext context) {
    if (summaryBuilder == null) return;

    final summary = summaryBuilder!();
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => Stack(
        children: [
          // Barrier untuk close
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Popover
          Positioned(
            left: offset.dx + size.width - 260, // Align ke kanan icon
            top: offset.dy + 40, // Di bawah icon
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          color: color,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Keseluruhan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // ✅ Total Data (pindahan dari badge count)
                    _buildSummaryRow(
                      icon: Icons.list_alt_outlined,
                      label: 'Total Label / Partial',
                      value: '${summary.totalData} item',
                      color: color,
                    ),
                    const SizedBox(height: 10),

                    // Total Sak
                    _buildSummaryRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Total Sak',
                      value: '${fmtNum(summary.totalSak)} sak',
                      color: color,
                    ),
                    const SizedBox(height: 10),

                    // Total Berat
                    _buildSummaryRow(
                      icon: Icons.scale_outlined,
                      label: 'Total Berat',
                      value: '${summary.totalBerat.toStringAsFixed(2)} kg',
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= HEADER =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                // Strip kecil warna di kiri
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),

                // Title
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ✅ Info icon (jika ada summaryBuilder)
                if (summaryBuilder != null && !isLoading)
                  InkWell(
                    onTap: () => _showSummaryPopover(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: color,
                      ),
                    ),
                  ),

                // ✅ REMOVED: Badge count tidak ditampilkan lagi di header
              ],
            ),
          ),
          // =================================================

          // Content with loading state
          Expanded(
            child: isLoading ? _buildSkeletonContent() : child,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonContent() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => _buildSkeletonItem(),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}