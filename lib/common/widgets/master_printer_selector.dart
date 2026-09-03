import 'package:flutter/material.dart';

import '../../core/printing/printer_target.dart';
import '../../core/utils/bt_print_service.dart';
import '../../core/utils/device_printer_service.dart';

class PrintOutcome {
  final String id; // microservice printer id
  final String mac;
  final String printerName;

  /// Target cetak konkret (Bluetooth/ESC/POS atau jaringan/TSPL). Kalau tidak
  /// diberikan, default ke Bluetooth berdasarkan [mac] agar kompatibel dengan
  /// pemanggil lama.
  final PrinterTarget target;

  PrintOutcome({
    required this.id,
    required this.mac,
    required this.printerName,
    PrinterTarget? target,
  }) : target =
           target ?? BtPrinterTarget(mac: mac, name: printerName);
}

class MasterPrinterSelector {
  const MasterPrinterSelector._();

  static Future<PrintOutcome?> show({
    required BuildContext context,
    String? currentMac,
  }) {
    return showDialog<PrintOutcome>(
      context: context,
      builder: (_) => _PrinterSelectionDialog(currentMac: currentMac),
    );
  }
}

// ── Dialog ─────────────────────────────────────────────────────────────────────

class _PrinterSelectionDialog extends StatefulWidget {
  final String? currentMac;

  const _PrinterSelectionDialog({this.currentMac});

