import 'package:flutter/material.dart';
import '../model/stock_opname_label_model.dart';

class StockOpnameExpandableCard extends StatefulWidget {
  final StockOpnameLabel item;

  const StockOpnameExpandableCard({
    super.key,
    required this.item,
  });

  @override
  State<StockOpnameExpandableCard> createState() =>
      _StockOpnameExpandableCardState();
}

class _StockOpnameExpandableCardState extends State<StockOpnameExpandableCard>
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

  String _formatLokasi({String? blok, int? idLokasi}) {
    final hasBlok = blok != null && blok.isNotEmpty;
    final hasId = idLokasi != null && idLokasi > 0;
    if (!hasBlok && !hasId) return '-';
    final sb = StringBuffer();
    if (hasBlok) sb.write(blok);
    if (hasId) sb.write(idLokasi.toString());
    return sb.toString();
  }

  /// ✅ Helper untuk cek apakah label memiliki sak
  bool _hasSak() {
    final label = widget.item.nomorLabel.toUpperCase();
    final labelType = widget.item.labelType.toLowerCase();

    // Cek berdasarkan kategori/labelType
    if (labelType == 'crusher' ||
        labelType == 'bonggolan' ||
        labelType == 'gilingan' ||
        labelType == 'reject') {
      return false;
    }

    // Cek berdasarkan prefix label
    if (label.startsWith('F.') ||   // crusher
        label.startsWith('M.') ||   // bonggolan
        label.startsWith('V.') ||   // gilingan
        label.startsWith('BF.')) {  // reject
      return false;
    }

    return true;
  }

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

                        // Kategori
                        _infoRow(
                          Icons.category,
                          "Kategori",
                          item.labelType.toUpperCase(),
                        ),

                        // ✅ Jumlah Sak - hanya tampil jika hasSak = true
                        if (_hasSak())
                          _infoRow(
                            Icons.inventory_2_rounded,
                            "Jumlah",
                            '${item.jmlhSak}',
                          ),

                        // Berat
                        _infoRow(
                          Icons.monitor_weight,
                          "Berat",
                          '${item.berat.toStringAsFixed(2)} kg',
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

  Widget _buildHeader(dynamic item) => Row(
    children: [
      const Icon(Icons.qr_code_2_rounded,
          color: Color(0xFF2196F3), size: 22),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatLokasi(blok: item.blok, idLokasi: item.idLokasi),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2196F3),
          ),
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
}