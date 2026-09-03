import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../utils/device_printer_service.dart';
import 'label_printer.dart';
import 'label_raster.dart';
import 'printer_target.dart';

/// Jalur cetak label jaringan (Xprinter XP-D4601B dsb), bahasa TSPL2.
///
/// Alur: raster tiap halaman PDF → bitmap 1-bit selebar kepala cetak →
/// perintah `SIZE`/`GAP`/`BITMAP`/`PRINT` → **POST payload ke device-service**
/// yang meneruskannya ke printer:9100 (relay). Tablet tidak lagi socket
/// langsung ke printer — cukup satu jalur firewall VM → printer.
class NetworkTsplPrinter implements LabelPrinter {
  NetworkTsplPrinter(this.target);

  final NetworkPrinterTarget target;

  @override
  Future<bool> printPdf(
    Uint8List pdfBytes, {
    PrintStatus? onStatus,
    PrintError? onError,
  }) async {
    try {
      onStatus?.call('Memproses PDF...');

      // 203 dpi → 8 dot/mm. Kertas sticker berukuran tetap: raster tiap halaman
      // di-fit ke kanvas persis seukuran label. Lebar dot dibulatkan ke /8.
      final dotsPerMm = target.dpi / 25.4;
      final widthDots = ((target.labelWidthMm * dotsPerMm) ~/ 8) * 8;
      final heightDots = (target.labelHeightMm * dotsPerMm).round();
      final wMm = target.labelWidthMm.round();
      final hMm = target.labelHeightMm.round();

      final payload = <int>[];
      var pageCount = 0;
      await for (final page in Printing.raster(
        pdfBytes,
        dpi: target.dpi.toDouble(),
      )) {
        final png = await page.toPng();
        final mono = await Isolate.run(
          () => LabelRaster.processPageFixed(
            png,
            width: widthDots,
            height: heightDots,
          ),
        );
        if (mono == null) continue;
        payload.addAll(_pageCommands(mono, wMm, hMm));
        pageCount++;
      }

      if (pageCount == 0) {
        onError?.call('Tidak ada halaman untuk dicetak.');
        return false;
      }

      debugPrint(
        '🖨️ [TSPL] $pageCount halaman → ${payload.length} bytes, '
        'relay ke ${target.host} (label ${target.labelWidthMm.round()}×'
        '${target.labelHeightMm.round()}mm)',
      );
      onStatus?.call('Mengirim ke server cetak...');
      await DevicePrinterService.relayNetworkPrint(
        ipAddress: target.host,
        bytes: payload,
      );

      onStatus?.call('✅ Terkirim ke printer');
      return true;
    } catch (e) {
      debugPrint('❌ NetworkTsplPrinter relay error: $e');
      onError?.call(
        'Gagal mengirim job cetak ke server (device-service).\n'
        'Pastikan device-service aktif dan bisa menjangkau printer '
        '${target.host}.\n$e',
      );
      return false;
    }
  }

  /// Bangun blok perintah TSPL untuk satu halaman dengan `SIZE` [widthMm]×[heightMm].
  List<int> _pageCommands(MonoRaster mono, int widthMm, int heightMm) {
    final widthBytes = (mono.width + 7) ~/ 8;
    final packed = Uint8List(widthBytes * mono.height);

    // TSPL `BITMAP`: bit = 1 → putih (tidak dicetak), bit = 0 → hitam (tinta).
    // Pixel di luar lebar konten dianggap putih (bit 1).
    for (var y = 0; y < mono.height; y++) {
      final rowBase = y * widthBytes;
      for (var xb = 0; xb < widthBytes; xb++) {
        var b = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xb * 8 + bit;
          final isWhite = x >= mono.width || mono.luma(x, y) >= 128;
          if (isWhite) b |= 0x80 >> bit;
        }
        packed[rowBase + xb] = b;
      }
    }

    final header =
        'SIZE $widthMm mm,$heightMm mm\r\n'
        'GAP ${target.gapMm.toStringAsFixed(0)} mm,0 mm\r\n'
        'DIRECTION 1\r\n'
        'CLS\r\n'
        'BITMAP 0,0,$widthBytes,${mono.height},0,';

    return <int>[
      ...ascii.encode(header),
      ...packed,
      ...ascii.encode('\r\nPRINT 1,1\r\n'),
    ];
  }
}
