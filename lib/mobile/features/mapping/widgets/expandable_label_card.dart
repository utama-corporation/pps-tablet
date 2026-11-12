import 'package:flutter/material.dart';
import '../model/label_item.dart';
import '../../../constants/kategori_constants.dart';


class LabelExpandableCard extends StatefulWidget {
  final LabelItem item;
  const LabelExpandableCard({super.key, required this.item});

  @override
  State<LabelExpandableCard> createState() => _LabelExpandableCardState();
}

class _LabelExpandableCardState extends State<LabelExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  String _formatQty(num? v) => v == null ? '-' : '$v pcs';
  String _formatBerat(double? v) =>
      v == null ? '-' : '${v.toStringAsFixed(2)} kg';

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _toggleExpand,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(item),

              /// 🔥 Animasi yang lebih halus dan natural
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                child: _expanded
                    ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        Divider(
                            color: Colors.grey.shade200, height: 10),
                        const SizedBox(height: 6),
                        _infoRow(Icons.date_range_outlined,
                            "Tanggal Terbit", item.dateCreate),
                        _infoRow(Icons.label_outline, "Jenis",
                            item.namaJenis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                                child: _compactInfo(
                                    Icons.category_outlined,
                                    "Kategori",
                                    KategoriConstants.getLabel(item.kategori))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _compactInfo(
                                    Icons.inventory_2_outlined,
                                    "Qty",
                                    _formatQty(item.qty))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _compactInfo(
                                    Icons.monitor_weight_outlined,
                                    "Berat",
                                    _formatBerat(item.berat))),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildHeader(LabelItem item) => Row(
    children: [
      const Icon(Icons.qr_code_2_rounded,
          color: Color(0xFF1565C0), size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          item.nomorLabel,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_rounded,
                size: 14, color: Color(0xFF1565C0)),
            const SizedBox(width: 4),
            Text(
              '${item.blok}${item.idLokasi}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 4),
      Icon(
        _expanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        color: Colors.grey.shade600,
      )
    ],
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label: $value",
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _compactInfo(IconData icon, String label, String value) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.blueGrey.shade600),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
