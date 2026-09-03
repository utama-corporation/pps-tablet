import 'dart:convert';

/// Target printer untuk cetak label — dua varian koneksi:
///
/// * [BtPrinterTarget]      — thermal 80mm via classic Bluetooth (SPP), ESC/POS.
/// * [NetworkPrinterTarget] — label printer (mis. Xprinter XP-D4601B) via TCP
///   RAW port 9100, bahasa TSPL.
///
/// Dipakai oleh [LabelPrinter.forTarget] untuk memilih implementasi cetak, dan
/// diserialisasi ke JSON agar bisa disimpan di SharedPreferences.
sealed class PrinterTarget {
  final String name;
  const PrinterTarget({required this.name});

  /// Identitas unik untuk ditampilkan / dicocokkan: MAC (BT) atau IP (jaringan).
  String get identifier;

  Map<String, dynamic> toJson();

  String encode() => jsonEncode(toJson());

  static PrinterTarget fromJson(Map<String, dynamic> m) {
    switch (m['type']) {
      case 'network':
        return NetworkPrinterTarget(
          host: (m['host'] ?? '').toString(),
          port: (m['port'] as num?)?.toInt() ?? 9100,
          name: (m['name'] ?? m['host'] ?? '').toString(),
          labelWidthMm: (m['labelWidthMm'] as num?)?.toDouble() ?? 100,
          labelHeightMm: (m['labelHeightMm'] as num?)?.toDouble() ?? 150,
          gapMm: (m['gapMm'] as num?)?.toDouble() ?? 2,
          dpi: (m['dpi'] as num?)?.toInt() ?? 203,
        );
      case 'bt':
      default:
        return BtPrinterTarget(
          mac: (m['mac'] ?? '').toString(),
          name: (m['name'] ?? m['mac'] ?? '').toString(),
        );
    }
  }

  static PrinterTarget? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }
}

class BtPrinterTarget extends PrinterTarget {
  final String mac;

  const BtPrinterTarget({required this.mac, required super.name});

  @override
  String get identifier => mac;

  @override
  Map<String, dynamic> toJson() => {'type': 'bt', 'mac': mac, 'name': name};
}

class NetworkPrinterTarget extends PrinterTarget {
  /// IP atau hostname printer, mis. `192.168.11.97`.
  final String host;

  /// Port RAW/JetDirect. Nyaris semua thermal/label printer listen di 9100.
  final int port;

  /// Ukuran label fisik dalam mm — kertas sticker ukurannya tetap, jadi lebar
  /// & panjang di-input manual dan selalu dikirim sebagai perintah TSPL `SIZE`.
  /// Konten tiap halaman di-fit ke kanvas seukuran label ini.
  final double labelWidthMm;
  final double labelHeightMm;

  /// Jarak antar-label (gap) dalam mm — perintah TSPL `GAP`.
  final double gapMm;

  /// Resolusi kepala cetak. XP-D4601B = 203 dpi.
  final int dpi;

  const NetworkPrinterTarget({
    required this.host,
    this.port = 9100,
    required super.name,
    this.labelWidthMm = 100,
    this.labelHeightMm = 150,
    this.gapMm = 2,
    this.dpi = 203,
  });

  @override
  String get identifier => host;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'network',
    'host': host,
    'port': port,
    'name': name,
    'labelWidthMm': labelWidthMm,
    'labelHeightMm': labelHeightMm,
    'gapMm': gapMm,
    'dpi': dpi,
  };
}
