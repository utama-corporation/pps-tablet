import 'package:flutter/material.dart';

import '../../core/utils/device_printer_service.dart';

/// Widget tile pemilihan printer yang digunakan secara konsisten
/// di seluruh aplikasi.
///
/// - [printerName] dan [printerMac]: null = belum ada printer terpilih.
/// - [printerId]: id microservice — jika diisi, tile akan otomatis fetch
///   status & printUsage terkini dari API.
/// - [onSelect]: dipanggil saat tombol PILIH/GANTI ditekan.
/// - [disabled]: mencegah interaksi (saat proses berjalan).
/// - [compact]: tampilan ringkas untuk dialog compact.
class PrinterSelectorTile extends StatefulWidget {
  final String? printerName;
  final String? printerMac;
  final String? printerId;
  final VoidCallback? onSelect;
  final bool disabled;
  final bool compact;

  const PrinterSelectorTile({
    super.key,
    this.printerName,
    this.printerMac,
    this.printerId,
    this.onSelect,
    this.disabled = false,
    this.compact = false,
  });

  @override
  State<PrinterSelectorTile> createState() => _PrinterSelectorTileState();
}

class _PrinterSelectorTileState extends State<PrinterSelectorTile> {
  DevicePrinter? _detail;
  bool _fetching = false;

  bool get _hasPrinter =>
      widget.printerMac != null || widget.printerName != null;

  String get _displayName =>
      widget.printerName ??
      widget.printerMac ??
      'Tap PILIH untuk memilih printer';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void didUpdateWidget(PrinterSelectorTile old) {
    super.didUpdateWidget(old);
    // Re-fetch jika printer berubah
    if (old.printerId != widget.printerId) {
      _fetchDetail();
    }
  }

  Future<void> _fetchDetail() async {
    final id = widget.printerId;
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _detail = null);
      return;
    }
    if (mounted) setState(() => _fetching = true);
    try {
      final detail = await DevicePrinterService.getPrinter(id);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
      // Gagal fetch tidak mengganggu UI — tile tetap tampil tanpa status
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact() : _buildFull();
  }

  // ── Variant penuh (pdf_viewer_screen, panel samping) ─────────────────────────

  Widget _buildFull() {
    final bg = _hasPrinter ? Colors.green.shade50 : Colors.amber.shade50;
    final border = _hasPrinter ? Colors.green.shade200 : Colors.amber.shade300;
    final iconBg = _hasPrinter ? Colors.green.shade100 : Colors.amber.shade100;
    final iconColor = _hasPrinter
        ? Colors.green.shade700
        : Colors.amber.shade700;
    final labelColor = _hasPrinter
        ? Colors.green.shade600
        : Colors.amber.shade700;
    final nameColor = _hasPrinter
        ? Colors.green.shade900
        : Colors.amber.shade900;
    final btnBg = _hasPrinter ? Colors.green.shade100 : Colors.amber.shade100;
    final btnFg = _hasPrinter ? Colors.green.shade800 : Colors.amber.shade800;

    // Printer jaringan (IP) tidak lewat Bluetooth — jangan tampilkan ikon BT
    // karena itu menyesatkan operator. `isNetwork` juga_true untuk identifier
    // berbentuk IPv4, jadi tetap aman untuk backend lama.
    final isNetwork = _detail?.isNetwork ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isNetwork ? Icons.lan_rounded : Icons.bluetooth_rounded,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hasPrinter ? 'PRINTER TERPILIH' : 'BELUM ADA PRINTER',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: nameColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_hasPrinter) ...[
                  const SizedBox(height: 4),
                  _buildStatusRow(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.disabled ? null : widget.onSelect,
            style: TextButton.styleFrom(
              backgroundColor: btnBg,
              foregroundColor: btnFg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _hasPrinter ? 'GANTI' : 'PILIH',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ── Variant compact (dialog auto-repeat, bt_auto_print) ───────────────────────

  Widget _buildCompact() {
    final color = _hasPrinter ? Colors.green : Colors.orange;
    final isNetwork = _detail?.isNetwork ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isNetwork ? Icons.lan_rounded : Icons.bluetooth_rounded,
            size: 18,
            color: color.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hasPrinter ? 'PRINTER TERPILIH' : 'BELUM ADA PRINTER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color.shade900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_hasPrinter) ...[
                  const SizedBox(height: 3),
                  _buildStatusRow(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: widget.disabled ? null : widget.onSelect,
            style: TextButton.styleFrom(
              backgroundColor: color.shade100,
              foregroundColor: color.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _hasPrinter ? 'GANTI' : 'PILIH',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status + printUsage row ───────────────────────────────────────────────────

  Widget _buildStatusRow() {
    if (_fetching) {
      return Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Memuat status…',
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
          ),
        ],
      );
    }

    if (_detail == null) return const SizedBox.shrink();

    final status = _detail!.status.toUpperCase();
    final usage = _detail!.printUsage;

    // Warna badge berdasarkan status
    final (badgeBg, badgeFg) = switch (status) {
      'NORMAL' => (Colors.green.shade100, Colors.green.shade800),
      'WARNING' => (Colors.orange.shade100, Colors.orange.shade800),
      'CRITICAL' => (Colors.red.shade100, Colors.red.shade800),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };

    // Warna usage
    final usageFg = switch (status) {
      'NORMAL' => Colors.green.shade700,
      'WARNING' => Colors.orange.shade700,
      'CRITICAL' => Colors.red.shade700,
      _ => Colors.grey.shade600,
    };

    return Row(
      children: [
        // Badge status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: badgeFg,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Print usage
        Icon(Icons.print_outlined, size: 10, color: usageFg),
        const SizedBox(width: 2),
        Text(
          usage,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: usageFg,
          ),
        ),
      ],
    );
  }
}