  @override
  State<_PrinterSelectionDialog> createState() =>
      _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<_PrinterSelectionDialog> {
  bool _loading = true;
  int _tab = 0; // 0 = Bluetooth, 1 = Jaringan
  // Printer terdaftar di microservice (device-service). Pemilih ini read-only —
  // penambahan/pengubahan printer dilakukan lewat aplikasi admin device-service.
  List<DevicePrinter> _registered = [];
  List<DevicePrinter> _network = [];
  String? _errorMsg;

  // Status online/offline printer jaringan (dari TCP probe di microservice).
  Map<String, bool> _online = {};
  bool _pinging = false;

  static NetworkPrinterTarget _targetFromDevice(DevicePrinter d) {
    final n = d.network;
    return NetworkPrinterTarget(
      host: n?.ipAddress ?? d.identifier,
      port: n?.port ?? 9100,
      name: d.name,
      labelWidthMm: n?.labelWidthMm ?? 100,
      labelHeightMm: n?.labelHeightMm ?? 150,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final allDevices = await DevicePrinterService.fetchPrinters();
      if (!mounted) return;

      final network = allDevices.where((p) => p.isNetwork).toList();
      setState(() {
        _registered = allDevices.where((p) => !p.isNetwork).toList();
        _network = network;
        // Seed status dari cache microservice (instan); lalu refresh live.
        _online = {
          for (final d in network)
            if (d.online != null) d.id: d.online!,
        };
        _loading = false;
      });
      _pingNetwork();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = 'Gagal mengambil daftar printer: $e';
      });
    }
  }

  Future<void> _pingNetwork() async {
    if (_network.isEmpty) return;
    setState(() => _pinging = true);
    final result = await DevicePrinterService.pingNetworkPrinters();
    if (!mounted) return;
    setState(() {
      _online = result;
      _pinging = false;
    });
  }

  ({Color color, String label})? _netBadge(String id) {
    final v = _online[id];
    if (v == true) {
      return (color: const Color(0xFF16A34A), label: 'Online');
    }
    if (v == false) {
      return (color: const Color(0xFFDC2626), label: 'Offline');
    }
    if (_pinging) {
      return (color: const Color(0xFF64748B), label: 'Cek…');
    }
    return null;
  }

  Future<void> _selectAndPop(DevicePrinter printer) async {
    // Pengaman: kalau ternyata printer jaringan (mis. muncul di daftar BT karena
    // backend lama), arahkan ke jalur TSPL, jangan kirim sebagai BtPrinterTarget.
    if (printer.isNetwork) {
      await _selectNetworkAndPop(printer);
      return;
    }
    final target = BtPrinterTarget(mac: printer.identifier, name: printer.name);
    await DevicePrinterService.saveDefaultPrinter(printer);
    // Simpan sbg default cetak berikutnya (mekanisme baru, BT + jaringan).
    await DevicePrinterService.saveLastTarget(
      target,
      id: printer.id,
      name: printer.name,
    );
    // Juga simpan ke BtPrintService agar kompatibel dengan alur print lama
    await BtPrintService.savePrinter(
      mac: printer.identifier,
      name: printer.name,
    );
    if (!mounted) return;
    Navigator.pop(
      context,
      PrintOutcome(
        id: printer.id,
        mac: printer.identifier,
        printerName: printer.name,
        target: target,
      ),
    );
  }

  Future<void> _selectNetworkAndPop(DevicePrinter d) async {
    final target = _targetFromDevice(d);
    // Printer jaringan sekarang JUGA tersimpan sebagai default cetak berikutnya.
    await DevicePrinterService.saveLastTarget(target, id: d.id, name: d.name);
    if (!mounted) return;
    Navigator.pop(
      context,
      PrintOutcome(
        id: d.id,
        mac: d.identifier,
        printerName: d.name,
        target: target,
      ),
    );
  }

  static const _kIndigo = Color(0xFF4F46E5);
  static const _kBlue = Color(0xFF2563EB);
  static const _kBorder = Color(0xFFE6E9EF);

  Color get _accent => _tab == 1 ? _kIndigo : _kBlue;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const SizedBox(
        height: 380,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 14),
              Text(
                'Memuat daftar printer…',
                style: TextStyle(color: Colors.grey, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    } else if (_errorMsg != null) {
      body = SizedBox(height: 380, child: _buildError());
    } else {
      body = SizedBox(
        height: 380,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _tab == 0 ? _buildBluetoothTab() : _buildNetworkTab(),
          ),
        ),
      );
    }

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (!_loading && _errorMsg == null) _buildTabBar(),
            body,
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Tambah / ubah printer lewat aplikasi admin device-service',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }


  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final total = _registered.length + _network.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(18, 15, 6, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent, Color.lerp(_accent, const Color(0xFF0B1020), 0.30)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.print_rounded,
              size: 21,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Printer',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _loading
                      ? 'Memuat…'
                      : '$total printer terdaftar di sistem',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Muat ulang',
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Tutup',
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _tabButton(
            0,
            Icons.bluetooth_rounded,
            'Bluetooth',
            _registered.length,
            _kBlue,
          ),
          _tabButton(
            1,
            Icons.lan_rounded,
            'Jaringan',
            _network.length,
            _kIndigo,
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    int idx,
    IconData icon,
    String label,
    int count,
    Color accent,
  ) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? accent : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? accent : Colors.grey.shade600,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? accent.withValues(alpha: 0.12)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? accent : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: _accent.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Muat ulang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: BorderSide(color: _accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Gagal memuat printer',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCurrent(String identifier) =>
      identifier.toUpperCase() == (widget.currentMac?.toUpperCase() ?? '');

  // ── Tab: Bluetooth ────────────────────────────────────────────────────────

  Widget _buildBluetoothTab() {
    if (_registered.isEmpty) {
      return _emptyState(
        icon: Icons.bluetooth_disabled_rounded,
        title: 'Belum ada printer Bluetooth',
        subtitle:
            'Daftarkan printer thermal di aplikasi admin, lalu Muat ulang.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      itemCount: _registered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _registered[i];
        return _PrinterCard(
          accent: _kBlue,
          icon: Icons.print_rounded,
          name: p.name,
          selected: _isCurrent(p.identifier),
          chips: [
            (Icons.bluetooth_rounded, p.identifier),
            (Icons.receipt_long_rounded, p.printUsage),
          ],
          onTap: () => _selectAndPop(p),
        );
      },
    );
  }

  // ── Tab: Jaringan ─────────────────────────────────────────────────────────

  Widget _buildNetworkTab() {
    if (_network.isEmpty) {
      return _emptyState(
        icon: Icons.lan_outlined,
        title: 'Belum ada printer jaringan',
        subtitle:
            'Tambahkan printer label (IP) di aplikasi admin, lalu Muat ulang.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      itemCount: _network.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = _network[i];
        final n = d.network;
        final host = n?.ipAddress ?? d.identifier;
        final w = (n?.labelWidthMm ?? 100).toStringAsFixed(0);
        final h = (n?.labelHeightMm ?? 150).toStringAsFixed(0);
        return _PrinterCard(
          accent: _kIndigo,
          icon: Icons.lan_rounded,
          name: d.name,
          selected: _isCurrent(host),
          badge: _netBadge(d.id),
          chips: [
            (Icons.dns_rounded, host),
            (Icons.crop_free_rounded, '$w × $h mm'),
          ],
          onTap: () => _selectNetworkAndPop(d),
        );
      },
    );
  }
}

// ── Kartu printer (dipakai kedua tab) ────────────────────────────────────────

class _PrinterCard extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String name;
  final bool selected;
  final ({Color color, String label})? badge;
  final List<(IconData, String)> chips;
  final VoidCallback onTap;

  const _PrinterCard({
    required this.accent,
    required this.icon,
    required this.name,
    required this.selected,
    this.badge,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : const Color(0xFFE6E9EF),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 21, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badge!.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: badge!.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    badge!.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: badge!.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final c in chips) _chip(c.$1, c.$2),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? accent : const Color(0xFFCBD5E1),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData ic, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

